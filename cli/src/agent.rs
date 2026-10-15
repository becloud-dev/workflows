//! Every agent call of the CLI goes through [`Agent::call`]. It spawns a pinned `claude -p
//! --restricted` with one tool (`Read`), its own settings and a JSON schema. The working directory
//! holds only the input files, stdin is `/dev/null`, and the environment is cleared down to
//! [`PASSED_ENV`], so no GitHub token reaches the agent. The output is validated against the schema
//! and the caller's rules; a missing or refused output is retried once, naming every reason.

use anyhow::{Context, Result};
use serde::Serialize;
use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU32, Ordering};

/// The only variables of the CLI's environment the agent process gets.
pub const PASSED_ENV: [&str; 5] = ["PATH", "HOME", "TMPDIR", "LANG", "CLAUDE_CODE_OAUTH_TOKEN"];

/// Passed with `--settings`. `--restricted` reads no user, project or local settings file; this
/// turns hooks off as well, in case a managed settings file on the machine defines some.
pub const SETTINGS: &str = r#"{"disableAllHooks":true}"#;

const ATTEMPTS: u32 = 2;

/// The `claude` binary to run and the environment it may take variables from.
pub struct Agent {
    pub program: PathBuf,
    pub parent_env: Vec<(String, String)>,
}

/// One agent call: a role, its prompt, its output schema, the files it may read and where it runs.
pub struct Request<'a> {
    pub role: &'a str,
    pub model: &'a str,
    pub prompt: &'a str,
    pub schema: &'a Value,
    /// Input files, written to a fresh working directory; only for a call without `scope.cwd`.
    pub files: &'a [(&'a str, Vec<u8>)],
    pub scope: Scope<'a>,
}

/// What a call may use and where it runs. `--restricted` confines the file tools to the working
/// directory and `add_dirs`, and leaves writes to settings, git and tool-configuration files to a
/// person, which `dontAsk` refuses.
pub struct Scope<'a> {
    /// The built-in tools the call has (`--tools`).
    pub tools: &'a [&'a str],
    /// The permission rules it may use without asking (`--allowedTools`).
    pub allow: &'a [&'a str],
    /// The working directory; `None` is a fresh directory holding only the input files.
    pub cwd: Option<&'a Path>,
    /// Further directories the file tools may reach (`--add-dir`).
    pub add_dirs: &'a [&'a Path],
}

impl Scope<'static> {
    /// A judging call: `Read` only, in a fresh directory holding only its input files.
    pub const READ_ONLY: Scope<'static> = Scope {
        tools: &["Read"],
        allow: &["Read"],
        cwd: None,
        add_dirs: &[],
    };
}

/// What one run of `claude` did; the run record keeps every attempt.
#[derive(Debug, Clone, Serialize)]
pub struct Attempt {
    pub role: String,
    pub attempt: u32,
    pub exit_code: Option<i32>,
    /// `ok`, `retry` (refused, asked again), `refused` (refused on the last attempt) or `failed`
    /// (`claude` failed; not retried).
    pub outcome: String,
    pub reasons: Vec<String>,
    pub is_error: Option<bool>,
    pub subtype: Option<String>,
    pub num_turns: u64,
    pub duration_ms: u64,
    pub duration_api_ms: u64,
    pub total_cost_usd: f64,
    pub permission_denials: Vec<Value>,
    pub model_usage: Value,
}

/// The attempts made, and the validated output or every reason it was refused.
pub struct Outcome {
    pub attempts: Vec<Attempt>,
    pub output: Result<Value, Vec<String>>,
}

impl Agent {
    /// `claude` from `PATH`, with the CLI's own environment as the source of [`PASSED_ENV`].
    pub fn from_env() -> Self {
        Agent {
            program: PathBuf::from("claude"),
            parent_env: std::env::vars().collect(),
        }
    }

    /// Runs the call, retrying once when the output is missing, breaks the schema or breaks one
    /// of `rules` (each returned string names a broken rule). A `claude` that exits non-zero or
    /// prints no result is not retried. An error means `claude` could not be started at all.
    pub fn call(&self, req: &Request, rules: &dyn Fn(&Value) -> Vec<String>) -> Result<Outcome> {
        let validator = jsonschema::validator_for(req.schema)
            .map_err(|e| anyhow::anyhow!("the {} schema is not valid: {e}", req.role))?;
        let schema = serde_json::to_string(req.schema)?;
        if req.scope.cwd.is_some() && !req.files.is_empty() {
            anyhow::bail!(
                "the {} call runs in a given directory; its inputs go in an added directory",
                req.role
            );
        }
        let dir = WorkDir::new(req.files)?;
        let cwd = req.scope.cwd.unwrap_or(dir.path());
        let mut attempts = Vec::new();
        let mut reasons: Vec<String> = Vec::new();
        for n in 1..=ATTEMPTS {
            let prompt = if n == 1 {
                req.prompt.to_string()
            } else {
                retry_prompt(req.prompt, &reasons)
            };
            let out = Command::new(&self.program)
                .args(args(req.model, &prompt, &schema, &req.scope))
                .current_dir(cwd)
                .env_clear()
                .envs(self.passed_env())
                .env("DISABLE_AUTOUPDATER", "1")
                .stdin(Stdio::null())
                .output()
                .with_context(|| format!("cannot run {}", self.program.display()))?;
            let result: Option<Value> = serde_json::from_slice(&out.stdout)
                .ok()
                .filter(|v: &Value| v.get("type").and_then(Value::as_str) == Some("result"));
            let mut attempt = Attempt::new(req.role, n, out.status.code(), result.as_ref());

            let fatal = match (&result, out.status.success()) {
                (_, false) => Some(format!(
                    "claude exited with {}: {}",
                    out.status
                        .code()
                        .map_or("a signal".into(), |c| c.to_string()),
                    tail(&out.stderr)
                )),
                (None, true) => Some(format!(
                    "claude printed no result JSON: {}",
                    tail(&out.stderr)
                )),
                _ => None,
            };
            if let Some(reason) = fatal {
                attempt.outcome = "failed".into();
                attempt.reasons = vec![reason.clone()];
                attempts.push(attempt);
                return Ok(Outcome {
                    attempts,
                    output: Err(vec![reason]),
                });
            }

            let structured = result
                .as_ref()
                .and_then(|r| r.get("structured_output"))
                .filter(|v| !v.is_null());
            reasons = match structured {
                None => vec![format!(
                    "no structured output (subtype {})",
                    attempt.subtype.as_deref().unwrap_or("none")
                )],
                Some(output) => {
                    let schema_errors: Vec<String> = validator
                        .iter_errors(output)
                        .map(|e| format!("schema: at '{}': {e}", e.instance_path()))
                        .collect();
                    if schema_errors.is_empty() {
                        rules(output)
                    } else {
                        schema_errors
                    }
                }
            };
            if reasons.is_empty() {
                attempt.outcome = "ok".into();
                attempts.push(attempt);
                return Ok(Outcome {
                    attempts,
                    output: Ok(structured.cloned().unwrap_or_default()),
                });
            }
            attempt.outcome = if n < ATTEMPTS { "retry" } else { "refused" }.into();
            attempt.reasons = reasons.clone();
            attempts.push(attempt);
        }
        Ok(Outcome {
            attempts,
            output: Err(reasons),
        })
    }

    fn passed_env(&self) -> impl Iterator<Item = (&str, &str)> {
        self.parent_env
            .iter()
            .filter(|(k, _)| PASSED_ENV.contains(&k.as_str()))
            .map(|(k, v)| (k.as_str(), v.as_str()))
    }
}

/// The arguments of every agent call; the prompt, schema and scope are the call's own.
pub fn args(model: &str, prompt: &str, schema: &str, scope: &Scope) -> Vec<String> {
    let mut a: Vec<String> = [
        "-p",
        prompt,
        "--model",
        model,
        "--restricted",
        "--tools",
        &scope.tools.join(","),
        "--allowedTools",
        &scope.allow.join(","),
    ]
    .map(String::from)
    .to_vec();
    for d in scope.add_dirs {
        a.push("--add-dir".into());
        a.push(d.to_string_lossy().into_owned());
    }
    a.extend(
        [
            "--permission-mode",
            "dontAsk",
            "--strict-mcp-config",
            "--settings",
            SETTINGS,
            "--json-schema",
            schema,
            "--output-format",
            "json",
            "--no-session-persistence",
        ]
        .map(String::from),
    );
    a
}

fn retry_prompt(prompt: &str, reasons: &[String]) -> String {
    let mut p = format!(
        "{prompt}\n\nYour previous answer was refused for the reasons below. Answer again, \
         fixing every one of them:\n"
    );
    for r in reasons {
        p.push_str(&format!("- {r}\n"));
    }
    p
}

fn tail(bytes: &[u8]) -> String {
    let s = String::from_utf8_lossy(bytes);
    let s = s.trim();
    let start = s.char_indices().rev().nth(499).map_or(0, |(i, _)| i);
    if s.is_empty() {
        "no output on stderr".into()
    } else {
        s[start..].to_string()
    }
}

impl Attempt {
    fn new(role: &str, attempt: u32, exit_code: Option<i32>, result: Option<&Value>) -> Self {
        let r = result.cloned().unwrap_or(Value::Null);
        let u = |k: &str| r.get(k).and_then(Value::as_u64).unwrap_or(0);
        Attempt {
            role: role.into(),
            attempt,
            exit_code,
            outcome: String::new(),
            reasons: Vec::new(),
            is_error: r.get("is_error").and_then(Value::as_bool),
            subtype: r.get("subtype").and_then(Value::as_str).map(String::from),
            num_turns: u("num_turns"),
            duration_ms: u("duration_ms"),
            duration_api_ms: u("duration_api_ms"),
            total_cost_usd: r
                .get("total_cost_usd")
                .and_then(Value::as_f64)
                .unwrap_or(0.0),
            permission_denials: r
                .get("permission_denials")
                .and_then(Value::as_array)
                .map(|d| {
                    d.iter()
                        .map(|x| {
                            let input = x
                                .get("tool_input")
                                .map(Value::to_string)
                                .unwrap_or_default();
                            serde_json::json!({
                                "tool_name": x.get("tool_name"),
                                "tool_input": input.chars().take(300).collect::<String>(),
                            })
                        })
                        .collect()
                })
                .unwrap_or_default(),
            model_usage: r
                .get("modelUsage")
                .cloned()
                .unwrap_or(Value::Object(Default::default())),
        }
    }
}

/// A fresh directory holding only the call's input files; removed when dropped.
struct WorkDir(PathBuf);

impl WorkDir {
    fn new(files: &[(&str, Vec<u8>)]) -> Result<Self> {
        static SEQ: AtomicU32 = AtomicU32::new(0);
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_or(0, |d| d.subsec_nanos());
        let path = std::env::temp_dir().join(format!(
            "wf-call-{}-{nanos}-{}",
            std::process::id(),
            SEQ.fetch_add(1, Ordering::Relaxed)
        ));
        std::fs::create_dir(&path).with_context(|| format!("cannot create {}", path.display()))?;
        let dir = WorkDir(path);
        for (name, body) in files {
            let target = dir.0.join(name);
            anyhow::ensure!(
                target.parent() == Some(dir.0.as_path()),
                "input file name '{name}' is not a plain file name"
            );
            std::fs::write(&target, body)
                .with_context(|| format!("cannot write {}", target.display()))?;
        }
        Ok(dir)
    }

    fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for WorkDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_judging_call_is_restricted_to_read_with_its_own_settings() {
        let a = args("m", "the prompt", "{}", &Scope::READ_ONLY);
        let joined = a.join(" ");
        for flag in [
            "--restricted",
            "--tools Read",
            "--allowedTools Read",
            "--permission-mode dontAsk",
            "--strict-mcp-config",
            "--output-format json",
            "--no-session-persistence",
        ] {
            assert!(joined.contains(flag), "missing {flag}");
        }
        assert_eq!(a[0..2], ["-p", "the prompt"]);
        let settings = a.iter().position(|x| x == "--settings").unwrap();
        assert_eq!(a[settings + 1], SETTINGS);
        assert!(!joined.contains("--setting-sources"));
        assert!(!joined.contains("--bare"));
        assert!(!joined.contains("--add-dir"));
    }

    #[test]
    fn a_wider_scope_names_its_tools_rules_and_added_directories() {
        let inputs = Path::new("/tmp/inputs");
        let scope = Scope {
            tools: &["Read", "Bash"],
            allow: &["Read", "Bash(git add:*)"],
            cwd: Some(Path::new("/repo")),
            add_dirs: &[inputs],
        };
        let a = args("m", "p", "{}", &scope);
        let at = |flag: &str| a.iter().position(|x| x == flag).unwrap();
        assert_eq!(a[at("--tools") + 1], "Read,Bash");
        assert_eq!(a[at("--allowedTools") + 1], "Read,Bash(git add:*)");
        assert_eq!(a[at("--add-dir") + 1], "/tmp/inputs");
        // still restricted, never asking, never bypassing
        assert!(a.contains(&"--restricted".to_string()));
        assert_eq!(a[at("--permission-mode") + 1], "dontAsk");
    }

    #[test]
    fn the_retry_prompt_names_every_reason() {
        let p = retry_prompt("Do it.", &["rule one".into(), "rule two".into()]);
        assert!(p.starts_with("Do it.\n\n"));
        assert!(p.contains("- rule one\n- rule two\n"));
    }

    #[test]
    fn an_input_file_name_cannot_leave_the_work_dir() {
        assert!(WorkDir::new(&[("../x.json", vec![])]).is_err());
        assert!(WorkDir::new(&[("sub/x.json", vec![])]).is_err());
    }

    #[test]
    fn tail_keeps_the_last_500_characters() {
        let long = "é".repeat(600);
        assert_eq!(tail(long.as_bytes()).chars().count(), 500);
        assert_eq!(tail(b"  "), "no output on stderr");
    }
}

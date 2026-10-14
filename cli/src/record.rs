//! The run record of a stage: the fields of the `record-run` action, every agent call attempt, and
//! the tokens per model the stage used, so the cost on another provider can be inferred later.

use crate::agent::Attempt;
use anyhow::{Context, Result};
use serde::Serialize;
use serde_json::Value;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

#[derive(Debug, Default, Clone, PartialEq, Serialize)]
pub struct Tokens {
    pub input: u64,
    pub output: u64,
    pub cache_read_input: u64,
    pub cache_creation_input: u64,
}

#[derive(Debug, Serialize)]
pub struct RunRecord {
    pub ts: String,
    pub repo: String,
    pub workflow: String,
    pub stage: String,
    pub issue_or_pr: String,
    pub run_id: String,
    pub run_attempt: String,
    pub model: String,
    /// `oauth_token` when `CLAUDE_CODE_OAUTH_TOKEN` is set, `login` otherwise.
    pub auth: String,
    pub ok: bool,
    pub total_cost_usd: f64,
    pub tokens: BTreeMap<String, Tokens>,
    pub calls: Vec<Attempt>,
}

impl RunRecord {
    /// A record for `stage`, with the run's identity read from the GitHub Actions variables
    /// (empty outside a runner).
    pub fn new(stage: &str, model: &str, issue_or_pr: &str, env: &[(String, String)]) -> Self {
        let var = |k: &str| {
            env.iter()
                .find(|(n, _)| n == k)
                .map(|(_, v)| v.clone())
                .unwrap_or_default()
        };
        let has_token = !var("CLAUDE_CODE_OAUTH_TOKEN").is_empty();
        RunRecord {
            ts: utc_now(),
            repo: var("GITHUB_REPOSITORY"),
            workflow: var("GITHUB_WORKFLOW"),
            stage: stage.into(),
            issue_or_pr: issue_or_pr.into(),
            run_id: var("GITHUB_RUN_ID"),
            run_attempt: var("GITHUB_RUN_ATTEMPT"),
            model: model.into(),
            auth: if has_token { "oauth_token" } else { "login" }.into(),
            ok: false,
            total_cost_usd: 0.0,
            tokens: BTreeMap::new(),
            calls: Vec::new(),
        }
    }

    /// Adds the attempts of one call, summing their tokens per model into the stage's totals.
    pub fn add(&mut self, attempts: &[Attempt]) {
        for a in attempts {
            self.total_cost_usd += a.total_cost_usd;
            if let Some(models) = a.model_usage.as_object() {
                for (model, u) in models {
                    let n = |k: &str| u.get(k).and_then(Value::as_u64).unwrap_or(0);
                    let t = self.tokens.entry(model.clone()).or_default();
                    t.input += n("inputTokens");
                    t.output += n("outputTokens");
                    t.cache_read_input += n("cacheReadInputTokens");
                    t.cache_creation_input += n("cacheCreationInputTokens");
                }
            }
            self.calls.push(a.clone());
        }
    }

    /// Writes `run-record-<stage>.json` in `dir` and returns its path.
    pub fn write(&self, dir: &Path) -> Result<PathBuf> {
        let safe: String = self
            .stage
            .chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || "._-".contains(c) {
                    c
                } else {
                    '_'
                }
            })
            .collect();
        let path = dir.join(format!("run-record-{safe}.json"));
        std::fs::write(&path, serde_json::to_vec_pretty(self)?)
            .with_context(|| format!("cannot write {}", path.display()))?;
        Ok(path)
    }
}

/// The current time as `YYYY-MM-DDTHH:MM:SSZ`, as `date -u +%FT%TZ` prints it.
fn utc_now() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_secs());
    format_utc(secs)
}

fn format_utc(secs: u64) -> String {
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    // Civil date from days since 1970-01-01 (H. Hinnant's days_from_civil, inverted).
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i64::from(m <= 2);
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3_600,
        rem % 3_600 / 60,
        rem % 60
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn utc_dates_match_date_u() {
        assert_eq!(format_utc(0), "1970-01-01T00:00:00Z");
        assert_eq!(format_utc(951_782_400), "2000-02-29T00:00:00Z");
        // 2026-10-13T19:46:10Z, the triage run of #82
        assert_eq!(format_utc(1_791_920_770), "2026-10-13T19:46:10Z");
    }

    #[test]
    fn auth_says_which_credential_the_run_had() {
        let env = vec![("CLAUDE_CODE_OAUTH_TOKEN".to_string(), "x".to_string())];
        assert_eq!(RunRecord::new("s", "m", "i", &env).auth, "oauth_token");
        assert_eq!(RunRecord::new("s", "m", "i", &[]).auth, "login");
    }
}

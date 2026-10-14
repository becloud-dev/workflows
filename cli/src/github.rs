//! Reads the GitHub REST API through `gh api`, so the build carries no HTTP stack and the tests stub
//! `gh` as the workflow suites do. `gh` takes its token from the CLI's own environment (`GH_TOKEN`);
//! the agent calls never see it (see `agent`).

use anyhow::{Context, Result, bail};
use serde_json::Value;
use std::path::PathBuf;
use std::process::{Command, Stdio};

pub struct Gh {
    pub program: PathBuf,
}

impl Gh {
    pub fn from_env() -> Self {
        Gh {
            program: PathBuf::from("gh"),
        }
    }

    /// GETs every page of the list at `path` (`gh api --paginate --slurp` wraps the pages in one
    /// array) and returns their items in order.
    pub fn list(&self, path: &str) -> Result<Vec<Value>> {
        let out = Command::new(&self.program)
            .args(["api", "--paginate", "--slurp", path])
            .stdin(Stdio::null())
            .output()
            .with_context(|| format!("cannot run {}", self.program.display()))?;
        if !out.status.success() {
            bail!(
                "gh api {path} failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            );
        }
        let pages: Vec<Value> = serde_json::from_slice(&out.stdout)
            .with_context(|| format!("gh api {path} did not print a JSON array of pages"))?;
        let mut items = Vec::new();
        for page in pages {
            match page {
                Value::Array(page) => items.extend(page),
                _ => bail!("gh api {path} returned a page that is not a list"),
            }
        }
        Ok(items)
    }

    /// GETs one object at `path`.
    pub fn get(&self, path: &str) -> Result<Value> {
        let out = self.api(&[path])?;
        if !out.status.success() {
            bail!(
                "gh api {path} failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            );
        }
        serde_json::from_slice(&out.stdout)
            .with_context(|| format!("gh api {path} did not print JSON"))
    }

    /// Whether `path` answers: a 404 is `false`, any other failure is an error.
    pub fn exists(&self, path: &str) -> Result<bool> {
        let out = self.api(&[path])?;
        if out.status.success() {
            return Ok(true);
        }
        let stderr = String::from_utf8_lossy(&out.stderr);
        if stderr.contains("404") {
            return Ok(false);
        }
        bail!("gh api {path} failed: {}", stderr.trim())
    }

    /// Posts a comment on an issue or pull request.
    pub fn comment(&self, repo: &str, issue: u64, body: &str) -> Result<()> {
        let path = format!("repos/{repo}/issues/{issue}/comments");
        let field = format!("body={body}");
        let out = self.api(&["-X", "POST", &path, "-f", &field])?;
        if !out.status.success() {
            bail!(
                "gh api POST {path} failed: {}",
                String::from_utf8_lossy(&out.stderr).trim()
            );
        }
        Ok(())
    }

    fn api(&self, args: &[&str]) -> Result<std::process::Output> {
        Command::new(&self.program)
            .arg("api")
            .args(args)
            .stdin(Stdio::null())
            .output()
            .with_context(|| format!("cannot run {}", self.program.display()))
    }
}

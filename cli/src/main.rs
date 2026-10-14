use becloud_workflows::agent::Agent;
use becloud_workflows::executor::{gate, publish, scope};
use becloud_workflows::github::Gh;
use becloud_workflows::planner::backlog;
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use std::process::ExitCode;

/// Runs the steps of the becloud-dev workflows.
#[derive(Parser)]
#[command(name = "wf", version)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// The planners; they write nothing on GitHub.
    #[command(subcommand)]
    Planner(Planner),
    /// The deterministic steps of the development executor.
    #[command(subcommand)]
    Executor(Executor),
}

#[derive(Subcommand)]
enum Planner {
    /// Order the open issues of a repository and report parents, blockers, duplicates and gaps.
    Backlog {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        model: String,
        /// Directory for the input, the report, the step summary and the run record.
        #[arg(long)]
        out: PathBuf,
    },
}

#[derive(Subcommand)]
enum Executor {
    /// Read an `/approve` comment: refuse it with a reply, or pin the plan it approves.
    /// The comment body is read from the environment variable `COMMENT_BODY`.
    Gate {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        issue: u64,
        /// Comma-separated logins that may have written the issue.
        #[arg(long)]
        owners: String,
        /// Where the plan comment's body is written.
        #[arg(long)]
        plan_file: PathBuf,
        /// The file the step outputs are appended to (`$GITHUB_OUTPUT`).
        #[arg(long)]
        github_output: PathBuf,
    },
    /// Check the round's deletions and workflow changes against the plan's Files list.
    Scope {
        /// The checkout the round worked in.
        #[arg(long, default_value = ".")]
        repo_dir: PathBuf,
        /// The commit the round started from.
        #[arg(long)]
        base: String,
        #[arg(long)]
        plan_file: PathBuf,
        /// The round's results file; the section is appended.
        #[arg(long)]
        results: PathBuf,
        /// The file the step outputs are appended to (`$GITHUB_OUTPUT`).
        #[arg(long)]
        github_output: PathBuf,
    },
    /// Judge a bundle against the plan that was approved, before anything is pushed.
    PublishCheck {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        issue: u64,
        /// The comment ID the gate pinned.
        #[arg(long)]
        plan_comment_id: u64,
        /// The body hash the gate pinned.
        #[arg(long)]
        plan_sha256: String,
        /// The commit the rounds started from.
        #[arg(long)]
        base: String,
        /// The bare git directory the bundle was fetched into (`refs/push/head` is its tip).
        #[arg(long)]
        git_dir: PathBuf,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let result = match cli.command {
        Command::Executor(Executor::Gate {
            repo,
            issue,
            owners,
            plan_file,
            github_output,
        }) => {
            let body = std::env::var("COMMENT_BODY").unwrap_or_default();
            gate::run(
                &Gh::from_env(),
                &repo,
                issue,
                &body,
                &owners,
                &plan_file,
                &github_output,
            )
        }
        Command::Executor(Executor::Scope {
            repo_dir,
            base,
            plan_file,
            results,
            github_output,
        }) => scope::run(&repo_dir, &base, &plan_file, &results, &github_output),
        Command::Executor(Executor::PublishCheck {
            repo,
            issue,
            plan_comment_id,
            plan_sha256,
            base,
            git_dir,
        }) => publish::run(
            &Gh::from_env(),
            &repo,
            issue,
            &publish::Pin {
                comment_id: plan_comment_id,
                sha256: &plan_sha256,
            },
            &base,
            &git_dir,
        ),
        Command::Planner(Planner::Backlog { repo, model, out }) => {
            let env: Vec<(String, String)> = std::env::vars().collect();
            backlog::run(
                &Agent::from_env(),
                &Gh::from_env(),
                &repo,
                &model,
                &out,
                &env,
            )
        }
    };
    match result {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(e) => {
            eprintln!("wf: {e:#}");
            ExitCode::FAILURE
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::CommandFactory;

    #[test]
    fn the_command_definition_is_valid() {
        Cli::command().debug_assert();
    }
}

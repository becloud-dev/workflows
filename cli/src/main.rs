use becloud_workflows::agent::Agent;
use becloud_workflows::executor::{calls, decide, gate, publish, red, scope, verdict};
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
    /// Check the round's deletions and workflow and action changes against the plan's Files list, and refuse a
    /// test file the implementer changed. `TEST_BOUNDARY` (the commit after the test-writer) and
    /// `TEST_PATHS` are read from the environment.
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
        /// The file the step outputs are appended to (`$GITHUB_OUTPUT`): `workflows=true|false`.
        #[arg(long)]
        github_output: PathBuf,
    },
    /// Write the approved plan for the rounds: the comment the gate pinned, refused if it changed.
    Plan {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        issue: u64,
        #[arg(long)]
        plan_comment_id: u64,
        #[arg(long)]
        plan_sha256: String,
        #[arg(long)]
        plan_file: PathBuf,
    },
    /// The test-writer call of a round: writes and commits the plan's tests in the checkout. It is
    /// not given the consumer commands; the CLI runs the test command for the red proof.
    TestWrite {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        issue: String,
        #[arg(long)]
        round: String,
        #[arg(long)]
        model: String,
        #[arg(long)]
        plan_file: PathBuf,
        /// The previous round's findings, or `none`.
        #[arg(long, default_value = "none")]
        findings_file: String,
        /// Where the inputs and the run record are written (`$RUNNER_TEMP`).
        #[arg(long)]
        work_dir: PathBuf,
        #[arg(long)]
        github_output: PathBuf,
    },
    /// The implementer call of a round: writes and commits the change in the checkout so the tests
    /// pass. The check and test commands are read from `CHECK` and `TEST`.
    Implement {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        issue: String,
        #[arg(long)]
        round: String,
        #[arg(long)]
        model: String,
        #[arg(long)]
        plan_file: PathBuf,
        /// The previous round's findings, or `none`.
        #[arg(long, default_value = "none")]
        findings_file: String,
        /// Where the inputs and the run record are written (`$RUNNER_TEMP`).
        #[arg(long)]
        work_dir: PathBuf,
        #[arg(long)]
        github_output: PathBuf,
    },
    /// The check call of a round: judges the change against the plan and the recorded results.
    Check {
        /// owner/repo
        #[arg(long)]
        repo: String,
        #[arg(long)]
        issue: String,
        #[arg(long)]
        round: String,
        #[arg(long)]
        model: String,
        #[arg(long)]
        plan_file: PathBuf,
        #[arg(long)]
        results_file: PathBuf,
        #[arg(long)]
        base: String,
        #[arg(long)]
        work_dir: PathBuf,
        #[arg(long)]
        github_output: PathBuf,
    },
    /// Run the test command on the base tree with the change's test files; they must fail there.
    /// The command and the test path globs are read from `TEST` and `TEST_PATHS`.
    Red {
        #[arg(long)]
        base: String,
        #[arg(long)]
        round: String,
        /// Where the base worktree and the log are made (`$RUNNER_TEMP`).
        #[arg(long)]
        work_dir: PathBuf,
        #[arg(long)]
        results: PathBuf,
        #[arg(long)]
        github_output: PathBuf,
    },
    /// The round's verdict. Reads `EXECUTE`, `CHECK`, `CHECK_EXIT`, `TEST_EXIT`, `RED_STATE`,
    /// `SCOPE_STATE`, `SCOPE_VIOLATIONS` and `SCOPE_KINDS` from the environment.
    Verdict {
        #[arg(long)]
        round: String,
        #[arg(long)]
        findings_file: PathBuf,
        #[arg(long)]
        github_output: PathBuf,
    },
    /// What the run publishes, from `R1_*`, `R2_*`, `R3_*` (`OUTCOME`, `VERDICT`, `FINDINGS`);
    /// bundles a pull request or draft into `<work-dir>/bundle/publish.bundle`.
    Decide {
        #[arg(long)]
        base: String,
        #[arg(long)]
        work_dir: PathBuf,
        #[arg(long)]
        github_output: PathBuf,
    },
}

/// A step input passed through the environment; unset reads as empty, as in the shell steps.
fn var(name: &str) -> String {
    std::env::var(name).unwrap_or_default()
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
        }) => scope::run(
            &repo_dir,
            &base,
            &plan_file,
            &var("TEST_BOUNDARY"),
            &var("TEST_PATHS"),
            &results,
            &github_output,
        ),
        Command::Executor(Executor::PublishCheck {
            repo,
            issue,
            plan_comment_id,
            plan_sha256,
            base,
            git_dir,
            github_output,
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
            &github_output,
        ),
        Command::Executor(Executor::Plan {
            repo,
            issue,
            plan_comment_id,
            plan_sha256,
            plan_file,
        }) => publish::read_pinned(
            &Gh::from_env(),
            &repo,
            issue,
            &publish::Pin {
                comment_id: plan_comment_id,
                sha256: &plan_sha256,
            },
            &plan_file,
        ),
        Command::Executor(Executor::TestWrite {
            repo,
            issue,
            round,
            model,
            plan_file,
            findings_file,
            work_dir,
            github_output,
        }) => {
            let env: Vec<(String, String)> = std::env::vars().collect();
            calls::test_write(
                &Agent::from_env(),
                &calls::Round {
                    repo: &repo,
                    issue: &issue,
                    round: &round,
                    model: &model,
                    repo_dir: std::path::Path::new("."),
                    work_dir: &work_dir,
                },
                &plan_file,
                &findings_file,
                &env,
                &github_output,
            )
        }
        Command::Executor(Executor::Implement {
            repo,
            issue,
            round,
            model,
            plan_file,
            findings_file,
            work_dir,
            github_output,
        }) => {
            let env: Vec<(String, String)> = std::env::vars().collect();
            calls::implement(
                &Agent::from_env(),
                &calls::Round {
                    repo: &repo,
                    issue: &issue,
                    round: &round,
                    model: &model,
                    repo_dir: std::path::Path::new("."),
                    work_dir: &work_dir,
                },
                &plan_file,
                &findings_file,
                &var("CHECK"),
                &var("TEST"),
                &env,
                &github_output,
            )
        }
        Command::Executor(Executor::Check {
            repo,
            issue,
            round,
            model,
            plan_file,
            results_file,
            base,
            work_dir,
            github_output,
        }) => {
            let env: Vec<(String, String)> = std::env::vars().collect();
            calls::check(
                &Agent::from_env(),
                &calls::Round {
                    repo: &repo,
                    issue: &issue,
                    round: &round,
                    model: &model,
                    repo_dir: std::path::Path::new("."),
                    work_dir: &work_dir,
                },
                &plan_file,
                &results_file,
                &base,
                &env,
                &github_output,
            )
        }
        Command::Executor(Executor::Red {
            base,
            round,
            work_dir,
            results,
            github_output,
        }) => red::run(
            std::path::Path::new("."),
            &work_dir,
            &base,
            &var("TEST"),
            &var("TEST_PATHS"),
            &round,
            &results,
            &github_output,
        ),
        Command::Executor(Executor::Verdict {
            round,
            findings_file,
            github_output,
        }) => verdict::run(
            &verdict::Inputs {
                execute: var("EXECUTE"),
                check: var("CHECK"),
                check_exit: var("CHECK_EXIT"),
                test_exit: var("TEST_EXIT"),
                red_state: var("RED_STATE"),
                scope_state: var("SCOPE_STATE"),
                scope_violations: var("SCOPE_VIOLATIONS"),
                scope_kinds: var("SCOPE_KINDS"),
                round,
            },
            &findings_file,
            &github_output,
        ),
        Command::Executor(Executor::Decide {
            base,
            work_dir,
            github_output,
        }) => {
            let rounds: Vec<decide::Round> = (1..=3)
                .map(|n| decide::Round {
                    outcome: var(&format!("R{n}_OUTCOME")),
                    verdict: var(&format!("R{n}_VERDICT")),
                    findings: var(&format!("R{n}_FINDINGS")),
                })
                .collect();
            decide::run(
                std::path::Path::new("."),
                &work_dir,
                &base,
                &rounds,
                &github_output,
            )
        }
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

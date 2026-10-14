use becloud_workflows::agent::Agent;
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

fn main() -> ExitCode {
    let cli = Cli::parse();
    let result = match cli.command {
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

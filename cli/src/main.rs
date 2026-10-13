use clap::Parser;

/// Runs the steps of the becloud-dev workflows.
#[derive(Parser)]
#[command(name = "wf", version)]
struct Cli {}

fn main() {
    Cli::parse();
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

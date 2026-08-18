# Unified SpinorBEC CLI — thin shim. The dispatch body lives in
# src/workflow/cli.jl (`SpinorBEC.cli_main`); run `... scripts/cli.jl help`
# for the subcommand list.

using SpinorBEC

exit(cli_main(copy(ARGS)))

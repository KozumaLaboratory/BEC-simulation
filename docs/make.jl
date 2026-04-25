# Documenter.jl driver. Build locally:
#   julia --project=docs docs/make.jl
#
# Requires `Pkg.develop(PackageSpec(path=".."))` once in the docs env.

using Documenter
using SpinorBEC

makedocs(
    sitename = "SpinorBEC",
    modules = [SpinorBEC],
    pages = [
        "Home" => "../README.md",
        "Pipeline cookbook" => "../pipeline_cookbook.md",
        "Lab user tutorial" => "../lab_user_tutorial.md",
        "Performance tuning" => "../performance_tuning.md",
        "API reference" => "api/index.md",
        "Design notes" => [
            "Mixed precision" => "../mixed_precision_design.md",
            "Two-component GP" => "../two_component_gp_design.md",
            "Live monitor" => "../live_monitor_design.md",
        ],
    ],
    format = Documenter.HTML(
        prettyurls = false,
        collapselevel = 2,
    ),
    warnonly = true,   # don't fail the build on missing docstrings yet
)

# --- I/O subsystem umbrella (top-level files only).
#
# The dashboard subsystem (`workflow/io/dashboard.jl` + `dashboard/`) is
# wrapped in its own `module Dashboard` and loaded later in SpinorBEC.jl,
# after the analysis subsystem is in scope (because Dashboard imports
# total_density, spin_density_vector, ... from SpinorBEC). ---
#
#   io                  — save_state / load_state (JLD2 round-trip)
#   unitful_support     — Unitful.jl helpers for YAML parsing
#   save_rotating_result — rotating-basis history → result.jld2 writer
#   vtk_export          — export_vtk + export_vtk_series stubs (real
#                         method bodies live in ext/SpinorBECVTKExt)
#   run_summary         — print_run_summary, compare_runs
#   html_report         — generate_html_report (self-contained static HTML)
#   budget              — estimate_run_budget (VRAM / RAM / disk forecast)
#   host_budget         — the SUPPLY side of the same question: what this host
#                         will give a run, derived per-term with provenance
#                         (budget.jl forecasts DEMAND; the two meet at launch)
#   catalog             — human-navigation layer (tags) over the CAS store

include("io/io.jl")
include("io/unitful_support.jl")
include("io/save_rotating_result.jl")
include("io/coarse_fields.jl")      # Tier 1: what survives deleting the frames
include("io/vtk_export.jl")
include("io/measurement_provenance.jl")  # provenance stamp + refusal for measurement outputs
include("io/run_summary.jl")
include("io/html_report.jl")
# host_budget BEFORE budget: `check_run_fits` in budget.jl annotates a kwarg with
# `::HostBudget`, and a type annotation is resolved when the method is defined,
# not when it is called. The reverse order loads and then dies on that line.
# host_budget.jl depends on Base alone, so it can always go first.
include("io/host_budget.jl")
include("io/budget.jl")
include("io/catalog.jl")
include("io/catalog_index.jl")
# What the store CONTAINS duplicate-wise, grouped by the knob that distinguishes
# each set. Uses `diff_dicts` from the experiments layer, which loads later — the
# reference is inside a function body, so it resolves at call time.
include("io/store_census.jl")
include("io/gs_library.jl")

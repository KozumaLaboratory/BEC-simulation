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
#   scan_summary        — scan_summary, scan_energy_comparison
#   catalog             — human-navigation layer (tags) over the CAS store

include("io/io.jl")
include("io/unitful_support.jl")
include("io/save_rotating_result.jl")
include("io/vtk_export.jl")
include("io/run_summary.jl")
include("io/html_report.jl")
include("io/budget.jl")
include("io/scan_summary.jl")
include("io/catalog.jl")

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
        "Home" => "index.md",
        "Guides" => [
            "Lab user tutorial" => "guides/lab_user_tutorial.md",
            "Pipeline cookbook" => "guides/pipeline_cookbook.md",
            "Klaus / fast-Larmor regime" => "guides/klaus_regime.md",
            "Performance tuning" => "guides/performance_tuning.md",
            "Migration guide" => "guides/migration_guide.md",
            "TSUBAME (dev + scaling)" => "guides/tsubame.md",
        ],
        "Reference" => [
            "Architecture" => "reference/architecture.md",
            "YAML schema" => "reference/yaml_schema_reference.md",
            "Dynamics block" => "reference/dynamics.md",
            "API" => "api/index.md",
        ],
        "Design notes" => [
            "Option γ rotating basis" => "design/option_gamma_rotating_basis.md",
            "Mixed precision" => "design/mixed_precision_design.md",
            "Multi-GPU" => "design/multi_gpu_design.md",
            "Two-component GP" => "design/two_component_gp_design.md",
            "Live monitor" => "design/live_monitor_design.md",
            "Integrator modernization plan" => "design/integrator_modernization_plan.md",
            "Integrator Ch.3 plan" => "design/integrator_ch3_plan.md",
            "Integrator Phase -1 protocol" => "design/integrator_phase_minus_1_protocol.md",
            "Track C derivation (Force-gradient)" => "design/integrator_track_c_derivation.md",
            "Ch.3 §3.5 narrative" => "design/integrator_ch3_5_narrative.md",
            "Ch.3 §3.7 narrative" => "design/integrator_ch3_7_narrative.md",
            "Ch.3 §3.8 narrative" => "design/integrator_ch3_8_narrative.md",
            "TDHFB pilot" => "design/tdhfb_pilot_design.md",
            "D-thesis Year 1 roadmap" => "design/dthesis_year1_roadmap.md",
            "Scan group redesign" => "design/scan_group_redesign.md",
            "Dashboard perf notes" => "design/dashboard_perf_notes.md",
            "Dashboard ensemble panel" => "design/dashboard_ensemble_panel.md",
            "Tier 4 research extensions" => "design/tier4_research_extensions.md",
        ],
        "Theory" => [
            "Icosahedral LHY" => "theory/icosahedral_lhy.md",
            "Sinatra criterion (F=6)" => "theory/sinatra_criterion_F6.md",
            "Kawaguchi-Ueda review notes" => "theory/kawaguchi_ueda_review_notes.md",
        ],
        "Research notes" => [
            "TWA on Eu EdH (synthesis)" => "research_notes/twa_eu_edh_synthesis.md",
            "F=6 phase boundaries" => "research_notes/F6_phase_boundaries.md",
            "Eu collapse: LHY insufficient" => "research_notes/eu_collapse_lhy_insufficient.md",
            "TWA N scan (raw)" => "research_notes/twa_N_scan_result.md",
            "TWA ε_dd species scan (raw)" => "research_notes/twa_eps_dd_scan.md",
            "TWA pinned 16g (raw)" => "research_notes/twa_pinned_16g_result.md",
            "TWA Sinatra validation (superseded)" => "research_notes/twa_sinatra_validation.md",
        ],
    ],
    format = Documenter.HTML(
        prettyurls = false,
        collapselevel = 2,
    ),
    warnonly = true,   # don't fail the build on missing docstrings yet
)

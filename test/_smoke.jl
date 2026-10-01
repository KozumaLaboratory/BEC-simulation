# Explicit development checks. These are views of the existing tiers, not new
# ownership lists: nightly's full tier still runs every deferred test.
# Budget: 2–3 minutes including setup on a warm GitHub runner. Keep solver
# campaigns and multi-minute compilation out of these views.
const SMOKE_TESTS = Dict(
    "smoke_fast" => [
        "test_tier_membership.jl",
        "test_prior_art_dispositions.jl",
        "test_docs_live_set.jl",
        "test_retracted_numbers_carry_their_replacement.jl",
        "test_state_doc_is_current.jl",
        "foundation/test_spin_matrices.jl",
        "foundation/test_grid.jl",
        "foundation/test_atoms.jl",
    ],
    "smoke_oracles" => [
        "oracles/test_doc_run_citations_resolve.jl",
        "oracles/test_spin_ladder_single_source.jl",
        "oracles/test_spin_operator_algebra.jl",
        "oracles/test_outer_chain_registry_mapping.jl",
    ],
    "smoke_integration" => [
        "hamiltonian/test_split_step.jl",
        "workflow/test_experiment.jl",
        "workflow/test_scalar_egpe_yaml.jl",
    ],
)

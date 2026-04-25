# Binary BEC immiscibility demo (#51 scaffold).
#
# Pure-Julia driver — the binary path is not yet in the YAML pipeline
# (see docs/two_component_gp_design.md for the integration plan). Run:
#
#   julia --project=. runs/samples/binary_immiscible/run.jl
#
# Produces a JLD2 with psi_A, psi_B and a quick text summary.

using SpinorBEC
using JLD2

const OUT_DIR = @__DIR__
const OUT_JLD = joinpath(OUT_DIR, "result.jld2")

function main()
    grid = make_grid(GridConfig((48, 48), (10.0, 10.0)))

    # Immiscible regime: g_AB^2 > g_AA * g_BB
    couplings = BinaryCouplings(
        g_AA = 100.0,
        g_BB = 100.0,
        g_AB = 130.0,           # > sqrt(100*100) = 100 → immiscible
        omega_coupling = 0.0,
    )
    @info "couplings" g_AA = couplings.g_AA g_BB = couplings.g_BB g_AB = couplings.g_AB
    @info "is_immiscible?" SpinorBEC.is_immiscible(couplings)

    # Both species in the same harmonic trap
    pot = HarmonicTrap(1.0, 1.0)

    @info "Running binary ITP (this is a placeholder solver — F=0+F=0)"
    state = find_binary_ground_state(
        grid;
        couplings = couplings,
        potential_A = pot,
        potential_B = pot,
        dt = 0.005,
        n_steps = 1500,
        tol = 1e-6,
        verbose = true,
    )

    n_A = abs2.(state.psi_A)
    n_B = abs2.(state.psi_B)
    overlap = sum(sqrt.(n_A .* n_B)) * SpinorBEC.cell_volume(grid)
    @info "Final overlap (∫√(n_A·n_B) dV)" overlap
    @info "(Immiscible GS should have small overlap; miscible large)"

    jldopen(OUT_JLD, "w") do f
        f["psi_A"] = state.psi_A
        f["psi_B"] = state.psi_B
        f["overlap"] = overlap
        f["g_AA"] = couplings.g_AA
        f["g_BB"] = couplings.g_BB
        f["g_AB"] = couplings.g_AB
    end
    @info "Wrote $OUT_JLD"
end

main()

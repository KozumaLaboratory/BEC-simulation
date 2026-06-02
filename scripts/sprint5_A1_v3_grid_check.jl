#!/usr/bin/env julia
# scripts/sprint5_A1_v3_grid_check.jl
#
# 2D grid convergence check for A1 v3. Re-relaxes 4 states at 24²
# (5× per-step vs 16², same 8.0 box) with n_steps=20000 / tol=1e-7
# to confirm v3's 16² rank is not lattice-artefact.
#
# 4 inits chosen as discriminators:
#   - icosahedral_explicit: 16² winner (E=2.5634)
#   - cyclic: close 16² runner-up (E=2.5641, conv=✗)
#   - biaxial_nematic: escaped to texture basin at 16²/20000 ITP
#   - antiferromagnetic: reliable texture-basin seed at 16² (E=2.6345)
#
# Run:  julia --project=. scripts/sprint5_A1_v3_grid_check.jl
# Expected wall-clock: ~ 60-90 min on 1 CPU core.

using SpinorBEC
using LinearAlgebra
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15

# 24² (vs 16² in v3) same physical box
const GRID = make_grid(GridConfig((24, 24), (8.0, 8.0)))
const POT = HarmonicTrap{2}((1.0, 1.0))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 20000
const TOL_ITP = 1e-7
const L_Z_DDI = 1.0

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const TEST_INITS = [
    :icosahedral_explicit,
    :cyclic,
    :biaxial_nematic,
    :antiferromagnetic,
]
const SEED = 1

function build_psi(state::Symbol, sys)
    if state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(GRID, sys; state=:polar)
        for j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, :)))
            for c in 1:size(psi, 3)
                psi[i, j, c] = spatial_amp * ζ[c]
            end
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        n > 0 && (psi ./= n)
        return psi
    else
        return init_psi(GRID, sys; state=state)
    end
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
    psi ./= n
end

function run_one(init_state::Symbol)
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, sys)
    apply_noise!(psi_init, 0.01, SEED)
    initial_state_for_fgs = init_state === :icosahedral_explicit ? :polar : init_state
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        quasi_2d=true, l_z=L_Z_DDI)
    return ws, E, conv
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi = ws.state.psi
    fx, fy, fz = spin_density_vector(psi, sm, 2)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    println("=== A1 v3 grid convergence (24² vs 16²) ===\n")
    @printf "Grid: 24×24, box=8.0  |  ITP: n_steps=%d  tol=%.1e\n\n" N_STEPS_ITP TOL_ITP
    println("Comparison to 16² v3 (tightened tol):")
    @printf "  %-26s 16²(E=%.6f)   24²(E=?)\n" "icosahedral_explicit s1" 2.563393
    @printf "  %-26s 16²(E=%.6f)   24²(E=?)\n" "cyclic s1" 2.564179
    @printf "  %-26s 16²(E=%.6f)   24²(E=?)\n" "biaxial_nematic s1" 2.634498
    @printf "  %-26s 16²(E=%.6f)   24²(E=?)\n\n" "antiferromagnetic s1" 2.634504

    results = []
    for init in TEST_INITS
        print("  init=$init seed=$SEED ... ")
        flush(stdout)
        try
            ws, E, conv = run_one(init)
            b = energy_decomposition(ws)
            f_max = spin_density_max(ws)
            push!(results, (init=init, E=E, conv=conv, b=b, f_max=f_max))
            @printf "E=%.6f conv=%s E_ddi=%+.4e E_spin=%+.4e f_max=%.4f\n" E (conv ? "✓" : "✗") b.ddi b.spin f_max
        catch err
            println("FAILED: $err")
        end
    end

    println("\n--- Rank at 24² (E_total) ---\n")
    sorted = sort(results; by=r -> r.E)
    for (i, r) in enumerate(sorted)
        @printf "  %d. %-26s  E=%.6f  E_ddi=%+.4e  f_max=%.4f  conv=%s\n" i string(r.init) r.E r.b.ddi r.f_max (
            r.conv ? "✓" : "✗"
        )
    end

    println("\n=== Done ===")
end

main()

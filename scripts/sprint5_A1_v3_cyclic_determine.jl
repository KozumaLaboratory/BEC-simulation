#!/usr/bin/env julia
# scripts/sprint5_A1_v3_cyclic_determine.jl
#
# Long-ITP run to determine whether cyclic at 2D quasi-2D Eu nominal is
# a separate near-degenerate uniform-inert minimum, or just slowly
# relaxing toward I_h. Same 16² envelope as v3 + analyze, but with
# n_steps=60000 (3× the analyze) and tol=1e-9 (2 orders tighter).
#
# Same setup for polar as a symmetry-conscious sanity check (polar is
# also a candidate for "near-degenerate vs same basin as I_h").
#
# Run:  julia --project=. scripts/sprint5_A1_v3_cyclic_determine.jl
# Expected wall-clock: ~ 30-40 min total.

using SpinorBEC
using LinearAlgebra
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((16, 16), (8.0, 8.0)))
const POT = HarmonicTrap{2}((1.0, 1.0))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 60000
const TOL_ITP = 1e-9
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

# 4 long-ITP tests: cyclic (the question), polar (sanity), I_h (anchor),
# antiferro (texture-basin anchor that converges everywhere)
const TEST_INITS = [:cyclic, :polar, :icosahedral_explicit, :antiferromagnetic]
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

function spinor_overlap(psi_a, psi_b)
    # Renormalised |⟨ψ_a|ψ_b⟩|²/(⟨ψ_a|ψ_a⟩⟨ψ_b|ψ_b⟩)
    dot_ab = sum(conj.(psi_a) .* psi_b)
    abs2(dot_ab) / (sum(abs2, psi_a) * sum(abs2, psi_b))
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi = ws.state.psi
    fx, fy, fz = spin_density_vector(psi, sm, 2)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    println("=== A1 v3 cyclic determination — long ITP at 16² ===\n")
    @printf "n_steps=%d  tol=%.1e  (3× more steps + 2 orders tighter tol than analyze)\n\n" N_STEPS_ITP TOL_ITP

    results = Dict{Symbol, Any}()
    for init in TEST_INITS
        print("  init=$init seed=$SEED ... ")
        flush(stdout)
        try
            ws, E, conv = run_one(init)
            b = energy_decomposition(ws)
            f_max = spin_density_max(ws)
            results[init] = (ws=ws, E=E, conv=conv, b=b, f_max=f_max)
            @printf "E=%.8f conv=%s E_ddi=%+.4e E_spin=%+.4e f_max=%.4f\n" E (conv ? "✓" : "✗") b.ddi b.spin f_max
        catch err
            println("FAILED: $err")
        end
    end

    # Overlap between cyclic, polar, I_h → are they the same basin?
    println("\n--- Pairwise overlap of relaxed states ---\n")
    labels = collect(keys(results))
    for i in 1:length(labels), j in (i + 1):length(labels)
        la, lb = labels[i], labels[j]
        ov = spinor_overlap(results[la].ws.state.psi, results[lb].ws.state.psi)
        @printf "  %-22s ↔ %-22s   |⟨ψ_a|ψ_b⟩|² = %.6f\n" string(la) string(lb) ov
    end

    println("\n--- E differences (vs I_h) ---\n")
    if haskey(results, :icosahedral_explicit)
        E_Ih = results[:icosahedral_explicit].E
        for (init, r) in results
            init === :icosahedral_explicit && continue
            @printf "  %-22s  E - E_Ih = %+.4e (%.4f%%)\n" string(init) (r.E - E_Ih) (
                100 * (r.E - E_Ih) / abs(E_Ih)
            )
        end
    end

    println("\n--- Verdict ---")
    if haskey(results, :icosahedral_explicit) && haskey(results, :cyclic)
        ov_Ih_cyc = spinor_overlap(
            results[:icosahedral_explicit].ws.state.psi,
            results[:cyclic].ws.state.psi)
        de = abs(results[:cyclic].E - results[:icosahedral_explicit].E)
        if ov_Ih_cyc > 0.99 && de < 1e-5
            println("  cyclic and I_h converged to the SAME basin (high overlap + tiny ΔE).")
        elseif ov_Ih_cyc > 0.95 && de < 1e-3
            println("  cyclic and I_h are NEARLY the same basin (some residual seed-memory).")
        elseif de < 1e-2
            println("  cyclic is a SEPARATE near-degenerate uniform-inert minimum.")
        else
            println("  cyclic relaxed to a distinct state (large ΔE).")
        end
    end

    println("\n=== Done ===")
end

main()

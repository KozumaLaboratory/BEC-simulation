#!/usr/bin/env julia
# scripts/sprint5_A1_v3_3d_followup.jl
#
# 3D follow-up to A1 v3. Use this AFTER the 2D scan completes and we
# have a preferred candidate (or the 2D rank is too close to call).
#
# Why 3D matters:
#   - 2D quasi-2D MDDI undercounts axial textures (KSU traditional
#     axial-circulation, true 3D skyrmion winding, axial flux closure).
#   - If 2D suggests texture wins, 3D should make the margin LARGER.
#   - If 2D rank is too close, 3D can be decisive.
#
# Compute envelope: 16³ × 6000 ITP × ~6 inits × 1 seed ≈ 12-18 h.
# Inits are downselected to the top-3 from v3 + 2 control (best uniform
# + best axially-favoured texture):
#   - Best uniform (carry from v3 — likely :biaxial_nematic or :polar)
#   - icosahedral_explicit (uniform inert reference)
#   - Best texture (from v3 — likely polar_core_vortex or ksu_circulation)
#   - skyrmion (axially-extended, 2D undercounts)
#   - vortex_lattice (axially-extended)
#   - ksu_circulation (axial spontaneous circulation, the KSU paradigm)
#
# Edit `INITS_3D` based on v3 result before launching.
#
# Run:   julia --project=. scripts/sprint5_A1_v3_3d_followup.jl
# Expected wall-clock: ~ 12-18 hours

using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15

# 3D 16³ — proper trap aspect (slightly oblate to mirror typical Eu setup;
# can be changed to 1:1:1 or 1:1:1.2 depending on physics question)
const GRID = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 6.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 6000   # reduced from 8000 to fit budget; tolerance check at end
const TOL_ITP = 1e-9

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

# Updated 2026-06-02 based on v3 2D result:
# 2D rank: I_h < cyclic < biaxial < polar < FM (uniform inert sweep);
# texture seeds either collapsed to uniform-inert or saddled at E≈2.634.
# ksu_circulation harvested E_ddi=-0.88 (modest MDDI gain) but lost +0.065
# total. In full 3D, axial DDI structure could reverse this.
const INITS_3D = [
    :icosahedral_explicit,    # 2D winner — uniform inert basin reference
    :cyclic,                  # 2D #2 — uniform inert, may merge with I_h
    :antiferromagnetic,       # reliable texture-basin seed (24² lattice-confirmed)
    :ksu_circulation,         # axial spontaneous circulation, 2D undercounts the most
    :polar_core_vortex,       # axial vortex core, candidate for 3D-only minimum
    :vortex_lattice,          # axial flux closure, Li-Saito ansatz
]
const NOISE_SEEDS = [1]  # single seed at 3D for budget; lift to [1,2] if budget allows
const OUT_DIR = "runs/sprint5_A1_v3_3d"

function build_psi(state::Symbol, sys)
    if state === :magnetic_domain_stripe
        return init_psi(GRID, sys; state=:magnetic_domain, init_vortex_charge=1)
    elseif state === :magnetic_domain_square
        return init_psi(GRID, sys; state=:magnetic_domain, init_vortex_charge=2)
    elseif state === :ksu_circulation
        psi = init_psi(GRID, sys; state=:m_plus_F)
        # phase winding in xy plane on m=+F (axial circulation = z-axis vortex)
        xs = GRID.x[1]
        ys = GRID.x[2]
        for k in 1:size(psi, 3), j in eachindex(ys), i in eachindex(xs)
            θ = atan(ys[j], xs[i])
            psi[i, j, k, 1] *= exp(im * θ)
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        psi ./= n
        return psi
    elseif state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(GRID, sys; state=:polar)
        for k in 1:size(psi, 3), j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, k, :)))
            for c in 1:size(psi, 4)
                psi[i, j, k, c] = spatial_amp * ζ[c]
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

function run_one(init_state::Symbol, seed::Int)
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, sys)
    apply_noise!(psi_init, 0.01, seed)
    initial_state_for_fgs = if init_state in (:magnetic_domain_stripe, :magnetic_domain_square)
        :magnetic_domain
    elseif init_state === :ksu_circulation
        :m_plus_F
    elseif init_state === :icosahedral_explicit
        :polar
    else
        init_state
    end
    # 3D full DDI (no quasi_2d) — the whole point is the axial DDI texturing
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false)
    return ws, E, conv
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi = ws.state.psi
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== A1 v3 3D follow-up — Eu nominal 16³ texture comparison ===\n")
    @printf "Atom: %s, N=%d, ω_ref=%.1f, grid=16³ (FULL 3D MDDI, no quasi_2d)\n" ATOM.name N_ATOMS OMEGA_REF
    @printf "c_dd/C_TOTAL = %.4f\n" (C_DD_DIMLESS / C_TOTAL)
    @printf "%d inits × %d seeds = %d ITPs (~ 12-18h total)\n\n" length(INITS_3D) length(
        NOISE_SEEDS
    ) (length(INITS_3D) * length(NOISE_SEEDS))

    results = []
    for init in INITS_3D, seed in NOISE_SEEDS
        print("  init=$init seed=$seed ... ")
        flush(stdout)
        ws, E, conv = run_one(init, seed)
        b = energy_decomposition(ws)
        f_max = spin_density_max(ws)
        push!(
            results,
            (init=init, seed=seed, E=E, conv=conv,
                breakdown=b, f_max=f_max, psi=Array(ws.state.psi)),
        )
        @printf "E=%.6f conv=%s E_ddi=%+.4e f_max=%.4f\n" E (conv ? "✓" : "✗") b.ddi f_max
    end

    println("\n--- 3D rank by E_total (full GP + MDDI) ---\n")
    sorted = sort(results; by=r -> r.E)
    for (i, r) in enumerate(sorted)
        @printf "  %d. %-26s seed=%d  E=%.6f  E_ddi=%+.4e  f_max=%.4f\n" i string(r.init) r.seed r.E r.breakdown.ddi r.f_max
    end

    # Save psi data for visualization
    save_path = joinpath(OUT_DIR, "3d_states.jld2")
    snapshot = [
        Dict(
            "init" => string(r.init), "seed" => r.seed,
            "E" => r.E, "conv" => r.conv,
            "breakdown" =>
                Dict(string(k) => getfield(r.breakdown, k) for k in propertynames(r.breakdown)),
            "f_max" => r.f_max, "psi" => r.psi) for r in sorted
    ]
    @save save_path snapshot
    @info "Saved to $save_path"

    # Compare to 2D winner
    println("\n--- 3D vs 2D comparison ---")
    println("(After this run completes, manually compare to v3 2D winner.)")
    println("Key questions:")
    println("  - Does the 2D winner still win at 3D?")
    println("  - Does an axially-extended texture overtake the 2D winner?")
    println("  - Does the E_ddi ratio change qualitatively?")

    println("\n=== Done ===")
end

main()

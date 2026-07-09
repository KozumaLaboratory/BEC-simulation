#!/usr/bin/env julia
# scripts/sprint5_A1_v3_texture_inclusive.jl
#
# Track A1 v3 — texture-inclusive GS scan for Eu nominal.
#
# Retracts v2's "uniform inert manifold" framing. v2 seeded only ⟨F⟩=0 /
# uniform states; for those f(r) ≡ 0 → MDDI ≡ 0, so the v2 ranking was
# contact-only. Eu is MDDI-dominated (μ ≈ 6.977 μ_B): the true GS may be
# a spatial texture that harvests MDDI energy and sits below the entire
# uniform-inert manifold.
#
# v3 design (anko 2026-06-02 correction):
#   - Include the uniform inert seeds (carry-over for cross-check + I_h
#     explicit reference)
#   - Add texture seeds: radial_spin_vortex, polar_core_vortex, chiral_spin_vortex,
#     spin_helix, magnetic_domain (stripe/square), vortex_lattice,
#     skyrmion, skyrmion_lattice, domain_wall
#   - KSU spontaneous-circulation analog ≈ m_plus_F + winding via radial_spin_vortex
#   - Li-Saito flux-closure analog ≈ vortex_lattice / magnetic_domain
#   - 2D quasi-2D MDDI (same envelope as v2 for compute parity)
#   - FULL ε breakdown via `energy_decomposition` → MDDI energy isolated
#   - Spatial spin density |f|(r) reported per relaxed state
#   - Rank by ε_total (contact + MDDI); compare to v2's uniform-only result
#
# Run:  julia --project=. scripts/sprint5_A1_v3_texture_inclusive.jl
# Expected wall-clock: ~ 60-90 minutes on a single CPU core
#   (~ 20 inits × 2 noise seeds × 2 min each)

using SpinorBEC
using LinearAlgebra
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15

# 2D quasi-2D, same as v2
const GRID = make_grid(GridConfig((16, 16), (8.0, 8.0)))
const POT = HarmonicTrap{2}((1.0, 1.0))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 8000
const TOL_ITP = 1e-10
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

# Uniform inert (carry-over from v2) + texture inits + explicit I_h
const UNIFORM_INITS = [:m_plus_F, :polar, :antiferromagnetic, :cyclic, :biaxial_nematic]
const TEXTURE_INITS = [
    :radial_spin_vortex,
    :polar_core_vortex,
    :chiral_spin_vortex,
    :spin_helix,
    :magnetic_domain_stripe,
    :magnetic_domain_square,
    :vortex_lattice,
    :skyrmion,
    :skyrmion_lattice,
    :domain_wall,
    :ksu_circulation,         # m_plus_F + winding (KSU spontaneous circulation analog)
    :icosahedral_explicit,    # explicit I_h spinor seed
]
const ALL_INITS = vcat(UNIFORM_INITS, TEXTURE_INITS)
const NOISE_SEEDS = [1, 2]

function build_psi(state::Symbol, sys)
    # Texture-extended dispatcher — state_zoo lacks explicit named entries
    # for some, so we route via init_psi with appropriate state symbols.
    if state === :magnetic_domain_stripe
        return init_psi(GRID, sys; state=:magnetic_domain, init_vortex_charge=1)
    elseif state === :magnetic_domain_square
        return init_psi(GRID, sys; state=:magnetic_domain, init_vortex_charge=2)
    elseif state === :ksu_circulation
        # m_plus_F base × overall phase winding 1 → KSU-like spontaneous circulation
        psi = init_psi(GRID, sys; state=:m_plus_F)
        # phase winding in xy plane on the m=+F component
        xs = GRID.x[1]
        ys = GRID.x[2]
        for j in eachindex(ys), i in eachindex(xs)
            θ = atan(ys[j], xs[i])
            psi[i, j, 1] *= exp(im * θ)   # winding-1 on m=+F
        end
        # renormalise
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        psi ./= n
        return psi
    elseif state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(GRID, sys; state=:polar)
        # overwrite spinor at every grid point with ζ × (gaussian profile)
        # use the existing polar profile shape, just substitute spinor
        for j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, :)))   # any nonzero baseline
            for c in 1:size(psi, 3)
                psi[i, j, c] = spatial_amp * ζ[c]
            end
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        if n > 0
            psi ./= n
        end
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
    # Map texture-extended labels back to find_ground_state's known initial_state
    initial_state_for_fgs = if init_state in (:magnetic_domain_stripe, :magnetic_domain_square)
        :magnetic_domain
    elseif init_state === :ksu_circulation
        :m_plus_F
    elseif init_state === :icosahedral_explicit
        :polar    # placeholder; psi_init is what's used
    else
        init_state
    end
    try
        ws, conv, E, dE, last = find_ground_state(;
            grid=GRID, atom=ATOM, interactions=ip,
            zeeman=ZEEMAN, potential=POT,
            dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
            initial_state=initial_state_for_fgs, verbose=false,
            psi_init=psi_init,
            enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
            quasi_2d=true, l_z=L_Z_DDI)
        return ws, E, conv
    catch err
        @warn "init=$init_state seed=$seed failed" err
        return nothing, NaN, false
    end
end

function spin_density_diagnostic(ws)
    # |f|(r) = √(fx²+fy²+fz²) spatial spin density — load-bearing for MDDI
    sm = ws.spin_matrices
    psi = ws.state.psi
    ndim = ndims(psi) - 1
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    f_mag = sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz))
    n = abs2.(view(psi, ntuple(_ -> Colon(), ndim)..., 1))
    for c in 2:size(psi, ndim + 1)
        n .+= abs2.(view(psi, ntuple(_ -> Colon(), ndim)..., c))
    end
    f_max = maximum(f_mag)
    # ⟨|f|/n⟩_n = density-weighted local polarisation
    dV = SpinorBEC.cell_volume(ws.grid)
    n_total = sum(n) * dV
    f_mean_density_weighted = n_total > 1e-30 ? sum(f_mag) * dV / n_total : 0.0
    return (f_max=f_max, f_mean=f_mean_density_weighted)
end

function main()
    println("=== A1 v3 — texture-inclusive GS scan for Eu nominal ===\n")
    @printf "Atom: %s, N=%d, ω_ref=%.1f rad/s\n" ATOM.name N_ATOMS OMEGA_REF
    @printf "Grid: 2D 16×16 quasi-2D, l_z=%.2f (MDDI)\n" L_Z_DDI
    @printf "c_dd (dimless) = %.4e   |  C_TOTAL = %.4e  → c_dd/C_TOTAL = %.4f\n" C_DD_DIMLESS C_TOTAL (
        C_DD_DIMLESS / C_TOTAL
    )
    @printf "Bz = 0 (no Zeeman bias)\n"
    @printf "%d inits × %d noise seeds = %d ITPs\n\n" length(ALL_INITS) length(NOISE_SEEDS) (
        length(ALL_INITS) * length(NOISE_SEEDS)
    )

    results = []
    for init in ALL_INITS, seed in NOISE_SEEDS
        print("  init=$init seed=$seed ... ")
        flush(stdout)
        ws, E, conv = run_one(init, seed)
        if ws === nothing
            println("FAILED")
            continue
        end
        breakdown = try
            energy_decomposition(ws)
        catch err
            @warn "energy_decomposition failed" err
            nothing
        end
        sd = try
            spin_density_diagnostic(ws)
        catch
            (f_max=NaN, f_mean=NaN)
        end
        push!(
            results,
            (
                init=init, seed=seed, ws=ws, E=E, conv=conv,
                breakdown=breakdown, f_max=sd.f_max, f_mean=sd.f_mean),
        )
        @printf "E=%.6f conv=%s f_max=%.4f\n" E (conv ? "✓" : "✗") sd.f_max
    end

    println()
    println("--- Per-run energy breakdown (sorted by total) ---\n")
    @printf "%-26s seed  %-10s  %-10s  %-10s  %-10s  %-10s  %-10s\n" "init" "E_kin" "E_trap" "E_dens" "E_spin" "E_ddi" "E_total"
    sorted = sort(results; by=r -> isnan(r.E) ? Inf : r.E)
    for r in sorted
        if r.breakdown === nothing
            @printf "%-26s %d  (E=%.4f, breakdown unavailable)\n" string(r.init) r.seed r.E
            continue
        end
        b = r.breakdown
        @printf "%-26s %d  %+.4e  %+.4e  %+.4e  %+.4e  %+.4e  %+.4e\n" string(r.init) r.seed b.kinetic b.trap b.density b.spin b.ddi b.total
    end

    println()
    println("--- Rank by E_total (full GP including MDDI) ---\n")
    for (i, r) in enumerate(sorted[1:min(end, 15)])
        @printf "  %2d. %-26s seed=%d  E=%.6f  E_ddi=%+.4e  f_max=%.4f\n" i string(r.init) r.seed r.E (
            r.breakdown === nothing ? NaN : r.breakdown.ddi
        ) r.f_max
    end

    println()
    println("--- Uniform vs texture winner comparison ---\n")
    uniform_results = filter(r -> r.init in UNIFORM_INITS, sorted)
    texture_results = filter(r -> r.init in TEXTURE_INITS, sorted)
    if !isempty(uniform_results) && !isempty(texture_results)
        u_best = uniform_results[1]
        t_best = texture_results[1]
        gap = t_best.E - u_best.E
        @printf "Uniform best:  %-26s seed=%d  E=%.6f\n" string(u_best.init) u_best.seed u_best.E
        @printf "Texture best:  %-26s seed=%d  E=%.6f\n" string(t_best.init) t_best.seed t_best.E
        @printf "ΔE (texture - uniform) = %+.6e\n" gap
        if gap < 0
            @printf "  → TEXTURE WINS by %.4f (fraction %.4f%% of |uniform E|)\n" abs(gap) (
                100abs(gap) / abs(u_best.E)
            )
            println("  → RETRACTION of v2 uniform-inert framing confirmed:")
            println("    Eu GS is a spatial spin texture, not a polyhedral inert state.")
        else
            @printf "  → Uniform inert wins by %.4f within this seed set.\n" gap
            println("  → Texture branch may still win at higher resolution / more seeds /")
            println("    different ansatz parameters; this is suggestive not conclusive.")
        end
    end

    # Save state for downstream comparison
    println()
    println("=== Done ===")
end

main()

#!/usr/bin/env julia
# The classical-field window at the #334 target point — MEASURED, not assumed.
#
# #334 asks whether a realistic cooling trajectory nucleates the ¹⁵¹Eu flower
# ground state in place at (κ = 1.8, B = 20 µG) or gets caught on the polarised
# branch. Before any SPGPE trajectory is launched, three numbers decide whether
# such a trajectory is representable at all, and every one of them is cheap:
#
#   1. **μ**, the chemical potential of the state the run must end on. The SPGPE
#      is undefined unless the C region extends above it (`ϵ_cut > μ`, enforced by
#      `spgpe_growth_rate`), so μ sets a FLOOR on the projector cutoff and hence
#      on the grid. Estimating μ from E/N is not good enough: the two differ by
#      the interaction energy, in the direction that flatters the grid.
#   2. **the occupied band** of that state, k where the norm runs out. The
#      campaign's grid (32³, box 24) has k_max = 4.19, and #335 §2 already notes
#      the band reaches k ≈ √(2µ) ≈ 4.3 — i.e. the condensate alone fills the
#      grid, leaving no room for a thermal band above it.
#   3. **T_c**, because "cool through the transition" only has a thermal reading
#      if the C region can hold the cloud at that temperature.
#
# Plus the two ratios that decide what the measurement can mean:
#
#   • **ΔE_total / k_BT** between the branches. The branches are 0.133 ℏω_ref
#     APART PER ATOM; at N = 5×10⁴ that is an extensive barrier, and if it is
#     ≫ T then equilibrium selection is deterministic and the whole question is
#     about the transient, not about a Boltzmann factor.
#   • **E_thermal(C region) / ΔE_total**. #334's acceptance criterion asks for
#     the branch to be read off the total energy against the two references. If
#     the C region's thermal energy is larger than the branch separation, that
#     criterion cannot be met literally and the classifier has to remove the
#     thermal part first. Better to know before the runs than after.
#
# Nothing here needs a GPU or more than a few seconds; it exists so the campaign
# design is derived from the target point rather than from the last campaign's
# grid.
#
# Env:
#   EW_KAPPA=1.8        trap oblateness (the target point's κ)
#   EW_B=20.0           field [µG]
#   EW_GRID=32 EW_BOX=24.0
#   EW_PIN=0.002        transverse pin ε [p-units] — the campaign pin
#   EW_SEEDS=figs/eu334/seeds     dir holding reference_{flower,m_minus_F}.jld2
#   EW_OUT=figs/eu334/window
#   EW_NT=1.0           C-region depth in thermal energies, ϵ_cut = µ + n_T·T
#
#   julia --project=. scripts/eu334/window.jl

using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    static_zeeman, spin_scalars, magnetization, orbital_angular_momentum,
    apply_operator_via_registry!, cell_volume, total_energy, CPUBackend,
    spgpe_growth_rate, spgpe_scattering_rate
using JLD2: jldopen
using DelimitedFiles: writedlm
using FFTW: fft
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)

const KAPPA = getf("EW_KAPPA", 1.8)
const B_UG = getf("EW_B", 20.0)
const GRID_N = Int(getf("EW_GRID", 32))
const BOX = getf("EW_BOX", 24.0)
const PIN = getf("EW_PIN", 0.002)
const N_T = getf("EW_NT", 1.0)
const SEEDS = gets("EW_SEEDS", joinpath("figs", "eu334", "seeds"))
const OUT = gets("EW_OUT", joinpath("figs", "eu334", "window"))
mkpath(OUT)

const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const NATOMS = PRESET.n_atoms
const A_HO = sqrt(Units.HBAR / (ATOM.mass * PRESET.omega_ref))
const A_S_HO = ATOM.a_s / A_HO                     # a_s in a_ho — the SPGPE's a_s
const MS_PER_TAU = 1e3 / PRESET.omega_ref

p_of(B) = Units.bfield_to_p(B * 1e-6, ATOM.g_F, PRESET.omega_ref)

base_kw(ε) = (; grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=PRESET.potential, zeeman=static_zeeman(; Bz=p_of(B_UG), Bx=ε, q=0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=CPUBackend(),
    ddi_padding=false, ddi_trunc_radius=-1.0)

"""ψ from a stored cell, with the parameter-epoch check every consumer owes: a
state converged in another epoch is not stationary in this Hamiltonian, and μ
read off it would be that mismatch."""
function load_cell(path)
    isfile(path) || error("no such cell: $path")
    jldopen(path, "r") do f
        g(k, d) = haskey(f, k) ? f[k] : d
        for (nm, got, want) in (("c0", g("c0", NaN), PRESET.interactions.c[0]),
            ("c1", g("c1", NaN), PRESET.interactions.c[1]),
            ("c_dd", g("c_dd", NaN), PRESET.c_dd))
            isnan(got) && continue
            abs(got - want) / max(abs(want), 1e-30) < 1e-8 ||
                error("cell/preset mismatch on $nm: $got vs $want — $path")
        end
        n = g("grid_n_points", nothing)
        n === nothing || first(n) == GRID_N ||
            error("cell grid $(first(n)) ≠ $GRID_N — $path")
        (; psi=Array{ComplexF64}(f["psi"]), B=Float64(g("B_uG", NaN)),
            E_stored=Float64(g("E_total", g("E", NaN))),
            pin=Float64(g("pin_bx", g("pin_eps", NaN))))
    end
end

"""(μ, E, ⟨F⊥⟩, F_z, L_z, J_z) at one ψ.

μ = Re⟨ψ, Ĥ[ψ]ψ⟩dV with the unit-norm convention ∫|ψ|²dV = 1, so it is the
per-atom chemical potential in ℏω_ref — the SAME number in the norm-N convention
the SPGPE needs, since ψ_N = √N ψ₁ with c⁽ᴺ⁾ = c⁽¹⁾/N leaves Ĥ[ψ] invariant.
That equivalence is what lets the reference energies (per atom) be reused by a
norm-N run, and it holds only while LHY is off: an n^(5/2) term does not scale."""
function state_scalars(psi, ε)
    ws = make_workspace(; base_kw(ε)...,
        sim_params=SimParams(; dt=0.002, n_steps=0, imaginary_time=false),
        psi_init=psi)
    dV = cell_volume(PRESET.grid)
    hpsi = similar(ws.state.psi)
    apply_operator_via_registry!(hpsi, ws)
    nrm2 = real(sum(abs2, ws.state.psi)) * dV
    mu = real(sum(conj(ws.state.psi) .* hpsi)) * dV / nrm2
    s = spin_scalars(psi, PRESET.grid)
    Lz = orbital_angular_momentum(psi, PRESET.grid, ws.fft_plans)
    Sz = magnetization(psi, PRESET.grid, SYS)
    (; mu, E=total_energy(ws), norm2=nrm2, s.fperp, s.fz, Lz, Sz, Jz=Lz + Sz)
end

"""Cumulative fraction of ‖ψ‖² below |k|, on the grid's own k-shells.

The occupied band is the thing the projector cutoff has to clear, and it is a
property of ψ, not of μ: `√(2µ)` is a Thomas-Fermi estimate of it and is what
#335 §2 quoted. Reported as the k at which a given fraction of the norm is
enclosed, so "the condensate fills the grid" is a number rather than an
impression."""
function band_edges(psi, fracs)
    g = PRESET.grid
    nd = ndims(psi) - 1
    D = size(psi)[end]
    ksq = g.k_squared
    tot = 0.0
    # accumulate |ψ̂(k)|² summed over components, then sort by |k|
    acc = zeros(Float64, size(ksq))
    for c in 1:D
        idx = ntuple(d -> d <= nd ? Colon() : c, nd + 1)
        f = fft(view(psi, idx...))
        acc .+= abs2.(f)
    end
    tot = sum(acc)
    ks = sqrt.(vec(ksq))
    w = vec(acc) ./ tot
    perm = sortperm(ks)
    ks, w = ks[perm], w[perm]
    cum = cumsum(w)
    out = Float64[]
    for fr in fracs
        i = findfirst(>=(fr), cum)
        push!(out, i === nothing ? NaN : ks[i])
    end
    out
end

# --- geometry / thermodynamics of the target point ---------------------------
const OMEGA_BAR_REL = (1.0 * 1.0 * KAPPA)^(1 / 3)        # ω̄/ω_ref
# Ideal-Bose T_c in ℏω_ref: k_BT_c = 0.94 ħω̄ N^{1/3}. Quoted as the SCALE the
# C region would have to hold, not as a prediction — interactions and finite N
# shift it by a few percent and that does not change any conclusion below.
const T_C = 0.94 * OMEGA_BAR_REL * NATOMS^(1 / 3)
const K_MAX = π / (BOX / GRID_N)                          # grid Nyquist
const EPS_MAX = 0.5 * K_MAX^2

# n_modes below k in a periodic box of volume V: V·(4π/3)k³/(2π)³
n_modes_below(k) = (BOX^3) * (4π / 3) * k^3 / (2π)^3

function main()
    flower = load_cell(joinpath(SEEDS, "reference_flower.jld2"))
    polar = load_cell(joinpath(SEEDS, "reference_m_minus_F.jld2"))
    ε = isnan(flower.pin) ? PIN : flower.pin

    @printf("\n#334 target point: κ = %.2f, B = %.1f µG, grid %d³, box %.1f, pin ε = %g\n",
        KAPPA, B_UG, GRID_N, BOX, ε)
    @printf("  N = %d, a_s/a_ho = %.5e, ω_ref/2π = %.1f Hz, 1 τ = %.4f ms\n",
        NATOMS, A_S_HO, PRESET.omega_ref / 2π, MS_PER_TAU)
    @printf("  c₀ = %.4g, c₁ = %.4g, c_dd = %.4g  (unit-norm epoch)\n",
        PRESET.interactions.c[0], PRESET.interactions.c[1], PRESET.c_dd)
    @printf("  grid k_max = %.3f, ϵ_max = ½k_max² = %.2f ℏω_ref\n", K_MAX, EPS_MAX)

    rows = Any[]
    for (name, cell) in (("flower", flower), ("polarised", polar))
        s = state_scalars(cell.psi, ε)
        be = band_edges(cell.psi, [0.99, 0.999, 0.9999])
        @printf("\n%s branch\n", name)
        @printf("  E/atom  = %.6f   (stored %.6f, Δ = %.2e);  ‖ψ‖²−1 = %.2e\n",
            s.E, cell.E_stored, s.E - cell.E_stored, s.norm2 - 1)
        @printf("  µ       = %.4f ℏω_ref      →  k_cut floor √(2µ) = %.3f\n",
            s.mu, sqrt(2 * s.mu))
        @printf("  ⟨F⊥⟩    = %.4f    F_z = %.4f    J_z = %.4f\n", s.fperp, s.fz, s.Jz)
        @printf("  band: 99%% of ‖ψ‖² below k = %.3f, 99.9%% below %.3f, 99.99%% below %.3f\n",
            be...)
        push!(rows, (name, s.E, s.mu, sqrt(2 * s.mu), s.fperp, s.fz, s.Jz, be...))
    end

    dE_atom = rows[2][2] - rows[1][2]
    dE_total = dE_atom * NATOMS
    @printf("\nbranch separation: ΔE = %.6f per atom = %.1f ℏω_ref total (N = %d)\n",
        dE_atom, dE_total, NATOMS)

    mu_ref = rows[1][3]        # the flower branch — the state a run must end on
    @printf("\nT_c (ideal Bose, ω̄/ω_ref = %.4f) = %.1f ℏω_ref = %.2f µK\n",
        OMEGA_BAR_REL, T_C, T_C * Units.HBAR * PRESET.omega_ref / Units.KB * 1e6)

    # --- the window table ---------------------------------------------------
    @printf("\nThe C region must satisfy ϵ_cut = µ + n_T·T with n_T = %.1f, and the grid\n", N_T)
    @printf("must resolve k_cut = √(2ϵ_cut). µ = %.3f is the floor; a grid whose k_max\n", mu_ref)
    @printf("is below it cannot represent ANY reservoir at this point.\n\n")
    hdr = ["T", "T/T_c", "eps_cut", "k_cut", "n_min_kmax_eq_kcut", "n_min_kmax_1.5kcut",
        "gamma", "M_bar", "tau_growth_ms", "dE_total_over_T", "E_therm_C_over_dE"]
    table = Any[]
    for T in (0.5, 1.0, 2.0, 5.0, 10.0, 20.0, T_C / 2, T_C, 1.2 * T_C)
        eps_cut = mu_ref + N_T * T
        k_cut = sqrt(2 * eps_cut)
        n_strict = ceil(Int, BOX * k_cut / π)
        n_comfort = ceil(Int, BOX * 1.5 * k_cut / π)
        γ = spgpe_growth_rate(; T, mu=mu_ref, eps_cut, a_s=A_S_HO)
        M = spgpe_scattering_rate(; T, mu=mu_ref, eps_cut, a_s=A_S_HO)
        # condensate growth e-folding time: the drift is γ(µ − L)ψ, so the rate
        # scale is γ·µ. Quoted in ms so it can be compared to a lab ramp.
        τ_ms = MS_PER_TAU / (γ * mu_ref)
        # thermal energy the C region carries, Rayleigh-Jeans: one T per mode
        # (classical equipartition), 2F+1 components.
        n_modes = n_modes_below(k_cut) * (2 * ATOM.F + 1)
        E_therm = n_modes * T
        push!(table, [T, T / T_C, eps_cut, k_cut, n_strict, n_comfort, γ, M, τ_ms,
            dE_total / T, E_therm / dE_total])
        @printf("  T=%7.2f  T/T_c=%.3f  ϵ_cut=%6.2f  k_cut=%5.2f  n≥%3d (%3d)  γ=%.3e  ℳ̄=%.3e  τ_grow=%8.1f ms  ΔE/T=%.3g  E_th/ΔE=%.3g\n",
            T, T / T_C, eps_cut, k_cut, n_strict, n_comfort, γ, M, τ_ms,
            dE_total / T, E_therm / dE_total)
    end

    bhdr = ["state", "E_atom", "mu", "sqrt_2mu", "fperp", "fz", "Jz", "k99", "k999", "k9999"]
    writedlm(joinpath(OUT, "branches.csv"),
        vcat(permutedims(bhdr), permutedims.(collect.(rows))...), '\t')
    writedlm(joinpath(OUT, "window.csv"), vcat(permutedims(hdr), permutedims.(table)...), '\t')
    @printf("\nwrote %s/{branches,window}.csv\n", OUT)
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main()
end

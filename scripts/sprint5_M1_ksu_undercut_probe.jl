#!/usr/bin/env julia
# scripts/sprint5_M1_ksu_undercut_probe.jl
#
# KSU axial-spin-texture undercut probe — closes the seed-completeness
# gap that `used_fallback` alone is BLIND to (stable-but-not-global
# undercut). See feedback caveat 2026-06-05.
#
# Question: does :axial_spin_texture (proper KSU spin texture, NOT the
# old mass-vortex-on-FM analog) find a lower-E basin than the Tier-1
# seeds (PCV, fl_vortex, chiral, AFM, skyrmion_lattice) at representative
# cells?
#
# Decision rule:
#   - undercut (NEW E < min(Tier-1 E) − ε_lattice) → STOP, lift KSU to
#     load-bearing Tier-1 before any full sweep
#   - no undercut (NEW E ≥ min(Tier-1 E))         → coverage confirmed,
#     fold KSU to revival-tier and proceed with the runner
#
# Cost: CPU 12³ (12 Eu D=13, small), ~5 seeds × 2 cells × ~5 min = ~50min.
# Cheap enough to parallelize with any GPU sweep.

using SpinorBEC
using SpinorBEC: SpinSystem
using LinearAlgebra
using Printf
using Random

const PROBE_GRID = make_grid(GridConfig{3}((12, 12, 12), (15.0, 15.0, 13.0)))
const PROBE_F = 6
const PROBE_D = 13
const PROBE_C0 = 30.0
const PROBE_C1 = PROBE_C0 / 36.0
const PROBE_CDD = PROBE_C0 * 0.09
const PROBE_IP = InteractionParams(Dict(0 => PROBE_C0, 1 => PROBE_C1))
const PROBE_POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))
const PROBE_N_ITP = 500
const PROBE_N_LBFGS = 800
const PROBE_TOL = 1e-4
const PROBE_SOBOLEV = 0.05
const NOISE_AMP = 0.01

# Two representative cells: texture-favored regime (low B, high Ω) +
# Larmor-favored regime (high B, high Ω). If KSU undercuts either, the
# coverage gap is real.
const PROBE_CELLS = [
    (B_nT=0.0, Ω=0.4, label="texture-favored (B=0, Ω=0.4)"),
    (B_nT=10.0, Ω=0.4, label="larmor-vs-texture (B=10, Ω=0.4)"),
]

# Seed roster: existing Tier-1 + the NEW axial_spin_texture
const PROBE_SEEDS = [
    :polar_core_vortex,
    :fl_vortex,
    :chiral_spin_vortex,
    :antiferromagnetic,
    :m_plus_F,                  # baseline uniform-FM (Larmor in high-B/high-Ω cells)
    :axial_spin_texture,        # NEW — KSU spin texture
]

# ─── Builders ─────────────────────────────────────────────────────────────

function build_seed(seed::Symbol)
    sys = SpinSystem(PROBE_F)
    return if seed === :polar_core_vortex
        init_psi(PROBE_GRID, sys; state=:polar_core_vortex, init_vortex_charge=1)
    elseif seed === :fl_vortex
        init_psi(PROBE_GRID, sys; state=:fl_vortex, init_vortex_charge=1)
    elseif seed === :chiral_spin_vortex
        init_psi(PROBE_GRID, sys; state=:chiral_spin_vortex, init_vortex_charge=1)
    elseif seed === :antiferromagnetic
        init_psi(PROBE_GRID, sys; state=:antiferromagnetic)
    elseif seed === :m_plus_F
        init_psi(PROBE_GRID, sys; state=:m_plus_F)
    elseif seed === :axial_spin_texture
        init_psi(PROBE_GRID, sys; state=:axial_spin_texture, init_vortex_charge=1)
    else
        throw(ArgumentError("Unknown probe seed: $seed"))
    end
end

# ─── Wind-check diagnostic ────────────────────────────────────────────────
#
# Distinguishes spin-texture from mass-vortex-on-FM by analyzing how the
# magnetization direction ⟨F̂(r)⟩ varies with position:
#
#   - mass-vortex-on-FM:  ⟨F̂⟩ ≈ const direction (e.g. +ẑ) with phase
#                         winding on one component → axial variance ≈ 0.
#   - spin texture:       ⟨F̂(r)⟩ direction varies in space → axial or
#                         transverse variance > 0.
#
# Returns the axial profile ⟨F_z⟩(z) and a scalar "texture indicator"
# (the L2 norm of (F_x(z), F_y(z), F_z(z) − ⟨F_z⟩) across axial slices,
# normalised by F). 0 = uniform, ~1 = full texture variation.

function spin_density_field(psi, F)
    # Per-voxel ⟨F_α(r)⟩ = (1/n(r)) Re(ψ†(r) F_α ψ(r))  for α ∈ {x, y, z}.
    # NOT density-weighted — caller does that in axial_profile.
    sm = spin_matrices(F)
    Fx, Fy, Fz = Matrix(sm.Fx), Matrix(sm.Fy), Matrix(sm.Fz)
    n_pts = size(psi)[1:3]
    D = size(psi, 4)
    fx_r = zeros(Float64, n_pts...)
    fy_r = zeros(Float64, n_pts...)
    fz_r = zeros(Float64, n_pts...)
    n_r = zeros(Float64, n_pts...)
    @inbounds for I in CartesianIndices(n_pts)
        ψ = view(psi, I, :)
        n_local = 0.0
        for c in 1:D
            n_local += abs2(ψ[c])
        end
        n_r[I] = n_local
        if n_local > 1e-30
            # Re(ψ† F_α ψ) = Σ_{c1,c2} Re(conj(ψ[c1]) · F_α[c1,c2] · ψ[c2])
            #             = Σ Re(a·b) with a = conj(ψ[c1])·ψ[c2], b = F_α[c1,c2]
            #             = Σ Re(a)·Re(b) − Im(a)·Im(b)
            fx_local = 0.0
            fy_local = 0.0
            fz_local = 0.0
            for c1 in 1:D, c2 in 1:D
                a = conj(ψ[c1]) * ψ[c2]
                w_r = real(a)
                w_i = imag(a)
                fx_local += w_r * real(Fx[c1, c2]) - w_i * imag(Fx[c1, c2])
                fy_local += w_r * real(Fy[c1, c2]) - w_i * imag(Fy[c1, c2])
                fz_local += w_r * real(Fz[c1, c2]) - w_i * imag(Fz[c1, c2])
            end
            fx_r[I] = fx_local / n_local  # NORMALIZE here
            fy_r[I] = fy_local / n_local
            fz_r[I] = fz_local / n_local
        end
    end
    return (; fx=fx_r, fy=fy_r, fz=fz_r, n=n_r)
end

function axial_profile(field, n_r)
    # Density-weighted average over (x, y) at each z.
    Lz = size(field, 3)
    out = zeros(Float64, Lz)
    for iz in 1:Lz
        num = sum(view(field, :, :, iz) .* view(n_r, :, :, iz))
        den = sum(view(n_r, :, :, iz))
        out[iz] = den > 1e-30 ? num / den : 0.0
    end
    return out
end

function wind_check(psi, F)
    fields = spin_density_field(psi, F)
    fz_z = axial_profile(fields.fz, fields.n)
    fx_z = axial_profile(fields.fx, fields.n)
    fy_z = axial_profile(fields.fy, fields.n)
    fz_mean = sum(fz_z) / length(fz_z)
    # Texture indicator: total L2 deviation of (F_x, F_y, F_z − ⟨F_z⟩)
    # axial profiles, normalised by F (so 0 = uniform, ~1 = full
    # axial-spin-rotation texture).
    tex_indicator =
        sqrt(sum(fx_z .^ 2) + sum(fy_z .^ 2) + sum((fz_z .- fz_mean) .^ 2)) /
        (F * sqrt(length(fz_z)))
    return (; fz_z, fx_z, fy_z, fz_mean, tex_indicator)
end

# ─── Per-seed run ──────────────────────────────────────────────────────────

function run_seed(B_nT::Float64, Ω::Float64, seed::Symbol)
    p_lab = B_nT * 0.148
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    psi_raw = build_seed(seed)
    SpinorBEC.add_white_noise!(psi_raw, NOISE_AMP, 17, PROBE_GRID)
    wc_raw = wind_check(psi_raw, PROBE_F)

    r_itp = find_ground_state(;
        grid=PROBE_GRID, atom=SpinorBEC.Eu151, interactions=PROBE_IP,
        zeeman=zeeman, potential=PROBE_POT,
        dt=0.005, n_steps=PROBE_N_ITP, tol=1e-12,
        initial_state=:polar, verbose=false,
        psi_init=psi_raw,
        enable_ddi=true, c_dd=PROBE_CDD, secular_ddi=false,
        rotating_frame_omega=Ω,
    )
    r = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=r_itp.workspace,
        n_steps=PROBE_N_LBFGS, tol=PROBE_TOL,
        verbose=false, sobolev_alpha=PROBE_SOBOLEV,
    )

    psi_final = Array(r.workspace.state.psi)
    wc_final = wind_check(psi_final, PROBE_F)
    return (; seed, E=r.energy, grad_norm=r.grad_norm,
        converged=r.converged, wc_raw, wc_final, psi=psi_final)
end

# ─── Probe driver ─────────────────────────────────────────────────────────

function probe_cell(B_nT::Float64, Ω::Float64, label::String)
    @printf "\n=== Cell: %s (B=%.1f nT, Ω=%.2f) ===\n" label B_nT Ω
    @printf "  raw-seed wind-check (texture indicator > 0 ⇒ spin texture):\n"
    results = []
    for seed in PROBE_SEEDS
        r = run_seed(B_nT, Ω, seed)
        push!(results, r)
        @printf "    %-22s  E=%+.5f  ‖∇E‖=%.2e  conv=%-5s  tex(raw)=%.3f  tex(final)=%.3f  ⟨F_z⟩(raw)=%+.3f  ⟨F_z⟩(final)=%+.3f\n" string(seed) r.E r.grad_norm r.converged r.wc_raw.tex_indicator r.wc_final.tex_indicator r.wc_raw.fz_mean r.wc_final.fz_mean
    end

    # Rank by E
    sorted = sort(results, by=r -> r.E)
    @printf "\n  Ranked by E:\n"
    for (i, r) in enumerate(sorted)
        flag = (i == 1) ? "★ winner" : "        "
        @printf "    %s  #%d  %-22s  E=%+.5f  tex(final)=%.3f\n" flag i string(r.seed) r.E r.wc_final.tex_indicator
    end

    # Undercut verdict
    new_seed_result = results[findfirst(r -> r.seed === :axial_spin_texture, results)]
    tier1_best = minimum(r.E for r in results if r.seed !== :axial_spin_texture)
    ΔE = new_seed_result.E - tier1_best
    @printf "\n  Undercut verdict:\n"
    @printf "    Tier-1 best E:           %+.5f\n" tier1_best
    @printf "    :axial_spin_texture E:   %+.5f\n" new_seed_result.E
    @printf "    ΔE (new − Tier1_best):   %+.5f\n" ΔE
    if ΔE < -1e-3
        @printf "    ⚠ UNDERCUT — new seed finds lower-E basin. KSU coverage gap CONFIRMED.\n"
    elseif ΔE > 1e-3
        @printf "    ✓ no undercut — Tier-1 already covers (or undercuts) the KSU basin.\n"
    else
        @printf "    ◆ basins co-locate within ε=1e-3 (likely same min); marginal/ambiguous.\n"
    end
    return (; label, B_nT, Ω, results, ΔE, undercut=(ΔE < -1e-3))
end

function main()
    @info "KSU undercut probe — CPU 12³, ~10min total"
    @info "Seeds: $(PROBE_SEEDS)"
    @info "Cells: $(PROBE_CELLS)"

    summaries = []
    for cell in PROBE_CELLS
        s = probe_cell(cell.B_nT, cell.Ω, cell.label)
        push!(summaries, s)
    end

    @printf "\n=== Probe summary ===\n"
    any_undercut = false
    for s in summaries
        flag = s.undercut ? "⚠ UNDERCUT" : "✓ ok      "
        @printf "  %s  %s  ΔE = %+.5f\n" flag s.label s.ΔE
        any_undercut = any_undercut || s.undercut
    end
    @printf "\n=== Decision ===\n"
    if any_undercut
        println("⚠ At least one cell shows KSU undercut. STOP before full-sweep launch.")
        println("  Lift :axial_spin_texture to Tier-1 (always-multistart) before any production sweep.")
    else
        println("✓ No undercut at probed cells. Existing Tier-1 coverage is sufficient.")
        println("  Fold :axial_spin_texture to Tier-4 revival-validation; proceed with launch.")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

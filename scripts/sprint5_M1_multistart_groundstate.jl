#!/usr/bin/env julia
# scripts/sprint5_M1_multistart_groundstate.jl
#
# Multi-start ground-state sweep for M1 rotating-frame phase diagram.
# Replaces sprint5_M1_ITP_omega_sweep_converged.jl's 2-seed methodology
# with the post-2026-06-05 texture-primary taxonomy + stability check
# + adiabatic re-anchoring.
#
# Spine G atomic finalization is now load-bearing (commit 3c3c3887):
# `find_ground_state_lbfgs` returns {ψ, E, ∇E} guaranteed self-consistent.
#
# Outputs: same directory layout as the predecessor (cell_*.jld2 per cell),
# but the saved struct includes:
#   - psi : ψ at the WINNER candidate (lowest-E among stable)
#   - E, grad_norm, converged : atomic triple from `_finalize_lbfgs_atomic!`
#   - winner_seed : which seed produced this ψ
#   - stability_verdict : :stable | :saddle | :ambiguous
#   - competing_candidates : Vector{NamedTuple} of other stable candidates
#     (seed, E, ΔE_from_winner) — load-bearing for c1 inference
#   - anchor_history : Vector{Symbol} — per-step :multi_start | :adiabatic
#
# Usage:
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#     scripts/sprint5_M1_multistart_groundstate.jl
#
# Memory:
#   - m1_multistart_seedset_2026_06_05.md (seed taxonomy)
#   - m1_save_bug_two_basins_2026_06_05.md (G atomic, save-bug closure)

import CUDA
using SpinorBEC
using SpinorBEC: SpinSystem
using LinearAlgebra
using Printf
using JLD2
using Random

const TW = eu151_preset()  # 24³, N=5×10⁴
const OUT_DIR = "runs/sprint5_M1_multistart_groundstate"
const N_ITP = 3000
const N_LBFGS = 15000
const TOL_LBFGS = 1e-5
const SOBOLEV = 0.05
const DT = 0.005
const NOISE_AMP = 0.01

# Sweep grid
const B_VALUES_NT = [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]
const OMEGAS = [0.0, 0.1, 0.2, 0.4, 0.6]

# Adiabatic re-anchor cadence
const N_ANCHOR = 5                # re-anchor every N_ANCHOR cells along inner sweep
const TOL_BRANCH_E = 1e-3         # E_tracked > E_multistart + TOL → switch
const TOL_OVERLAP = 1e-2          # overlap drop trigger

# Stability check
const ε_PERTURB = 1e-3
const N_RECONVERGE = 500
const TOL_OVERLAP_STABLE = 1e-3   # ‖ψ_cand − ψ_reconverge‖ < TOL → stable
const TOL_E_SADDLE = 1e-5         # E_reconv < E_cand − TOL → saddle (found lower)

# ─── Seed taxonomy (per m1_multistart_seedset_2026_06_05.md) ───────────────

# Tier 1 — texture primary (real basins per Phase-1 arc closure)
# NOTE: :ksu_circulation in north_star plan is axial m_plus_F + winding
# but no init_psi builder exists; future addition. Currently covered
# approximately by :polar_core_vortex (axial polar core) + :radial_spin_vortex
# (xy winding) + :chiral_spin_vortex (chiral winding).
const TIER1_SEEDS = [
    :polar_core_vortex,
    :radial_spin_vortex,
    :antiferromagnetic,
    :chiral_spin_vortex,
    :skyrmion_lattice,
]

# Tier 2 — baseline reference (control)
const TIER2_SEEDS = [:polar]

# Tier 3 — FM (Larmor-driven uniform; high Ω + high B)
const TIER3_SEEDS = [:m_plus_F]

# Tier 4 — phantom-validation (Ω>0 revival candidates) — actively run
# at boundary cells. :axial_spin_texture folded here per the 2026-06-05
# KSU undercut probe (m1_ksu_undercut_probe_2026_06_05.md): no undercut
# at 12³ probed cells, all seeds find the same basin. Kept in revival-
# tier as a safety net in case 24³ landscape differs.
# NOTE: :icosahedral_explicit / :vortex_lattice not yet wired here.
# Documented future additions.
const TIER4_SEEDS = [
    :cyclic,
    :biaxial_nematic,
    :spin_helix,
    :axial_spin_texture,        # KSU revival, per 2026-06-05 probe
]

"""
    seeds_for_cell(B_nT, Ω) → Vector{Symbol}

Apply the pruning rule from m1_multistart_seedset_2026_06_05.md.
"""
function seeds_for_cell(B_nT::Float64, Ω::Float64)
    seeds = vcat(TIER1_SEEDS, TIER2_SEEDS)              # always
    if B_nT >= 10.0 || Ω >= 0.4
        append!(seeds, TIER3_SEEDS)                      # Ω-large or B-large
    end
    # Boundary cells: low B + high Ω OR very high Ω — run full Tier-4
    # revival set (polyhedral inerts + KSU axial texture).
    if (B_nT < 2.6 && Ω >= 0.4) || Ω >= 0.6
        append!(seeds, TIER4_SEEDS)
    end
    return seeds
end

# ─── Seed builders ────────────────────────────────────────────────────────

function build_seed(seed::Symbol, grid)
    sys = SpinSystem(TW.F)
    return if seed === :polar_core_vortex
        init_psi(grid, sys; state=:polar_core_vortex, init_vortex_charge=1)
    elseif seed === :radial_spin_vortex
        init_psi(grid, sys; state=:radial_spin_vortex, init_vortex_charge=1)
    elseif seed === :antiferromagnetic
        init_psi(grid, sys; state=:antiferromagnetic)
    elseif seed === :chiral_spin_vortex
        init_psi(grid, sys; state=:chiral_spin_vortex, init_vortex_charge=1)
    elseif seed === :skyrmion_lattice
        init_psi(grid, sys; state=:skyrmion_lattice)
    elseif seed === :polar
        init_psi(grid, sys; state=:polar)
    elseif seed === :m_plus_F
        init_psi(grid, sys; state=:m_plus_F)
    elseif seed === :cyclic
        init_psi(grid, sys; state=:cyclic)
    elseif seed === :biaxial_nematic
        init_psi(grid, sys; state=:biaxial_nematic)
    elseif seed === :spin_helix
        init_psi(grid, sys; state=:spin_helix)
    elseif seed === :vortex_lattice
        init_psi(grid, sys; state=:vortex_lattice)
    else
        throw(ArgumentError("Unknown seed: $seed"))
    end
end

# ─── Stability check: perturb-and-reconverge ──────────────────────────────

"""
    stability_check(ws, psi_candidate; ε=ε_PERTURB, n_reconv=N_RECONVERGE)
        → (:stable | :saddle | :ambiguous, psi_new_or_nothing, ΔE)

Adds a random perturbation of magnitude ε to ψ_candidate, runs LBFGS for
n_reconv steps, and classifies based on where it lands. Returns the new
ψ if a lower basin was found.
"""
function stability_check(ws, psi_candidate, B_nT, Ω; ε=ε_PERTURB, n_reconv=N_RECONVERGE)
    rng = MersenneTwister(round(Int, 1000 * B_nT + 100 * Ω))
    # Perturb
    psi_perturb = copy(psi_candidate) .+
        ε .* (randn(rng, ComplexF64, size(psi_candidate)) .+
              im .* randn(rng, ComplexF64, size(psi_candidate)))
    # Renormalize
    dV = SpinorBEC.cell_volume(ws.grid)
    psi_perturb ./= sqrt(sum(abs2, psi_perturb) * dV)

    # Energy at original candidate
    copyto!(ws.state.psi, psi_candidate)
    E_cand = Float64(SpinorBEC.total_energy(ws))

    # Reconverge from perturbed
    r_reconv = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=ws,
        psi_init=psi_perturb,
        n_steps=n_reconv, tol=TOL_LBFGS,
        verbose=false, sobolev_alpha=SOBOLEV,
    )
    psi_reconv = Array(r_reconv.workspace.state.psi)
    E_reconv = r_reconv.energy

    # Overlap to determine if we returned to candidate or escaped
    overlap = abs(sum(conj.(psi_candidate) .* psi_reconv)) * dV
    overlap_norm = overlap /
        sqrt(sum(abs2, psi_candidate) * dV * sum(abs2, psi_reconv) * dV)
    ψ_diff_L2 = sqrt(sum(abs2, psi_candidate .- psi_reconv) * dV)

    ΔE = E_reconv - E_cand
    if ΔE < -TOL_E_SADDLE
        # Found a lower basin → candidate was a saddle
        return (:saddle, psi_reconv, ΔE)
    elseif ψ_diff_L2 < TOL_OVERLAP_STABLE
        return (:stable, nothing, ΔE)
    else
        # Drifted to a different (but not lower) basin — ambiguous
        return (:ambiguous, psi_reconv, ΔE)
    end
end

# ─── Per-seed run ──────────────────────────────────────────────────────────

"""
    run_seed(B_nT, Ω, seed; psi_warmstart=nothing)
        → NamedTuple(seed, E, grad_norm, converged, stability, psi)
"""
function run_seed(B_nT::Float64, Ω::Float64, seed::Symbol;
        psi_warmstart::Union{Nothing, AbstractArray}=nothing)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )

    psi_init = if psi_warmstart === nothing
        psi = build_seed(seed, TW.grid)
        SpinorBEC.add_white_noise!(psi, NOISE_AMP, abs(round(Int, 1e6 * B_nT + 1e4 * Ω)), TW.grid)
        psi
    else
        copy(psi_warmstart)
    end

    # ITP + LBFGS (atomic-G finalization via the driver epilogue commit 3c3c3887)
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT, n_steps=(psi_warmstart === nothing ? N_ITP : 0),
        tol=1e-12, initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=Ω, backend=CUDABackend(),
    )
    r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=r_itp.workspace,
        n_steps=N_LBFGS, tol=TOL_LBFGS,
        verbose=false, sobolev_alpha=SOBOLEV,
    )

    # Atomic guarantee: ws.state.psi corresponds to E and grad_norm
    psi_final = Array(r_lbfgs.workspace.state.psi)

    # Stability check
    stability, psi_escape, ΔE_stab = stability_check(
        r_lbfgs.workspace, psi_final, B_nT, Ω)

    if stability === :saddle
        # Refit at the escaped basin
        r2 = SpinorBEC.find_ground_state_lbfgs(;
            ws_init=r_lbfgs.workspace,
            psi_init=psi_escape,
            n_steps=N_LBFGS, tol=TOL_LBFGS,
            verbose=false, sobolev_alpha=SOBOLEV,
        )
        psi_final = Array(r2.workspace.state.psi)
        # Re-verify stability of the escaped basin
        stability2, _, _ = stability_check(r2.workspace, psi_final, B_nT, Ω)
        return (;
            seed, E=r2.energy, grad_norm=r2.grad_norm,
            converged=r2.converged, stability=stability2,
            psi=psi_final, prior_saddle_E=r_lbfgs.energy, ΔE_escape=ΔE_stab,
        )
    end

    return (;
        seed, E=r_lbfgs.energy, grad_norm=r_lbfgs.grad_norm,
        converged=r_lbfgs.converged, stability=stability,
        psi=psi_final,
    )
end

# ─── Winner selection (pure; unit-testable in isolation) ─────────────────
#
# Critical contract: **stability filter PRECEDES E-ranking**. A lower-E
# saddle MUST NOT win over a higher-E true minimum — `:saddle` and
# `:ambiguous` candidates are excluded from the winner pool before
# `argmin` runs. Without this ordering, the runner would silently report
# saddles as the GS at degenerate-landscape cells (the cyclic-saddle
# case in M1 cells with Ω=0).
#
# Returns `(winner, competing, used_fallback)` where:
#   - `winner` is the selected candidate (NamedTuple from the candidates
#     vector).
#   - `competing` is the other `:stable && converged` candidates,
#     sorted by E ascending.
#   - `used_fallback` is `true` when no `:stable && converged` candidate
#     exists (full-set argmin fallback was used; the caller may want to
#     print a warning).
#
# Empty `candidates` is an upstream programming error; we throw.

function _select_winner(candidates::AbstractVector)
    isempty(candidates) && throw(ArgumentError("_select_winner: empty candidate list"))
    stable = filter(c -> c.stability === :stable && c.converged, candidates)
    used_fallback = isempty(stable)
    pool = used_fallback ? candidates : stable
    winner = pool[argmin([c.E for c in pool])]
    competing = filter(c -> c !== winner && c.stability === :stable && c.converged, candidates)
    sort!(competing, by=c -> c.E)
    return (winner, competing, used_fallback)
end

# ─── Per-cell driver ──────────────────────────────────────────────────────

function run_cell(B_nT::Float64, Ω::Float64;
        warmstart_psi::Union{Nothing, AbstractArray}=nothing,
        warmstart_seed::Union{Nothing, Symbol}=nothing,
        force_anchor::Bool=false)
    @printf "\n[cell B=%.1f Ω=%.2f]\n" B_nT Ω
    candidates = []

    # If warm-start available and not force-anchor: do warm-start first
    if warmstart_psi !== nothing && !force_anchor
        @printf "  warm-start from %s (adiabatic continuation)\n" string(warmstart_seed)
        r = run_seed(B_nT, Ω, warmstart_seed; psi_warmstart=warmstart_psi)
        push!(candidates, r)
        @printf "    E=%.6f  ‖∇E‖=%.3e  conv=%s  stability=%s\n" r.E r.grad_norm r.converged r.stability
    end

    # Full multi-start (always at anchor points; supplement after warm-start)
    if warmstart_psi === nothing || force_anchor
        for seed in seeds_for_cell(B_nT, Ω)
            r = run_seed(B_nT, Ω, seed)
            push!(candidates, r)
            @printf "  seed=%-20s E=%.6f  ‖∇E‖=%.3e  conv=%s  stability=%s\n" string(seed) r.E r.grad_norm r.converged r.stability
        end
    end

    winner, competing, used_fallback = _select_winner(candidates)
    if used_fallback
        @printf "  ⚠ NO stable converged candidate; using lowest-E from full set\n"
    end

    @printf "  ✓ winner: seed=%s  E=%.6f  ‖∇E‖=%.3e  competing=%d\n" string(winner.seed) winner.E winner.grad_norm length(competing)

    return (;
        B_nT, omega=Ω,
        winner_seed=winner.seed, E=winner.E, grad_norm=winner.grad_norm,
        converged=winner.converged, stability=winner.stability,
        psi=winner.psi,
        competing_candidates=[(; c.seed, c.E, ΔE=c.E - winner.E) for c in competing],
        all_candidates_summary=[(; c.seed, c.E, c.grad_norm, c.stability) for c in candidates],
    )
end

# ─── Sweep driver with adiabatic re-anchoring ─────────────────────────────

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)

    @info "M1 multi-start ground state sweep — texture-primary, stability-checked, adiabatic-re-anchored"
    @info "Seed taxonomy: m1_multistart_seedset_2026_06_05.md"
    @info "Atomic G: commit 3c3c3887"
    @info "Grid" B_VALUES_NT OMEGAS
    @info "N_ITP=$N_ITP, N_LBFGS=$N_LBFGS, tol=$TOL_LBFGS, sobolev_α=$SOBOLEV"
    @info "Adiabatic: re-anchor every $N_ANCHOR cells"
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    results = Dict{Tuple{Float64, Float64}, Any}()

    cell_idx = 0
    prev_winner = nothing
    for B_nT in B_VALUES_NT, Ω in OMEGAS
        cell_idx += 1
        is_anchor = (cell_idx % N_ANCHOR == 1)  # first cell of every block

        r = run_cell(B_nT, Ω;
            warmstart_psi=(is_anchor ? nothing : (prev_winner !== nothing ? prev_winner.psi : nothing)),
            warmstart_seed=(is_anchor ? nothing : (prev_winner !== nothing ? prev_winner.winner_seed : nothing)),
            force_anchor=is_anchor,
        )
        results[(B_nT, Ω)] = r
        prev_winner = r

        # Save per-cell atomically (G provenance)
        cell_path = joinpath(OUT_DIR,
            @sprintf("cell_B%.1f_Om%.2f.jld2", B_nT, Ω))
        JLD2.jldopen(cell_path, "w") do f
            f["psi"] = r.psi
            f["result"] = Dict(
                "B_nT" => B_nT, "omega" => Ω,
                "winner_seed" => string(r.winner_seed),
                "E" => r.E, "grad_norm" => r.grad_norm,
                "converged" => r.converged,
                "stability" => string(r.stability),
            )
            f["competing_candidates"] = [
                (string(c.seed), c.E, c.ΔE) for c in r.competing_candidates]
            f["all_candidates_summary"] = [
                (string(c.seed), c.E, c.grad_norm, string(c.stability))
                for c in r.all_candidates_summary]
            f["anchor_step"] = is_anchor
        end
        CUDA.reclaim()
    end

    @info "Sweep complete. Cells in OUT_DIR." OUT_DIR
end

# Guard so test files (and other includers) can load `_select_winner` and
# friends without triggering the full GPU sweep.
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

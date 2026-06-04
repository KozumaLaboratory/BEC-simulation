#!/usr/bin/env julia
# scripts/m1_basin_valley_discriminator.jl
#
# Positive discriminator between (a) "multiple basins" and (a')
# "soft Goldstone valley around a single basin" — the two failure
# modes that look the same in the (a)/(b)/(c) triage but require
# **opposite** cures:
#
#   (a)  : seeds land at DIFFERENT energies AT PLATEAU  ⟹ seed diversification works
#   (a') : seeds land at SAME energy AT PLATEAU (different states up to
#          symmetry)                                    ⟹ seeds wasted;
#          need soft-mode preconditioning or criterion change
#          (gauge fixing, vortex-core anchoring).
#
# ─── ORDERING DISCIPLINE ──────────────────────────────────────────
# Plateau detection is the FIRST gate. Reading structure (ΔE, overlap)
# from unconverged-state-pair differences is the same mistake the
# (a)/(b)/(c) audit was built to prevent — same as `mistake_*`. ΔE
# between two non-extremum points in the SAME basin (or in a soft
# valley) can easily be 0.05; only AT PLATEAU does ΔE carry a basin
# signal.
#
# Verdict order (strict):
#   1. Plateau gate: ≥ 2 seeds must plateau (phase-2 ‖∇E‖ ratio
#      AND phase-2 ΔE both below thresholds). Otherwise INCONCLUSIVE
#      → recommend re-run with longer N_LBFGS, NO structural read.
#   2. Among plateau'd seeds, **overlap is the primary signal**:
#      - overlap > 0.95              → same basin, same state
#      - overlap < 0.30 + ΔE > 0.01  → multiple basins
#      - overlap < 0.30 + ΔE < 0.01  → soft valley (same energy,
#                                       different states)
#      - overlap medium              → INCONCLUSIVE
#   3. ΔE never decides on its own; only enters the multi-basin vs
#      soft-valley branch where it differentiates two cases that low
#      overlap already qualified.
#
# See "Methodology gaps in the (a)/(b)/(c) audit" in
# mistake_unconverged_to_new_physics_ignoring_analytical_oracle.md.
#
# Procedure: at ONE hard Ω > 0 cell, run two-phase LBFGS (N/2 + N/2)
# from 3-4 distinct seeds (polar, fl_vortex, transverse-x polarised,
# vortex charge=2). Report:
#   * E_phase1, E_phase2, ΔE_phase2 (energy progress in second half)
#   * ‖∇E‖_phase1, ‖∇E‖_phase2, grad_ratio (plateau signal)
#   * ‖P_⊥∇E‖_final per seed (projected residual, comparable to gate)
#   * pairwise wavefunction overlap |⟨ψ_a, ψ_b⟩|² (gauge-invariant)
#   * verdict gated on plateau status, then overlap, then ΔE.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m1_basin_valley_discriminator.jl
#
# Optional CLI args:
#   --B-nT VALUE     (default 0.0)
#   --omega VALUE    (default 0.4)
#   --n-lbfgs N      (default 5000)
#   --cpu            (force CPU backend)
#
# Cost: ~1 cell × ~3 seeds × LBFGS budget. On GPU ≈ 1-1.5 h. The
# audit's verdict drives the choice of whether to invest 3 h of
# seed time in the full sweep extend.

const USE_CPU = "--cpu" in ARGS

if !USE_CPU
    import CUDA
end
using SpinorBEC
using LinearAlgebra
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

function get_arg_float(name::String, default::Float64)
    for (i, a) in enumerate(ARGS)
        if a == name && i + 1 <= length(ARGS)
            return parse(Float64, ARGS[i + 1])
        end
    end
    return default
end
function get_arg_int(name::String, default::Int)
    for (i, a) in enumerate(ARGS)
        if a == name && i + 1 <= length(ARGS)
            return parse(Int, ARGS[i + 1])
        end
    end
    return default
end

const TW = eu_digital_twin()
const B_NT = get_arg_float("--B-nT", 0.0)
const OMEGA = get_arg_float("--omega", 0.4)
const N_LBFGS = get_arg_int("--n-lbfgs", 5000)
const N_LBFGS_PHASE_1 = N_LBFGS ÷ 2
const N_LBFGS_PHASE_2 = N_LBFGS - N_LBFGS_PHASE_1
const TOL_LBFGS = 1e-5
const SOBOLEV = 0.05
const N_ITP = 3000
const NOISE_AMP = 0.01
const NOISE_SEED = 1
const BACKEND = USE_CPU ? CPUBackend() : CUDABackend()

# Plateau detection thresholds. A seed is "plateau'd" when phase 2
# of its LBFGS run reduces neither ‖∇E‖ nor E meaningfully:
#   * grad_ratio  = ‖∇E‖_phase2_end / ‖∇E‖_phase1_end ≥ THRESH_GRAD_RATIO
#     (phase 2 didn't reduce the gradient norm by more than 1 - threshold)
#   * dE_phase2   = E_phase1_end − E_phase2_end ≤ THRESH_DE
#     (phase 2 didn't lower the energy by more than threshold)
# Both must hold to call plateau. Otherwise descent is still active
# and any structure read is premature.
const PLATEAU_THRESH_GRAD_RATIO = 0.7   # phase2 ‖∇E‖ ≥ 70% of phase1
const PLATEAU_THRESH_DE = 1e-4          # phase2 dropped <1e-4 in E

# Verdict thresholds (applied ONLY after plateau gate passes).
const VERDICT_OVERLAP_SAME = 0.95       # same basin + same state if overlap > this
const VERDICT_OVERLAP_DIFF = 0.30       # different basin/state if overlap < this
const VERDICT_DE_BASIN = 0.01           # ΔE > this (and low overlap) ⇒ different basins

# Seed catalog. Two of these (polar, fl_vortex) are what the live
# sweep used; the discriminator's value is in the EXTRA seeds —
# specifically `transverse_x` (full F_x eigenstate, m=+F along x)
# and `fl_vortex_q2` (vortex charge 2 instead of 1).
const SEEDS = [
    (:polar, "polar (m=0)"),
    (:fl_vortex, "fl_vortex(q=1)"),
    (:transverse_x, "transverse-x polarised"),
    (:fl_vortex_q2, "fl_vortex(q=2)"),
]

function build_seed(state::Symbol, grid)
    sys = SpinSystem(TW.F)
    # Prefer the named state-zoo wrappers (`init_psi_<name>` in
    # `src/workflow/initialization/state_zoo.jl`) over raw `init_psi`
    # calls. There is no `init_psi_transverse_x`; the canonical
    # equivalent for "F_x +polarised" is the spin_coherent wrapper
    # at θ=π/2, φ=0.
    if state == :fl_vortex
        return SpinorBEC.init_psi_fl_vortex(grid, sys; winding=1)
    elseif state == :fl_vortex_q2
        return SpinorBEC.init_psi_fl_vortex(grid, sys; winding=2)
    elseif state == :transverse_x
        return SpinorBEC.init_psi_spin_coherent(grid, sys; theta=π/2, phi=0.0)
    else
        return init_psi(grid, sys; state=state)
    end
end

# Compute the projected residual ‖P_⊥∇E‖ = ‖grad − μ·ψ‖, where
# μ = Re ⟨grad, ψ⟩ / ‖ψ‖². Comparable to the LBFGS gate.
#
# energy_gradient!'s default k_squared_dev=ws.grid.k_squared is CPU-only;
# on a GPU workspace the kinetic term's kernel compile fails with
# "non-bitstype" because the CPU Array can't be passed into the CUDA
# kernel. find_ground_state_lbfgs handles this by pre-computing a
# device-resident copy (driver.jl L109): `_to_device(ws.backend, ws.grid.k_squared)`.
# We replicate that here.
function projected_residual(ws, psi_cpu, dV)
    grad_dev = similar(ws.state.psi)
    k_squared_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev)
    grad_cpu = Array(grad_dev)
    psi_norm² = sum(abs2, psi_cpu) * dV
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / psi_norm²
    res = grad_cpu .- μ .* psi_cpu
    return sqrt(sum(abs2, res) * dV), μ
end

function run_one_seed(seed_state::Symbol, label::String)
    @printf "\n=== seed: %s ===\n" label
    flush(stdout)
    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    psi_init = build_seed(seed_state, TW.grid)
    add_noise!(psi_init, NOISE_AMP, NOISE_SEED, TW.grid)
    # When psi_init is supplied, find_ground_state ignores `initial_state`
    # — but the kwarg is required. Map our internal seed labels to a
    # valid symbol in init_psi's dispatch table.
    initial_state_for_fgs = if seed_state in (:fl_vortex, :fl_vortex_q2)
        :fl_vortex
    elseif seed_state == :transverse_x
        :spin_coherent
    else
        seed_state   # :polar (or any other directly-valid symbol)
    end

    t0 = time()
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=N_ITP, tol=1e-7,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA,
        backend=BACKEND)
    t_itp = time() - t0

    # Phase 1 — half of the LBFGS budget.
    t0 = time()
    r_p1 = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=r_itp.workspace,
        n_steps=N_LBFGS_PHASE_1, tol=TOL_LBFGS,
        verbose=false, sobolev_alpha=SOBOLEV,
    )
    t_p1 = time() - t0
    E_p1 = r_p1.energy
    grad_p1_raw = r_p1.grad_norm

    # Phase 2 — warm-start from phase-1 workspace, run the rest. The
    # delta between phases is what tells us if descent has plateau'd.
    t0 = time()
    r_p2 = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=r_p1.workspace,
        n_steps=N_LBFGS_PHASE_2, tol=TOL_LBFGS,
        verbose=false, sobolev_alpha=SOBOLEV,
    )
    t_p2 = time() - t0
    E_p2 = r_p2.energy
    grad_p2_raw = r_p2.grad_norm

    # Plateau signals.
    grad_ratio = grad_p2_raw / max(grad_p1_raw, eps())
    dE_phase2 = E_p1 - E_p2
    plateau = grad_ratio > PLATEAU_THRESH_GRAD_RATIO &&
              dE_phase2 < PLATEAU_THRESH_DE

    ws_out = r_p2.workspace
    psi_out = Array(ws_out.state.psi)
    dV = SpinorBEC.cell_volume(TW.grid)
    res_norm, μ = projected_residual(ws_out, psi_out, dV)

    @printf "  ITP:   %.1f min\n" t_itp/60
    @printf "  LBFGS phase 1 (%d steps): E=%.6f  ‖∇E‖=%.3e  (%.1f min)\n" N_LBFGS_PHASE_1 E_p1 grad_p1_raw t_p1/60
    @printf "  LBFGS phase 2 (%d steps): E=%.6f  ‖∇E‖=%.3e  (%.1f min)\n" N_LBFGS_PHASE_2 E_p2 grad_p2_raw t_p2/60
    @printf "  phase-2 progress: ΔE=%.3e (thresh %.0e)  grad_ratio=%.3f (thresh %.2f)\n" dE_phase2 PLATEAU_THRESH_DE grad_ratio PLATEAU_THRESH_GRAD_RATIO
    @printf "  PLATEAU       = %s\n" (plateau ? "YES" : "NO — still descending")
    @printf "  ‖P_⊥∇E‖       = %.3e   (μ = %.4f)\n" res_norm μ
    @printf "  conv flag     = %s\n" r_p2.converged
    !USE_CPU && CUDA.reclaim()

    return (;
        seed=seed_state, label=label,
        E=E_p2, E_phase1=E_p1, dE_phase2=dE_phase2,
        grad_raw=grad_p2_raw, grad_phase1=grad_p1_raw,
        grad_ratio=grad_ratio,
        grad_projected=res_norm, mu=μ,
        conv=r_p2.converged, plateau=plateau, psi=psi_out,
    )
end

# Global-phase-aligned overlap: |⟨ψ_a, ψ_b⟩|² / (‖ψ_a‖² ‖ψ_b‖²).
# This is invariant under U(1) phase. NOT invariant under spin
# rotations or translations — but those would show up as "low
# overlap, same E" which is exactly the soft-valley signature.
function overlap(ψa, ψb, dV)
    inner = sum(conj.(ψa) .* ψb) * dV
    nrm_a = sum(abs2, ψa) * dV
    nrm_b = sum(abs2, ψb) * dV
    return abs2(inner) / (nrm_a * nrm_b)
end

function main()
    println("=== M1 basin-vs-valley discriminator ===")
    @printf "Cell: B=%.1f nT, Ω=%.2f, N_LBFGS=%d, Sobolev α=%.3f\n" B_NT OMEGA N_LBFGS SOBOLEV
    @printf "Backend: %s, seeds: %d\n\n" (USE_CPU ? "CPU" : "CUDA") length(SEEDS)
    !USE_CPU && @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    results = [run_one_seed(s, label) for (s, label) in SEEDS]

    println("\n=== Summary ===\n")
    @printf "%-25s %10s %10s %10s %10s %8s %8s %s\n" "seed" "E_phase1" "E_phase2" "ΔE_p2" "‖P_⊥∇E‖" "g_ratio" "plateau" "conv"
    for r in results
        @printf "%-25s %10.6f %10.6f %+10.3e %10.3e %8.3f %8s %s\n" r.label r.E_phase1 r.E r.dE_phase2 r.grad_projected r.grad_ratio (r.plateau ? "YES" : "no") string(r.conv)
    end

    println("\n--- Pairwise wavefunction overlaps |⟨ψ_a, ψ_b⟩|² ---")
    dV = SpinorBEC.cell_volume(TW.grid)
    n = length(results)
    @printf "%-25s " ""
    for r in results
        @printf "%-18s " r.label
    end
    println()
    overlap_mat = [overlap(results[i].psi, results[j].psi, dV) for i in 1:n, j in 1:n]
    for i in 1:n
        @printf "%-25s " results[i].label
        for j in 1:n
            @printf "%-18.4f " overlap_mat[i, j]
        end
        println()
    end

    println("\n=== Verdict (plateau-gated) ===")
    # ── Stage 1: plateau gate ────────────────────────────────────
    # Reading structure from non-plateau'd states is the meta-recurrence
    # of `mistake_unconverged_to_new_physics_ignoring_analytical_oracle`.
    # If fewer than 2 seeds plateau'd, we report INCONCLUSIVE and stop
    # — no overlap or ΔE interpretation.
    plateau_results = filter(r -> r.plateau, results)
    n_plateau = length(plateau_results)
    @printf "Plateau'd seeds: %d / %d  (gate: ≥2 required)\n" n_plateau length(results)
    for r in results
        @printf "  %-25s plateau=%s  (g_ratio=%.3f vs %.2f, ΔE_p2=%.2e vs %.0e)\n" r.label (r.plateau ? "YES" : "no") r.grad_ratio PLATEAU_THRESH_GRAD_RATIO r.dE_phase2 PLATEAU_THRESH_DE
    end

    if n_plateau < 2
        println("\n⚠ INCONCLUSIVE — fewer than 2 seeds plateau'd in the N_LBFGS = $(N_LBFGS) budget.")
        println("  No basin/valley verdict possible. Doing so would replay the")
        println("  same 'reading structure from unconverged states' mistake.")
        println("  Recommended action:")
        println("    1. Re-run with --n-lbfgs $(2 * N_LBFGS).")
        println("    2. If still not plateau'd, the LBFGS preconditioning may be")
        println("       the bottleneck (try sobolev_alpha ∈ {0.02, 0.10, 0.20}).")
        println("    3. ΔE between non-plateau'd seeds is NOT a basin signal.")
        verdict_label = :INCONCLUSIVE_NO_PLATEAU
    else
        # ── Stage 2: overlap is the primary signal among plateau'd ──
        plat_idxs = [i for (i, r) in enumerate(results) if r.plateau]
        E_plat = [results[i].E for i in plat_idxs]
        ΔE_plat = maximum(E_plat) - minimum(E_plat)
        # Off-diagonal min within plateau'd seeds only.
        if length(plat_idxs) >= 2
            min_overlap_plat = minimum(
                overlap_mat[i, j] for i in plat_idxs for j in plat_idxs if i != j)
            max_overlap_plat = maximum(
                overlap_mat[i, j] for i in plat_idxs for j in plat_idxs if i != j)
        else
            min_overlap_plat = NaN
            max_overlap_plat = NaN
        end
        @printf "\nPlateau'd-subset analysis (n=%d):\n" length(plat_idxs)
        @printf "  ΔE (within plateau)         = %.4e\n" ΔE_plat
        @printf "  min off-diag overlap         = %.4f  (thresh > %.2f = same state)\n" min_overlap_plat VERDICT_OVERLAP_SAME
        @printf "                                       (thresh < %.2f = different state)\n" VERDICT_OVERLAP_DIFF

        if min_overlap_plat > VERDICT_OVERLAP_SAME
            println("\n→ SAME BASIN, SAME STATE.")
            println("  All plateau'd seeds collapse to the same wavefunction (overlap > $(VERDICT_OVERLAP_SAME)).")
            println("  Whatever the floor is, it's NOT seeds. Issue is iter budget,")
            println("  Sobolev preconditioning, or (if state still wrong physics)")
            println("  the analytic GS landscape itself.")
            verdict_label = :SAME_BASIN_SAME_STATE
        elseif min_overlap_plat < VERDICT_OVERLAP_DIFF
            if ΔE_plat > VERDICT_DE_BASIN
                println("\n→ MULTIPLE BASINS (a) CONFIRMED.")
                println("  Plateau'd seeds land at distinct states (overlap < $(VERDICT_OVERLAP_DIFF))")
                println("  AND distinct energies (ΔE = $(round(ΔE_plat; digits=4)) > $(VERDICT_DE_BASIN)).")
                println("  Seed diversification is the right cure for the full sweep.")
                verdict_label = :MULTIPLE_BASINS
            else
                println("\n→ SOFT VALLEY (a').")
                println("  Plateau'd seeds land at distinct states (overlap < $(VERDICT_OVERLAP_DIFF))")
                println("  but SAME energy (ΔE = $(round(ΔE_plat; digits=4)) < $(VERDICT_DE_BASIN)).")
                println("  This is a degenerate set of GS — seeds will keep finding")
                println("  different members of the same valley. The floor isn't a")
                println("  basin-trap; it's the soft direction(s).")
                println("  Cures: soft-mode preconditioning (anchor vortex core, fix")
                println("  gauge in the soft direction), or change the criterion to")
                println("  be invariant under the soft direction (project ‖∇E‖ onto")
                println("  the orthogonal complement).")
                verdict_label = :SOFT_VALLEY
            end
        else
            println("\n⚠ INCONCLUSIVE — overlap is mid-range ($(round(min_overlap_plat; digits=2))).")
            println("  Plateau'd states are neither clearly same nor clearly different.")
            println("  Possible: partial structural alignment, or some seeds at sub-minima")
            println("  within a single basin. Re-run with --n-lbfgs $(2 * N_LBFGS) to push")
            println("  closer to true minimum, then re-classify.")
            verdict_label = :INCONCLUSIVE_MEDIUM_OVERLAP
        end
    end

    # Save full result for downstream analysis. Includes plateau
    # signals so a reader can re-classify if the verdict thresholds
    # are tweaked.
    out = "runs/sprint5_M1_basin_valley_B$(B_NT)_Om$(OMEGA).jld2"
    isdir("runs") || mkpath("runs")
    JLD2.jldopen(out, "w") do f
        f["B_nT"] = B_NT
        f["omega"] = OMEGA
        f["N_LBFGS"] = N_LBFGS
        f["seeds"] = [string(r.seed) for r in results]
        f["E_phase1"] = [r.E_phase1 for r in results]
        f["E_phase2"] = [r.E for r in results]
        f["dE_phase2"] = [r.dE_phase2 for r in results]
        f["grad_phase1"] = [r.grad_phase1 for r in results]
        f["grad_phase2"] = [r.grad_raw for r in results]
        f["grad_ratio"] = [r.grad_ratio for r in results]
        f["grad_projected"] = [r.grad_projected for r in results]
        f["plateau"] = [r.plateau for r in results]
        f["conv"] = [r.conv for r in results]
        f["overlap_matrix"] = overlap_mat
        f["verdict"] = String(verdict_label)
        # Save psi for each seed too — useful for post-hoc structural
        # comparison or for feeding into _extend.jl.
        for r in results
            f["psi_$(r.seed)"] = r.psi
        end
    end
    @printf "\nSaved: %s   verdict=%s\n" out verdict_label
end

main()

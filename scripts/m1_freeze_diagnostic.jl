#!/usr/bin/env julia
# scripts/m1_freeze_diagnostic.jl
#
# Disambiguate "optimizer freeze at non-stationary point" from
# "landscape stuck (basin/valley)" at the M1 B=0, Ω=0.4 cell.
#
# Premise: at the discriminator's plateau states, ‖P_⊥∇E‖ = 0.2-0.5.
# A converged cell has ‖P_⊥∇E‖ ~ 1e-5. We are 4-5 decades from
# stationary. Yet phase-2 LBFGS made literally 0 progress (ΔE=0,
# grad_ratio=1.000). At gradient 0.4 the landscape CANNOT stop a
# downhill move — for any α, E(x − α∇E) = E − α‖∇E‖² < E by Taylor.
# So the freeze is in the optimizer (Sobolev-norm stopping rule
# masking L² gradient, or LBFGS curvature/line-search corruption),
# NOT the landscape.
#
# Decisive test: take a plateau state and apply pure projected gradient
# flow (ITP, ~100 steps). If E drops + ‖P_⊥∇E‖ drops → landscape
# descent is available, freeze IS the optimizer. If ITP also stalls
# at this scale → deeper issue (gradient/energy mismatch at this state),
# triggers separate investigation.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m1_freeze_diagnostic.jl
#
# Optional CLI:
#   --seed SYMBOL    which plateau state to test (default :polar; one of
#                    :polar, :radial_spin_vortex, :transverse_x, :radial_spin_vortex_q2)
#   --n-steps N      ITP steps (default 200)
#   --smoke          CPU + tiny N for quick error-class check
#
# Cost: ~3-5 min on GPU at 200 ITP steps.

const USE_SMOKE = "--smoke" in ARGS
const USE_CPU = USE_SMOKE  # smoke implies CPU

if !USE_CPU
    import CUDA
end
using SpinorBEC
using Printf
using JLD2
function get_arg_str(name::String, default::String)
    for (i, a) in enumerate(ARGS)
        a == name && i + 1 <= length(ARGS) && return ARGS[i + 1]
    end
    default
end
function get_arg_int(name::String, default::Int)
    for (i, a) in enumerate(ARGS)
        a == name && i + 1 <= length(ARGS) && return parse(Int, ARGS[i + 1])
    end
    default
end
function get_arg_float(name::String, default::Float64)
    for (i, a) in enumerate(ARGS)
        a == name && i + 1 <= length(ARGS) && return parse(Float64, ARGS[i + 1])
    end
    default
end

const TW = eu151_preset()
const SEED = Symbol(get_arg_str("--seed", "polar"))
const N_STEPS = USE_SMOKE ? 5 : get_arg_int("--n-steps", 200)
const DT = get_arg_float("--dt", 0.005)
const BACKEND = USE_CPU ? CPUBackend() : CUDABackend()

const CACHED_PATH = "runs/sprint5_M1_basin_valley_B0.0_Om0.4.jld2"
const B_NT = 0.0
const OMEGA = 0.4

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

function main()
    println("=== M1 freeze diagnostic ===")
    @printf "Cell: B=%.1f nT, Ω=%.2f   seed: :%s   ITP steps: %d (%s)\n" B_NT OMEGA SEED N_STEPS (USE_CPU ? "CPU" : "CUDA")
    isfile(CACHED_PATH) || error("Missing $CACHED_PATH — run discriminator first.")
    cached = JLD2.load(CACHED_PATH)
    psi_key = "psi_$(SEED)"
    haskey(cached, psi_key) ||
        error("$psi_key not in $CACHED_PATH. Available: $(filter(startswith("psi_"), collect(keys(cached))))")
    psi_cached = cached[psi_key]
    @printf "Loaded ψ from %s (key %s, shape %s)\n\n" CACHED_PATH psi_key string(size(psi_cached))

    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    dV = SpinorBEC.cell_volume(TW.grid)

    # Phase A: warm-start workspace via 1 ITP step (n_steps>0 required by
    # SimParams), then restore ψ to the cached value before measuring so
    # the residual is exactly at the plateau, not at "plateau + 1 ITP step".
    println("--- Phase A: warm-start workspace, measure starting state ---")
    r_warm = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT, n_steps=1, tol=0.0,
        initial_state=:polar, verbose=false,
        psi_init=psi_cached,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA,
        backend=BACKEND)
    ws_start = r_warm.workspace
    copyto!(ws_start.state.psi, psi_cached)   # snap back to exact cached ψ
    E_start = SpinorBEC.energy_decomposition(ws_start).total
    res_start, μ_start = projected_residual(ws_start, psi_cached, dV)
    @printf "  E_start         = %.8f\n" E_start
    @printf "  ‖P_⊥∇E‖_start   = %.3e   μ = %.4f\n\n" res_start μ_start

    # Phase B: pure ITP from cached ψ, no LBFGS, no Sobolev.
    println("--- Phase B: pure ITP (projected gradient flow), $(N_STEPS) steps ---")
    flush(stdout)
    t0 = time()
    r_itp = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=DT, n_steps=N_STEPS, tol=0.0,  # tol=0 → never early-exit
        initial_state=:polar, verbose=false,
        psi_init=psi_cached,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA,
        backend=BACKEND)
    t_itp = time() - t0
    ws_end = r_itp.workspace
    E_end = r_itp.energy
    res_end, μ_end = projected_residual(ws_end, Array(ws_end.state.psi), dV)
    @printf "  E_end           = %.8f\n" E_end
    @printf "  ‖P_⊥∇E‖_end     = %.3e   μ = %.4f\n" res_end μ_end
    @printf "  ΔE              = %+.3e   (negative = descended)\n" (E_end - E_start)
    @printf "  ‖P_⊥∇E‖ ratio   = %.3f   (<1 = residual shrank)\n" (res_end / res_start)
    @printf "  wall            = %.1f s (%.1f min)\n" t_itp t_itp/60
    !USE_CPU && CUDA.reclaim()

    # Verdict
    println("\n=== Verdict ===")
    descended = (E_end - E_start) < -1e-6
    residual_shrank = res_end < 0.5 * res_start
    if descended && residual_shrank
        @printf "→ FREEZE WAS OPTIMIZER. ITP descended (ΔE=%.2e) and ‖P_⊥∇E‖ shrank %.2fx.\n" (E_end-E_start) (res_start/res_end)
        println("  The landscape provides descent at the plateau state — LBFGS's")
        println("  internal stopping rule (Sobolev-norm vs L² mismatch) OR curvature")
        println("  history corruption stopped the optimizer prematurely.")
        println("  Fix candidates:")
        println("    1. Align LBFGS internal ‖∇E‖_stop with reported ‖P_⊥∇E‖_R (L²)")
        println("       — same lesson as the audit's criterion alignment from 2 turns back.")
        println("    2. Force LBFGS history clear / restart from current state.")
        println("    3. Switch polish from LBFGS to direct gradient flow + line search,")
        println("       OR conjugate gradient.")
        println("  Hessian / Bogoliubov spectrum NOT informative until the optimizer is fixed.")
    elseif descended && !residual_shrank
        @printf "→ MIXED. E dropped (ΔE=%.2e) but ‖P_⊥∇E‖ barely moved (ratio %.2f).\n" (E_end-E_start) (res_end/res_start)
        println("  Likely: ITP is descending along a narrow direction without shrinking")
        println("  the broad-channel residual. Try longer N_STEPS or check if the")
        println("  Bz=0 spin rotation symmetry is being numerically broken.")
    else
        @printf "→ DEEPER ISSUE. ITP also failed to descend (ΔE=%.2e).\n" (E_end-E_start)
        @printf "  At ‖∇E‖ ≈ %.2f, ITP must descend by Taylor — if it doesn't, the\n" res_start
        println("  gradient/energy bookkeeping at THIS state has a deeper inconsistency")
        println("  (not the rotating-frame term, which the audit cleared). Audit:")
        println("    - ITP propagator's effective Hamiltonian vs energy_decomposition's")
        println("    - DDI / LHY / centrifugal contributions evaluated consistently")
        println("    - Numerical underflow in dt·∇E if ‖∇E‖ × dt < machine eps somewhere")
    end
end

main()

# Weak-field Eu+DDI ground state via SYMMETRY-BREAKING PINNING + ε→0 extrapolation.
#
# Problem: below ~60 µG the Eu F=6 + DDI GS spontaneously breaks the exact axial
# U(1) e^{-iθ(L_z+F_z)} (spin+space co-rotation). The resulting Goldstone makes
# the GS a degenerate ORBIT, so |∇E| floors ~0.05 and BdG λ_min≈0 are PHYSICAL,
# not numerical failure — there is no point to converge to, and seeding from
# :polar additionally false-converges to a HIGHER-energy symmetric saddle (E≈12.2
# vs true ≈9.1). See memory gotcha_low_field_transverse_spin_xy_pattern_ddi_soft_manifold.
#
# Fix (textbook SSB): add a small explicit term ε that BREAKS e^{-iθ(L_z+F_z)},
# turning the degenerate orbit into an isolated non-degenerate minimum where
# |∇E|→0 and λ_min>0 are reachable cleanly. Run a continuation in decreasing ε,
# evaluate the BARE (ε=0) energy at each pinned state, and extrapolate
#   E_bare(ε) = E0 + c·ε²            (state distorts O(ε) ⇒ bare energy O(ε²))
# to recover the reproducible, certified GS energy E0 of the degenerate problem.
#
# Two independent pins (cross-check — same E0 ⇒ trustworthy):
#   SM_PIN=bx   transverse field b_x = ε   (the field CONJUGATE to the broken
#               transverse-spin order; lifts the Goldstone with a cos θ potential,
#               pseudo-Goldstone mass ∝ √ε ⇒ λ_min(ε) ~ √ε).
#   SM_PIN=trap elliptical trap ω_y² → (1+ε) ω_x²  (breaks L_z spatial axial;
#               lifts with a cos 2θ potential). Pure spatial, no Zeeman path.
#
# Env (all optional):
#   SM_PIN=bx|trap  SM_EPS=4e-3,2e-3,1e-3,5e-4,2.5e-4
#   SM_GRID=48  SM_BOX=24.0  SM_B_UG=10.0  SM_DT=0.002
#   SM_ITP=4000 SM_LBFGS=400 SM_NITER=300 SM_NOISE=0.02
#   SM_SMOKE=1  -> grid 16, itp 200, lbfgs 60, niter 80, eps 4e-3,1e-3
#
#   julia --project=. scripts/eu_pinning_extrapolation.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem, make_workspace,
    SimParams, total_energy, static_zeeman, trapped_bdg_lowest_eigenvalue,
    CUDABackend, CPUBackend
using Printf
using LinearAlgebra: dot
using Dates: now, format

clk() = format(now(), "HH:MM:SS")

geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)
const SMOKE = get(ENV, "SM_SMOKE", "") == "1"

const PIN   = Symbol(gets("SM_PIN", "bx"))   # :bx (conjugate field) or :trap
PIN in (:bx, :trap) || error("SM_PIN must be bx or trap, got $PIN")
const NX    = SMOKE ? 16 : Int(geti("SM_GRID", 48))
const BOX   = geti("SM_BOX", 24.0)
const B_UG  = geti("SM_B_UG", 10.0)
const DT    = geti("SM_DT", 0.002)
const ITP   = SMOKE ? 200 : Int(geti("SM_ITP", 4000))
const LBFGS = SMOKE ? 60 : Int(geti("SM_LBFGS", 400))
const NITER = SMOKE ? 80 : Int(geti("SM_NITER", 300))
const NOISE = geti("SM_NOISE", 0.02)
const VERB  = get(ENV, "SM_VERBOSE", "1") == "1"   # per-step LBFGS/ITP ETA
const EPS   = let d = SMOKE ? "4e-3,1e-3" : "4e-3,2e-3,1e-3,5e-4,2.5e-4"
    sort(parse.(Float64, split(gets("SM_EPS", d), ",")); rev=true)   # descending ⇒ continuation
end

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
if !HAS_GPU && !SMOKE
    @warn "CUDA not functional -> CPU run. SLOW at $(NX)^3; intended for TSUBAME GPU."
end

# Isotropic (bare, ε=0) preset — the reference Hamiltonian we extrapolate toward.
const ISO_RATIOS = (1.0, 1.0, 1.1818)
const PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX), trap_ratios=ISO_RATIOS)
const ATOM  = PRESET.atom
const SYS   = SpinSystem(ATOM.F)
const P_ZEE = Units.bfield_to_p(B_UG * 1e-6, ATOM.g_F, PRESET.omega_ref)

# --- bare (ε=0) energy evaluator: isotropic trap, axial-only Zeeman -----------
const BARE_WS = make_workspace(;
    grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=PRESET.potential, zeeman=ZeemanParams(P_ZEE, 0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND,
    sim_params=SimParams(; dt=DT, n_steps=1, imaginary_time=true),
)
bare_energy(psi) = (copyto!(BARE_WS.state.psi, psi); total_energy(BARE_WS))

# --- pinned configuration at strength ε ---------------------------------------
# Returns make_workspace/solver kwargs realising H_bare + ε·(symmetry breaker).
function pin_kwargs(eps)
    if PIN === :bx
        zee = static_zeeman(; Bz=P_ZEE, Bx=eps, q=0.0)   # b_x = ε conjugate field
        pot = PRESET.potential
    else  # :trap — elliptical ω_y² = (1+ε) ω_x²
        pe = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
            trap_ratios=(1.0, 1.0 + eps, 1.1818))
        zee = ZeemanParams(P_ZEE, 0.0)
        pot = pe.potential
    end
    (; grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
        potential=pot, zeeman=zee, enable_ddi=true, c_dd=PRESET.c_dd,
        secular_ddi=false, backend=BACKEND)
end

@printf("Eu pinning-extrapolation: pin=%s grid=%d^3 box=%.1f B=%.1f uG p=%.3e %s%s\n",
    PIN, NX, BOX, B_UG, P_ZEE, HAS_GPU ? "CUDA" : "CPU", SMOKE ? " [SMOKE]" : "")
@printf("c0=%.1f c1=%.3f c_dd=%.3f  eps=%s  ITP=%d LBFGS=%d niter=%d\n",
    PRESET.interactions[0], PRESET.interactions[1], PRESET.c_dd,
    join(EPS, ","), ITP, LBFGS, NITER)
flush(stdout)

# --- continuation in ε --------------------------------------------------------
const NEPS = length(EPS)
const T_START = time()
rows = NamedTuple[]
prev_psi = nothing
for (i, eps) in enumerate(EPS)
    @printf("\n[%s] === eps %d/%d = %.3e  (elapsed %.1f min) ===\n",
        clk(), i, NEPS, eps, (time() - T_START) / 60)
    flush(stdout)
    t_eps = time()
    kw = pin_kwargs(eps)
    if prev_psi === nothing
        # First (largest) ε: short ITP from a symmetry-broken seed to enter the
        # true basin (the finite pin makes :polar non-stationary, but the kick
        # avoids lingering near it), then LBFGS + Newton polish to a CLEAN
        # isolated minimum.
        psi0 = init_psi(PRESET.grid, SYS; state=:m_plus_F)
        add_white_noise!(psi0, NOISE, 1, PRESET.grid)
        println("  [$(clk())] ITP $(ITP) steps (first eps only)…"); flush(stdout)
        gs = find_ground_state(; kw..., psi_init=psi0, dt=DT, n_steps=ITP,
            tol=1e-12, save_every=max(1, ITP ÷ 10), verbose=VERB)
        seed = Array{ComplexF64}(gs.workspace.state.psi)
    else
        seed = Array{ComplexF64}(prev_psi)   # warm-start: stay on the same orbit point
    end
    println("  [$(clk())] LBFGS $(LBFGS) + Newton polish…"); flush(stdout)
    gl = find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=LBFGS,
        tol=1e-12, m_lbfgs=10, newton_polish=true, verbose=VERB)
    psi = gl.workspace.state.psi
    global prev_psi = Array{ComplexF64}(psi)

    HAS_GPU && CUDA.synchronize()
    println("  [$(clk())] BdG λ_min (niter=$(NITER))…"); flush(stdout)
    c = trapped_bdg_lowest_eigenvalue(gl.workspace, psi; niter=NITER, atol=1e-6)
    Eb = bare_energy(psi)
    push!(rows, (; eps, E_pin=gl.energy, E_bare=Eb, grad=gl.grad_norm,
        λ_min=c.λ_min, conv=c.converged, gold=c.goldstone))

    dt_eps = (time() - t_eps) / 60
    elapsed = (time() - T_START) / 60
    eta = (NEPS - i) * (elapsed / i)   # average-per-eps × remaining (warm eps are faster)
    @printf("  [%s] RESULT eps=%.3e  E_bare=%.5f  E_pin=%.5f  |gradE|=%.2e  λ_min=%+.3e conv=%s\n",
        clk(), eps, Eb, gl.energy, gl.grad_norm, c.λ_min, c.converged)
    @printf("  [progress] %d/%d done | this eps %.1f min | elapsed %.1f min | est remaining ~%.0f min\n",
        i, NEPS, dt_eps, elapsed, eta)
    flush(stdout)
end

# --- least-squares extrapolation E_bare = E0 + c·ε² ---------------------------
function extrapolate(rows)
    x = [r.eps^2 for r in rows]
    y = [r.E_bare for r in rows]
    n = length(x)
    n < 2 && return (y[1], 0.0, NaN)
    x̄ = sum(x) / n; ȳ = sum(y) / n
    sxx = sum((x .- x̄) .^ 2)
    c = sxx == 0 ? 0.0 : dot(x .- x̄, y .- ȳ) / sxx
    E0 = ȳ - c * x̄
    resid = y .- (E0 .+ c .* x)
    rms = sqrt(sum(resid .^ 2) / n)
    (E0, c, rms)
end

E0, slope, rms = extrapolate(rows)

println("\n================ SUMMARY (pin=$PIN) ================")
@printf("%-10s %11s %11s %10s %12s %5s\n", "eps", "E_bare", "E_pin", "|gradE|", "λ_min", "conv")
for r in rows
    @printf("%-10.3e %11.5f %11.5f %10.2e %+12.3e %5s\n",
        r.eps, r.E_bare, r.E_pin, r.grad, r.λ_min, r.conv)
end
@printf("\nε→0 extrapolation:  E0 = %.5f   (slope c = %.4g, fit RMS = %.2e)\n", E0, slope, rms)
@printf("min pinned |gradE| over ε: %.2e   (clean isolated minima ⇒ should ≪ 0.05 soft floor)\n",
    minimum(r.grad for r in rows))
println("DONE")

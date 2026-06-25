# Converge a REAL Flower-phase reference: a ferromagnetic-contact (c1 < 0) + DDI
# ground state. Kawaguchi-Ueda: FM order (c1<0) + DDI ⇒ a flux-closure spin
# texture ∇·F ≈ 0 (the Flower phase). This is the KNOWN-structure anchor that
# validates the LOW END of the flux-closure metric (‖∇·F‖/‖∇F‖ → 0), the one
# caveat left open by the weak-field Eu fingerprint (only the high end, 0.66–0.94
# non-flux-closure imprints, was pinned before).
#
# Pin: same SSB continuation as eu_pinning_extrapolation.jl (bx=ε conjugate field
# or elliptical trap) because the Flower also breaks the axial U(1). Converges the
# isolated minimum, then prints the full validated fingerprint at the smallest ε.
#
# Env:
#   FL_C1   = -0.5      c1 as a FRACTION of |c0/36| (negative = ferromagnetic).
#   FL_CDD  = 1.0       multiplier on c_dd (crank DDI to deepen the texture).
#   FL_PIN  = bx|trap   FL_EPS = 4e-3,2e-3,1e-3   FL_B_UG = 10.0
#   FL_GRID = 48  FL_BOX = 24.0  FL_ITP = 4000  FL_LBFGS = 400
#   FL_SMOKE = 1   -> grid 16, itp 200, lbfgs 60, eps 4e-3,1e-3
#   FL_OUT  = figs/flower_ref   (saves the converged ψ + fingerprint)
#   julia --project=. scripts/eu_flower_reference.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem,
    static_zeeman, InteractionParams, save_state, CUDABackend, CPUBackend
using JLD2: jldsave
using Printf
using Dates: now, format
include(joinpath(@__DIR__, "phase_fingerprint_lib.jl"))

clk() = format(now(), "HH:MM:SS")
geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)

const SMOKE = get(ENV, "FL_SMOKE", "") == "1"
const PIN   = Symbol(gets("FL_PIN", "bx"));  PIN in (:bx, :trap) || error("FL_PIN bx|trap")
const C1FR  = geti("FL_C1", -0.5)            # negative ⇒ ferromagnetic
const CDDX  = geti("FL_CDD", 1.0)
const NX    = SMOKE ? 16 : Int(geti("FL_GRID", 48))
const BOX   = geti("FL_BOX", 24.0)
const B_UG  = geti("FL_B_UG", 10.0)
const DT    = geti("FL_DT", 0.002)
const ITP   = SMOKE ? 200 : Int(geti("FL_ITP", 4000))
const LBFGS = SMOKE ? 60 : Int(geti("FL_LBFGS", 400))
const NOISE = geti("FL_NOISE", 0.02)
const OUT   = gets("FL_OUT", "figs/flower_ref")
const EPS   = sort(parse.(Float64, split(gets("FL_EPS", SMOKE ? "4e-3,1e-3" :
    "4e-3,2e-3,1e-3"), ",")); rev=true)
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
(!HAS_GPU && !SMOKE) && @warn "CUDA not functional -> CPU run, SLOW at $(NX)^3"

const RATIOS = (1.0, 1.0, 1.1818)
const PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX), trap_ratios=RATIOS)
const ATOM   = PRESET.atom
const SYS    = SpinSystem(ATOM.F)
const C0     = PRESET.interactions[0]
const C1     = C1FR * abs(C0 / 36.0)                       # ferromagnetic when C1FR<0
const CDD    = CDDX * PRESET.c_dd
const INTER  = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
const P_ZEE  = Units.bfield_to_p(B_UG * 1e-6, ATOM.g_F, PRESET.omega_ref)
const CTX    = fp_context(PRESET.grid; box=BOX, F=ATOM.F)

function pin_kwargs(eps)
    if PIN === :bx
        zee = static_zeeman(; Bz=P_ZEE, Bx=eps, q=0.0)
        pot = PRESET.potential
    else
        pot = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
            trap_ratios=(1.0, 1.0 + eps, 1.1818)).potential
        zee = ZeemanParams(P_ZEE, 0.0)
    end
    (; grid=PRESET.grid, atom=ATOM, interactions=INTER, potential=pot, zeeman=zee,
        enable_ddi=true, c_dd=CDD, secular_ddi=false, backend=BACKEND)
end

@printf("Flower reference: c1=%.4f (=%.2f·|c0/36|, %s)  c_dd=%.3f (×%.2f)  B=%.1f uG  pin=%s grid=%d^3 %s%s\n",
    C1, C1FR, C1 < 0 ? "FERRO" : "polar", CDD, CDDX, B_UG, PIN, NX,
    HAS_GPU ? "CUDA" : "CPU", SMOKE ? " [SMOKE]" : "")
flush(stdout)

prev = nothing
last_psi = nothing
for (i, eps) in enumerate(EPS)
    @printf("\n[%s] === eps %d/%d = %.3e ===\n", clk(), i, length(EPS), eps); flush(stdout)
    kw = pin_kwargs(eps)
    if prev === nothing
        psi0 = init_psi(PRESET.grid, SYS; state=:m_plus_F)
        add_white_noise!(psi0, NOISE, 1, PRESET.grid)
        gs = find_ground_state(; kw..., psi_init=psi0, dt=DT, n_steps=ITP,
            tol=1e-12, save_every=max(1, ITP ÷ 10), verbose=!SMOKE)
        seed = Array{ComplexF64}(gs.workspace.state.psi)
    else
        seed = Array{ComplexF64}(prev)
    end
    gl = find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=LBFGS,
        tol=1e-12, m_lbfgs=10, newton_polish=true, verbose=!SMOKE)
    global prev = Array{ComplexF64}(gl.workspace.state.psi)
    global last_psi = prev
    HAS_GPU && CUDA.synchronize()
    fp = fingerprint(CTX, prev)
    @printf("  [%s] eps=%.1e  E=%.5f |∇E|=%.2e  |F|=%.3f g=%.3f Jz=%+.3f flux=%s\n",
        clk(), eps, gl.energy, gl.grad_norm, fp.mF, fp.coh, fp.Jz,
        isnan(fp.fluxclosure) ? "N/A" : @sprintf("%.4f", fp.fluxclosure))
    flush(stdout)
end

println("\n================ FLOWER REFERENCE — final fingerprint ================")
fp = fingerprint(CTX, last_psi)
print_fingerprint(CTX, fp, @sprintf("flower c1=%.3f cdd×%.2f B=%.1fuG", C1, CDDX, B_UG))
fc = fp.fluxclosure
println()
if isnan(fc)
    println("VERDICT: |F|≈0 (not ferromagnetic) — c1 not negative enough; raise |FL_C1|.")
elseif fp.coh > 0.95
    @printf("VERDICT: nearly UNIFORM FM (g=%.3f) — DDI texture weak; raise FL_CDD or |FL_C1|.\n", fp.coh)
elseif fc < 0.20
    @printf("VERDICT: flux-closure CONFIRMED low-end (‖∇·F‖/‖∇F‖=%.3f ≪ 0.66) — true Flower.\n", fc)
else
    @printf("VERDICT: textured FM, flux-closure=%.3f (intermediate; vs 0.66–0.94 non-flux imprints).\n", fc)
end

jldsave(joinpath(OUT, "flower_state.jld2"); psi=last_psi, t=0.0, step=0,
    grid_n_points=PRESET.grid.config.n_points, grid_box_size=PRESET.grid.config.box_size,
    atom_name=ATOM.name, c0=C0, c1=C1, c_dd=CDD, zeeman_p=P_ZEE, zeeman_q=0.0)
println("DONE → ", joinpath(OUT, "flower_state.jld2"))

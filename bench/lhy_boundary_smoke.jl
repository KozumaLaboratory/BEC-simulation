# Cost + wiring smoke for the LHY phase-boundary measurement (#337 criterion B).
#
# Answers three things before any production launch, in ≤ a couple of minutes:
#   1. how long ONE ground state costs at the candidate geometry, per LHY arm
#      (the tabulated arms pay a one-time table build that the `none` arm does
#      not, and `spatial` pays ~n_bins BdG solves);
#   2. whether each arm's table actually reaches the solve — an arm whose energy
#      is bit-identical to `none` is not running LHY, which is the exact failure
#      that made a 40-point A/B read as "LHY does not matter" in 2026-07;
#   3. whether `fm_dipolar` and the SI-anchored `scalar` + Q₅ agree, which they
#      must: under the Eu constraint g_{2F} = c₀ + 36c₁ = c_total, so the FM
#      single-mode closed form and scalar Lima-Pelster are the same number by
#      algebra. Two independent code paths, one identity — a differential gate.
#
#   julia --project=. bench/lhy_boundary_smoke.jl [n_xy] [n_z] [n_steps]

using Printf
import CUDA
using SpinorBEC
using SpinorBEC: lhy_energy_fm_dipolar, build_fm_lhy_coefs, c_to_g,
    _lhy_texture_spread, spatial_lhy_residual, LHYTableOpts
using LinearAlgebra: norm

include(joinpath(@__DIR__, "eu151_params.jl"))

const NXY = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const NZ = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 32
const NSTEPS = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 400
const C1_RATIO = 1 / 36
const F = 6
const BOX = (12.0, 12.0, 12.0)
const B_TEST = 4.4e-5      # Gauss — inside the κ=1 boundary bracket of config_boundary_64

grid_of() = make_grid(GridConfig((NXY, NXY, NZ), BOX))

# The SI-anchored scalar coefficient the YAML layer would derive for this run.
const A_HO = sqrt(Units.HBAR / (Eu151.mass * EU_ω_ref))
const C_LHY_SCALAR = scalar_lhy_coefficient(Eu151.a_s / A_HO, EU_N_atoms; eps_dd=EU_ε_dd)

"""One ground state. `kind` is a spinor-LHY symbol or `nothing`; `c_lhy` rides
in `interactions` and is what the `:scalar` path reads."""
function solve(; kind, seed::Symbol, c_lhy::Float64=0.0)
    ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F)
    ip = InteractionParams(Dict(0 => ip[0], 1 => ip[1]); c_lhy)
    t0 = time()
    r = find_ground_state_lbfgs(;
        grid=grid_of(), atom=Eu151, interactions=ip,
        zeeman=ZeemanParams(linear_zeeman_p(Eu151, B_TEST, EU_ω_ref), 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        initial_state=seed, n_steps=NSTEPS, tol=1.0e-9,
        enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true,
        spinor_lhy=kind, lhy_opts=LHYTableOpts(; n_atoms=EU_N_atoms),
        backend=CUDABackend(), verbose=false)
    (E=r.energy, grad=r.grad_norm, steps=r.last_step, wall=time() - t0,
        psi=Array(r.workspace.state.psi))
end

println("="^96)
println("LHY boundary smoke — $(NXY)²×$(NZ), box $(BOX), c1_ratio=$(round(C1_RATIO; sigdigits=6)), ",
    "B=$(B_TEST) G, n_steps=$(NSTEPS)")
println("device: $(CUDA.name(CUDA.device()))")
@printf("scalar c_lhy (SI-anchored, Q5(ε_dd=%.4f)=%.4f): %.6g\n",
    EU_ε_dd, lima_pelster_Q5(EU_ε_dd), C_LHY_SCALAR)
println("="^96)

# --- identity check: fm_dipolar vs scalar+Q5, no solve needed -----------------
let ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=C1_RATIO, F),
    gd = c_to_g(F, ip), g2F = get(gd, 2F, 0.0),
    eps_dd_fm = abs(EU_c_dd) * F^2 / (3 * abs(g2F))

    n = 3.7e-3
    e_fm = lhy_energy_fm_dipolar(n, build_fm_lhy_coefs(F, gd), eps_dd_fm) / EU_N_atoms
    e_sc = 0.4 * C_LHY_SCALAR * n^2.5
    println("\n[identity] ε_LHY at n=$(n):")
    @printf("  fm_dipolar / N   = %.10g\n", e_fm)
    @printf("  (2/5)c_lhy n^5/2 = %.10g\n", e_sc)
    @printf("  relative gap     = %.3e   (g_2F = %.6g vs c_total = %.6g; ε_dd^FM = %.6f)\n",
        abs(e_fm - e_sc) / abs(e_sc), g2F, EU_c_total, eps_dd_fm)
end

# --- per-arm cost and wiring --------------------------------------------------
arms = [
    ("none", (kind=nothing, c_lhy=0.0)),
    ("scalar (×1)", (kind=:scalar, c_lhy=C_LHY_SCALAR)),
    ("scalar (×30, control)", (kind=:scalar, c_lhy=30 * C_LHY_SCALAR)),
    ("fm_dipolar", (kind=:fm_dipolar, c_lhy=0.0)),
    ("polar_contact", (kind=:polar_contact, c_lhy=0.0)),
    ("spatial", (kind=:spatial, c_lhy=0.0)),
]

println("\n[arms] one ground state each, seed = m_plus_F")
@printf("  %-24s %14s %10s %8s %9s %12s\n",
    "arm", "E", "grad", "steps", "wall (s)", "E − E(none)")
function run_arms()
    E_none = NaN
    for (label, a) in arms
        r = try
            solve(; kind=a.kind, seed=:m_plus_F, c_lhy=a.c_lhy)
        catch e
            @printf("  %-24s  FAILED: %s\n", label, sprint(showerror, e))
            continue
        end
        label == "none" && (E_none = r.E)
        @printf("  %-24s %14.8f %10.2e %8d %9.1f %12.3e\n",
            label, r.E, r.grad, r.steps, r.wall, r.E - E_none)
        flush(stdout)
        GC.gc(true)
        CUDA.reclaim()
    end
end
run_arms()

println("\nAn arm whose `E − E(none)` is exactly 0 is NOT running LHY. That is the")
println("wiring check, and it is the one this project has failed before.")

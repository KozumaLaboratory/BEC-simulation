# Does the block preconditioner change a GATE-2 VERDICT, and can it converge
# λ_min on the polarised branch?  (#397 and #399, one job, because they are the
# same knob on the same cells.)
#
# READ THIS FIRST — #397's premise does not survive a grep, and the measurement
# below is built to establish that rather than to assume it.
#
# #397 says `trapped_bdg_low_modes` "is on gate-2's stability verdict
# (`stability_spec.jl`, alongside `trapped_bdg_lowest_eigenvalue`)". It is not.
# `check(::StabilitySpec, ws, ψ)` calls `trapped_bdg_lowest_eigenvalue` — bare
# Lanczos, which **takes no `precond` keyword at all** — and `low_modes` has
# exactly one consumer under `src/`: `trapped_bdg_frequencies`, which uses its
# eigenVECTORS as a subspace for the symplectic reduction and never reads the
# sign of λ. So changing `low_modes`' default preconditioner CANNOT move a
# gate-2 verdict, and an A/B over verdicts would have been an A/B over a wire
# that does not exist.
#
# That is a grep, not a measurement, so this script re-establishes it by
# EXECUTION (CLAUDE.md commitment 12): `_consumer_probe()` calls the gate with a
# poisoned `low_modes` and shows the verdict is unchanged, and calls it with a
# poisoned Lanczos and shows the verdict moves. A claim about which wire is live
# is exactly the sort that reads identically whether it is right or wrong.
#
# What is left, and IS worth measuring:
#
#   #397a  the real consumer is `trapped_bdg_frequencies`. Does `:combined`
#          change ω, `spectrum_reached`, or the per-mode Hessian convergence
#          the frequencies are built on? The equivalence gate promises the
#          SPECTRUM is unchanged; it promises nothing about which modes get
#          RESOLVED, and an unconverged Hessian mode makes every frequency
#          built from it suspect.
#   #397b  on a GAPPED small problem (the CI fixture's regime) is `:combined`
#          SLOWER? It costs 2 extra FFTs and 2 multiplies per application, so
#          losing there is a real possibility and would be a result.
#   #399   with `:combined` and a large `max_iter`, does λ_min on the polarised
#          branch converge WITH A CERTIFICATE? An upper bound is not a proof of
#          a minimum. If it does not converge, WHY — is the bottom a cluster
#          (read the block's Ritz spread) or is the preconditioner looking at
#          the wrong stiffness (sweep `α_v`)?
#
# Every row carries `converged` and `width` beside `λ`, because #383's whole
# lesson was that a value one tenth of its own uncertainty is not a number.
#
# Env (plus the shared SP_* in `_cells.jl`):
#   PA_PRECONDS=kinetic;combined     arms
#   PA_MAXITERS=200;800              iteration budgets per arm
#   PA_NEV=4 PA_BLOCK=10 PA_TOL=1e-6 PA_FD_EPS=1e-5
#   PA_ALPHA_V=                      `;`-separated α_v sweep for :combined ("" = default)
#   PA_LANCZOS_NITER=300             the arm gate-2 ACTUALLY runs
#   PA_SKIP_GAPPED=0                 skip the #397b timing fixture
#   PA_SKIP_CONSUMER_PROBE=0         skip the executed consumer-map check
#   PA_OUT=figs/eu_spectrum/precond_ab
#
#   [GPU]  julia --project=. scripts/eu_spectrum/precond_ab.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, make_workspace, SimParams,
    static_zeeman, find_ground_state_lbfgs, cell_volume, energy_gradient!,
    constrained_hessian_params, trapped_bdg_low_modes, trapped_bdg_frequencies,
    trapped_bdg_lowest_eigenvalue, StabilitySpec, check,
    CUDABackend, CPUBackend, InteractionParams, HarmonicTrap, ZeemanParams
using DelimitedFiles: writedlm
using JLD2: jldopen
using Printf
using Random

include(joinpath(@__DIR__, "_cells.jl"))

const NEV = Int(getf("PA_NEV", 4))
const BLOCK = Int(getf("PA_BLOCK", 10))
const TOL = getf("PA_TOL", 1e-6)
const FD_EPS = getf("PA_FD_EPS", 1e-5)
const LANCZOS_NITER = Int(getf("PA_LANCZOS_NITER", 300))
const OUT = get(ENV, "PA_OUT", "figs/eu_spectrum/precond_ab")
mkpath(OUT)

splitlist(k, d) = String.(split(get(ENV, k, d), r"[,;]"))
const PRECONDS = Symbol.(splitlist("PA_PRECONDS", "kinetic;combined"))
const MAXITERS = parse.(Int, splitlist("PA_MAXITERS", "200;800"))
const ALPHA_VS = let s = get(ENV, "PA_ALPHA_V", "")
    isempty(s) ? [nothing] : Union{Nothing, Float64}[parse(Float64, x)
                                                     for x in split(s, r"[,;]")]
end

# ------------------------------------------------------- #397: the consumer map
#
# Executed, not asserted. The instrument is a POISONED function: if gate-2 read
# `low_modes`, replacing it with something that returns garbage would move the
# verdict. It does not. Replacing the Lanczos does. That is the difference
# between a wire that exists and one that was written down.
function consumer_probe()
    grid = make_grid(GridConfig(16, 10.0))
    ip = InteractionParams(Dict(0 => 4.0, 1 => 0.3))
    r = find_ground_state_lbfgs(; grid, atom=Rb87, interactions=ip,
        potential=HarmonicTrap(1.0), n_steps=400, tol=1e-11,
        initial_state=:polar, verbose=false)
    ws = r.workspace
    ψ = copy(ws.state.psi)
    spec = StabilitySpec(; niter=120)

    base = check(spec, ws, ψ; rng=MersenneTwister(7))
    # Same call twice with the same seed: the verdict must be reproducible
    # before any difference below can be attributed to a poison.
    again = check(spec, ws, ψ; rng=MersenneTwister(7))
    stable = base.status === again.status

    # A/B on `low_modes`' own knob, through the gate. If the gate read it, the
    # two arms could differ; that they cannot is the point.
    kin = check(spec, ws, ψ; rng=MersenneTwister(7))
    lm_k = trapped_bdg_low_modes(ws, ψ; nev=2, block=8, max_iter=200, tol=1e-7,
        params=constrained_hessian_params(ws, ψ), rng=MersenneTwister(3))
    lm_c = trapped_bdg_low_modes(ws, ψ; nev=2, block=8, max_iter=200, tol=1e-7,
        precond=:combined, params=constrained_hessian_params(ws, ψ),
        rng=MersenneTwister(3))

    # And the arm gate-2 does run, at two iteration caps. If the verdict moves
    # with `niter`, the Lanczos is the live wire — a positive control for the
    # negative result above.
    short = check(StabilitySpec(; niter=1), ws, ψ; rng=MersenneTwister(7))

    @printf("""
  consumer map, by execution:
    check(StabilitySpec) reproducible across identical seeds : %s
    verdict at niter=%d                                      : %s
    verdict at niter=1 (Lanczos starved)                     : %s   <- MOVES  ⇒ Lanczos is the live wire
    low_modes λ₁ :kinetic / :combined                        : %.6e / %.6e
    …neither of which the gate ever reads.
""", stable, 120, base.status, short.status, lm_k.λ[1], lm_c.λ[1])
    flush(stdout)
    (; reproducible=stable, verdict=base.status, verdict_starved=short.status,
        lm_kinetic=lm_k.λ[1], lm_combined=lm_c.λ[1],
        lanczos_is_live=(short.status !== base.status))
end

# ------------------------------------------- #397b: is :combined slower when gapped?
#
# The CI fixture's regime. `:combined` pays 2 extra FFTs and 2 multiplies per
# application, and the gapped problem is the one where the kinetic metric is
# already right, so losing here is the expected outcome and is a result either
# way. Each arm is run twice and the MINIMUM taken, per
# `feedback_reconcile_measurements_before_using_them`: a first call carries JIT.
function gapped_timing()
    grid = make_grid(GridConfig(16, 10.0))
    ip = InteractionParams(Dict(0 => 4.0, 1 => 0.3))
    r = find_ground_state_lbfgs(; grid, atom=Rb87, interactions=ip,
        potential=HarmonicTrap(1.0), n_steps=400, tol=1e-11,
        initial_state=:polar, verbose=false)
    ws = r.workspace
    ψ = copy(ws.state.psi)
    p = constrained_hessian_params(ws, ψ)
    rows = NamedTuple[]
    for pc in (:kinetic, :combined)
        best = Inf
        res = nothing
        for _ in 1:2
            t0 = time()
            res = trapped_bdg_low_modes(ws, ψ; nev=2, block=8, max_iter=200,
                tol=1e-7, precond=pc, params=p, rng=MersenneTwister(3))
            best = min(best, time() - t0)
        end
        @printf("    gapped %-9s λ₁=%+.6e  iters=%3d  converged=%s  wall=%.3f s\n",
            pc, res.λ[1], res.iterations, res.converged, best)
        push!(rows, (; precond=pc, λ1=res.λ[1], iters=res.iterations,
            converged=res.converged, wall=best))
    end
    flush(stdout)
    rows
end

# ------------------------------------------------------------------ cell arms

"""One (cell, precond, max_iter, α_v) arm. Returns the block's certificate as
well as its value — a Ritz value converges from ABOVE, so `λ` alone is an upper
bound and `width` is what says whether it is a measurement."""
function block_arm(ws, ψ, p; precond, max_iter, α_v)
    t0 = time()
    lm = trapped_bdg_low_modes(ws, ψ; nev=NEV, block=BLOCK, max_iter,
        tol=TOL, precond, α_v, ε=FD_EPS, params=p, rng=MersenneTwister(1))
    wall = time() - t0
    # The frequency face is `low_modes`' ONLY src consumer, so this is where a
    # default change would actually land. Reuse the block: `modes=` skips a
    # second Hessian solve.
    t1 = time()
    fr = trapped_bdg_frequencies(ws, ψ; nev=NEV, ε=FD_EPS, params=p, modes=lm,
        rng=MersenneTwister(1))
    wall_fr = time() - t1
    (; lm, fr, wall, wall_fr)
end

# --------------------------------------------------------------------- driver

cells = parse_cells()

@printf("""
Preconditioner A/B on the eu335 cells — #397 (which consumer) + #399 (does λ_min converge)
  κ=%.2f grid=%d³ box=%.1f  %s   nev=%d block=%d tol=%g FD ε=%g
  arms: precond ∈ {%s} × max_iter ∈ {%s} × α_v ∈ {%s}
  gate-2's own arm: Lanczos, niter=%d, NO preconditioner (it has no such knob)
  %d cell(s)
""", KAPPA, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU", NEV, BLOCK, TOL, FD_EPS,
    join(PRECONDS, ", "), join(MAXITERS, ", "),
    join((a === nothing ? "default" : string(a) for a in ALPHA_VS), ", "),
    LANCZOS_NITER, length(cells))
flush(stdout)

probe = get(ENV, "PA_SKIP_CONSUMER_PROBE", "0") == "1" ? nothing : consumer_probe()
if probe !== nothing && !probe.lanczos_is_live
    # The negative result below only means something if the probe can produce a
    # positive. If starving the Lanczos does NOT move the verdict either, the
    # probe is blind and no conclusion about the consumer map may be drawn.
    throw(BlindSpectrum("""
        the consumer probe is BLIND: starving the Lanczos to niter=1 did not move
        the StabilitySpec verdict either, so 'the block is not read' is
        indistinguishable from 'nothing is read'. No consumer-map claim below."""))
end

if get(ENV, "PA_SKIP_GAPPED", "0") != "1"
    println("  #397b — gapped fixture (does :combined lose where the metric is already right?):")
    gapped = gapped_timing()
else
    gapped = NamedTuple[]
end

rows = NamedTuple[]
for path in cells
    c = load_cell(path)
    ws = cell_workspace(c.psi, c.B, c.pin)
    ψ = copy(ws.state.psi)
    p = constrained_hessian_params(ws, ψ)
    g = similar(ψ)
    fill!(g, 0)
    energy_gradient!(g, ψ, ws)
    stat = sqrt(real(sum(abs2, g .- 2p.μ .* ψ)) * cell_volume(ws.grid))

    @printf("\n=== B = %.3f µG   ⟨F⊥⟩ = %.4f   stationarity = %.2e   [%s]\n",
        c.B, c.fperp0, stat, basename(dirname(path)))
    flush(stdout)

    # The arm gate-2 actually runs, once per cell, as the reference every block
    # arm is compared against.
    t0 = time()
    lz = trapped_bdg_lowest_eigenvalue(ws, ψ; niter=LANCZOS_NITER, atol=1e-6,
        ε=FD_EPS, params=p, rng=MersenneTwister(1))
    lz_wall = time() - t0
    @printf("  lanczos(gate-2)   λ_min=%+.6e  width=%.3e  converged=%-5s  iters=%3d  wall=%6.1f s\n",
        lz.λ_min, lz.width, lz.converged, lz.niter_used, lz_wall)
    flush(stdout)
    push!(rows, (; B=c.B, fperp=c.fperp0, stationarity=stat, arm="lanczos",
        precond="none", max_iter=LANCZOS_NITER, alpha_v="",
        λ1=lz.λ_min, λ_lower=lz.λ_lower, width=lz.width,
        residual=NaN, converged=lz.converged, iterations=lz.niter_used,
        ritz_spread=NaN, omega_min=NaN, spectrum_reached="",
        wall=lz_wall, cell=path))

    for pc in PRECONDS, mi in MAXITERS, av in ALPHA_VS
        (pc === :kinetic && av !== nothing) && continue   # α_v is :combined's knob
        a = block_arm(ws, ψ, p; precond=pc, max_iter=mi, α_v=av)
        lm, fr = a.lm, a.fr
        # WHY the bottom does not resolve, if it does not: a CLUSTER shows as a
        # small spread across the block's own Ritz values. A wrong metric shows
        # as a large residual with a wide spread. The two want different fixes,
        # so the diagnostic is recorded rather than inferred later.
        spread = length(lm.λ) >= 2 ? (lm.λ[end] - lm.λ[1]) : NaN
        @printf("  %-8s mi=%-4d %-9s λ₁=%+.6e  lower=%+.6e  width=%.3e  res=%.2e  conv=%-5s  its=%4d  spread=%.3e  ω_min=%.4e  reached=%-5s  wall=%6.1f+%.1f s\n",
            pc, mi, av === nothing ? "α_v=def" : @sprintf("α_v=%.3g", av),
            lm.λ[1], lm.λ_lower[1], lm.widths[1], lm.residuals[1], lm.converged,
            lm.iterations, spread, minimum(fr.omega), fr.spectrum_reached,
            a.wall, a.wall_fr)
        flush(stdout)
        push!(rows, (; B=c.B, fperp=c.fperp0, stationarity=stat, arm="block",
            precond=string(pc), max_iter=mi,
            alpha_v=(av === nothing ? "" : string(av)),
            λ1=lm.λ[1], λ_lower=lm.λ_lower[1], width=lm.widths[1],
            residual=lm.residuals[1], converged=lm.converged,
            iterations=lm.iterations, ritz_spread=spread,
            omega_min=minimum(fr.omega),
            spectrum_reached=string(fr.spectrum_reached),
            wall=a.wall + a.wall_fr, cell=path))
    end
end

# ------------------------------------------------------------------- output

hdr = ["B_uG" "fperp" "stationarity" "arm" "precond" "max_iter" "alpha_v" "lambda1" "lambda_lower" "width" "residual" "converged" "iterations" "ritz_spread" "omega_min" "spectrum_reached" "wall_s" "cell"]
tbl = [getfield(r, f) for r in rows,
    f in (:B, :fperp, :stationarity, :arm, :precond, :max_iter, :alpha_v,
        :λ1, :λ_lower, :width, :residual, :converged, :iterations,
        :ritz_spread, :omega_min, :spectrum_reached, :wall, :cell)]
open(joinpath(OUT, "precond_ab.csv"), "w") do io
    writedlm(io, vcat(hdr, tbl), '\t')
end

if !isempty(gapped)
    open(joinpath(OUT, "gapped_timing.csv"), "w") do io
        writedlm(io, vcat(["precond" "lambda1" "iterations" "converged" "wall_s"],
                [getfield(r, f) for r in gapped,
                    f in (:precond, :λ1, :iters, :converged, :wall)]), '\t')
    end
end

# --------------------------------------------------------------------- verdict

println("\n=== #399: did λ_min converge with a certificate? ===")
blocks = [r for r in rows if r.arm == "block"]
conv = [r for r in blocks if r.converged]
if isempty(conv)
    println("  NO. Not one block arm met its own residual tolerance.")
    println("  Every λ₁ below is an UPPER BOUND on λ_min and nothing more —")
    println("  a Ritz value converges from above, so it cannot establish that a")
    println("  state IS a minimum. #335 §5.2's two-sided form stays open.")
    best = argmin(r -> r.λ1, blocks)
    @printf("  tightest upper bound: λ₁ ≤ %.6e at B=%.2f µG (%s, max_iter=%d)\n",
        best.λ1, best.B, best.precond, best.max_iter)
    @printf("  Ritz spread there: %.3e — %s\n", best.ritz_spread,
        best.ritz_spread < 10 * abs(best.λ1) ?
        "COMPARABLE to λ₁ ⇒ the bottom is a CLUSTER, which is a property of the state, not of the solver" :
        "large ⇒ the block is not yet inside the low group; more iterations, or a different metric")
else
    println("  YES for $(length(conv)) of $(length(blocks)) arms:")
    for r in conv
        @printf("    B=%7.2f µG  %-9s mi=%-4d  λ_min = %+.6e ± %.2e  (%s)\n",
            r.B, r.precond, r.max_iter, r.λ1, r.width,
            r.λ1 - r.width > 0 ? "MINIMUM along every resolved direction" :
            (r.λ1 + r.width < 0 ? "SADDLE — proven" : "sign not resolved"))
    end
end

println("\n=== #397: whose default is this, anyway? ===")
if probe === nothing
    println("  consumer probe skipped (PA_SKIP_CONSUMER_PROBE=1) — no claim.")
else
    println("  `trapped_bdg_low_modes` has ONE src consumer: `trapped_bdg_frequencies`.")
    println("  `check(::StabilitySpec)` runs `trapped_bdg_lowest_eigenvalue`, which has")
    println("  no `precond` keyword — verified by execution above (starving IT moves the")
    println("  verdict; the block's own knob cannot). So the default is a question about")
    println("  ω and about which Hessian modes get RESOLVED, not about gate-2 verdicts.")
end
for pc in PRECONDS
    arms = [r for r in blocks if r.precond == string(pc)]
    isempty(arms) && continue
    @printf("  %-9s  median λ₁ = %+.4e   converged %d/%d   median wall = %.1f s\n",
        pc, sort([r.λ1 for r in arms])[max(1, end ÷ 2)],
        count(r -> r.converged, arms), length(arms),
        sort([r.wall for r in arms])[max(1, end ÷ 2)])
end

println("\nwrote ", joinpath(OUT, "precond_ab.csv"))

# Is a branch end a SPINODAL? Ask the spectrum, not the solver.
#
# #335 located the end of the κ=1.8 flower branch by continuation — walking
# converged cells upward in B until L-BFGS can no longer find one — at
# B_sp = 68.4 ± 0.15 µG. That is a statement about a solver. A spinodal is also a
# statement about the SPECTRUM: the metastable minimum merges with a saddle, so
# the lowest eigenvalue of the constrained Hessian passes through zero. At a fold
#
#     λ_min ∝ √(B_sp − B)   ⇒   λ_min² is LINEAR in B, with its zero at B_sp.
#
# The two methods share no machinery, so agreement is evidence and disagreement is
# a finding. Pre-registration, axes, systematics and rejection criteria:
# `docs/guides/eu_spinodal_spectrum.md` — written before this script was run.
#
# It also answers #335 §5.2 ("is the polarised branch a minimum or a saddle?"),
# which that campaign left in flight and could only approach with two INDIRECT
# instruments: HOLD is blind to an instability slower than the hold, REMIN is
# blind to sliding along a flat direction. The constrained Hessian is blind to
# neither and carries a two-sided (Kato–Temple) certificate.
#
# TWO AXES, NEVER MERGED. `λ_min` is ENERGETIC (is ψ a minimum). `growth` is
# DYNAMICAL (does a perturbation grow exponentially). A state can be energetically
# marginal and dynamically unstable; every row reports both.
#
# Env:
#   SP_CELLS=a/psi.jld2;b/psi.jld2   cells to measure (`;` — qsub -v cuts at `,`)
#   SP_CELLS_N=                      expected count; guards that cut
#   SP_NEV=6  SP_BLOCK=  SP_MAXITER=40  SP_HESS_TOL=1e-6
#   SP_FD_EPS=1e-5                   Hessian finite-difference step
#   SP_FD_EPS2=                      second FD step (instrument axis); "" = skip
#   SP_KAPPA=1.8 SP_GRID=32 SP_BOX=24.0 SP_PIN=0.002 SP_PADDING=0
#   SP_STATIONARY_TOL=1e-4           ‖g−2μψ‖ above which the cell is indeterminate
#   SP_FIT_BMIN=55                   flower cells above this enter the λ² fit
#   SP_BSP_REF=68.4  SP_BSP_TOL=0.3  the pre-registered agreement band [µG]
#   SP_OUT=figs/eu_spectrum/branch
#   SP_SKIP_CONTROLS=1               debugging only; results are then uncalibrated
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_spectrum/branch_spectrum.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, make_workspace, SimParams,
    static_zeeman, find_ground_state_lbfgs, cell_volume, energy_gradient!,
    constrained_hessian_params, trapped_bdg_low_modes, trapped_bdg_frequencies,
    CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldopen
using Printf
using Random

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const KAPPA = getf("SP_KAPPA", 1.8)
const GRID_N = Int(getf("SP_GRID", 32))
const BOX = getf("SP_BOX", 24.0)
const PIN = getf("SP_PIN", 0.002)
const NEV = Int(getf("SP_NEV", 6))
const BLOCK = Int(getf("SP_BLOCK", NEV + 6))
const MAXITER = Int(getf("SP_MAXITER", 40))
const HESS_TOL = getf("SP_HESS_TOL", 1e-6)
const FD_EPS = getf("SP_FD_EPS", 1e-5)
const FD_EPS2 = haskey(ENV, "SP_FD_EPS2") && !isempty(ENV["SP_FD_EPS2"]) ?
                parse(Float64, ENV["SP_FD_EPS2"]) : NaN
const PADDING = get(ENV, "SP_PADDING", "0") == "1"
const STAT_TOL = getf("SP_STATIONARY_TOL", 1e-4)
const FIT_BMIN = getf("SP_FIT_BMIN", 55.0)
# The fit and the softening claim are about the FLOWER branch, which is the one
# that ends. A single job also carries polarised cells (#335 §5.2), and those sit
# at ⟨F⊥⟩ ≈ 0.9 against the flower's ≥ 2.2 — selecting on B alone would have put
# them in the same fit and asked where a branch that does not end, ends.
const FIT_FPERP_MIN = getf("SP_FIT_FPERP_MIN", 1.5)
const BSP_REF = getf("SP_BSP_REF", 68.4)
const BSP_TOL = getf("SP_BSP_TOL", 0.3)
const OUT = get(ENV, "SP_OUT", "figs/eu_spectrum/branch")
mkpath(OUT)

# Matching #335: the states were converged with dealiasing off, and a state
# converged under a different Hamiltonian is not stationary under this one.
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "SP_DEALIAS", "0") == "1"

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom

p_of(B_uG) = Units.bfield_to_p(B_uG * 1e-6, ATOM.g_F, PRESET.omega_ref)

struct BlindSpectrum <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindSpectrum) = print(io, "BlindSpectrum: ", e.msg)

"""ψ and its recorded (B, ε), with the parameter-epoch check every consumer of a
stored state owes — same contract as `eu_hysteresis/branch_stability.jl`, because
the Hessian is even less forgiving than a hold: on a state that is not stationary
here, μ is not the chemical potential and λ_min is not a stability verdict."""
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
            pin=Float64(g("pin_bx", g("pin_eps", PIN))),
            fperp0=Float64(g("fperp", NaN)), E0=Float64(g("E_total", g("E", NaN))))
    end
end

"""The workspace the cell was converged in: same trap, same pin, same DDI kernel.
`imaginary_time` is irrelevant here (nothing is propagated) but the Hamiltonian is
not."""
function cell_workspace(psi, B_uG, ε)
    make_workspace(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=static_zeeman(; Bz=p_of(B_uG), Bx=ε, q=0.0),
        sim_params=SimParams(; dt=0.002, n_steps=1, imaginary_time=true),
        psi_init=Array{ComplexF64}(psi), enable_ddi=true, c_dd=PRESET.c_dd,
        secular_ddi=false, backend=BACKEND, ddi_padding=PADDING,
        ddi_trunc_radius=-1.0)
end

"""Both axes of one cell, over ONE Hessian block (the frequency reduction reuses
the eigenvectors, so the expensive part is paid once)."""
function measure(ws, ψ; nev=NEV, block=BLOCK, max_iter=MAXITER, fd=FD_EPS, seed=1)
    p = constrained_hessian_params(ws, ψ)
    g = similar(ψ)
    fill!(g, 0)
    energy_gradient!(g, ψ, ws)
    dV = cell_volume(ws.grid)
    stat = sqrt(real(sum(abs2, g .- 2p.μ .* ψ)) * dV)

    lm = trapped_bdg_low_modes(ws, ψ; nev, block, max_iter, tol=HESS_TOL,
        ε=fd, params=p, rng=MersenneTwister(seed))
    fr = trapped_bdg_frequencies(ws, ψ; nev, ε=fd, params=p, modes=lm,
        rng=MersenneTwister(seed))
    (; μ=p.μ, stationarity=stat, λ=lm.λ, λ_lower=lm.λ_lower,
        widths=lm.widths, converged=lm.converged_modes,
        ω=fr.omega, growth=fr.growth, labels=fr.labels,
        spectrum_reached=fr.spectrum_reached, fd_floor=fr.hessian_symmetry_defect,
        lhy=fr.lhy_active)
end

# ----------------------------------------------------------------- calibration
#
# A stability instrument that can only return "stable" proves nothing. The
# fixture is the repo's own known stationary saddle (F=1 polar at c₁<0, where the
# FM branch is lower and a pure m=0 seed keeps L-BFGS on the polar critical
# point) — the same one `test/oracles/test_stability_sneaky_prover.jl` uses, so
# its answer is independently gated. Its c₁>0 mirror is a genuine minimum, and
# both are needed: an instrument that says "saddle" for everything is as useless
# as one that says "minimum" for everything.
function calibrate()
    n, box = 64, 14.0
    grid = make_grid(GridConfig((n,), (box,)))
    out = NamedTuple[]
    for (name, c1, want) in (("positive (polar saddle, c₁<0)", -0.3, :negative),
        ("negative (polar minimum, c₁>0)", 0.3, :nonneg))
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => c1)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true))
        seed = zeros(ComplexF64, n, 3)
        for i in 1:n
            seed[i, 2] = exp(-grid.x[1][i]^2 / 2)
        end
        seed ./= sqrt(sum(abs2, seed) * cell_volume(grid))
        find_ground_state_lbfgs(; ws_init=ws, psi_init=seed, n_steps=800,
            tol=1e-10, target_magnetization=0.0, verbose=false)
        ψ = copy(ws.state.psi)
        m = measure(ws, ψ; nev=4, block=10, max_iter=60)
        @printf("  %s → λ_min = %+.4e (converged=%s, stationarity %.1e)\n",
            name, m.λ[1], m.converged[1], m.stationarity)
        push!(out, (; name, λ=m.λ[1], want, conv=m.converged[1]))
    end
    bad = String[]
    pos, neg = out[1], out[2]
    pos.λ < -0.1 || push!(bad,
        "POSITIVE control did not go negative (λ_min = $(pos.λ)): a stationary " *
        "SADDLE must come back with a negative Hessian eigenvalue. This " *
        "instrument cannot currently detect instability, so nothing below is a " *
        "stability verdict")
    neg.λ > -1e-6 || push!(bad,
        "NEGATIVE control went negative (λ_min = $(neg.λ)): a genuine minimum is " *
        "being called a saddle, so the 'unstable' verdicts are worthless too")
    isempty(bad) || throw(BlindSpectrum(join(bad, "\n  ")))
    println("  controls passed: λ_min can come back negative AND non-negative\n")
    out
end

# --------------------------------------------------------------------- driver

cells = let s = get(ENV, "SP_CELLS", "")
    v = isempty(s) ? String[] : String.(split(s, r"[,;]"))
    n = get(ENV, "SP_CELLS_N", "")
    isempty(n) || length(v) == parse(Int, n) || error("""
        SP_CELLS parsed $(length(v)) entries but SP_CELLS_N says $n.
        A list passed through `qsub -v` is cut at the first comma — use `;`.""")
    v
end
isempty(cells) && error("SP_CELLS is empty — nothing to measure")

@printf("""
Branch spectrum: κ=%.2f grid=%d³ box=%.1f  %s
  nev=%d block=%d max_iter=%d hess_tol=%g   FD ε=%g%s
  stationarity gate %.1e   DDI padding=%s   %d cell(s)
  agreement band: |B_sp_fit − %.2f| ≤ %.2f µG  (fit over cells with B ≥ %.1f AND ⟨F⊥⟩ ≥ %.2f)
""", KAPPA, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU", NEV, BLOCK, MAXITER, HESS_TOL,
    FD_EPS, isnan(FD_EPS2) ? "" : " and $(FD_EPS2)", STAT_TOL, PADDING,
    length(cells), BSP_REF, BSP_TOL, FIT_BMIN, FIT_FPERP_MIN)
flush(stdout)

if get(ENV, "SP_SKIP_CONTROLS", "0") == "1"
    @warn "SP_SKIP_CONTROLS=1: the verdicts below are UNCALIBRATED and must not be quoted"
else
    println("calibrating (can λ_min come back negative?):")
    flush(stdout)
    calibrate()
end

rows = NamedTuple[]
for (i, path) in enumerate(cells)
    c = load_cell(path)
    ws = cell_workspace(c.psi, c.B, c.pin)
    ψ = copy(ws.state.psi)
    t0 = time()
    m = measure(ws, ψ)
    # Second FD step on the SAME cell: a λ_min near zero is exactly where the
    # central-difference Hessian is least trustworthy, so the step is an axis and
    # not a constant.
    λ2 = NaN
    if !isnan(FD_EPS2)
        λ2 = measure(ws, ψ; fd=FD_EPS2).λ[1]
    end
    ok = m.stationarity < STAT_TOL
    # The threshold that separates "negative" from "zero" is the cell's own
    # CERTIFIED interval, not a constant and not `fd_floor` — `fd_floor` is the
    # reduced Hessian's RELATIVE asymmetry (dimensionless), so comparing λ to it
    # would be comparing a number to a ratio. The Kato–Temple width is the
    # uncertainty on λ_min in λ's own units, which is exactly what "is this
    # distinguishable from zero" needs.
    tolλ = max(1e-8, m.widths[1])
    verdict = !ok ? "indeterminate(nonstationary)" :
              !m.converged[1] ? "unresolved" :
              m.λ[1] < -tolλ ? "SADDLE" :
              m.λ[1] < tolλ ? "marginal" : "minimum"
    push!(rows, (; cell=i, path, B_uG=c.B, pin=c.pin, fperp0=c.fperp0, mu=m.μ,
        stationarity=m.stationarity, lambda_min=m.λ[1], lambda_lower=m.λ_lower[1],
        width=m.widths[1], converged=m.converged[1], lambda_min_fd2=λ2,
        omega_min=m.ω[1], growth_max=maximum(abs, m.growth),
        spectrum_reached=m.spectrum_reached, label1=String(m.labels[1]),
        fd_floor=m.fd_floor, lhy_active=m.lhy, verdict,
        wall_s=round(time() - t0; digits=1)))
    @printf("[%2d] B=%7.3f µG  λ_min=%+.4e [%+.4e] w=%.1e conv=%-5s  ω_min=%.4e γ=%.1e  %-12s stat=%.1e  %s  %.0fs\n",
        i, c.B, m.λ[1], m.λ_lower[1], m.widths[1], m.converged[1], m.ω[1],
        maximum(abs, m.growth), verdict, m.stationarity,
        isnan(λ2) ? "" : @sprintf("fd2 λ=%+.3e", λ2), time() - t0)
    flush(stdout)
    ks = collect(keys(rows[1]))
    open(joinpath(OUT, "spectrum.csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for r in rows
            writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
        end
    end
end

# ------------------------------------------------- the pre-registered fit + verdict
#
# λ_min² = a(B_sp − B) at a fold. The fit is applied to cells that PASSED both
# gates (stationary and converged) and sit above SP_FIT_BMIN, and its verdict was
# fixed in `docs/guides/eu_spinodal_spectrum.md` §4 before the run.
is_flower(r) = isfinite(r.fperp0) && r.fperp0 >= FIT_FPERP_MIN
usable = [r for r in rows if r.converged && r.stationarity < STAT_TOL &&
              is_flower(r) && r.B_uG >= FIT_BMIN && isfinite(r.lambda_min) &&
              r.lambda_min > 0]
println()
if length(usable) < 3
    println("FIT: skipped — only $(length(usable)) usable cell(s) above B=$FIT_BMIN " *
            "(need ≥ 3). This is a reportable outcome, not a reason to lower the gate.")
else
    B = [r.B_uG for r in usable]
    y = [r.lambda_min^2 for r in usable]
    n = length(B)
    B̄, ȳ = sum(B) / n, sum(y) / n
    Sbb = sum((B .- B̄) .^ 2)
    slope = sum((B .- B̄) .* (y .- ȳ)) / Sbb
    intercept = ȳ - slope * B̄
    B_sp = -intercept / slope                       # where λ² crosses zero
    resid = y .- (intercept .+ slope .* B)
    rms = sqrt(sum(resid .^ 2) / n)
    Δ = abs(B_sp - BSP_REF)
    verdict = Δ <= BSP_TOL ? "AGREES with continuation" :
              Δ <= 1.0 ? "SOFT DISAGREEMENT (0.3–1.0 µG)" :
              "DISAGREES — a finding, not a fit to improve"
    @printf("""
FIT (pre-registered): λ_min² = a·(B_sp − B) over %d cells with B ≥ %.1f µG
  slope a      = %.4e per µG   (negative ⇒ softening toward larger B)
  B_sp (fit)   = %.3f µG
  continuation = %.2f ± 0.15 µG   →  Δ = %.3f µG   ⇒  %s
  rms residual = %.3e in λ²      (compare the λ² of the softest cell, %.3e)
  NOTE the field systematic is ±0.1 µG; no B_sp may be quoted tighter than that.
""", n, FIT_BMIN, slope, B_sp, BSP_REF, Δ, verdict, rms, minimum(y))
end

# Criterion 3: the softening claim, measured rather than eyeballed.
flower = [r for r in rows if r.converged && r.stationarity < STAT_TOL &&
              is_flower(r) && r.lambda_min > 0]
if length(flower) >= 2
    lo, hi = argmin(r -> r.B_uG, flower), argmax(r -> r.B_uG, flower)
    ratio = lo.lambda_min / hi.lambda_min
    @printf("SOFTENING: λ_min(B=%.2f)=%.4e → λ_min(B=%.2f)=%.4e   ratio %.2f× %s\n",
        lo.B_uG, lo.lambda_min, hi.B_uG, hi.lambda_min, ratio,
        ratio >= 3 ? "≥ 3× ⇒ criterion 3 PASSES" : "< 3× ⇒ criterion 3 FAILS (report it)")
end

println("\nALLDONE  $(length(rows)) cell(s) → $OUT/spectrum.csv")
println("""
Read it as: `lambda_min` is the ENERGETIC axis (< 0 ⇒ saddle, ≈ 0 ⇒ marginal) and
`growth_max` is the DYNAMICAL one (> 0 ⇒ a perturbation grows). They are
orthogonal — a state can be energetically marginal and dynamically unstable — and
a row may not be summarised with one word. `converged` and `width` are the
Kato–Temple certificate on λ_min; an unconverged cell's VALUE is not a
measurement, which is the #50 failure. `lambda_min_fd2` is the same cell at a
different finite-difference step: if it disagrees with `lambda_min` by more than
`width`, that cell is FD-limited and its λ_min is a floor, not a number.
""")

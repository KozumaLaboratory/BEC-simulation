# Read the #337 criterion-B campaign and say where each arm's phase boundary is.
#
# Separate from the measurement on purpose (CLAUDE.md "measurement loops must be
# cheap to RE-READ"): changing how a verdict is read costs a second and no GPU.
# The campaign is `runs/eu_lhy_boundary_337/config_arms.yaml`; this reads the
# `point_*.jld2` it wrote.
#
# The boundary is where ΔE(B) = E(stretched) − E(polar) crosses zero, located by
# linear interpolation between the bracketing B points. δB between arms is the
# answer to "how far does the boundary move if LHY is left out".
#
# THE VERDICT IS REFUSED, not softened, when:
#   * the positive control (×10 scalar) fails to move the boundary — then the
#     instrument cannot see LHY and no physics arm means anything;
#   * an arm's ΔE(B) is bit-identical to the `none` arm's — that arm is not
#     running LHY at all, which is the 2026-07-29 failure;
#   * a bracketing cell did not converge — a crossing between two unconverged
#     runs is a crossing between two trajectories.
#
#   julia --project=. bench/lhy_boundary_report.jl <run_dir> [--residual]
#
# `--residual` additionally rebuilds a SpatialLHY table from each converged ψ and
# reports `spatial_lhy_residual` (criterion C). That costs BdG solves, so it is
# opt-in.

using Printf
using JLD2
using YAML
using SpinorBEC
using SpinorBEC: compute_spatial_lhy, spatial_lhy_residual, LHYTableOpts

const RUN_DIR = length(ARGS) >= 1 ? ARGS[1] : error("usage: lhy_boundary_report.jl <run_dir>")
const WANT_RESIDUAL = "--residual" in ARGS

# Arm pairings: (label, stretched-branch run name, polar-branch run name).
const PAIRS = [
    ("none (mean field)", "fm_none", "polar_none"),
    ("one functional (fm_dipolar both)", "fm_fmdip", "polar_fmdip"),
    ("own ansatz per branch", "fm_fmdip", "polar_polcon"),
    ("spatial (texture-following)", "fm_spatial", "polar_spatial"),
    ("CONTROL scalar ×10", "fm_ctrl10", "polar_ctrl10"),
]

# dp/dB at the campaign's atom and ω_ref, from cli.jl inspect: p = −0.651 at
# 44 µG. The stretched branch sits at m = −F and gains 6p; the polar branch is
# flat in p. So |∂ΔE/∂B| = 6 |dp/dB|.
const DPDB_PER_UG = 0.651 / 44.0
const SLOPE_PER_UG = 6 * DPDB_PER_UG

function load_points(dir)
    cfg = YAML.load_file(joinpath(dir, "config.yaml"))
    bz = cfg["scan"]["product"]["pipeline.0.B.Bz"]
    # "4.4e-5 Gauss" → µG
    b_ug = map(bz) do s
        v = s isa AbstractString ? parse(Float64, split(String(s))[1]) : Float64(s)
        v * 1e6
    end
    pts = Dict{Tuple{Int, String}, Any}()
    for f in readdir(dir)
        m = match(r"^point_(\d+)_(.+)\.jld2$", f)
        m === nothing && continue
        idx = parse(Int, m.captures[1])
        arm = String(m.captures[2])
        jldopen(joinpath(dir, f)) do io
            ks = keys(io)
            elhy = try
                io["analyze/energy_decomposition/lhy"]
            catch
                NaN
            end
            phase = try
                io["analyze/phase_classify_distance/phase"]
            catch
                "?"
            end
            pts[(idx, arm)] = (
                E="energy" in ks ? io["energy"] : NaN,
                conv="converged" in ks ? io["converged"] : false,
                grad="grad_norm" in ks ? io["grad_norm"] : NaN,
                mz="mz_actual" in ks ? io["mz_actual"] : NaN,
                elhy=elhy, phase=String(string(phase)), file=joinpath(dir, f),
            )
        end
    end
    (b_ug, pts)
end

"""Zero crossing of ΔE(B) by linear interpolation, plus the local slope actually
observed. Returns `nothing` when no bracketing pair exists — an extrapolated
boundary is not a measured one."""
function crossing(bs, des)
    for i in 1:(length(bs) - 1)
        a, b = des[i], des[i + 1]
        (isnan(a) || isnan(b)) && continue
        if (a > 0) != (b > 0)
            t = a / (a - b)
            return (B=bs[i] + t * (bs[i + 1] - bs[i]),
                slope=abs(b - a) / (bs[i + 1] - bs[i]), i=i)
        end
    end
    nothing
end

b_ug, pts = load_points(RUN_DIR)
println("="^104)
println("#337 criterion B — LHY and the Eu F=6 phase boundary.  run: ", RUN_DIR)
println("B points (µG): ", join(round.(b_ug; digits=2), ", "))
println("|∂ΔE/∂B| expected from the Zeeman slope alone: ",
    round(SLOPE_PER_UG; sigdigits=4), " per µG")
println("="^104)

# --- per-cell table, so a bad cell is visible before any verdict --------------
arms = sort(unique(k[2] for k in keys(pts)))
println("\n[cells] E, convergence and E_LHY per arm and field")
@printf("  %-15s %8s %12s %6s %10s %10s %-18s\n",
    "arm", "B (µG)", "E", "conv", "grad", "E_LHY", "phase")
for arm in arms, i in eachindex(b_ug)
    p = get(pts, (i, arm), nothing)
    p === nothing && continue
    @printf("  %-15s %8.2f %12.7f %6s %10.2e %10.5f %-18s\n",
        arm, b_ug[i], p.E, p.conv ? "yes" : "NO", p.grad, p.elhy, p.phase)
end

# --- ΔE and boundary per arm pair --------------------------------------------
println("\n[boundary] ΔE(B) = E(stretched) − E(polar), and its zero crossing")
results = Dict{String, Any}()
de_by_pair = Dict{String, Vector{Float64}}()
for (label, fm, pol) in PAIRS
    des = Float64[]
    allconv = true
    for i in eachindex(b_ug)
        a = get(pts, (i, fm), nothing)
        b = get(pts, (i, pol), nothing)
        if a === nothing || b === nothing
            push!(des, NaN)
            continue
        end
        push!(des, a.E - b.E)
        (a.conv && b.conv) || (allconv = false)
    end
    de_by_pair[label] = des
    c = crossing(b_ug, des)
    results[label] = (c=c, conv=allconv, des=des)
    @printf("\n  %-34s  %s\n", label, allconv ? "" : "  [NOT every cell converged]")
    @printf("    ΔE: %s\n", join([isnan(d) ? "  —  " : @sprintf("%+8.4f", d) for d in des], " "))
    if c === nothing
        println("    no sign change inside the scanned window — boundary NOT bracketed")
    else
        @printf("    B_c = %.3f µG   (local |∂ΔE/∂B| = %.4f per µG, %.2f× the Zeeman-only slope)\n",
            c.B, c.slope, c.slope / SLOPE_PER_UG)
    end
end

# --- wiring: is any arm bit-identical to the baseline? -----------------------
println("\n[wiring] max |ΔE(arm) − ΔE(none)| over the scan — exactly 0 means the arm")
println("         is not running LHY, whatever its label says.")
base = de_by_pair["none (mean field)"]
for (label, _, _) in PAIRS
    label == "none (mean field)" && continue
    d = de_by_pair[label]
    m = maximum(i -> (isnan(d[i]) || isnan(base[i])) ? -Inf : abs(d[i] - base[i]),
        eachindex(d))
    @printf("  %-34s %12.3e %s\n", label, m, m == 0 ? "  <-- INERT, refuse" : "")
end

# --- verdict ------------------------------------------------------------------
println("\n[verdict]")
bc_none = results["none (mean field)"].c
bc_ctrl = results["CONTROL scalar ×10"].c
if bc_none === nothing || bc_ctrl === nothing
    println("  REFUSED: the boundary is not bracketed for the baseline or the control,")
    println("  so there is nothing to compare. Widen the B window and re-run.")
else
    ctrl_shift = bc_ctrl.B - bc_none.B
    @printf("  control shift: %+.3f µG\n", ctrl_shift)
    if abs(ctrl_shift) < 5.0
        println("  REFUSED: the ×10 control moved the boundary by less than the 5 µG the")
        println("  pre-launch criterion demanded. The instrument cannot see LHY here, so")
        println("  no verdict may be read off the physics arms.")
    else
        println("  control passes — the instrument responds to LHY amplitude.\n")
        @printf("  %-34s %12s %12s\n", "arm", "B_c (µG)", "δB vs none")
        for (label, _, _) in PAIRS
            r = results[label]
            r.c === nothing && continue
            @printf("  %-34s %12.3f %12.3f%s\n", label, r.c.B, r.c.B - bc_none.B,
                r.conv ? "" : "   [unconverged cells]")
        end
    end
end

# --- criterion C: the SpatialLHY residual, and what it is worth in µG ---------
if WANT_RESIDUAL
    println("\n[criterion C] SpatialLHY residual on the converged states, and the")
    println("boundary displacement it implies.")
    ip = interaction_params_from_constraint(; c_total=4687.27, c1_ratio=1 / 36, F=6)
    c_dd = 211.021
    @printf("\n  %-15s %8s %12s %12s %14s\n",
        "arm", "B (µG)", "residual", "E_LHY", "δ(ΔE) bound")
    for arm in ("fm_spatial", "polar_spatial"), i in eachindex(b_ug)
        p = get(pts, (i, arm), nothing)
        p === nothing && continue
        psi = jldopen(io -> io["psi"], p.file)
        pB = SpinorBEC.linear_zeeman_p(Eu151, b_ug[i] * 1e-10, 691.1504)
        zee = ZeemanParams(pB,
            SpinorBEC.compute_quadratic_zeeman(Eu151; p_dimless=pB, omega_ref=691.1504))
        tbl = compute_spatial_lhy(; psi_init=Array(psi), F=6, interactions=ip,
            zeeman=zee, c_dd=c_dd, n_atoms=50000)
        r = tbl === nothing ? NaN :
            spatial_lhy_residual(tbl, Array(psi), 6, ip; zeeman=zee, c_dd=c_dd)
        @printf("  %-15s %8.2f %12.4g %12.5f %14.5f\n",
            arm, b_ug[i], r, p.elhy, isnan(r) ? NaN : r * abs(p.elhy))
        flush(stdout)
    end
    println("\n  A residual r on ε_LHY moves each branch's energy by at most r·E_LHY, so")
    println("  the gap by at most the SUM of the two (they can move oppositely), and the")
    println("  boundary by that over ", round(SLOPE_PER_UG; sigdigits=4), " per µG.")
end

println("\ndone.")

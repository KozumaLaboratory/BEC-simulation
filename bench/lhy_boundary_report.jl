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
using SpinorBEC: compute_spatial_lhy, spatial_lhy_residual,
    spatial_lhy_energy_residual, LHYTableOpts

const RUN_DIR = length(ARGS) >= 1 ? ARGS[1] : error("usage: lhy_boundary_report.jl <run_dir>")
const WANT_RESIDUAL = "--residual" in ARGS

# Arm pairings: (label, stretched-branch run name, polar-branch run name).
const PAIRS_BASE = [
    ("none (mean field)", "fm_none", "polar_none"),
    ("one functional (fm_dipolar both)", "fm_fmdip", "polar_fmdip"),
    ("own ansatz per branch", "fm_fmdip", "polar_polcon"),
    ("spatial (texture-following)", "fm_spatial", "polar_spatial"),
]
# The control arm is named for its factor, so which one exists tells us the
# factor without a second place to keep it in sync.
const CONTROL_LABEL = Ref("CONTROL")

# dp/dB at the campaign's atom and ω_ref, from cli.jl inspect: p = −0.651 at
# 44 µG. The stretched branch sits at m = −F and gains 6p; the polar branch is
# flat in p. So |∂ΔE/∂B| = 6 |dp/dB|.
const DPDB_PER_UG = 0.651 / 44.0
const SLOPE_PER_UG = 6 * DPDB_PER_UG
# ...and the slope actually OBSERVED near the crossing, which is 0.35x that
# because the stretched branch is `cyclic` rather than fully polarised at these
# fields. Derived slopes are for sanity-checking; measured ones are for dividing by.
const SLOPE_MEASURED_PER_UG = 0.0311
# The pre-launch rejection threshold, per axis: 5 µG on the field scan, one grid
# step (0.001) on the c1 scan. Below this the control is inside the resolution
# and proves nothing.
ctrl_min_shift(unit) = unit == "µG" ? 5.0 : 0.001

"""Scan axis, values and unit label. The two campaigns scan DIFFERENT axes — Bz
in `config_arms.yaml`, c1_ratio in `config_arms_c1.yaml` — and hard-coding one of
them is how a report silently misreads the other's points as fields."""
function scan_axis(cfg)
    prod = cfg["scan"]["product"]
    if haskey(prod, "pipeline.0.B.Bz")
        vals = map(prod["pipeline.0.B.Bz"]) do s
            v = s isa AbstractString ? parse(Float64, split(String(s))[1]) : Float64(s)
            v * 1e6                       # Gauss → µG
        end
        return (collect(vals), "B (µG)", "µG")
    elseif haskey(prod, "pipeline.0.interactions.c1_ratio")
        r = prod["pipeline.0.interactions.c1_ratio"]
        vals = r isa AbstractDict ?
               collect(range(Float64(r["from"]), Float64(r["to"]); length=Int(r["n"]))) :
               Float64.(collect(r))
        return (vals, "c1_ratio", "c1")
    end
    error("scan axis is neither pipeline.0.B.Bz nor pipeline.0.interactions.c1_ratio")
end

function load_points(dir)
    cfg = YAML.load_file(joinpath(dir, "config.yaml"))
    b_ug, axis_label, axis_unit = scan_axis(cfg)
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
    (b_ug, pts, axis_label, axis_unit)
end

"""Median |ΔΕ/Δaxis| over the scan — the conversion factor from an energy-gap
shift to a boundary displacement. Reported per arm because it is NOT arm
independent: measured 66.8 and 58.5 on the two arms that cross, 13 % apart."""
function local_slope(bs, des)
    sl = Float64[]
    for i in 1:(length(bs) - 1)
        (isnan(des[i]) || isnan(des[i + 1])) && continue
        push!(sl, abs(des[i + 1] - des[i]) / (bs[i + 1] - bs[i]))
    end
    isempty(sl) ? NaN : sort(sl)[cld(length(sl), 2)]
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

b_ug, pts, AXIS, AXIS_UNIT = load_points(RUN_DIR)
# Build PAIRS now that the arm names on disk are known: the control's factor is
# in its name (fm_ctrl10 / fm_ctrl30), so the label reports the real factor
# instead of a constant that can drift away from the config.
const CTRL_ARM = let a = sort(unique(k[2] for k in keys(pts)))
    i = findfirst(x -> startswith(x, "fm_ctrl"), a)
    i === nothing ? nothing : a[i]
end
# Absent is NOT "no control needed" — it is a directory that cannot support a
# verdict, and the verdict block below says so rather than quietly omitting the
# row. (This path is normal when only the `spatial` arms have been pulled for a
# `--residual` pass.)
const PAIRS = if CTRL_ARM === nothing
    CONTROL_LABEL[] = ""
    PAIRS_BASE
else
    CONTROL_LABEL[] = "CONTROL scalar ×" * replace(CTRL_ARM, "fm_ctrl" => "")
    vcat(PAIRS_BASE, [(CONTROL_LABEL[], CTRL_ARM, replace(CTRL_ARM, "fm_" => "polar_"))])
end
println("="^104)
println("#337 criterion B — LHY and the Eu F=6 phase boundary.  run: ", RUN_DIR)
println(AXIS, " points: ", join(round.(b_ug; sigdigits=5), ", "))
println("|∂ΔE/∂B| expected from the Zeeman slope alone: ",
    round(SLOPE_PER_UG; sigdigits=4), " per µG")
println("="^104)

# --- per-cell table, so a bad cell is visible before any verdict --------------
arms = sort(unique(k[2] for k in keys(pts)))
println("\n[cells] E, convergence and E_LHY per arm and field")
@printf("  %-15s %10s %12s %6s %10s %10s %-18s\n",
    "arm", AXIS, "E", "conv", "grad", "E_LHY", "phase")
for arm in arms, i in eachindex(b_ug)
    p = get(pts, (i, arm), nothing)
    p === nothing && continue
    @printf("  %-15s %10.5g %12.7f %6s %10.2e %10.5f %-18s\n",
        arm, b_ug[i], p.E, p.conv ? "yes" : "NO", p.grad, p.elhy, p.phase)
end

# --- ΔE and boundary per arm pair --------------------------------------------
println("\n[boundary] ΔE(B) = E(stretched) − E(polar), and its zero crossing")
results = Dict{String, Any}()
de_by_pair = Dict{String, Vector{Float64}}()
for (label, fm, pol) in PAIRS
    des = Float64[]
    merged = Bool[]
    allconv = true
    for i in eachindex(b_ug)
        a = get(pts, (i, fm), nothing)
        b = get(pts, (i, pol), nothing)
        if a === nothing || b === nothing
            push!(des, NaN)
            continue
        end
        push!(des, a.E - b.E)
        push!(merged, a.phase == b.phase)
        (a.conv && b.conv) || (allconv = false)
    end
    de_by_pair[label] = des
    c = crossing(b_ug, des)
    results[label] = (c=c, conv=allconv, des=des, merged=merged, slope=local_slope(b_ug, des))
    @printf("\n  %-34s  %s\n", label, allconv ? "" : "  [NOT every cell converged]")
    @printf("    ΔE: %s\n", join([isnan(d) ? "  —  " : @sprintf("%+8.4f", d) for d in des], " "))
    if any(merged)
        # The degeneracy guard this project insists on: when both seeds land in
        # the SAME phase they have merged, and their ΔE is a gap between two
        # points on one branch, not between two phases. A ΔE drifting to zero
        # then reads exactly like an approaching crossing and is not one.
        @printf("    MERGED at %s = %s — both seeds in one phase there; ΔE past that\n",
            AXIS, join([@sprintf("%.4g", b_ug[i]) for i in eachindex(merged) if merged[i]], ", "))
        println("    point is not a gap between phases and no crossing may be read from it.")
    end
    if c === nothing
        println("    no sign change inside the scanned window — boundary NOT bracketed")
    else
        @printf("    crossing at %s = %.5g   (local |∂ΔE/∂axis| = %.5g)\n",
            AXIS, c.B, c.slope)
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
bc_ctrl = CTRL_ARM === nothing ? nothing : results[CONTROL_LABEL[]].c
if CTRL_ARM === nothing
    println("  REFUSED: no positive-control arm (fm_ctrl*) is present in this")
    println("  directory, so nothing establishes that the instrument can see LHY.")
elseif bc_none === nothing || bc_ctrl === nothing
    println("  REFUSED: the boundary is not bracketed for the baseline or the control,")
    println("  so there is nothing to compare. Widen the scan window and re-run.")
else
    ctrl_shift = bc_ctrl.B - bc_none.B
    CTRL_MIN_SHIFT = ctrl_min_shift(AXIS_UNIT)
    @printf("  control shift: %+.5g (%s), threshold %.5g\n", ctrl_shift, AXIS, CTRL_MIN_SHIFT)
    if abs(ctrl_shift) < CTRL_MIN_SHIFT
        println("  REFUSED: the control moved the boundary by less than the pre-launch")
        println("  criterion demanded. The instrument cannot see LHY here, so")
        println("  no verdict may be read off the physics arms.")
    else
        println("  control passes — the instrument responds to LHY amplitude.\n")
        @printf("  %-34s %14s %14s\n", "arm", "crossing", "δ vs none")
        for (label, _, _) in PAIRS
            r = results[label]
            r.c === nothing && continue
            @printf("  %-34s %14.5g %14.5g%s\n", label, r.c.B, r.c.B - bc_none.B,
                r.conv ? "" : "   [unconverged cells]")
        end
    end
end

# --- the gap shift, which exists whether or not a crossing does ---------------
#
# A crossing is the preferred readout, but it is not always available: the
# baseline's stretched branch can MERGE into the polar one before ΔE reaches
# zero, in which case there is no mean-field boundary on this axis to displace.
# The shift in the gap is defined regardless, and converts to an axis
# displacement through each arm's own measured slope. First order, and labelled
# as such — it assumes the arms are parallel near the reference point.
println("\n[gap shift] δ(ΔE) against the baseline, at the reference point and converted")
println("through each arm's own median |∂ΔE/∂axis|. Independent of whether a crossing")
println("exists, so this is the reading when a branch merges instead of crossing.")
const REF_I = cld(length(b_ug), 2)
@printf("\n  reference %s = %.5g\n", AXIS, b_ug[REF_I])
@printf("  %-34s %12s %12s %12s %14s\n",
    "arm", "ΔE", "δ(ΔE)", "slope", "δ(axis)")
for (label, _, _) in PAIRS
    r = results[label]
    d = r.des[REF_I]
    isnan(d) && continue
    dd = d - base[REF_I]
    @printf("  %-34s %12.5f %12.5f %12.4g %14.5g\n",
        label, d, dd, r.slope, isnan(r.slope) || r.slope == 0 ? NaN : dd / r.slope)
end

# --- criterion C: the SpatialLHY residual, and what it is worth in µG ---------
if WANT_RESIDUAL
    println("\n[criterion C] SpatialLHY residual on the converged states, and the")
    println("boundary displacement it implies.")
    ip = interaction_params_from_constraint(; c_total=4687.27, c1_ratio=1 / 36, F=6)
    c_dd = 211.021
    println("  `signed` is the error on ∫ε_LHY dV and is what propagates. `uniform worst`")
    println("  is the OLD unweighted worst case, kept so the difference is visible: it is")
    println("  dominated by dilute edge voxels that carry no energy.")
    @printf("\n  %-15s %10s %10s %10s %10s %14s %12s\n",
        "arm", AXIS, "signed", "abs", "worst", "uniform worst", "E_LHY")
    resid = Dict{Tuple{String, Int}, Float64}()
    for arm in ("fm_spatial", "polar_spatial"), i in eachindex(b_ug)
        p = get(pts, (i, arm), nothing)
        p === nothing && continue
        psi = Array(jldopen(io -> io["psi"], p.file))
        pB = SpinorBEC.linear_zeeman_p(Eu151, b_ug[i] * 1e-10, 691.1504)
        zee = ZeemanParams(pB,
            SpinorBEC.compute_quadratic_zeeman(Eu151; p_dimless=pB, omega_ref=691.1504))
        tbl = compute_spatial_lhy(; psi_init=psi, F=6, interactions=ip,
            zeeman=zee, c_dd=c_dd, n_atoms=50000)
        if tbl === nothing
            # `compute_spatial_lhy` returns nothing when the p spread is below
            # `min_spread`, i.e. when the state HAS one spinor shape and the
            # single-spinor table is exact. That is residual 0 by construction,
            # not a missing measurement — recording it as absent would drop the
            # branch out of the propagation below and silently halve the answer.
            resid[(arm, i)] = 0.0
            @printf("  %-15s %10.5g %10s %10s %10s %14s %12.5f\n",
                arm, b_ug[i], "0 (exact)", "—", "—", "—", p.elhy)
            continue
        end
        sg, ab, wo = spatial_lhy_energy_residual(tbl, psi, 6, ip; zeeman=zee, c_dd=c_dd)
        un = spatial_lhy_residual(tbl, psi, 6, ip; zeeman=zee, c_dd=c_dd)
        resid[(arm, i)] = sg
        @printf("  %-15s %10.5g %10.4f %10.4f %10.4f %14.4f %12.5f\n",
            arm, b_ug[i], sg, ab, wo, un, p.elhy)
        flush(stdout)
    end

    println("\n  [propagation] the boundary displacement the signed residual implies")
    @printf("  %10s %14s %14s %14s %12s\n",
        AXIS, "δE(stretched)", "δE(polar)", "δ(ΔE)", "δB (µG)")
    for i in eachindex(b_ug)
        sf = get(resid, ("fm_spatial", i), NaN)
        sp = get(resid, ("polar_spatial", i), NaN)
        pf = get(pts, (i, "fm_spatial"), nothing)
        pp = get(pts, (i, "polar_spatial"), nothing)
        (isnan(sf) || isnan(sp) || pf === nothing || pp === nothing) && continue
        dEf = sf * pf.elhy
        dEp = sp * pp.elhy
        # They can move oppositely, so the gap error is the DIFFERENCE of the two
        # signed shifts, not a sum of magnitudes — which would be a bound nobody
        # could ever tighten.
        dgap = dEf - dEp
        @printf("  %10.5g %14.5f %14.5f %14.5f %12.3f\n",
            b_ug[i], dEf, dEp, dgap, dgap / SLOPE_MEASURED_PER_UG)
    end
    println("\n  δB uses the MEASURED local slope ", SLOPE_MEASURED_PER_UG,
        " per µG, not the Zeeman-only ", round(SLOPE_PER_UG; sigdigits=4), ".")
end

println("\ndone.")

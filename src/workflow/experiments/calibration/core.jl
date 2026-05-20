# --- Lab calibration layer (Phase 5.3 / Scenario #66) ---

export CalibrationSet, CoilCalibration, FORTCalibration, RabiCalibration
export DEFAULT_CALIBRATION, load_calibration, apply_calibration!, run_yaml_calibrated
export coil_mv_to_gauss, fort_mw_to_trap_hz, rabi_mw_to_rad_s
export CalibrationHistory, load_calibration_history, load_calibration_csv,
    interpolate_calibration

# Translates lab-hardware units (mV on a coil driver, mW of FORT / microwave
# power) into fields the existing pipeline parser already understands — i.e.
# Unitful-tagged strings like `"1.08 Gauss"` or `"180 Hz"`. Downstream
# `_parse_bfield` and Unitful trap parsers do the SI → dimensionless step.
#
# This module is deliberately narrow: only the small set of lab-specific
# conversions that can't be derived from first principles. Constants live
# in a per-experiment `CalibrationSet` loaded from YAML, not hard-coded
# here.
#
# Usage:
#   calib = load_calibration("lab_calib_2026_04.yaml")
#   apply_calibration!(raw_yaml_dict, calib)
#   run_config(load_config_from_dict(raw_yaml_dict))
#
# Or the one-shot wrapper:
#   run_yaml_calibrated("experiment.yaml"; calibration_path="lab_calib_2026_04.yaml")

using YAML: YAML
using Dates: Date

# --- Calibration struct (one per hardware epoch) ---

struct CoilCalibration
    gauss_per_mv::Float64
    gauss_offset::Float64           # residual field at 0 mV [G]
    valid_range_mv::NTuple{2, Float64}
end

CoilCalibration() = CoilCalibration(0.0, 0.0, (-Inf, Inf))

struct FORTCalibration
    # ω_axis(Hz) = sqrt_coeffs[axis] * sqrt(P_mW) + offsets[axis]
    sqrt_coeffs_hz::NTuple{3, Float64}
    offsets_hz::NTuple{3, Float64}
end

FORTCalibration() = FORTCalibration((0.0, 0.0, 0.0), (0.0, 0.0, 0.0))

struct RabiCalibration
    rad_per_s_per_mw::Float64
end

RabiCalibration() = RabiCalibration(0.0)

Base.@kwdef struct CalibrationSet
    epoch::String = "default"
    date::String = "unknown"
    coil_strong::CoilCalibration = CoilCalibration()
    coil_weak::CoilCalibration = CoilCalibration()
    fort::FORTCalibration = FORTCalibration()
    microwave::RabiCalibration = RabiCalibration()
end

"""
Placeholder calibration. Values are illustrative — replace with site-measured
constants before using for real experiments. Prefer `load_calibration("...")`
from a YAML file checked in per epoch.
"""
const DEFAULT_CALIBRATION = CalibrationSet(;
    epoch="placeholder",
    date="2026-04-24",
    coil_strong=CoilCalibration(0.4, 0.05, (-1000.0, 1000.0)),
    coil_weak=CoilCalibration(0.04, 0.002, (-100.0, 100.0)),
    fort=FORTCalibration((450.0, 450.0, 600.0), (0.0, 0.0, 0.0)),
    microwave=RabiCalibration(1.2e6),
)

# --- Conversions ---

function coil_mv_to_gauss(mv::Real, calib::CoilCalibration)
    lo, hi = calib.valid_range_mv
    if mv < lo || mv > hi
        @warn "calibration: mv=$mv outside validated range ($lo, $hi)"
    end
    calib.gauss_per_mv * Float64(mv) + calib.gauss_offset
end

function fort_mw_to_trap_hz(mw::Real, axis::Int, calib::FORTCalibration)
    1 <= axis <= 3 || throw(ArgumentError("fort axis must be 1..3"))
    calib.sqrt_coeffs_hz[axis] * sqrt(max(Float64(mw), 0.0)) + calib.offsets_hz[axis]
end

rabi_mw_to_rad_s(mw::Real, calib::RabiCalibration) =
    calib.rad_per_s_per_mw * Float64(mw)

# --- YAML loader ---

function load_calibration(path::AbstractString)
    raw = YAML.load_file(String(path))
    root = haskey(raw, "calibration") ? raw["calibration"] : raw
    _calibration_from_dict(root)
end

function _calibration_from_dict(d::Dict)
    kwargs = Dict{Symbol, Any}()
    haskey(d, "epoch") && (kwargs[:epoch] = String(d["epoch"]))
    haskey(d, "date") && (kwargs[:date] = String(d["date"]))
    if haskey(d, "coil_strong")
        kwargs[:coil_strong] = _parse_coil(d["coil_strong"])
    end
    if haskey(d, "coil_weak")
        kwargs[:coil_weak] = _parse_coil(d["coil_weak"])
    end
    if haskey(d, "fort")
        kwargs[:fort] = _parse_fort(d["fort"])
    end
    if haskey(d, "microwave")
        kwargs[:microwave] = RabiCalibration(Float64(d["microwave"]["rad_per_s_per_mw"]))
    end
    CalibrationSet(; kwargs...)
end

function _parse_coil(d::Dict)
    rng = get(d, "valid_range_mv", nothing)
    lo, hi = if rng isa Dict
        (Float64(get(rng, "min", -Inf)), Float64(get(rng, "max", Inf)))
    elseif rng isa AbstractVector && length(rng) == 2
        (Float64(rng[1]), Float64(rng[2]))
    else
        (-Inf, Inf)
    end
    CoilCalibration(
        Float64(d["gauss_per_mv"]),
        Float64(get(d, "gauss_offset", 0.0)),
        (lo, hi),
    )
end

function _parse_fort(d::Dict)
    c = Tuple(Float64(x) for x in d["sqrt_coeffs_hz"])
    o = Tuple(Float64(x) for x in get(d, "offsets_hz", [0.0, 0.0, 0.0]))
    length(c) == 3 || throw(ArgumentError("fort.sqrt_coeffs_hz must have length 3"))
    length(o) == 3 || throw(ArgumentError("fort.offsets_hz must have length 3"))
    FORTCalibration(NTuple{3, Float64}(c), NTuple{3, Float64}(o))
end

# --- Apply to raw YAML config dict ---

"""
    apply_calibration!(config::Dict, calib::CalibrationSet=DEFAULT_CALIBRATION)

Walk a raw YAML config dict (as returned by `YAML.load_file`) and rewrite
lab-unit fields into Unitful-tagged strings that the existing pipeline
parser already consumes via `Units.safe_parse_quantity`.

Recognized conventions (unified `B:` block; magnitude + direction in
one mapping):

- `B: {p_mv: 2.7, coil_mode: strong|weak, theta: ..., phi: ...}` →
  internally normalized to `zeeman: {p: "X Gauss"}` (the `p` key here
  is internal-only). `coil_mode` defaults to `strong`. `q` is
  auto-derived from |B|² unless explicit.

- `B: {q_mv: 0.1, coil_mode: ...}` → keeps `q_gauss` key for
  downstream-specific handling (pipeline default is to parse quadratic
  Zeeman directly; leave to caller). Note `q` is *usually* auto-derived
  and should not be specified by users.

- inside a potential block with `type: harmonic`:
  `{fort_power_mw: [Px, Py, Pz]}` → `{omega: ["fx Hz", "fy Hz", "fz Hz"]}`.

- `raman: {power_mw: P, ...}` → `raman: {Omega: "Y rad/s", ...}`. Gated
  on the presence of `detuning`/`delta` or an explicit `_kind: raman` so
  stray `power_mw` fields in other contexts are left alone.

Returns the (mutated) `config`.
"""
function apply_calibration!(config::Dict, calib::CalibrationSet=DEFAULT_CALIBRATION)
    _calibrate_recurse!(config, calib)
    config
end

function _calibrate_recurse!(node, calib::CalibrationSet)
    if node isa Dict
        _calibrate_zeeman_node!(node, calib)
        _calibrate_trap_node!(node, calib)
        _calibrate_raman_node!(node, calib)
        for v in values(node)
            _calibrate_recurse!(v, calib)
        end
    elseif node isa AbstractVector
        for x in node
            _calibrate_recurse!(x, calib)
        end
    end
    nothing
end

function _pick_coil(node::Dict, calib::CalibrationSet)
    mode = Symbol(get(node, "coil_mode", "strong"))
    mode === :strong && return calib.coil_strong
    mode === :weak && return calib.coil_weak
    throw(ArgumentError("calibration: unknown coil_mode=$(mode) (expected :strong or :weak)"))
end

function _calibrate_zeeman_node!(node::Dict, calib::CalibrationSet)
    if haskey(node, "p_mv")
        coil = _pick_coil(node, calib)
        gauss = coil_mv_to_gauss(Float64(node["p_mv"]), coil)
        # Output as a Cartesian Bz quantity-string. The canonical convention
        # was `p: "X Gauss"`, but `p` is the dimensionless Zeeman energy
        # internally — feeding a Gauss-string into `p` collides with
        # `_zeeman_scalar` (which only handles Reals + dim-less). The
        # B_block normalizer + downstream `_parse_bfield` correctly handle
        # `Bz: "X Gauss"`. Calibration→units pipeline ordering bug fix
        # (2026-05-02).
        node["Bz"] = "$(gauss) Gauss"
        delete!(node, "p_mv")
    end
    if haskey(node, "q_mv")
        coil = _pick_coil(node, calib)
        gauss = coil_mv_to_gauss(Float64(node["q_mv"]), coil)
        node["q_gauss"] = gauss
        delete!(node, "q_mv")
    end
    # coil_mode was only meaningful alongside the lab-unit fields; drop it.
    (haskey(node, "coil_mode") && !haskey(node, "p") && !haskey(node, "q")) &&
        delete!(node, "coil_mode")
end

function _calibrate_trap_node!(node::Dict, calib::CalibrationSet)
    haskey(node, "fort_power_mw") || return nothing
    pw = node["fort_power_mw"]
    if pw isa AbstractVector
        freqs_hz = [fort_mw_to_trap_hz(Float64(pw[i]), i, calib.fort)
                    for i in 1:length(pw)]
        node["omega"] = ["$(f) Hz" for f in freqs_hz]
    else
        f = fort_mw_to_trap_hz(Float64(pw), 1, calib.fort)
        node["omega"] = "$(f) Hz"
    end
    delete!(node, "fort_power_mw")
end

function _calibrate_raman_node!(node::Dict, calib::CalibrationSet)
    haskey(node, "power_mw") || return nothing
    is_raman =
        haskey(node, "detuning") || haskey(node, "delta") ||
        get(node, "_kind", "") == "raman"
    is_raman || return nothing
    mw = Float64(node["power_mw"])
    node["Omega"] = "$(rabi_mw_to_rad_s(mw, calib.microwave)) rad/s"
    delete!(node, "power_mw")
end

# --- One-shot wrapper ---

# --- Time-interpolated calibration history (Phase 5.5 / Scenario #68) ---

"""
A series of dated `CalibrationSet` snapshots used to capture week-to-week
hardware drift. `dates` and `entries` are parallel vectors of equal length;
`dates` must be strictly increasing.
"""
struct CalibrationHistory
    dates::Vector{Date}
    entries::Vector{CalibrationSet}
    function CalibrationHistory(dates::Vector{Date}, entries::Vector{CalibrationSet})
        length(dates) == length(entries) ||
            throw(ArgumentError("dates and entries must have the same length"))
        length(dates) >= 1 || throw(ArgumentError("calibration history is empty"))
        issorted(dates) || throw(ArgumentError("calibration dates must be sorted ascending"))
        new(dates, entries)
    end
end

"""
    load_calibration_csv(path) -> CalibrationHistory

Load a drift table from CSV (Excel-friendly). Expected columns (header
row required):

    date, coil_strong_gauss_per_mv, coil_strong_gauss_offset,
    coil_weak_gauss_per_mv, coil_weak_gauss_offset,
    fort_x_hz, fort_y_hz, fort_z_hz,
    microwave_rad_per_s_per_mw

Missing columns default to 0. Date format: YYYY-MM-DD.
Comma- or tab-separated; auto-detected.
"""
function load_calibration_csv(path::AbstractString)
    text = read(String(path), String)
    lines = filter(!isempty, strip.(split(text, '\n')))
    isempty(lines) && throw(ArgumentError("calibration CSV $path is empty"))
    sep = occursin('\t', lines[1]) ? '\t' : ','
    header = String.(strip.(split(lines[1], sep)))
    col(name) =
        let i = findfirst(==(name), header);
            i === nothing ? nothing : i;
        end

    dates = Date[]
    entries = CalibrationSet[]
    @inbounds for line in lines[2:end]
        startswith(line, "#") && continue
        cells = String.(strip.(split(line, sep)))
        length(cells) == length(header) || continue
        i_date = col("date")
        i_date === nothing && throw(ArgumentError("CSV needs a `date` column"))
        push!(dates, Date(cells[i_date]))
        getf(name, default=0.0) =
            let i = col(name)
                i === nothing || isempty(cells[i]) ? default : parse(Float64, cells[i])
            end
        cs_strong = CoilCalibration(
            getf("coil_strong_gauss_per_mv"),
            getf("coil_strong_gauss_offset"),
            (-Inf, Inf),
        )
        cs_weak = CoilCalibration(
            getf("coil_weak_gauss_per_mv"),
            getf("coil_weak_gauss_offset"),
            (-Inf, Inf),
        )
        fort = FORTCalibration(
            (getf("fort_x_hz"), getf("fort_y_hz"), getf("fort_z_hz")),
            (0.0, 0.0, 0.0),
        )
        mw = RabiCalibration(getf("microwave_rad_per_s_per_mw"))
        push!(
            entries,
            CalibrationSet(
                epoch="csv_row",
                date=cells[i_date],
                coil_strong=cs_strong,
                coil_weak=cs_weak,
                fort=fort,
                microwave=mw,
            ),
        )
    end
    perm = sortperm(dates)
    CalibrationHistory(dates[perm], entries[perm])
end

function load_calibration_history(path::AbstractString)
    raw = YAML.load_file(String(path))
    root = haskey(raw, "calibration_history") ? raw["calibration_history"] : raw
    root isa AbstractVector ||
        throw(ArgumentError("calibration_history must be a list of dated entries"))
    dates = Date[]
    entries = CalibrationSet[]
    for entry in root
        entry isa Dict || throw(ArgumentError("calibration_history entry must be a Dict"))
        haskey(entry, "date") || throw(ArgumentError("calibration_history entry needs `date`"))
        push!(dates, Date(String(entry["date"])))
        push!(entries, _calibration_from_dict(entry))
    end
    perm = sortperm(dates)
    CalibrationHistory(dates[perm], entries[perm])
end

"""
    interpolate_calibration(history, target_date) -> CalibrationSet

Linearly interpolate per-field between the two history entries that bracket
`target_date`. Outside the range we clamp to the nearest endpoint (no
extrapolation — drift outside the measured window is unsafe).
"""
function interpolate_calibration(hist::CalibrationHistory, target::Date)
    n = length(hist.dates)
    if target <= hist.dates[1]
        return _stamped(hist.entries[1], target)
    elseif target >= hist.dates[end]
        return _stamped(hist.entries[end], target)
    end
    # Find the bracket [i, i+1]
    i = searchsortedlast(hist.dates, target)
    d_lo = hist.dates[i];
    d_hi = hist.dates[i + 1]
    a = (Float64((target - d_lo).value)) / Float64((d_hi - d_lo).value)
    lo = hist.entries[i];
    hi = hist.entries[i + 1]
    interp = CalibrationSet(;
        epoch="interp[$(d_lo)..$(d_hi) @ $(target)]",
        date=string(target),
        coil_strong=_interp_coil(lo.coil_strong, hi.coil_strong, a),
        coil_weak=_interp_coil(lo.coil_weak, hi.coil_weak, a),
        fort=_interp_fort(lo.fort, hi.fort, a),
        microwave=RabiCalibration(
            (1 - a) * lo.microwave.rad_per_s_per_mw + a * hi.microwave.rad_per_s_per_mw),
    )
    interp
end

function _stamped(cs::CalibrationSet, target::Date)
    CalibrationSet(;
        epoch="$(cs.epoch) (clamped to $(target))",
        date=string(target),
        coil_strong=cs.coil_strong, coil_weak=cs.coil_weak,
        fort=cs.fort, microwave=cs.microwave,
    )
end

function _interp_coil(a_c::CoilCalibration, b_c::CoilCalibration, a::Float64)
    CoilCalibration(
        (1 - a) * a_c.gauss_per_mv + a * b_c.gauss_per_mv,
        (1 - a) * a_c.gauss_offset + a * b_c.gauss_offset,
        (max(a_c.valid_range_mv[1], b_c.valid_range_mv[1]),
            min(a_c.valid_range_mv[2], b_c.valid_range_mv[2])),
    )
end

function _interp_fort(a_f::FORTCalibration, b_f::FORTCalibration, a::Float64)
    FORTCalibration(
        ntuple(i -> (1 - a) * a_f.sqrt_coeffs_hz[i] + a * b_f.sqrt_coeffs_hz[i], 3),
        ntuple(i -> (1 - a) * a_f.offsets_hz[i] + a * b_f.offsets_hz[i], 3),
    )
end

"""
    run_yaml_calibrated(path; calibration_path=nothing, base_dir=pwd(), kwargs...)

Load a YAML config file, apply calibration, and delegate to `run_yaml`.

Calibration source precedence:
1. explicit `calibration_path` argument
2. top-level `calibration:` key embedded in `path`'s YAML
3. `DEFAULT_CALIBRATION` (placeholder — warns).
"""
function run_yaml_calibrated(path::AbstractString;
    calibration_path::Union{Nothing, AbstractString}=nothing,
    base_dir::AbstractString=pwd(),
    kwargs...)
    raw = YAML.load_file(String(path))
    calib = if calibration_path !== nothing
        load_calibration(String(calibration_path))
    elseif haskey(raw, "calibration") && raw["calibration"] isa Dict
        _calibration_from_dict(pop!(raw, "calibration"))
    else
        @warn "run_yaml_calibrated: no calibration provided — using DEFAULT_CALIBRATION placeholder"
        DEFAULT_CALIBRATION
    end
    apply_calibration!(raw, calib)
    tmpfile = tempname() * ".yaml"
    YAML.write_file(tmpfile, raw)
    try
        run_yaml(tmpfile; base_dir=base_dir, kwargs...)
    finally
        rm(tmpfile; force=true)
    end
end

# Dashboard compute helpers + run metadata
#
# Trilinear upsampling kernel + run-metadata readers.
# Extracted from dashboard/compute.jl in the 2026-05-09 refactor.

function _trilinear_upsample(data::Array{Float64, 3}, target_n::Int)
    nx, ny, nz = size(data)
    out = Array{Float64, 3}(undef, target_n, target_n, target_n)
    @inbounds for iz in 1:target_n
        fz = 1.0 + (iz - 1) * (nz - 1) / (target_n - 1)
        z0 = clamp(floor(Int, fz), 1, nz - 1)
        z1 = z0 + 1
        wz = fz - z0
        for iy in 1:target_n
            fy = 1.0 + (iy - 1) * (ny - 1) / (target_n - 1)
            y0 = clamp(floor(Int, fy), 1, ny - 1)
            y1 = y0 + 1
            wy = fy - y0
            for ix in 1:target_n
                fx = 1.0 + (ix - 1) * (nx - 1) / (target_n - 1)
                x0 = clamp(floor(Int, fx), 1, nx - 1)
                x1 = x0 + 1
                wx = fx - x0
                c000 = data[x0, y0, z0];
                c100 = data[x1, y0, z0]
                c010 = data[x0, y1, z0];
                c110 = data[x1, y1, z0]
                c001 = data[x0, y0, z1];
                c101 = data[x1, y0, z1]
                c011 = data[x0, y1, z1];
                c111 = data[x1, y1, z1]
                c00 = c000 * (1 - wx) + c100 * wx
                c01 = c001 * (1 - wx) + c101 * wx
                c10 = c010 * (1 - wx) + c110 * wx
                c11 = c011 * (1 - wx) + c111 * wx
                c0 = c00 * (1 - wy) + c10 * wy
                c1 = c01 * (1 - wy) + c11 * wy
                out[ix, iy, iz] = c0 * (1 - wz) + c1 * wz
            end
        end
    end
    out
end

"""
Compute 3D density for each m-component.
Uses trilinear interpolation to produce smooth output at `target_n` resolution.
Top `max_components` by population are included, plus total.
"""

function _read_box_size(jld2_path::String)
    # Embedded dataset (preferred)
    try
        d = _with_jld_handle(jld2_path) do f
            haskey(f, "grid_box_size") ? f["grid_box_size"] : nothing
        end
        if d !== nothing
            return d isa Vector ? Float64.(d) : Float64[Float64(d)]
        end
    catch
        # fall through
    end
    # Sibling config.yaml fallback
    config_path = joinpath(dirname(jld2_path), "config.yaml")
    isfile(config_path) || return nothing
    try
        data = YAML.load_file(config_path)
        pipe = get(data, "pipeline", [])
        isempty(pipe) && return nothing
        gs = first(values(pipe[1]))
        g = get(gs, "grid", nothing)
        g === nothing && return nothing
        box_raw = g isa Dict ? get(g, "box", get(g, "box_size", nothing)) : nothing
        box_raw === nothing && return nothing
        box_raw isa Vector ? Float64.(box_raw) : Float64[Float64(box_raw)]
    catch
        nothing
    end
end

"""
    RunMetadata(box_size, n_points, atom_name, omega_ref, n_atoms)

Run-level geometry + physics constants extracted once and reused across
endpoint handlers. Resolved by `load_run_metadata(jld2_path)` which tries
the embedded JLD2 datasets first and falls back to the sibling
config.yaml. All fields except `box_size` may be `nothing` when the
source file doesn't carry the data (older runs / GS-only files).
"""
struct RunMetadata
    box_size::NTuple{3, Float64}
    n_points::Union{Nothing, NTuple{3, Int}}
    atom_name::Union{Nothing, String}
    omega_ref::Union{Nothing, Float64}
    n_atoms::Union{Nothing, Int}
end

function load_run_metadata(jld2_path::String)
    box_vec = _read_box_size(jld2_path)
    if box_vec === nothing || length(box_vec) < 3
        throw(
            ArgumentError(
                "Cannot resolve box_size for $(jld2_path): missing " *
                "`grid_box_size` in the JLD2 file and no usable grid.box " *
                "in config.yaml.",
            ),
        )
    end
    box = NTuple{3, Float64}((Float64(box_vec[1]), Float64(box_vec[2]), Float64(box_vec[3])))

    n_points = try
        n_vec = _with_jld_handle(jld2_path) do f
            haskey(f, "grid_n_points") ? f["grid_n_points"] : nothing
        end
        if n_vec === nothing
            nothing
        else
            NTuple{3, Int}((Int(n_vec[1]), Int(n_vec[2]), Int(n_vec[3])))
        end
    catch
        nothing
    end

    atom_name, omega_ref, n_atoms = _read_run_physics(jld2_path)
    RunMetadata(box, n_points, atom_name, omega_ref, n_atoms)
end

"""Tuple `(atom_name, omega_ref, n_atoms)` from JLD2 first then YAML."""
function _read_run_physics(jld2_path::String)
    # JLD2 may carry these inside `units/` group or `env/`
    try
        out = _with_jld_handle(jld2_path) do f
            atom = haskey(f, "units/atom") ? String(f["units/atom"]) : nothing
            omega = if haskey(f, "units/omega_ref_rad_s")
                Float64(f["units/omega_ref_rad_s"])
            else
                nothing
            end
            n = haskey(f, "units/N_atoms") ? Int(f["units/N_atoms"]) : nothing
            (atom, omega, n)
        end
        return out
    catch
        # fall through
    end
    # YAML fallback
    config_path = joinpath(dirname(jld2_path), "config.yaml")
    isfile(config_path) || return (nothing, nothing, nothing)
    try
        data = YAML.load_file(config_path)
        pipe = get(data, "pipeline", [])
        isempty(pipe) && return (nothing, nothing, nothing)
        gs = first(values(pipe[1]))
        atom = haskey(gs, "atom") ? String(gs["atom"]) : nothing
        inter = get(gs, "interactions", Dict())
        omega = inter isa Dict && haskey(inter, "omega_ref") ? Float64(inter["omega_ref"]) : nothing
        n = inter isa Dict && haskey(inter, "N_atoms") ? Int(inter["N_atoms"]) : nothing
        (atom, omega, n)
    catch
        (nothing, nothing, nothing)
    end
end

"""
Compute column densities (integrated along `axis`) for each m-component.
Returns Dict with m_values, densities (list of 2D arrays), grid info.
"""

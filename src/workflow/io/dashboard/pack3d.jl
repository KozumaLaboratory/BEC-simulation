# --- 3D density / phase / vorticity / vector / coherence binary packers ---

# Standard 3D volume binary: 24-byte header (nx, ny, nz, n_comp, F, component)
# + normalized per-component populations + the Float32 volume payload. Shared
# by density3d / phase3d / vorticity3d / rotated-density so the frontend parses
# one layout. `data` may be a flat Vector or an n_pts-shaped Array — `write`
# serializes column-major either way.
function _pack_3d_volume(psi, n_comp, ndim, n_pts, F, component,
    data::AbstractArray{Float32})
    pops = Float32[
        Float32(sum(abs2, view(psi, _component_slice(ndim, n_pts, m)...); init=0.0))
        for m in 1:n_comp
    ]
    pops ./= max(sum(pops), 1.0f-30)
    N = prod(n_pts)
    buf = IOBuffer(; sizehint=24 + n_comp * 4 + N * 4)
    write(buf, Int32(n_pts[1]), Int32(n_pts[2]), Int32(n_pts[3]))
    write(buf, Int32(n_comp), Int32(F), Int32(component))
    write(buf, pops)
    write(buf, data)
    take!(buf)
end

function _compute_3d_density_binary(psi, n_comp, ndim, n_pts, F; component::Int=0)
    ndim == 3 || throw(ArgumentError("3D density requires 3D data"))
    _pack_3d_binary(psi, n_comp, ndim, n_pts, F, component)
end

"""
3D vorticity magnitude |∇×v_s| as Float32 volume. Matches density3d_bin's
header layout so the frontend can reuse the same parser. Breathing/radial
modes have ∇×v = 0, so peaks in this field isolate the rotational part of
the flow — vortex cores show up cleanly even when the mass current is
dominated by a radial-inflow component.
"""
function _compute_3d_vorticity_binary(psi, n_comp, ndim, n_pts, F, box_size)
    ndim == 3 || throw(ArgumentError("3D vorticity requires 3D data"))
    plans, grid = _get_plans_and_grid(n_pts, box_size)
    # v = j/n explodes where n → 0 (trap vacuum), and ∇×v inherits those
    # spurious peaks. Scale the density cutoff to the actual cloud: 1% of
    # peak |ψ|² masks out everything outside the Thomas-Fermi radius without
    # touching the physical vortex-core structure (where n is small but the
    # j ≈ nv compensates the denominator).
    total_n = sum(m -> Float64.(abs2.(view(psi, _component_slice(ndim, n_pts, m)...))), 1:n_comp)
    n_peak = maximum(total_n)
    cutoff = max(1e-8, 1e-2 * n_peak)
    ωx, ωy, ωz = superfluid_vorticity(psi, grid, plans; density_cutoff=cutoff)

    N = prod(n_pts)
    # Also zero the output outside the cloud to be defensive; the cutoff
    # above zeroes v, but numerical ∇ can still pick up edge gradients.
    mag = Vector{Float32}(undef, N)
    total_flat = vec(total_n)
    @inbounds for i in 1:N
        if total_flat[i] < cutoff
            mag[i] = 0.0f0
        else
            a = ωx[i];
            b = ωy[i];
            c = ωz[i]
            mag[i] = Float32(sqrt(a*a + b*b + c*c))
        end
    end

    _pack_3d_volume(psi, n_comp, ndim, n_pts, F, 0, mag)
end

"""
3D per-component phase arg(ψ_m) as Float32 volume. Matches density3d_bin's
header layout so the frontend can reuse the same parser. Requires a
specific component (`component >= 1`); the total spinor has no scalar phase.
"""
function _compute_3d_phase_binary(psi, n_comp, ndim, n_pts, F; component::Int=0)
    ndim == 3 || throw(ArgumentError("3D phase requires 3D data"))
    component >= 1 || throw(ArgumentError("phase3d requires component >= 1 (per-m only)"))
    c = clamp(component, 1, n_comp)

    psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
    phase = zeros(Float32, n_pts...)
    @inbounds for i in eachindex(psi_c)
        phase[i] = Float32(angle(psi_c[i]))
    end

    _pack_3d_volume(psi, n_comp, ndim, n_pts, F, c, phase)
end

"""
Compute rotated 3D density: rotate quantization axis by angle_deg around y, then extract component.
Optimized: only computes the single requested component (not full matrix multiply).
Total density (component=0) is rotation-invariant, so skip rotation entirely.
"""
function _compute_rotated_3d_density_binary(
    psi, n_comp, ndim, n_pts, F; angle_deg::Float64=0.0, component::Int=0
)
    ndim == 3 || throw(ArgumentError("3D density requires 3D data"))
    if abs(angle_deg) < 0.01 || component == 0
        return _pack_3d_binary(psi, n_comp, ndim, n_pts, F, component)
    end
    beta = angle_deg * π / 180
    Fy = spin_matrices(F).Fy
    R = exp(-im * beta * Matrix{ComplexF64}(Fy))

    c = clamp(component, 1, n_comp)
    N = prod(n_pts)
    # ψ'_c(r) = Σ_m R[c,m] * ψ_m(r) — only one row of R needed
    # Match precision so the BLAS matmul stays on the fast path; psi may
    # be ComplexF32 (snapshot default) and R is ComplexF64.
    R_row = convert(Vector{eltype(psi)}, R[c, :])
    psi_flat = reshape(psi, N, n_comp)
    psi_c_rot = psi_flat * conj.(R_row)  # (N,D) * (D,) → (N,) complex
    dens = Float32.(abs2.(psi_c_rot))

    _pack_3d_volume(psi, n_comp, ndim, n_pts, F, component, dens)
end

function _pack_3d_binary(psi, n_comp, ndim, n_pts, F, component)
    # Use 3D array matching psi_c shape (eachindex returns CartesianIndices for SubArray)
    dens = zeros(Float32, n_pts...)
    if component == 0
        for c in 1:n_comp
            psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
            @inbounds for i in eachindex(psi_c)
                dens[i] += Float32(abs2(psi_c[i]))
            end
        end
    else
        c = clamp(component, 1, n_comp)
        psi_c = view(psi, _component_slice(ndim, n_pts, c)...)
        @inbounds for i in eachindex(psi_c)
            dens[i] = Float32(abs2(psi_c[i]))
        end
    end

    _pack_3d_volume(psi, n_comp, ndim, n_pts, F, component, vec(dens))
end

"""
Compute coherence matrix C_{mn}(x,y) = Σ_z ψ_m*(x,y,z) ψ_n(x,y,z) for quantization axis rotation.
"""
function _compute_coherence_matrix_binary(psi, n_comp, ndim, n_pts, F, axis::Int=3)
    ndim == 3 || throw(ArgumentError("Coherence matrix requires 3D data"))
    axis = clamp(axis, 1, 3)

    remaining = [i for i in 1:3 if i != axis]
    n1, n2 = n_pts[remaining[1]], n_pts[remaining[2]]

    buf = IOBuffer()
    # Header
    write(buf, Int32(n1), Int32(n2), Int32(n_comp), Int32(F), Int32(axis))

    # Compute and write upper triangle
    for m in 1:n_comp
        psi_m = view(psi, _component_slice(ndim, n_pts, m)...)
        for n in m:n_comp
            psi_n = view(psi, _component_slice(ndim, n_pts, n)...)
            # C_{mn}(x,y) = Σ_axis conj(ψ_m) * ψ_n
            c_mn = dropdims(sum(conj.(psi_m) .* psi_n; dims=axis); dims=axis)
            for val in vec(c_mn)
                write(buf, Float32(real(val)), Float32(imag(val)))
            end
        end
    end

    take!(buf)
end

# --- Vector field (current / spin_density / velocity) binary API ---

const _vector3d_plans_cache = Dict{NTuple{3, Int}, Tuple{FFTPlans, Grid{3}}}()

"""Compatibility shim: returns just the `box_size` tuple. Prefer
`load_run_metadata(jld2_path).box_size` in new code."""
_load_box_size(jld2_path::String) = load_run_metadata(jld2_path).box_size

function _get_plans_and_grid(n_pts::NTuple{3, Int}, box_size::NTuple{3, Float64})
    get!(_vector3d_plans_cache, n_pts) do
        grid = make_grid(GridConfig(n_pts, box_size))
        plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
        (plans, grid)
    end
end

function _compute_vector3d_binary(psi, n_comp, ndim, n_pts, F, box_size;
    field::Symbol=:current, stride::Int=2)
    stride = max(1, stride)
    sub_idx = ntuple(d -> 1:stride:n_pts[d], 3)
    n_sub = ntuple(d -> length(sub_idx[d]), 3)

    if field === :spin_density
        sm = spin_matrices(F)
        vx, vy, vz = spin_density_vector(psi, sm, 3)
    else
        plans, grid = _get_plans_and_grid(n_pts, box_size)
        if field === :current
            vx, vy, vz = probability_current(psi, grid, plans)
        elseif field === :velocity
            vx, vy, vz = superfluid_velocity(psi, grid, plans)
        else
            throw(ArgumentError("Unknown vector field: $field"))
        end
    end

    N_sub = prod(n_sub)
    buf = IOBuffer(; sizehint=28 + 4 * 4 * N_sub)
    write(buf, Int32(n_sub[1]), Int32(n_sub[2]), Int32(n_sub[3]))
    write(buf, Int32(stride), Int32(0), Int32(0), Int32(0))

    for iz in sub_idx[3], iy in sub_idx[2], ix in sub_idx[1]
        ux = Float32(vx[ix, iy, iz])
        uy = Float32(vy[ix, iy, iz])
        uz = Float32(vz[ix, iy, iz])
        mag = sqrt(ux^2 + uy^2 + uz^2)
        write(buf, ux, uy, uz, mag)
    end

    take!(buf)
end

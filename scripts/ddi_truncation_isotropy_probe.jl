# Diagnostic (B: physics-fidelity): does the spherically-truncated DDI kernel
# (Tier A, Ronen cutoff) remove the lattice/periodic-image anisotropy of the
# un-padded convolution at fixed resolution?
#
# Run:
#   julia --project=. scripts/ddi_truncation_isotropy_probe.jl
#
# Method. Put an isotropic, z-polarized Gaussian spin density f_z(r) = exp(-r²/2σ²)
# (f_x=f_y=0) into the box and compute the dipolar field Φ_z three ways:
#   • un-padded periodic convolution, BARE kernel          (production default)
#   • un-padded periodic convolution, TRUNCATED kernel R=L/2 (Tier A)
#   • a large-box (3×) TRUNCATED-kernel reference          ≈ free space
# The reference is image-free and well-resolved, so its Φ_z is azimuthally
# symmetric about z (depends only on cylindrical ρ and z). We report, per
# resolution n ∈ {32,48,64}:
#   err_∞   = max interior |Φ_z − Φ_ref| / max|Φ_ref|
#   C4      = explicit axis-vs-diagonal anisotropy of Φ_z on a fixed ρ-ring
#             (max|Φ along x̂ − Φ along (x̂+ŷ)/√2| / |Φ|), interpolated from the
#             field — the deviation from *continuous* rotation symmetry that a
#             discrete lattice test cannot see.
#
# Expectation if DDI lattice anisotropy is the culprit: the BARE column's C4 and
# err_∞ stay sizeable and shrink only slowly with n, while the TRUNCATED column
# is already small at n=32 and ~flat in n (spectral accuracy at fixed grid).

using SpinorBEC
using Printf
using LinearAlgebra

const σ = 1.5            # Gaussian width (well inside the box)
const L = 12.0           # physical box length
const REF_FACTOR = 3     # reference box = REF_FACTOR × L (images negligible)
const REF_N = 144        # reference resolution (dx_ref = REF_FACTOR*L/REF_N)

"Isotropic z-polarized Gaussian spin density on `grid` (m=-F component)."
function gaussian_zpol(grid)
    n = grid.config.n_points
    D = 3                                   # spin-1 probe (F=1, D=3)
    psi = zeros(ComplexF64, n..., D)
    x, y, z = grid.x[1], grid.x[2], grid.x[3]
    @inbounds for I in CartesianIndices(n)
        r2 = x[I[1]]^2 + y[I[2]]^2 + z[I[3]]^2
        psi[I, D] = exp(-r2 / (2σ^2))
    end
    psi
end

"Φ_z(r) from the un-padded periodic convolution with the given kernel."
function phi_z(grid; trunc_radius)
    npts = grid.config.n_points
    sm = spin_matrices(1)
    ddi = make_ddi_params(grid, Eu151; trunc_radius)
    bufs = make_ddi_buffers(npts)
    psi = gaussian_zpol(grid)
    SpinorBEC._compute_and_convolve_ddi!(psi, sm, ddi, bufs, Val(3), 3, npts)
    copy(bufs.Phi_z)
end

"Trilinear sample of field `A` on `grid` at physical point (px,py,pz)."
function sample(A, grid, px, py, pz)
    x, y, z = grid.x[1], grid.x[2], grid.x[3]
    dx = grid.dx
    fx = (px - x[1]) / dx[1] + 1
    fy = (py - y[1]) / dx[2] + 1
    fz = (pz - z[1]) / dx[3] + 1
    n = grid.config.n_points
    i0 = clamp(floor(Int, fx), 1, n[1] - 1); tx = fx - i0
    j0 = clamp(floor(Int, fy), 1, n[2] - 1); ty = fy - j0
    k0 = clamp(floor(Int, fz), 1, n[3] - 1); tz = fz - k0
    c(a, b, t) = a * (1 - t) + b * t
    c00 = c(A[i0, j0, k0], A[i0 + 1, j0, k0], tx)
    c10 = c(A[i0, j0 + 1, k0], A[i0 + 1, j0 + 1, k0], tx)
    c01 = c(A[i0, j0, k0 + 1], A[i0 + 1, j0, k0 + 1], tx)
    c11 = c(A[i0, j0 + 1, k0 + 1], A[i0 + 1, j0 + 1, k0 + 1], tx)
    c(c(c00, c10, ty), c(c01, c11, ty), tz)
end

"Axis-vs-diagonal anisotropy on a ρ-ring at z=0 (continuous-rotation deviation)."
function c4_anisotropy(A, grid)
    ρ = 3.0
    z0 = 0.0
    axis = sample(A, grid, ρ, 0.0, z0)
    diag = sample(A, grid, ρ / sqrt(2), ρ / sqrt(2), z0)
    scale = max(abs(axis), abs(diag), eps())
    abs(axis - diag) / scale
end

"Max interior relative error of Φ_z vs the resampled reference field."
function interior_err(A, grid, ref, refgrid)
    n = grid.config.n_points
    lo = (n[1] ÷ 4, n[2] ÷ 4, n[3] ÷ 4)
    hi = (3n[1] ÷ 4, 3n[2] ÷ 4, 3n[3] ÷ 4)
    x, y, z = grid.x[1], grid.x[2], grid.x[3]
    num = 0.0; den = 0.0
    @inbounds for k in lo[3]:hi[3], j in lo[2]:hi[2], i in lo[1]:hi[1]
        r = sample(ref, refgrid, x[i], y[j], z[k])
        num = max(num, abs(A[i, j, k] - r))
        den = max(den, abs(r))
    end
    num / max(den, eps())
end

function main()
    println("DDI truncation isotropy probe  (σ=$σ, L=$L, ref=$(REF_FACTOR)L @ $REF_N³)\n")

    refgrid = make_grid(GridConfig((REF_N, REF_N, REF_N),
        (REF_FACTOR * L, REF_FACTOR * L, REF_FACTOR * L)))
    ref = phi_z(refgrid; trunc_radius=REF_FACTOR * L / 2)
    println("reference: large-box truncated kernel built ($(REF_N)³)\n")

    @printf("%4s | %-22s | %-22s\n", "n", "BARE kernel", "TRUNCATED R=L/2")
    @printf("%4s | %10s %10s | %10s %10s\n", "", "C4", "err_inf", "C4", "err_inf")
    println("-"^62)
    for n in (32, 48, 64)
        grid = make_grid(GridConfig((n, n, n), (L, L, L)))
        Φb = phi_z(grid; trunc_radius=nothing)
        Φt = phi_z(grid; trunc_radius=L / 2)
        c4b = c4_anisotropy(Φb, grid); eb = interior_err(Φb, grid, ref, refgrid)
        c4t = c4_anisotropy(Φt, grid); et = interior_err(Φt, grid, ref, refgrid)
        @printf("%4d | %10.2e %10.2e | %10.2e %10.2e\n", n, c4b, eb, c4t, et)
    end
    println("\nIf TRUNCATED C4/err_inf are small and flat in n while BARE shrinks")
    println("slowly, the residual anisotropy is the DDI lattice/image artifact and")
    println("Tier A fixes it at fixed resolution (B: physics-fidelity).")
end

main()

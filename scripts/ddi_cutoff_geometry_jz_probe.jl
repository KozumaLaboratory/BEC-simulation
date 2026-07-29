# Diagnostic (A: code correctness): how much of the DDI kernel's J_z violation is
# fixable by CUTOFF GEOMETRY, and would a CYLINDRICAL cutoff buy anything the
# spherical cutoff + anisotropic zero-padding cannot already express?
#
# At B = 0 in an axially symmetric trap the exact free-space dipolar interaction
# conserves J_z = L_z + <F_z>. The DDI is covariant under a SIMULTANEOUS rotation
# of spin and space about z, and every other Hamiltonian term commutes with J_z on
# its own, so the instantaneous violation rate
#
#     tau = d<J_z>/dt = -2 Im <H_DDI psi | J_z psi>,     H_DDI psi = (Phi . F) psi
#
# is ENTIRELY the DDI kernel's error, readable from a single state with no time
# stepping (seconds, versus the 40-minute dynamic A/B).
#
# Two error sources are mixed into tau:
#   (i)  periodic images / truncated kernel — cutoff + padding fix it, FLAT in n
#   (ii) grid roughness (dx)                — falls as dx^2, no cutoff can help
# Refining n at fixed box separates them: (i) plateaus, (ii) drops.
#
# Reported as tau / |E_DDI| (dimensionless — hbar = 1, so both are energies).
#
# The probe state is smooth by construction, which pushes channel (ii) far below
# the kernel error; the n-refinement column is what confirms that rather than
# assumes it.
#
# Dealias is left at its default (OFF). The default Orszag mask is a per-axis
# index cutoff — a CUBE in k-space, which is only C4-symmetric about z and would
# inject its own J_z violation on top of the kernel's.
#
# Run:
#   julia --project=. scripts/ddi_cutoff_geometry_jz_probe.jl

using SpinorBEC
using FFTW, LinearAlgebra, Printf, Random

const ATOM = Eu151
const N_ATOMS = 30_000
const OMEGA_REF = 628.3
const SUPPORT_SIGMAS = 4.0     # density support half-extent taken as 4 sigma
const PAD_POINT_CAP = 4_000_000  # skip padded configs above this many points

"""
Generic smooth probe state: a Gaussian envelope times a few box-commensurate
Fourier modes with fixed pseudo-random coefficients, independent per spin
component.

The obvious states are all BLIND to this diagnostic — measured, not argued
(`Q_xx x 1.3` is a kernel that cannot possibly conserve J_z, so any state that
does not respond to it is disqualified):

    uniform spinor x scalar envelope, elliptical   ->  4e-16   blind
    azimuthal spin winding, round envelope         ->  1e-17   blind
    azimuthal spin winding, elliptical envelope    ->  7e-18   blind
    generic smooth random (this one)               ->  9e-2    responds 4.5x

Two structural reasons. A state with a spatially UNIFORM spin direction makes
<H psi|J_z psi> real term by term, so the imaginary part it is built from is
identically zero. And any J_z EIGENSTATE gives tau = -2 j Im<H psi|psi> = 0
whatever the kernel, which disqualifies the clean spin-texture states — they are
exactly the ones a joint spin-space rotation leaves invariant. A generic state
has neither property.

Mode wavevectors are 2*pi*j/L_d per axis, so the state is the same physical
function at every resolution and the n-refinement column means what it says.

tau vanishes for the exact free-space kernel for ANY state (the DDI energy is
invariant under the joint spin-space rotation, so Noether applies along the GP
flow), so a generic state sharpens the diagnostic without weakening the null.
"""
function probe_state(grid, sm, sigma; seed=20260729, n_modes=1)
    n = grid.config.n_points
    D = size(sm.Fz, 1)
    box = grid.config.box_size
    rng = MersenneTwister(seed)
    w = 2 * n_modes + 1
    A = randn(rng, ComplexF64, w, w, w, D)
    psi = zeros(ComplexF64, n..., D)
    x, y, z = grid.x[1], grid.x[2], grid.x[3]
    @inbounds for I in CartesianIndices(n)
        X, Y, Z = x[I[1]], y[I[2]], z[I[3]]
        env = exp(-X^2 / (2 * sigma[1]^2) - Y^2 / (2 * sigma[2]^2) - Z^2 / (2 * sigma[3]^2))
        for c in 1:D
            s = zero(ComplexF64)
            for d in 1:w, b in 1:w, a in 1:w
                ph = (a - n_modes - 1) * X / box[1] + (b - n_modes - 1) * Y / box[2] +
                     (d - n_modes - 1) * Z / box[3]
                s += A[a, b, d, c] * cis(2π * ph)
            end
            psi[I, c] = env * s
        end
    end
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    psi
end

"L_z psi = -i (x d_y - y d_x) psi, spectrally, per spin component."
function lz_psi(psi, grid)
    n = grid.config.n_points
    D = size(psi, 4)
    dx = grid.dx
    kx = collect(fftfreq(n[1], 2π / dx[1]))
    ky = collect(fftfreq(n[2], 2π / dx[2]))
    x, y = grid.x[1], grid.x[2]
    out = similar(psi)
    for c in 1:D
        u = @view psi[:, :, :, c]
        ux = ifft(im .* reshape(kx, :, 1, 1) .* fft(u, 1), 1)
        uy = ifft(im .* reshape(ky, 1, :, 1) .* fft(u, 2), 2)
        @inbounds for I in CartesianIndices(n)
            out[I, c] = -im * (x[I[1]] * uy[I] - y[I[2]] * ux[I])
        end
    end
    out
end

"J_z psi = L_z psi + F_z psi."
function jz_psi(psi, grid, sm)
    out = lz_psi(psi, grid)
    mz = diag(Matrix(sm.Fz))
    D = size(psi, 4)
    @inbounds for c in 1:D
        @views out[:, :, :, c] .+= mz[c] .* psi[:, :, :, c]
    end
    out
end

"H_DDI psi = (Phi_x F_x + Phi_y F_y + Phi_z F_z) psi — the mean-field operator."
function hddi_psi(psi, sm, phi)
    n = size(psi)[1:3]
    D = size(psi, 4)
    Fx, Fy, Fz = Matrix(sm.Fx), Matrix(sm.Fy), Matrix(sm.Fz)
    px, py, pz = phi
    out = zeros(ComplexF64, size(psi))
    @inbounds for I in CartesianIndices(n)
        for cp in 1:D, c in 1:D
            m = px[I] * Fx[c, cp] + py[I] * Fy[c, cp] + pz[I] * Fz[c, cp]
            iszero(m) && continue
            out[I, c] += m * psi[I, cp]
        end
    end
    out
end

struct Cfg
    name::String
    trunc::Union{Nothing, Float64}
    pad::Union{Nothing, NTuple{3, Float64}}
    corrupt::Float64        # POSITIVE CONTROL: scale Q_xx by this (1.0 = untouched)
end
Cfg(name, trunc, pad) = Cfg(name, trunc, pad, 1.0)

"Dipolar field Phi and spin density F for one cutoff/padding configuration."
function ddi_fields(grid, sm, psi, cfg, c_dd)
    n_pts = grid.config.n_points
    D = size(psi, 4)
    ddi = make_ddi_params(grid, ATOM; c_dd, trunc_radius=cfg.trunc)
    # Positive control. Scaling Q_xx alone destroys the x<->y symmetry of the
    # kernel, so it CANNOT be covariant under rotation about z and MUST produce a
    # nonzero tau. If this row reads machine epsilon too, the meter is broken and
    # every null above it is uninterpretable.
    cfg.corrupt == 1.0 || (ddi.Q_xx .*= cfg.corrupt)
    if cfg.pad === nothing
        bufs = make_ddi_buffers(n_pts)
        SpinorBEC._compute_and_convolve_ddi!(psi, sm, ddi, bufs, Val(D), 3, n_pts)
        return ((bufs.Phi_x, bufs.Phi_y, bufs.Phi_z), (bufs.Fx_r, bufs.Fy_r, bufs.Fz_r))
    end
    ctx = make_ddi_padded(grid, ATOM; c_dd, trunc_radius=cfg.trunc, pad_factor=cfg.pad,
        fft_flags=FFTW.ESTIMATE)
    SpinorBEC._compute_and_convolve_ddi_padded!(psi, sm, ddi, ctx, Val(D), 3, n_pts)
    crop = CartesianIndices(n_pts)
    ((ctx.Phi_x_pad[crop], ctx.Phi_y_pad[crop], ctx.Phi_z_pad[crop]),
        (ctx.Fx_pad[crop], ctx.Fy_pad[crop], ctx.Fz_pad[crop]))
end

"""
tau / |E_DDI| and, against a free-space reference field, max relative field error.

The two metrics answer different questions and NEITHER is sufficient alone:

  tau  sees ROTATION COVARIANCE. The periodic image lattice is cubic and breaks
       it, which is what tau catches. But a spherical cutoff is exactly covariant
       at ANY radius, so a far-too-small R scores perfectly here while quietly
       deleting real interaction. A cylindrical cutoff is axially symmetric too,
       so tau cannot rank sphere against cylinder at all.

  err  sees MAGNITUDE. Comparing Phi to the free-space field catches a cutoff
       radius that is too small, which is the failure mode tau is blind to.

`ref_phi` must be the exact free-space field. No separate large-box build is
needed: a spherical cutoff at R >= (the support's own diameter) on a grid padded
to f_d >= 1 + R/L_d IS the free-space convolution, which is exactly the
"pad exact" configuration.
"""
function measure(grid, sm, psi, jzp, cfg, c_dd; ref_phi=nothing)
    dV = cell_volume(grid)
    phi, fdens = ddi_fields(grid, sm, psi, cfg, c_dd)
    hpsi = hddi_psi(psi, sm, phi)
    tau = -2 * imag(sum(conj(hpsi) .* jzp)) * dV
    e_ddi = 0.5 * sum(phi[1] .* fdens[1] .+ phi[2] .* fdens[2] .+ phi[3] .* fdens[3]) * dV
    err = if ref_phi === nothing
        NaN
    else
        num = maximum(max.(abs.(phi[1] .- ref_phi[1]), abs.(phi[2] .- ref_phi[2]),
            abs.(phi[3] .- ref_phi[3])))
        den = maximum(max.(abs.(ref_phi[1]), abs.(ref_phi[2]), abs.(ref_phi[3])))
        num / max(den, eps())
    end
    (tau=tau, e_ddi=e_ddi, ratio=abs(tau) / max(abs(e_ddi), eps()), err=err, phi=phi)
end

"""
Minimum zero-pad factors that make each cutoff shape EXACT, given a density
support of half-extents `a`. The truncation region must contain every pairwise
separation vector of the support, and the pad must be long enough to hold the
cutoff extent along each axis.

The support is an ELLIPSOID with semi-axes `a` (a Gaussian cloud), so its
self-difference is the same ellipsoid scaled by 2, and the smallest enclosing

    sphere:   R = 2 max(a_d)
    cylinder: rho_c = 2 max(a_x, a_y),  Z_c = 2 a_z

Treating the support as a BOX instead takes its corner, `R = 2|a|`, which
overestimates the sphere on every geometry and manufactures a spurious cylinder
saving even for a round cloud, where symmetry forces the two to be equal.

Padding then needs f_d = 1 + (cutoff extent along d) / L_d. Note the cylinder
sized to the cloud gives f_d = 2 on EVERY axis — a cylindrical cutoff matched to
the box is just plain 2x zero-padding, which `pad_factor: 2.0` already is.

The ratio of the two padded volumes is the entire cost case for a cylindrical
kernel: it is what the cylinder buys BEFORE paying for the quadrature and the
loss of rotation covariance.
"""
function pad_cost(box, a)
    R = 2 * maximum(a)
    rho_c = 2 * max(a[1], a[2])
    z_c = 2 * a[3]
    f_sph = ntuple(d -> 1 + R / box[d], 3)
    f_cyl = (1 + rho_c / box[1], 1 + rho_c / box[2], 1 + z_c / box[3])
    (R=R, rho_c=rho_c, z_c=z_c, f_sph=f_sph, f_cyl=f_cyl,
        saving=prod(f_sph) / prod(f_cyl))
end

function run_geometry(label, box, sigma, n_list)
    sm = spin_matrices(1)          # kernel geometry is F-independent; D=3 for speed
    c_dd = compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
    a = ntuple(d -> min(SUPPORT_SIGMAS * sigma[d], box[d] / 2), 3)
    cost = pad_cost(box, a)

    @printf("\n=== %s   box=%s  sigma=%s\n", label, box, sigma)
    @printf("    support half-extent a = (%.1f, %.1f, %.1f)\n", a...)
    @printf("    exact sphere   R=%.1f  -> pad (%.2f, %.2f, %.2f)  vol x%.1f\n",
        cost.R, cost.f_sph..., prod(cost.f_sph))
    @printf("    exact cylinder rho=%.1f Z=%.1f -> pad (%.2f, %.2f, %.2f)  vol x%.1f\n",
        cost.rho_c, cost.z_c, cost.f_cyl..., prod(cost.f_cyl))
    @printf("    >> cylinder would save %.2fx padded volume\n", cost.saving)

    # "sphere R=Lmin, pad 2" is the config that carries the whole cylinder case:
    # at plain 2x padding a spherical cutoff is capped at R <= Lmin, while a
    # cylinder at the SAME memory reaches rho_c = Lperp, Z_c = Lz and is exact.
    # Its field error against the free-space reference is therefore exactly what a
    # cylindrical kernel would buy at equal cost.
    ref = Cfg("sphere R=Rexact, pad exact (= free space)", cost.R, cost.f_sph)
    cfgs = [
        Cfg("bare, unpadded", nothing, nothing),
        Cfg("sphere R=Lmin/2, unpadded", minimum(box) / 2, nothing),
        # Padding with NO cutoff. Pushes the density images out but leaves the
        # kernel itself periodic on the doubled box, so a residual survives —
        # this is what `analysis/dipole_field.jl` currently does.
        Cfg("pad 2, no cutoff", nothing, (2.0, 2.0, 2.0)),
        Cfg("sphere R=Lmin, pad 2", minimum(box), (2.0, 2.0, 2.0)),
        ref,
        # The reference reads err = 0 against itself by construction, which proves
        # nothing about the reference. Padding it 1.25x further must not move the
        # field: if this row is not at round-off, "pad exact = free space" is an
        # assumption rather than a measurement and every err above it is suspect.
        Cfg("REF CHECK: pad exact x1.25", cost.R, ntuple(d -> 1.25 * cost.f_sph[d], 3)),
        Cfg("CONTROL: Q_xx x1.3, bare", nothing, nothing, 1.3),
    ]

    over_cap(cfg, n) = cfg.pad !== nothing &&
                       prod(ntuple(d -> ceil(Int, cfg.pad[d] * n[d]), 3)) > PAD_POINT_CAP

    results = Dict{Tuple{String, Any}, Any}()
    for n in n_list
        grid = make_grid(GridConfig(n, box))
        psi = probe_state(grid, sm, sigma)
        jzp = jz_psi(psi, grid, sm)
        ref_phi = over_cap(ref, n) ? nothing :
                  measure(grid, sm, psi, jzp, ref, c_dd).phi
        for cfg in cfgs
            results[(cfg.name, n)] = over_cap(cfg, n) ? nothing :
                                     measure(grid, sm, psi, jzp, cfg, c_dd; ref_phi)
        end
    end

    for (title, field) in (("tau/|E_DDI|  (rotation covariance)", :ratio),
        ("max field error vs free space  (magnitude)", :err))
        @printf("\n%-40s", title)
        for n in n_list
            @printf("%14s", string(n))
        end
        println()
        println("-"^(40 + 14 * length(n_list)))
        for cfg in cfgs
            @printf("%-40s", cfg.name)
            for n in n_list
                m = results[(cfg.name, n)]
                m === nothing ? @printf("%14s", "skip>cap") :
                @printf("%14.2e", getfield(m, field))
            end
            println()
        end
    end
end

function main()
    println("DDI cutoff-geometry J_z probe — tau/|E_DDI|, static, no time stepping")
    println("dealias: ", SpinorBEC.DEALIAS_2_3_ENABLED[], "  (cubic mask would add its own J_z violation)")
    println("skipped padded configs above $(PAD_POINT_CAP) points are marked skip>cap")

    run_geometry("isotropic (147 production configs)", (12.0, 12.0, 12.0),
        (1.5, 1.5, 1.5), [(32, 32, 32), (48, 48, 48), (64, 64, 64)])
    run_geometry("cigar aspect 2 (15 configs)", (12.0, 12.0, 24.0),
        (1.5, 1.5, 3.0), [(32, 32, 64), (48, 48, 96)])
    run_geometry("pancake aspect 2 (10 configs)", (20.0, 20.0, 10.0),
        (2.5, 2.5, 1.25), [(32, 32, 16), (48, 48, 24)])

    println("\nReading the table:")
    println("  FLAT in n   -> kernel/image error; a better cutoff geometry can help.")
    println("  FALLS in n  -> dx roughness; no cutoff geometry can help.")
    println("  If 'pad exact' is already at the floor, a cylinder buys only the")
    println("  padded-volume saving printed per geometry, not accuracy.")
    println("\n  Cutoff and padding are not interchangeable. Padding alone leaves a")
    println("  ~4e-4 (isotropic) to ~9e-4 (aspect 2) residual; the cutoff alone")
    println("  fixes covariance but not magnitude. On an ANISOTROPIC box at pad 2")
    println("  the auto cutoff is capped at R <= Lmin while exactness wants Lmax, so")
    println("  it trades a slightly larger field error for essentially exact J_z —")
    println("  raise pad_factor on the short axes to get both.")
end

main()

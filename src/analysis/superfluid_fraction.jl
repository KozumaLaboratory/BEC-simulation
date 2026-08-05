export superfluid_fraction, plane_averaged_density, spin_direction_spread

# Translational superfluid fraction from the phase-twist free energy.
#
# Twisted boundary conditions ψ(r + L ê_d) = e^{iθ} ψ(r) are gauged into a
# uniform phase gradient q = θ/L. Writing the phase as q(x_d + u(r)) with
# periodic u, the energy cost at fixed density is
#
#     E(q) − E(0) = (q²/2) ∫ n |ê_d + ∇u|² dV        (ℏ = m = 1)
#
# and the superfluid fraction is that cost normalised by the rigid-flow value
# (q²/2)∫n dV:
#
#     f_s = min_u ∫ n |ê_d + ∇u|² dV / ∫ n dV
#
# The density is held rigid — exact at O(q²) within mean field, since the
# untwisted state is stationary and the density response therefore only reaches
# the energy at O(q⁴). Restricting u to depend on x_d alone gives Leggett's
# closed form: a genuine upper bound on the above, and the quantity usually
# reported for supersolids.

"""
    plane_averaged_density(n, d) -> Vector{Float64}

Density averaged over the hyperplane perpendicular to axis `d`,
n̄(x_d) = ⟨n⟩_{other axes}.
"""
function plane_averaged_density(n::AbstractArray{<:Real, N}, d::Int) where {N}
    1 <= d <= N || throw(ArgumentError("direction $d outside 1:$N"))
    nd = size(n, d)
    nbar = zeros(Float64, nd)
    @inbounds for I in CartesianIndices(n)
        nbar[I[d]] += n[I]
    end
    nbar ./= (length(n) ÷ nd)
    nbar
end

"""
    superfluid_fraction(psi, grid; direction=1, method=:leggett) -> Float64
    superfluid_fraction(n, grid; direction=1, method=:leggett) -> Float64

Translational superfluid fraction along axis `direction`, from the free-energy
cost of a phase twist across the periodic box (ℏ = m = 1).

`psi` is a spinor `psi[x, y, …, c]` (all components contribute through the
total density) or a bare density array `n`.

`method`:

- `:leggett` — Leggett's closed form for flow along `d`, obtained by letting
  only the plane-averaged phase relax:

      f_s = L² / [ (∫ n̄ dx_d)(∫ dx_d / n̄) ]     n̄ = plane-averaged density

  Equals 1 iff n̄ is uniform, and falls as `1/n̄` develops peaks — a
  Cauchy–Schwarz bound, so `0 ≤ f_s ≤ 1` always.

- `:relaxed` — the full variational minimum over a periodic phase `u(r)`: solves
  ∇·(n(ê_d + ∇u)) = 0 on the grid and returns `1 + ∫n ∂_d u / ∫n`. Letting the
  phase vary transversally lets the flow concentrate where the density is high,
  which *lowers* the energy cost and hence the fraction:
  `f_s(:relaxed) ≤ f_s(:leggett)`, with equality when the density is modulated
  along `d` only.

!!! warning "Comparing the two branches at a fixed grid"
    That inequality is a *continuum* statement. `:leggett` is a trapezoid sum
    over a periodic analytic integrand and is spectrally accurate; `:relaxed`
    is a second-order finite-volume solve whose truncation error is positive —
    it approaches the true value from above, by roughly `(k·dx)²` scaled by the
    density contrast (~1e-4 at 128 points and contrast 0.5, ~8e-3 at 64 points
    and contrast 0.99). So a *small* excess of `:relaxed` over `:leggett` means
    the grid is coarse, not that the density reroutes flow. Only a gap well
    above that scale is physics. Refine until the gap stops shrinking.

Both branches hold the density rigid. Within Gross–Pitaevskii mean field that
costs nothing at the order that matters: the density response to the twist is
O(q²), and because the untwisted state is stationary that response only reaches
the energy at O(q⁴) — so `f_s`, an O(q²) quantity, is *exact*, not an upper
bound. `test_superfluid_fraction_gp_twist.jl` checks this against a direct
twisted-boundary-condition GP minimisation across f_s from 1.5e-4 to 0.53.

The upper-bound caveat belongs one level up, beyond mean field: a one-body
phase cannot represent correlated backflow. That gap is where the long-standing
solid-⁴He discrepancy lives — the Leggett bound gives ~20 % where experiment
found ~1 %.

For a **spinor** input this answers only the mass-flow question: the spinor is
reduced to its total density, so a spin texture is invisible to it. That is exact
when the local spin *direction* is uniform (measured: density-only and true
mass-twist `f_s` agree to 4 digits across polar, ferro and `c1 = 0`), and wrong by
a factor that reaches ~20 once the direction winds. A warning fires above a
direction spread of 0.05; pass `warn_texture=false` to silence it, and see
`spin_direction_spread`.

The twist is only meaningful when the cloud connects to itself across the
periodic box. A trapped cloud surrounded by vacuum has no phase rigidity along
the flow axis and gives `f_s ≈ 0`; that is the correct answer to the question
asked, not a bug. Pass `warn_vacuum=false` to silence the advisory.

References:
- A. J. Leggett, "Can a solid be superfluid?", Phys. Rev. Lett. 25, 1543
  (1970), doi:10.1103/PhysRevLett.25.1543 — the harmonic-mean bound.
- G. Biagioni et al., "Measurement of the superfluid fraction of a supersolid
  by Josephson effect", Nature (2024), doi:10.1038/s41586-024-07361-9 — the
  experiment this quantity is the theory counterpart of.
"""
function superfluid_fraction(
    psi::AbstractArray{<:Complex},
    grid::Grid{N};
    direction::Int=1,
    method::Symbol=:leggett,
    warn_vacuum::Bool=true,
    warn_texture::Bool=true,
    rtol::Float64=1e-10,
    maxiter::Int=0,
) where {N}
    warn_texture && _warn_spin_direction_texture(psi)
    superfluid_fraction(
        total_density(_to_host(psi), N), grid; direction, method, warn_vacuum, rtol, maxiter
    )
end

function _warn_spin_direction_texture(psi::AbstractArray{<:Complex})
    spread = spin_direction_spread(psi)
    spread <= _FS_DIRECTION_WARN && return nothing
    @warn "superfluid_fraction reduces the spinor to its total density, so it \
           answers only the MASS-flow question — and this state's spin direction \
           is textured (spread ≈ $(round(spread; digits=3))), which the density \
           alone cannot see. Measured on a 1D spin-1 GP against a direct \
           twisted-boundary-condition minimisation, the density-only value \
           overestimates the true mass-flow f_s by ~1.16× at spread 0.18 and by \
           ~20× at spread 0.8. Treat this number as an upper bound of unknown \
           tightness. A spin-flow f_s is not available: a textured state carries \
           a spin current, so E(0) is not the twist parabola's vertex and the \
           usual formula diverges. See docs/validation/\
           superfluidity_knowledge_state.md §1." maxlog = 1
    nothing
end

function superfluid_fraction(
    n_any::AbstractArray{<:Real, N},
    grid::Grid{N};
    direction::Int=1,
    method::Symbol=:leggett,
    warn_vacuum::Bool=true,
    rtol::Float64=1e-10,
    maxiter::Int=0,
) where {N}
    1 <= direction <= N || throw(ArgumentError("direction $direction outside 1:$N"))
    # Every loop below scalar-indexes, so a device array has to come home; the
    # widening also accepts the Float32 densities the mixed-precision path
    # produces, which the solve then carries in Float64.
    n = convert(Array{Float64, N}, _to_host(n_any))
    all(>=(0.0), n) || throw(ArgumentError("density must be non-negative"))

    nbar = plane_averaged_density(n, direction)
    n_mean = sum(nbar) / length(nbar)
    n_mean > 0 || throw(ArgumentError("density is identically zero"))

    if warn_vacuum && minimum(nbar) <= 1e-8 * n_mean
        @warn "superfluid_fraction: plane-averaged density vanishes somewhere along \
               axis $direction — the cloud does not connect across the periodic box, \
               so f_s ≈ 0 is geometric, not a property of the state." min_over_mean =
            minimum(nbar) / n_mean
    end

    if method === :leggett
        _superfluid_fraction_leggett(nbar)
    elseif method === :relaxed
        _superfluid_fraction_relaxed(n, grid, direction, rtol, maxiter)
    else
        throw(ArgumentError("unknown method $method (expected :leggett or :relaxed)"))
    end
end

# f_s = L² / [(∫ n̄)(∫ 1/n̄)]; the grid spacing cancels between the two integrals.
function _superfluid_fraction_leggett(nbar::Vector{Float64})
    minimum(nbar) > 0 || return 0.0
    npt = length(nbar)
    npt^2 / (sum(nbar) * sum(inv, nbar))
end

# --- Spin-direction texture guard ---

"""
    spin_direction_spread(psi) -> Float64

How much the local spin *direction* varies across the cloud, as the
rotation-invariant `1 - |⟨n̂⟩|` with `n̂ = ⟨F⟩/|⟨F⟩|` averaged under density
weight. `0` for a spinor whose direction is uniform (however its magnitude or
density varies); `→ 1` for a fully wound texture. Returns `0` for a
single-component field, which has no direction.

Not the same quantity as `_lhy_texture_spread` in `make_workspace`, which
measures the spread in the *magnitude* `|⟨F⟩|/F`. The two guards are
complementary and point opposite ways: for LHY a direction texture is free and
only the magnitude matters, while for `superfluid_fraction` the magnitude is
irrelevant and the direction is what breaks the density-only formula.
"""
function spin_direction_spread(psi::AbstractArray{<:Complex, M}) where {M}
    N = M - 1
    D = size(psi, M)
    D > 1 || return 0.0
    isodd(D) || return 0.0                      # D = 2F+1 ⇒ D must be odd
    F = (D - 1) ÷ 2
    p = _to_host(psi)
    n_pts = ntuple(d -> size(p, d), N)
    fx, fy, fz = spin_density_vector(p, spin_matrices(F), N)
    n = total_density(p, N)

    acc = zeros(3)
    w = 0.0
    cut = 1e-6 * maximum(n)
    @inbounds for I in CartesianIndices(n_pts)
        n[I] > cut || continue
        fmag = sqrt(fx[I]^2 + fy[I]^2 + fz[I]^2)
        fmag > 1e-12 || continue                # unpolarised voxel: no direction
        acc[1] += n[I] * fx[I] / fmag
        acc[2] += n[I] * fy[I] / fmag
        acc[3] += n[I] * fz[I] / fmag
        w += n[I]
    end
    w > 0 || return 0.0
    max(0.0, 1 - sqrt(acc[1]^2 + acc[2]^2 + acc[3]^2) / w)
end

# Above this direction spread the density-only f_s is worth flagging.
#
# Calibrated, not guessed. Measured on a 1D spin-1 GP by comparing the
# density-only value against the true mass-twist f_s (a symmetric second
# difference of E(±q), so immune to any spin current), with the spin direction
# swept on a cone B = (b⊥cos kx, b⊥sin kx, b_z):
#
#   spread   0.0000  0.0039  0.0153  0.0573  0.1835   0.798
#   dens/true 1.000   1.003   1.010   1.040   1.161   19.9
#
# The error tracks ≈0.7·spread while the texture is gentle and then runs away
# once the direction fully winds — a factor of TWENTY at spread 0.8, not a few
# per cent. 0.05 keeps the silent regime under ~4 %, matching the tolerance the
# LHY texture guard settles for.
const _FS_DIRECTION_WARN = 0.05

# --- Variational branch: ∇·(n(ê_d + ∇u)) = 0 on the periodic grid ---

@inline _fwd(i::Int, n::Int) = ifelse(i == n, 1, i + 1)
@inline _bwd(i::Int, n::Int) = ifelse(i == 1, n, i - 1)

@inline function _shift(I::CartesianIndex{N}, d::Int, np::NTuple{N, Int}, fwd::Bool) where {N}
    CartesianIndex(ntuple(e -> e == d ? (fwd ? _fwd(I[e], np[e]) : _bwd(I[e], np[e])) : I[e], N))
end

# Face densities n_{i+1/2} in each direction, as the ARITHMETIC mean of the two
# cells. Harmonic averaging — the usual finite-volume choice for a
# discontinuous coefficient — is wrong here: it satisfies Σ 1/n_face = Σ 1/n
# but breaks Σ n_face = Σ n, and that second identity is what makes the
# rigid-flow reference in the f_s ratio consistent with the flux. Concretely, a
# blob of 21 filled cells surrounded by vacuum has 20 harmonic faces against 21
# cells of mass and reports f_s = 1/21 instead of the correct 0. Arithmetic
# faces give the two half-weight edge faces that close the sum exactly.
function _face_densities(n::AbstractArray{Float64, N}, np::NTuple{N, Int}) where {N}
    ntuple(N) do d
        nf = similar(n)
        @inbounds for I in CartesianIndices(n)
            nf[I] = 0.5 * (n[I] + n[_shift(I, d, np, true)])
        end
        nf
    end
end

# out .= -∇·(n ∇u), the SPD operator of the variational problem.
function _apply_flux_laplacian!(
    out::Array{Float64, N},
    u::Array{Float64, N},
    nf::NTuple{N, Array{Float64, N}},
    inv_dx2::NTuple{N, Float64},
    np::NTuple{N, Int},
) where {N}
    fill!(out, 0.0)
    @inbounds for I in CartesianIndices(u)
        acc = 0.0
        for d in 1:N
            Ip = _shift(I, d, np, true)
            Im = _shift(I, d, np, false)
            acc += (nf[d][I] * (u[Ip] - u[I]) - nf[d][Im] * (u[I] - u[Im])) * inv_dx2[d]
        end
        out[I] = -acc
    end
    out
end

function _superfluid_fraction_relaxed(
    nd::Array{Float64, N},
    grid::Grid{N},
    d0::Int,
    rtol::Float64,
    maxiter::Int,
) where {N}
    np = grid.config.n_points
    size(nd) == np || throw(ArgumentError("density size $(size(nd)) ≠ grid $(np)"))

    nf = _face_densities(nd, np)
    inv_dx2 = ntuple(d -> 1.0 / grid.dx[d]^2, N)
    inv_dx0 = 1.0 / grid.dx[d0]

    # b = ∂_{d0} n, discretised through the same face values as the operator.
    # Telescoping then makes ∑b vanish over every connected region, i.e. b is
    # orthogonal to the null space of A and the singular system is compatible.
    b = similar(nd)
    @inbounds for I in CartesianIndices(b)
        b[I] = (nf[d0][I] - nf[d0][_shift(I, d0, np, false)]) * inv_dx0
    end

    u = _solve_cg(b, nf, inv_dx2, np, rtol, maxiter <= 0 ? 10 * length(b) : maxiter)

    # f_s = 1 + ∫n ∂_{d0} u / ∫n, with the flux form matching the operator.
    flux = 0.0
    @inbounds for I in CartesianIndices(u)
        flux += nf[d0][I] * (u[_shift(I, d0, np, true)] - u[I]) * inv_dx0
    end
    1.0 + flux / sum(nd)
end

# Conjugate gradient for the consistent singular system A u = b. The null
# space (one constant per connected region) never enters: b is orthogonal to
# it by construction, and a constant offset in `u` drops out of the flux.
function _solve_cg(
    b::Array{Float64, N},
    nf::NTuple{N, Array{Float64, N}},
    inv_dx2::NTuple{N, Float64},
    np::NTuple{N, Int},
    rtol::Float64,
    maxiter::Int,
) where {N}
    u = zeros(Float64, size(b))
    r = copy(b)
    p = copy(r)
    Ap = similar(b)

    rr = sum(abs2, r)
    b_norm = sqrt(sum(abs2, b))
    b_norm > 0 || return u
    tol2 = (rtol * b_norm)^2

    iter = 0
    while rr > tol2 && iter < maxiter
        _apply_flux_laplacian!(Ap, p, nf, inv_dx2, np)
        pAp = sum(p .* Ap)
        pAp > 0 || break                       # null direction: nothing left to relax
        α = rr / pAp
        @. u += α * p
        @. r -= α * Ap
        rr_new = sum(abs2, r)
        @. p = r + (rr_new / rr) * p
        rr = rr_new
        iter += 1
    end
    if rr > tol2
        @warn "superfluid_fraction(:relaxed): CG stopped at residual \
               $(sqrt(rr) / b_norm) after $iter iterations"
    end
    u
end

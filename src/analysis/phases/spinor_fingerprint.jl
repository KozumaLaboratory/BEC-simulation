# Gauge/frame-invariant phase fingerprint for an F-spinor dipolar BEC.
#
# A fingerprint is ONE invariant vector per state, layered:
#   A local  — bulk-spinor σ_S polyhedral fingerprint + |⟨F⟩|/F + inert label
#   B uniform — spinor coherence g (multipole-complete, 1 uniform … 0 textured)
#   C topo   — ⟨L_z⟩, ⟨F_z⟩, J_z, per-component winding, scalar spin chirality,
#              flux-closure fraction ‖∇·F‖/‖∇F‖
#   D modul  — spin / density structure-factor peak beyond the cloud envelope
#
# Single source for every consumer (phase-map cells, reference validation) so the
# same physics is never hand-written twice. Built on the existing invariants
# `polyhedral_fingerprint` / `classify_polyhedral` (polyhedral_classifier.jl),
# `winding_number_field` / `_spin_expectation_fields` (topology.jl).
#
# Grid is assumed uniform-cubic (single spacing dx); the metrics central-difference
# the spin field, so a magnetised cloud must sit away from the box edge.

export spinor_fingerprint, flux_closure_fraction, spinor_coherence

# B. spinor coherence: density-weighted |⟨z_ref|z⟩|² against the peak spinor.
# 1 ⇒ spatially uniform spinor (single order parameter), 0 ⇒ fully textured.
# Multipole-complete (gauge invariant): sees any spinor texture, not just ⟨F⟩.
function spinor_coherence(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    dens = dropdims(sum(abs2, psi; dims=N + 1); dims=N + 1)
    _spinor_coherence(psi, dens, size(psi, N + 1))
end

function _spinor_coherence(psi, dens, D)
    pk = argmax(dens)
    zref = ComplexF64[psi[pk, c] for c in 1:D]
    zref ./= norm(zref)
    thr = 0.02 * maximum(dens)
    num = 0.0
    den = 0.0
    @inbounds for I in CartesianIndices(dens)
        dens[I] > thr || continue
        z = ComplexF64[psi[I, c] for c in 1:D]
        nz = norm(z)
        nz > 1e-12 || continue
        num += dens[I] * abs2(dot(zref, z)) / nz^2
        den += dens[I]
    end
    den > 0 ? num / den : 0.0
end

# C. ⟨L_z⟩ per atom, L_z = -i(x ∂_y - y ∂_x), central differences.
function _mean_Lz(psi, grid::Grid{N}, D) where {N}
    n = grid.config.n_points
    NX = n[1]
    dx = grid.x[1][2] - grid.x[1][1]
    xs = collect(grid.x[1])
    ys = collect(grid.x[2])
    Lz = 0.0
    nrm = 0.0
    @inbounds for c in 1:D, k in 1:n[3], j in 2:(n[2] - 1), i in 2:(NX - 1)
        ψ = psi[i, j, k, c]
        dψx = (psi[i + 1, j, k, c] - psi[i - 1, j, k, c]) / (2dx)
        dψy = (psi[i, j + 1, k, c] - psi[i, j - 1, k, c]) / (2dx)
        Lzψ = -im * (xs[i] * dψy - ys[j] * dψx)
        Lz += real(conj(ψ) * Lzψ)
        nrm += abs2(ψ)
    end
    nrm > 0 ? Lz / nrm : 0.0
end

# C. per-component net winding at the z-midplane; `missing` for a depopulated m.
function _winding_vector(psi::AbstractArray{<:Complex}, grid::Grid{N}, D) where {N}
    kz = grid.config.n_points[3] ÷ 2 + 1
    tot = sum(abs2, psi)
    map(1:D) do c
        pop = sum(abs2, view(psi,:,:,:,c)) / tot
        pop < 1e-3 ? missing :
        sum(view(winding_number_field(psi, grid; component=c),:,:,kz))
    end
end

# C. scalar spin chirality / 2D skyrmion density (z-midplane, density-weighted).
function _spin_chirality(fx, fy, fz, dens, dx)
    NX = size(dens, 1)
    NY = size(dens, 2)
    kz = size(dens, 3) ÷ 2 + 1
    fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    χ = 0.0
    w = 0.0
    @inbounds for j in 2:(NY - 1), i in 2:(NX - 1)
        fmag[i, j, kz] > 1e-9 || continue
        n = [fx[i, j, kz], fy[i, j, kz], fz[i, j, kz]] ./ fmag[i, j, kz]
        nx =
            (
                [fx[i + 1, j, kz], fy[i + 1, j, kz], fz[i + 1, j, kz]] ./
                max(fmag[i + 1, j, kz], 1e-12) .-
                [fx[i - 1, j, kz], fy[i - 1, j, kz], fz[i - 1, j, kz]] ./
                max(fmag[i - 1, j, kz], 1e-12)
            ) ./ (2dx)
        ny =
            (
                [fx[i, j + 1, kz], fy[i, j + 1, kz], fz[i, j + 1, kz]] ./
                max(fmag[i, j + 1, kz], 1e-12) .-
                [fx[i, j - 1, kz], fy[i, j - 1, kz], fz[i, j - 1, kz]] ./
                max(fmag[i, j - 1, kz], 1e-12)
            ) ./ (2dx)
        cross = [
            nx[2] * ny[3] - nx[3] * ny[2],
            nx[3] * ny[1] - nx[1] * ny[3],
            nx[1] * ny[2] - nx[2] * ny[1],
        ]
        χ += dens[i, j, kz] * dot(n, cross)
        w += dens[i, j, kz]
    end
    w > 0 ? χ / w : 0.0
end

"""
    flux_closure_fraction(fx, fy, fz, dx) -> Float64

Flux-closure metric `‖∇·F‖ / ‖∇F‖` of a spin field, summed over magnetised
voxels (`|F| > 0.05·max|F|`). A flux-closure (divergence-free) texture — e.g.
the Kawaguchi–Ueda Flower phase — reads `≈0`; a divergent texture (radial /
hedgehog) reads `≫0`. Returns `NaN` for an unmagnetised field (`max|F| ≈ 0`).
"""
function flux_closure_fraction(fx, fy, fz, dx)
    NX, NY, NZ = size(fx)
    fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    mx = maximum(fmag)
    mx < 1e-8 && return NaN
    fthr = 0.05 * mx
    divsq = 0.0
    gradsq = 0.0
    @inbounds for k in 2:(NZ - 1), j in 2:(NY - 1), i in 2:(NX - 1)
        fmag[i, j, k] > fthr || continue
        dxFx = (fx[i + 1, j, k] - fx[i - 1, j, k]) / (2dx)
        dyFy = (fy[i, j + 1, k] - fy[i, j - 1, k]) / (2dx)
        dzFz = (fz[i, j, k + 1] - fz[i, j, k - 1]) / (2dx)
        divsq += (dxFx + dyFy + dzFz)^2
        for Fc in (fx, fy, fz)
            gradsq +=
                ((Fc[i + 1, j, k] - Fc[i - 1, j, k]) / (2dx))^2 +
                ((Fc[i, j + 1, k] - Fc[i, j - 1, k]) / (2dx))^2 +
                ((Fc[i, j, k + 1] - Fc[i, j, k - 1]) / (2dx))^2
        end
    end
    gradsq > 0 ? sqrt(divsq / gradsq) : 0.0
end

# D. structure-factor peak power (and its k) beyond the cloud envelope k.
function _struct_peak(field, dens, dx)
    dims = size(dens)                       # per-axis; grid may be non-cubic
    center = (dims .+ 1) ./ 2
    rms =
        sqrt(
            sum(dens[I] * sum(abs2, Tuple(I) .- center) for I in CartesianIndices(dens)) /
            sum(dens),
        ) * dx
    kenv = 1 / max(rms, dx)
    kf = ntuple(d -> 2π .* fftfreq(dims[d], 1 / dx), length(dims))   # dx isotropic
    kg = [sqrt(sum(kf[d][I[d]]^2 for d in 1:length(dims))) for I in CartesianIndices(dims)]
    S = abs.(fft(field)) .^ 2
    beyond = kg .> 3 * kenv
    tot = sum(S)
    (any(beyond) && tot > 1e-30) || return (0.0, 0.0)
    (maximum(S[beyond]) / tot, kg[argmax(S .* beyond)])
end

"""
    spinor_fingerprint(psi, grid, F) -> NamedTuple

One gauge/frame-invariant fingerprint vector for the spinor field `psi`
(`[x,y,z,m]`, `D = 2F+1` components). Fields:

  `sigma` (σ_S polyhedral fingerprint), `mF` (=|⟨F⟩|/F of the bulk spinor),
  `coh` (spinor coherence g), `Lz`, `Fz`, `Jz`, `winding` (per-m, `missing`
  if depopulated), `chirality`, `fluxclosure` (‖∇·F‖/‖∇F‖, `NaN` if |F|≈0),
  `spin_mod`/`kspin`, `dens_mod`/`kdens` (structure-factor peaks), and the
  nearest polyhedral inert state `inert` with `inert_score`.

Assumes uniform (isotropic) grid spacing; the shape may be non-cubic.
"""
function spinor_fingerprint(psi::AbstractArray{<:Complex}, grid::Grid{N}, F::Int) where {N}
    D = 2F + 1
    sm = spin_matrices(F)
    dx = grid.x[1][2] - grid.x[1][1]
    dV = cell_volume(grid)
    dens = dropdims(sum(abs2, psi; dims=N + 1); dims=N + 1)
    fx, fy, fz = _spin_expectation_fields(psi, grid)

    pk = argmax(dens)
    zbulk = ComplexF64[psi[pk, c] for c in 1:D]
    zbulk ./= norm(zbulk)

    sigma = polyhedral_fingerprint(zbulk, F)
    mF =
        sqrt(
            real(dot(zbulk, sm.Fx * zbulk))^2 +
            real(dot(zbulk, sm.Fy * zbulk))^2 +
            real(dot(zbulk, sm.Fz * zbulk))^2,
        ) / F
    coh = _spinor_coherence(psi, dens, D)
    Lz = _mean_Lz(psi, grid, D)
    Fz = sum(fz) * dV / (sum(dens) * dV)
    wv = _winding_vector(psi, grid, D)
    χ = _spin_chirality(fx, fy, fz, dens, dx)
    fc = flux_closure_fraction(fx, fy, fz, dx)
    spin_mod, kspin = _struct_peak(fx, dens, dx)
    dens_mod, kdens = _struct_peak(ComplexF64.(dens .- sum(dens) / length(dens)), dens, dx)
    loc = classify_polyhedral(zbulk, F)

    (; sigma, mF, coh, Lz, Fz, Jz=Lz + Fz, winding=wv, chirality=χ, fluxclosure=fc,
        spin_mod, kspin, dens_mod, kdens, inert=loc.best, inert_score=loc.score)
end

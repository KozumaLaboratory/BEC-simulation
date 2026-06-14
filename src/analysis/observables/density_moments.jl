# --- Cloud shape observables ---
#
# Second-moment (covariance) tensor of the total density and the shape
# parameters derived from it: center of mass, per-axis RMS widths, the
# principal-axis widths (aspect ratio), and the in-plane tilt angle. These
# quantify cloud deformation (anisotropic expansion, shear, bending) across
# a dynamics snapshot series, where the bare density movie only shows it.

export density_moments

"""
    density_moments(psi, grid) -> NamedTuple

Density-weighted shape descriptors of the total density `n(r) = Σ_c|ψ_c|²`.

Returns `(mass, com, widths, principal_widths, aspect_ratio, tilt, cov)`:
- `mass`             — `∫n dV` (= `total_norm`).
- `com`              — center of mass `⟨x⟩` per axis (length-N tuple).
- `widths`           — per-axis RMS width `√⟨(x_d-⟨x_d⟩)²⟩`.
- `principal_widths` — RMS widths along the principal axes (eigenvalues of
                       the covariance tensor, ascending), capturing tilted
                       elongation that per-axis widths miss.
- `aspect_ratio`     — `max(principal_widths) / min(principal_widths)` (≥ 1).
- `tilt`             — orientation of the major principal axis w.r.t. axis 1,
                       in `(-π/2, π/2]`. Meaningful for N=2; `0.0` for N=1
                       and not reduced to a single angle for N=3.
- `cov`              — the full N×N second central-moment tensor.

`com`/`widths`/`cov` are independent of the cell volume (it cancels in the
density-weighted average); only `mass` carries `dV`.
"""
function density_moments(psi::AbstractArray{<:Complex}, grid::Grid{N}) where {N}
    dV = cell_volume(grid)
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    axs = grid.x

    raw_mass = 0.0
    m1 = zeros(N)        # Σ n x_i
    m2 = zeros(N, N)     # Σ n x_i x_j (upper triangle filled)
    coord = zeros(N)

    @inbounds for I in CartesianIndices(n_pts)
        n = 0.0
        for c in 1:n_comp
            n += abs2(psi[I, c])
        end
        n == 0.0 && continue
        for d in 1:N
            coord[d] = axs[d][I[d]]
        end
        raw_mass += n
        for i in 1:N
            m1[i] += n * coord[i]
            for j in i:N
                m2[i, j] += n * coord[i] * coord[j]
            end
        end
    end

    if raw_mass == 0.0
        zero_com = ntuple(_ -> 0.0, Val(N))
        return (
            mass=0.0,
            com=zero_com,
            widths=zero_com,
            principal_widths=zero_com,
            aspect_ratio=1.0,
            tilt=0.0,
            cov=zeros(N, N),
        )
    end

    com = ntuple(i -> m1[i] / raw_mass, Val(N))
    cov = zeros(N, N)
    for i in 1:N, j in i:N
        c = m2[i, j] / raw_mass - com[i] * com[j]
        cov[i, j] = c
        cov[j, i] = c
    end

    widths = ntuple(i -> sqrt(max(cov[i, i], 0.0)), Val(N))
    vals = eigvals(Symmetric(cov))                  # ascending
    pw = ntuple(i -> sqrt(max(vals[i], 0.0)), Val(N))
    aspect = pw[1] > 0 ? pw[N] / pw[1] : 1.0
    tilt = N == 2 ? 0.5 * atan(2 * cov[1, 2], cov[1, 1] - cov[2, 2]) : 0.0

    (
        mass=raw_mass * dV,
        com=com,
        widths=widths,
        principal_widths=pw,
        aspect_ratio=aspect,
        tilt=tilt,
        cov=cov,
    )
end

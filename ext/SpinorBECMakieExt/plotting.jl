const COMPONENT_COLORS = [:blue, :green, :red, :orange, :purple, :cyan, :magenta]
const COMPONENT_LABELS = ["m=+F", "m=+F-1", "m=0", "m=-F+1", "m=-F"]

function _component_label(sys::SpinorBEC.SpinSystem, c::Int)
    "m=$(sys.m_values[c])"
end

function SpinorBEC.plot_density(
    grid::SpinorBEC.Grid{1},
    psi::AbstractArray{ComplexF64};
    components::Bool=true,
    title::String="Density",
)
    x = grid.x[1]
    ndim = 1
    nc = size(psi, ndim + 1)

    fig = Figure(; size=(800, 500))
    ax = Axis(fig[1, 1]; xlabel="x", ylabel="n(x)", title)

    n_total = SpinorBEC.total_density(psi, ndim)
    lines!(ax, x, n_total; color=:black, linewidth=2, label="total")

    if components
        for c in 1:nc
            nc_density = SpinorBEC.component_density(psi, ndim, c)
            color = COMPONENT_COLORS[mod1(c, length(COMPONENT_COLORS))]
            lines!(
                ax,
                x,
                nc_density;
                color,
                linewidth=1.5,
                linestyle=:dash,
                label="m=$(nc ÷ 2 + 1 - c)",
            )
        end
    end

    axislegend(ax; position=:rt)
    fig
end

function SpinorBEC.plot_density(
    grid::SpinorBEC.Grid{2},
    psi::AbstractArray{ComplexF64};
    components::Bool=false,
    title::String="Density",
)
    x, y = grid.x
    ndim = 2
    nc = size(psi, ndim + 1)

    n_total = SpinorBEC.total_density(psi, ndim)

    if components
        fig = Figure(; size=(300 * (nc + 1), 400))
        ax = Axis(fig[1, 1]; xlabel="x", ylabel="y", title="Total", aspect=DataAspect())
        heatmap!(ax, x, y, n_total)
        for c in 1:nc
            nc_density = SpinorBEC.component_density(psi, ndim, c)
            ax_c = Axis(fig[1, c + 1]; xlabel="x", ylabel="y",
                title="m=$(nc ÷ 2 + 1 - c)", aspect=DataAspect())
            heatmap!(ax_c, x, y, nc_density)
        end
    else
        fig = Figure(; size=(600, 500))
        ax = Axis(fig[1, 1]; xlabel="x", ylabel="y", title, aspect=DataAspect())
        hm = heatmap!(ax, x, y, n_total)
        Colorbar(fig[1, 2], hm)
    end

    fig
end

function SpinorBEC.plot_spinor(
    grid::SpinorBEC.Grid{1},
    psi::AbstractArray{ComplexF64};
    title::String="Spinor Components",
)
    x = grid.x[1]
    nc = size(psi, 2)

    fig = Figure(; size=(800, 600))

    ax_amp = Axis(fig[1, 1]; xlabel="x", ylabel="|ψ|", title="$title - Amplitude")
    ax_phase = Axis(fig[2, 1]; xlabel="x", ylabel="arg(ψ)")

    for c in 1:nc
        color = COMPONENT_COLORS[mod1(c, length(COMPONENT_COLORS))]
        label = "m=$(nc ÷ 2 + 1 - c)"
        lines!(ax_amp, x, abs.(psi[:, c]); color, linewidth=1.5, label)
        lines!(ax_phase, x, angle.(psi[:, c]); color, linewidth=1.5, label)
    end

    axislegend(ax_amp; position=:rt)
    fig
end

function SpinorBEC.plot_spin_texture(
    grid::SpinorBEC.Grid{1},
    psi::AbstractArray{ComplexF64},
    sm::SpinorBEC.SpinMatrices;
    title::String="Spin Texture",
)
    x = grid.x[1]
    fx, fy, fz = SpinorBEC.spin_density_vector(psi, sm, 1)
    n = SpinorBEC.total_density(psi, 1)
    threshold = maximum(n) * 1e-6

    fx_norm = [ni > threshold ? fi / ni : 0.0 for (fi, ni) in zip(fx, n)]
    fy_norm = [ni > threshold ? fi / ni : 0.0 for (fi, ni) in zip(fy, n)]
    fz_norm = [ni > threshold ? fi / ni : 0.0 for (fi, ni) in zip(fz, n)]

    fig = Figure(; size=(800, 500))
    ax = Axis(fig[1, 1]; xlabel="x", ylabel="⟨F_α⟩/n", title)

    lines!(ax, x, fx_norm; color=:red, linewidth=1.5, label="Fx/n")
    lines!(ax, x, fy_norm; color=:green, linewidth=1.5, label="Fy/n")
    lines!(ax, x, fz_norm; color=:blue, linewidth=1.5, label="Fz/n")

    axislegend(ax; position=:rt)
    fig
end

"""
    plot_dipole_field(grid, density, Bx, By, Bz; plane=:xz, ...)

Slice plot of the dipolar magnetic field a cloud radiates (see
`SpinorBEC.dipole_magnetic_field`): a heatmap of |B| on a coordinate plane,
the in-plane field as a quiver, and a density contour outlining the gas — the
x–z view from the MATLAB reference. `density`/`B*` are the 3D arrays on `grid`.

Keywords: `plane ∈ (:xz, :xy, :yz)`; `slice_index` (default the central
plane); `field_scale` (default `1e4`, tesla → gauss) + `field_label`;
`arrow_step` downsamples the quiver; `density_contour` toggles the outline.
"""
function SpinorBEC.plot_dipole_field(
    grid::SpinorBEC.Grid{3},
    density::AbstractArray{<:Real},
    Bx::AbstractArray{<:Real},
    By::AbstractArray{<:Real},
    Bz::AbstractArray{<:Real};
    plane::Symbol=:xz,
    slice_index::Union{Nothing, Int}=nothing,
    field_scale::Real=1e4,
    field_label::String="|B| (G)",
    arrow_step::Int=8,
    density_contour::Bool=true,
    title::String="Dipolar magnetic field",
)
    # (axis-1 index, axis-2 index, fixed axis), axis labels, component arrays.
    a1, a2, fixed, l1, l2 = if plane === :xz
        (1, 3, 2, "x", "z")
    elseif plane === :xy
        (1, 2, 3, "x", "y")
    elseif plane === :yz
        (2, 3, 1, "y", "z")
    else
        throw(ArgumentError("plane must be :xz, :xy or :yz, got :$plane"))
    end

    n_fixed = grid.config.n_points[fixed]
    idx = slice_index === nothing ? n_fixed ÷ 2 + 1 : slice_index
    sl = ntuple(d -> d == fixed ? idx : Colon(), 3)

    comp = (Bx, By, Bz)
    Btot = @. sqrt(Bx^2 + By^2 + Bz^2)
    Btot2d = Btot[sl...] .* field_scale
    n2d = density[sl...]
    u2d = comp[a1][sl...] .* field_scale
    v2d = comp[a2][sl...] .* field_scale

    ax1 = grid.x[a1]
    ax2 = grid.x[a2]

    fig = Figure(; size=(700, 560))
    ax = Axis(fig[1, 1]; xlabel=l1, ylabel=l2, title, aspect=DataAspect())
    hm = heatmap!(ax, ax1, ax2, Btot2d; colormap=:dense)
    Colorbar(fig[1, 2], hm; label=field_label)

    step = max(arrow_step, 1)
    i1 = 1:step:length(ax1)
    i2 = 1:step:length(ax2)
    ps = [Point2f(ax1[i], ax2[j]) for i in i1 for j in i2]
    vs = [Vec2f(u2d[i, j], v2d[i, j]) for i in i1 for j in i2]
    vmax = isempty(vs) ? 0.0 : maximum(v -> sqrt(v[1]^2 + v[2]^2), vs)
    lscale = vmax > 0 ? Float32(0.06 * (maximum(ax1) - minimum(ax1)) / vmax) : 1.0f0
    arrows!(ax, ps, vs; lengthscale=lscale, color=:black, arrowsize=8)

    if density_contour && maximum(n2d) > 0
        contour!(ax, ax1, ax2, n2d; levels=[maximum(n2d) * 0.01], color=:white, linewidth=1.5)
    end

    fig
end

function SpinorBEC.plot_spin_texture(
    grid::SpinorBEC.Grid{2},
    psi::AbstractArray{ComplexF64},
    sm::SpinorBEC.SpinMatrices;
    title::String="Spin Texture",
)
    x, y = grid.x
    fx, fy, fz = SpinorBEC.spin_density_vector(psi, sm, 2)
    n = SpinorBEC.total_density(psi, 2)
    threshold = maximum(n) * 1e-6

    fz_norm = @. ifelse(n > threshold, fz / n, 0.0)

    fig = Figure(; size=(600, 500))
    ax = Axis(fig[1, 1]; xlabel="x", ylabel="y", title="$title: Fz/n", aspect=DataAspect())
    hm = heatmap!(ax, x, y, fz_norm; colorrange=(-1, 1), colormap=:RdBu)
    Colorbar(fig[1, 2], hm)
    fig
end

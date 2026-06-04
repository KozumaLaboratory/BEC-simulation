# Makie sweep renderer: consumes the same `to_viewspec(::SweepResult)`
# output that the React dashboard renders. Renderer paints, does not
# decide — every per-cell fill / alpha / oracle line comes from the
# resolved spec. Compare with `src/analysis/sweep.jl::to_viewspec` and
# `dashboard/src/components/SweepView.tsx`. See
# `docs/architecture/sweep_view.md`.

using SpinorBEC: SweepResult, SweepAxis, SweepObservable,
    to_viewspec, _cell_edges, resolve_signed_cell_hex,
    resolve_positive_cell_hex, compute_quality_alpha

# Tiny hex → Makie RGBAf converter. We deliberately do NOT go through
# Colors.jl here — the dispatcher already resolved the per-cell hex, and
# pulling Colors into the Makie ext for one parse step would balloon
# precompile.
function _hex_to_rgba(hex::AbstractString, alpha::Real=1.0)
    s = hex
    if startswith(s, "#")
        s = SubString(s, 2)
    end
    length(s) >= 6 || return Makie.RGBAf(0.6, 0.63, 0.65, clamp(alpha, 0.0, 1.0))
    r = parse(Int, SubString(s, 1, 2); base=16) / 255
    g = parse(Int, SubString(s, 3, 4); base=16) / 255
    b = parse(Int, SubString(s, 5, 6); base=16) / 255
    return Makie.RGBAf(r, g, b, clamp(alpha, 0.0, 1.0))
end

"""
    plot_sweep(result::SweepResult; signed_clip=Dict(),
        positive_clip=Dict(), spectrum_margin=0.1, F=6,
        quality_threshold=1e-5, quality_dynamic_range_decades=4.0,
        size=nothing) → Figure

Render a `SweepResult` to a Makie `Figure` using the same dispatcher as
the dashboard. The dispatcher resolves vmin/vmax, per-cell fill hex,
and per-cell `quality_alpha`; this function paints them as Makie
`poly!` rectangles. Out-of-the-box for 2D sweeps; 1D and ≥3D return a
placeholder figure with a note.

Keyword args mirror `to_viewspec` so the React and Makie renderings are
pixel-decision identical:
  * `signed_clip` — observable_key => (vmin, vmax). Default `(-F, +F)`.
  * `positive_clip` — observable_key => (vmin, vmax). Default auto via
    converged-only p05/p95.
  * `spectrum_margin` — dominant-m decision gap.
  * `quality_threshold` / `quality_dynamic_range_decades` — VSUP alpha
    fade parameters.
  * `size` — figure size override. When omitted, scales with the panel
    count.

Returns a `Makie.Figure`. The caller saves with `Makie.save("…", fig)`.
"""
function SpinorBEC.plot_sweep(result::SweepResult;
    signed_clip::Dict=Dict(),
    positive_clip::Dict=Dict(),
    spectrum_margin::Real=0.1,
    F::Int=6,
    quality_threshold::Real=1e-5,
    quality_dynamic_range_decades::Real=4.0,
    size=nothing)
    spec = to_viewspec(result;
        signed_clip, positive_clip, spectrum_margin, F,
        quality_threshold, quality_dynamic_range_decades)
    view_shape = spec["_view_shape"]
    panels = get(spec, "vconcat", Dict{String, Any}[])

    if view_shape != "heatmap" || isempty(panels)
        fig = Makie.Figure(; size=(800, 200))
        Makie.Label(fig[1, 1],
            "plot_sweep: $(view_shape) shape not implemented yet " *
            "(or no data-role observables in spec).";
            tellwidth=false, tellheight=false)
        return fig
    end

    n_panels = length(panels)
    ncols = min(n_panels, 3)
    nrows = cld(n_panels, ncols)
    sz = size === nothing ? (400 * ncols, 340 * nrows) : size
    fig = Makie.Figure(; size=sz)

    # Identify which two SweepResult axes are swept (matches to_viewspec).
    swept_axes = filter(a -> length(a.values) > 1, result.axes)
    length(swept_axes) == 2 || return fig
    x_axis = swept_axes[2]
    y_axis = swept_axes[1]

    for (idx, panel) in enumerate(panels)
        r, c = fldmod1(idx, ncols)
        title = String(get(panel, "title", ""))
        layer = first(panel["layer"])
        marks = layer["data"]["values"]
        meta = get(panel, "_meta", Dict{String, Any}())
        xscale = x_axis.scale === :log ? log10 : identity
        yscale = y_axis.scale === :log ? log10 : identity

        ax = Makie.Axis(fig[r, c];
            title,
            xlabel=string(x_axis.name, " [", x_axis.unit, "]"),
            ylabel=string(y_axis.name, " [", y_axis.unit, "]"),
            xscale=xscale,
            yscale=yscale,
        )

        # Paint per-cell rectangles. The dispatcher gave us x/x2/y/y2 in
        # data units, plus a resolved hex and alpha. We push the same
        # values into Makie poly!.
        for m in marks
            x1 = Float64(m["x"])
            x2 = Float64(m["x2"])
            y1 = Float64(m["y"])
            y2 = Float64(m["y2"])
            α = Float64(get(m, "alpha", 1.0))
            hex = String(m["fill"])
            color = _hex_to_rgba(hex, α)
            poly = Makie.Point2f[
                (x1, y1), (x2, y1), (x2, y2), (x1, y2)
            ]
            Makie.poly!(ax, poly; color=color, strokewidth=0)
        end

        # Footnote — vmin/vmax band so paper readers see the clip.
        vmin = get(meta, "vmin", nothing)
        vmax = get(meta, "vmax", nothing)
        cmap = get(meta, "colormap", "")
        if vmin !== nothing && vmax !== nothing
            ax.subtitle = string(cmap, "  [", round(vmin; digits=3),
                ", ", round(vmax; digits=3), "]")
        end
    end

    # Top strip: schema + axes summary, mirrors the React Chrome row.
    smeta = spec["_meta"]
    qobs = get(smeta, "quality_observable", nothing)
    summary = string(
        "F=", F,
        "  schema=", get(smeta, "schema_version", "?"),
        "  quality=", qobs === nothing ? "none" : qobs,
        "  axes: ", x_axis.name, "×", y_axis.name,
    )
    Makie.Label(fig[0, :], summary; halign=:left, tellwidth=false,
        fontsize=11, padding=(8, 8, 4, 4))

    return fig
end

# Paper #3 FIG-6: Polyhedral inert state Majorana configurations.
#
# Output preserves the existing on-disk filename `fig-7_paper3_majorana`
# (matching the committed matplotlib renderer in docs/manuscript/.../figures/).
# The registry FIG-6 ↔ disk fig-7 offset is historical; the renderer side is
# the load-bearing contract.

function build_paper3_fig6(io::IO, paper::AbstractString, fig::AbstractString)
    dir = manuscript_figure_dir(paper)
    csv_path = joinpath(dir, "fig-7_paper3_majorana.csv")

    # `_stereo_to_sphere` is internal but stable since the U2 z=∞ → north
    # pole fix (commit a9a3d95).
    stereo = _stereo_to_sphere

    open(csv_path, "w") do f
        println(f, "panel_idx,F,label,ref,point_idx,x,y,z")
        for (panel_idx, (F, label, ref, spinor)) in
            enumerate(paper3_canonical_states())
            stars = majorana_stars(spinor, F)
            for (i, z) in enumerate(stars)
                p = stereo(z)
                println(f, "$panel_idx,$F,$label,$ref,$i,$(p[1]),$(p[2]),$(p[3])")
            end
        end
    end

    py_path = joinpath(dir, "fig-7_paper3_majorana.py")
    println(io, "OK: $paper $fig")
    println(io, "  CSV: $csv_path")
    println(io, "  renderer: $py_path (committed)")
    println(io, "  Build: python3 $py_path")
end

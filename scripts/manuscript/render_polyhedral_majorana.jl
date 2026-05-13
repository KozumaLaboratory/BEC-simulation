# Render Majorana-star configurations for the 7 polyhedral inert states
# of Paper #3 §V.A through §V.G:
#
#   F=2  T_d cyclic            (§V.A,  4 stars on tetrahedron)
#   F=3  O:A_2                 (§V.B,  6 stars on octahedron)
#   F=4  O:A_1 cube            (§V.C,  8 stars on cube)
#   F=6  I:A icosahedron       (§V.D, 12 stars on icosahedron)
#   F=8  O:A_1 cube-octa       (§V.E, 16 stars on cube∪octa orbit)
#   F=10 I:A dodecahedron      (§V.F, 20 stars on dodecahedron)
#   F=12 I:A icosahedron       (§V.G, 24 stars on I_h orbit, C_5^z invariant)
#
# Output:
#   docs/manuscript/papers/paper3_universal_theorem/figures/
#     fig-7_paper3_majorana.csv
#     fig-7_paper3_majorana.py     (matplotlib renderer)
#
# Stars are computed via SpinorBEC.majorana_stars (single source of truth —
# the same code path used in detect_point_group regression tests at
# test/hamiltonian/test_majorana.jl).
#
# Usage:
#   julia --project=. scripts/manuscript/render_polyhedral_majorana.jl
#   python3 docs/manuscript/papers/paper3_universal_theorem/figures/fig-7_paper3_majorana.py

using SpinorBEC: majorana_stars
using SpinorBEC.LinearAlgebra
using Printf
import SpinorBEC

const STEREO = SpinorBEC._stereo_to_sphere  # internal, but stable since U2 fix

# ─── canonical Paper #3 §V state spinors ─────────────────────────────────────
#
# Component order: index k+1 corresponds to m = F-k, so the first index is
# m=+F and the last is m=-F. F=0 components live at the centre index F+1.

function canonical_states()
    states = Tuple{Int, String, String, Vector{ComplexF64}}[]

    # §V.A  F=2  T_d cyclic: ζ = (1, 0, i√2, 0, 1) / 2
    let z = ComplexF64[1.0, 0.0, im*sqrt(2.0), 0.0, 1.0] ./ 2.0
        push!(states, (2, "F=2 cyclic", "T_d (§V.A)", z))
    end

    # §V.B  F=3  O:A_2:  ζ = (|+2⟩ − |−2⟩) / √2
    let z = zeros(ComplexF64, 7)
        z[2] =  1.0 / sqrt(2.0)   # m=+2
        z[6] = -1.0 / sqrt(2.0)   # m=-2
        push!(states, (3, "F=3 octa", "O:A_2 (§V.B)", z))
    end

    # §V.C  F=4  O:A_1 cube: ζ = √(5/24)|+4⟩ + √(7/12)|0⟩ + √(5/24)|−4⟩
    let z = zeros(ComplexF64, 9)
        z[1] = sqrt(5/24); z[5] = sqrt(7/12); z[9] = sqrt(5/24)
        push!(states, (4, "F=4 cube", "O:A_1 (§V.C)", z))
    end

    # §V.D  F=6  I:A canonical (ZETA_F6_IH in src/.../lhy/icosahedral.jl):
    #   ζ = √7/5(|+5⟩ − |−5⟩) + √11/5|0⟩
    # 5-fold axis along z, gives 12 distinct stars (poles + 10 mid-latitude).
    # The Barnett-Mukerjee form (ψ_+6, ψ_+1, ψ_-4) gives the same I_h state
    # but collapses 2 roots at the north pole — avoided here.
    let z = ComplexF64[
            0, sqrt(7.0)/5, 0, 0, 0, 0, sqrt(11.0)/5,
            0, 0, 0, 0, -sqrt(7.0)/5, 0,
        ]
        push!(states, (6, "F=6 icosa", "I:A (§V.D)", z))
    end

    # §V.E  F=8  O:A_1 cube-like octa: √390/48|±8⟩ + √42/24|±4⟩ + √33/8|0⟩
    let z = zeros(ComplexF64, 17)
        z[1]  = sqrt(390)/48
        z[5]  = sqrt(42)/24
        z[9]  = sqrt(33)/8
        z[13] = sqrt(42)/24
        z[17] = sqrt(390)/48
        push!(states, (8, "F=8 cube-octa", "O:A_1 (§V.E)", z))
    end

    # §V.F  F=10 I:A dodec: √561/75|±10⟩ + √209/25(|+5⟩−|−5⟩) + √741/75|0⟩
    let z = zeros(ComplexF64, 21)
        z[1]  =  sqrt(561)/75
        z[6]  =  sqrt(209)/25
        z[11] =  sqrt(741)/75
        z[16] = -sqrt(209)/25
        z[21] =  sqrt(561)/75
        push!(states, (10, "F=10 dodec", "I:A (§V.F)", z))
    end

    # §V.G  F=12 I:A icosa (C_5^z-invariant), U(1)-rotated to real form
    let z = zeros(ComplexF64, 25)
        z[3]  =  0.4871    # m=+10
        z[8]  = -0.3024    # m=+5
        z[13] =  0.5853    # m=0
        z[18] =  0.3024    # m=-5
        z[23] =  0.4871    # m=-10
        z ./= sqrt(sum(abs2, z))
        push!(states, (12, "F=12 I:A", "I:A (§V.G)", z))
    end

    states
end

# ─── compute stars + project ─────────────────────────────────────────────────

function compute_panels()
    panels = Tuple{Int, Int, String, String, Vector{NTuple{3, Float64}}}[]
    for (panel_idx, (F, label, ref, spinor)) in enumerate(canonical_states())
        stars = majorana_stars(spinor, F)
        pts = [STEREO(z) for z in stars]
        push!(panels, (panel_idx, F, label, ref, pts))
    end
    panels
end

# ─── emit CSV ────────────────────────────────────────────────────────────────

function emit_csv(panels, csv_path)
    open(csv_path, "w") do io
        println(io, "panel_idx,F,label,ref,point_idx,x,y,z")
        for (panel_idx, F, label, ref, pts) in panels
            for (i, p) in enumerate(pts)
                println(io, "$panel_idx,$F,$label,$ref,$i,$(p[1]),$(p[2]),$(p[3])")
            end
        end
    end
end

# ─── main ────────────────────────────────────────────────────────────────────
#
# The matplotlib renderer is committed at
#   docs/manuscript/papers/paper3_universal_theorem/figures/fig-7_paper3_majorana.py
# and reads the CSV emitted here. This split keeps Julia free of Python
# string-escape concerns while letting the renderer evolve independently
# (e.g. for thesis vs paper figure sizing).

function main()
    fig_dir = joinpath(@__DIR__, "..", "..", "docs", "manuscript", "papers",
                       "paper3_universal_theorem", "figures")
    mkpath(fig_dir)
    csv_path = joinpath(fig_dir, "fig-7_paper3_majorana.csv")
    py_path  = joinpath(fig_dir, "fig-7_paper3_majorana.py")

    panels = compute_panels()
    emit_csv(panels, csv_path)

    println("Wrote $csv_path")
    println()
    println("Build PDF/PNG/SVG:")
    println("  python3 $py_path")
    println()
    println("Star counts (stars are 2F per state — multiplicities flagged below):")
    for (panel_idx, F, label, ref, pts) in panels
        # cluster within tol 0.05 to detect multiplicity
        clusters = NTuple{3, Float64}[]
        for p in pts
            merged = false
            for (i, c) in enumerate(clusters)
                if sqrt(sum((p[k] - c[k])^2 for k in 1:3)) < 0.05
                    merged = true
                    break
                end
            end
            merged || push!(clusters, p)
        end
        n_geo = length(clusters)
        n_stars = length(pts)
        mult_note = n_stars == n_geo ? "$(n_stars) stars" :
                    "$(n_stars) stars = $(n_geo) × mult. $(div(n_stars, n_geo))"
        @printf("  panel %d  %-14s  %-14s  %s\n",
                panel_idx, label, ref, mult_note)
    end
end

main()

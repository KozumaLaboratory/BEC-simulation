# Paper #3 §V canonical inert-state spinors.
#
# Component order: index k+1 corresponds to m = F-k, so the first index
# is m=+F and the last is m=-F. F=0 components live at the centre index
# F+1.
#
# Each tuple is (F, label, ref, spinor) — label is for figure axes,
# `ref` is the manuscript section anchor.

export paper3_canonical_states

function paper3_canonical_states()
    states = Tuple{Int, String, String, Vector{ComplexF64}}[]

    # §V.A  F=2  T_d cyclic: ζ = (1, 0, i√2, 0, 1) / 2
    let z = ComplexF64[1.0, 0.0, im * sqrt(2.0), 0.0, 1.0] ./ 2.0
        push!(states, (2, "F=2 cyclic", "T_d (§V.A)", z))
    end
    # §V.B  F=3  O:A_2:  ζ = (|+2⟩ − |−2⟩) / √2
    let z = zeros(ComplexF64, 7)
        z[2] = 1.0 / sqrt(2.0);
        z[6] = -1.0 / sqrt(2.0)
        push!(states, (3, "F=3 octa", "O:A_2 (§V.B)", z))
    end
    # §V.C  F=4  O:A_1 cube
    let z = zeros(ComplexF64, 9)
        z[1] = sqrt(5 / 24);
        z[5] = sqrt(7 / 12);
        z[9] = sqrt(5 / 24)
        push!(states, (4, "F=4 cube", "O:A_1 (§V.C)", z))
    end
    # §V.D  F=6  I:A canonical (ZETA_F6_IH)
    let z = ComplexF64[
            0, sqrt(7.0) / 5, 0, 0, 0, 0, sqrt(11.0) / 5,
            0, 0, 0, 0, -sqrt(7.0) / 5, 0,
        ]
        push!(states, (6, "F=6 icosa", "I:A (§V.D)", z))
    end
    # F=7 O:A_2 (supplementary — m ∈ {±6, ±2})
    let z = ComplexF64[
            0,
            -0.3635626373 + 0.3114303701im,
            0, 0, 0,
            -0.3952342557 + 0.3385605063im,
            0, 0, 0,
            0.3952342557 - 0.3385605063im,
            0, 0, 0,
            0.3635626373 - 0.3114303701im,
            0,
        ]
        push!(states, (7, "F=7 octa", "O:A_2 (supp)", z))
    end
    # §V.E  F=8  O:A_1 cube-octa
    let z = zeros(ComplexF64, 17)
        z[1] = sqrt(390) / 48;
        z[5] = sqrt(42) / 24;
        z[9] = sqrt(33) / 8
        z[13] = sqrt(42) / 24;
        z[17] = sqrt(390) / 48
        push!(states, (8, "F=8 cube-octa", "O:A_1 (§V.E)", z))
    end
    # F=9 O:A_1 (supplementary — m ∈ {±8, ±4})
    let z = ComplexF64[
            0,
            0.1779105488 + 0.3379070434im,
            0, 0, 0,
            -0.2772535655 - 0.526590094im,
            0, 0, 0, 0, 0, 0, 0,
            0.2772535655 + 0.526590094im,
            0, 0, 0,
            -0.1779105488 - 0.3379070434im,
            0,
        ]
        push!(states, (9, "F=9 octa", "O:A_1 (supp)", z))
    end
    # §V.F  F=10 I:A dodec
    let z = zeros(ComplexF64, 21)
        z[1] = sqrt(561) / 75;
        z[6] = sqrt(209) / 25;
        z[11] = sqrt(741) / 75
        z[16] = -sqrt(209) / 25;
        z[21] = sqrt(561) / 75
        push!(states, (10, "F=10 dodec", "I:A (§V.F)", z))
    end
    # F=11 O:A_2 (supplementary — m ∈ {±10, ±6, ±2})
    let z = ComplexF64[
            0,
            -0.2933098261 + 0.2952057405im,
            0, 0, 0,
            -0.2288986869 + 0.2303782566im,
            0, 0, 0,
            -0.3316081934 + 0.3337516632im,
            0, 0, 0,
            0.3316081934 - 0.3337516632im,
            0, 0, 0,
            0.2288986869 - 0.2303782566im,
            0, 0, 0,
            0.2933098261 - 0.2952057405im,
            0,
        ]
        push!(states, (11, "F=11 octa", "O:A_2 (supp)", z))
    end
    # §V.G  F=12 I:A icosa (C_5^z-invariant)
    let z = zeros(ComplexF64, 25)
        z[3] = 0.4871;
        z[8] = -0.3024;
        z[13] = 0.5853
        z[18] = 0.3024;
        z[23] = 0.4871
        z ./= sqrt(sum(abs2, z))
        push!(states, (12, "F=12 I:A", "I:A (§V.G)", z))
    end
    states
end

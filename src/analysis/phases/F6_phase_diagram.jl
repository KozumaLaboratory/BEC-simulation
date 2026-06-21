export compute_F6_phase_diagram, summarize_F6_phase_diagram,
    dump_F6_phase_diagram_json

using JSON

"""
F=6 mean-field phase diagram in the (g_10, g_12) plane.

At each grid point compares the contact mean-field energy density of four
candidate spinors:

  polar     ζ = e_0                                       (uniaxial nematic)
  FM        ζ = e_{+F}                                    (ferromagnetic)
  cyclic    ζ = (e_{+F} + e^{i 2π/3} e_0 + e^{i 4π/3} e_{-F}) / √3
  I_h       canonical icosahedral state (ZETA_F6_IH)

Per-spinor mean-field energy density:

  ε_MF(ζ; g_S, n) = (n²/2) Σ_S g_S σ_S(ζ),
      σ_S(ζ) = Σ_M | Σ_{m1,m2} ⟨S,M|F,m1; F,m2⟩ ζ_{m1} ζ_{m2} |²

Linearised boundary coefficients (parallel-session derivation):
  I_h vs polar:  +(20433/96577) δg_10 + (-56/391)   δg_12 = 0
  I_h vs FM:     +(147/391)     δg_10 + (-4701/5681) δg_12 = 0
"""
const _F6_PD_F = 6
const _F6_PD_D = 2 * _F6_PD_F + 1
const _F6_PD_G_FIXED = (1.0, 1.0, 1.0, 1.0, 1.0)  # g_0, g_2, g_4, g_6, g_8

const _F6_PD_COEF_IH_VS_POLAR = Dict{Int, Float64}(
    0 => 0.0,
    2 => -14 / 143,
    4 => -252 / 2431,
    6 => 49 / 187,
    8 => -350 / 2717,
    10 => 20433 / 96577,
    12 => -56 / 391,
)
const _F6_PD_COEF_IH_VS_FM = Dict{Int, Float64}(
    0 => 1 / 13,
    2 => 0.0,
    4 => 0.0,
    6 => 121 / 323,
    8 => 0.0,
    10 => 147 / 391,
    12 => -4701 / 5681,
)

function _f6_pd_candidate_spinors()::Dict{Symbol, Vector{ComplexF64}}
    F = _F6_PD_F
    D = _F6_PD_D
    polar = zeros(ComplexF64, D)
    polar[F + 1] = 1.0

    fm = zeros(ComplexF64, D)
    fm[1] = 1.0

    cyclic = zeros(ComplexF64, D)
    inv_sqrt3 = 1.0 / sqrt(3.0)
    cyclic[1] = inv_sqrt3
    cyclic[F + 1] = inv_sqrt3 * cis(2π / 3)
    cyclic[D] = inv_sqrt3 * cis(4π / 3)

    Dict(:polar => polar, :FM => fm, :cyclic => cyclic,
        :I_h => copy(ZETA_F6_IH))
end

function _f6_pd_sigma_S(F::Int, S::Int, ζ::AbstractVector{ComplexF64})::Float64
    σ = 0.0
    for M in (-S):S
        amp = 0.0 + 0.0im
        for m1 in (-F):F
            m2 = M - m1
            (-F <= m2 <= F) || continue
            cg = clebsch_gordan(F, m1, F, m2, S, M)
            cg == 0 && continue
            ζ1 = ζ[F - m1 + 1]
            ζ2 = ζ[F - m2 + 1]
            amp += cg * ζ1 * ζ2
        end
        σ += abs2(amp)
    end
    σ
end

function _f6_pd_mf_energy(ζ::AbstractVector{ComplexF64}, g_S::Vector{Float64})::Float64
    e = 0.0
    for (i, S) in enumerate(0:2:12)
        e += g_S[i] * _f6_pd_sigma_S(_F6_PD_F, S, ζ)
    end
    e / 2
end

function _f6_pd_g_S_vec(g10::Float64, g12::Float64)
    [_F6_PD_G_FIXED[1], _F6_PD_G_FIXED[2], _F6_PD_G_FIXED[3],
        _F6_PD_G_FIXED[4], _F6_PD_G_FIXED[5], g10, g12]
end

"""
    compute_F6_phase_diagram(; nscan=50, g_range=range(0.5, 1.5; length=nscan))

Compute the F=6 (g_10, g_12) mean-field phase grid. Returns a NamedTuple
with `energies` (Dict label => Matrix), `winner` (Matrix{Symbol}),
`g10_range`, `g12_range`, `spinors`, `labels`, `nscan`.
"""
function compute_F6_phase_diagram(;
    nscan::Int=50,
    g_range::AbstractVector{<:Real}=range(0.5, 1.5; length=nscan),
)
    spinors = _f6_pd_candidate_spinors()
    labels = (:polar, :FM, :cyclic, :I_h)
    energies = Dict(label => zeros(nscan, nscan) for label in labels)
    winner = fill(:polar, nscan, nscan)
    for (i, g10) in enumerate(g_range)
        for (j, g12) in enumerate(g_range)
            g_S = _f6_pd_g_S_vec(g10, g12)
            best_label, best_e = first(labels), Inf
            for label in labels
                e = _f6_pd_mf_energy(spinors[label], g_S)
                energies[label][i, j] = e
                if e < best_e
                    best_e, best_label = e, label
                end
            end
            winner[i, j] = best_label
        end
    end
    (; energies, winner,
        g10_range=collect(g_range), g12_range=collect(g_range),
        spinors, labels, nscan)
end

"""
    summarize_F6_phase_diagram(io, result)

Print the winner-symbol grid, linearised I_h vs {polar, FM} boundary
slopes, and the per-spinor energy at the Eu reference point.
"""
function summarize_F6_phase_diagram(io::IO, result)
    nscan = result.nscan
    winner = result.winner
    g_range = result.g10_range
    sym = Dict(:polar => "P", :FM => "F", :cyclic => "C", :I_h => "I")
    println(io, "Phase grid (rows: g_10, columns: g_12; both ∈ ",
        "[$(first(g_range)), $(last(g_range))]):\n")
    print(io, "       ")
    for j in 1:5:nscan
        @printf io "%5.2f " g_range[j]
    end
    println(io)
    for i in 1:5:nscan
        @printf io "%4.2f  " g_range[i]
        for j in 1:5:nscan
            print(io, sym[winner[i, j]], "    ")
        end
        println(io)
    end
    println(io, "\nLegend: P=polar, F=FM, C=cyclic, I=I_h\n")

    bp_a, bp_b = _F6_PD_COEF_IH_VS_POLAR[10], _F6_PD_COEF_IH_VS_POLAR[12]
    bf_a, bf_b = _F6_PD_COEF_IH_VS_FM[10], _F6_PD_COEF_IH_VS_FM[12]
    slope_p = iszero(bp_b) ? Inf : -bp_a / bp_b
    slope_f = iszero(bf_b) ? Inf : -bf_a / bf_b
    println(io, "Parallel-session linearised boundaries (origin at g_S = 1):")
    @printf io "  I_h vs polar :  δg_12 = %+8.4f · δg_10\n" slope_p
    @printf io "  I_h vs FM    :  δg_12 = %+8.4f · δg_10\n" slope_f
    println(io)

    @printf io "Energy at Eu reference (g_10=1.0, g_12=1.0):\n"
    g_eu = _f6_pd_g_S_vec(1.0, 1.0)
    for label in result.labels
        ζ = result.spinors[label]
        e = _f6_pd_mf_energy(ζ, g_eu)
        @printf io "  %-7s : %+.6e\n" String(label) e
    end
    return nothing
end

summarize_F6_phase_diagram(result) = summarize_F6_phase_diagram(stdout, result)

"""
    dump_F6_phase_diagram_json(result; out_path)

Write the phase-grid result as JSON for downstream plotting. Default
path is `runs/F6_phase_diagram/result.json`.
"""
function dump_F6_phase_diagram_json(
    result;
    out_path::AbstractString=joinpath("runs", "F6_phase_diagram", "result.json"),
)
    mkpath(dirname(out_path))
    payload = Dict(
        "F" => _F6_PD_F,
        "g_fixed" => Dict(2k => _F6_PD_G_FIXED[k + 1] for k in 0:4),
        "g_10_range" => result.g10_range,
        "g_12_range" => result.g12_range,
        "n_scan" => result.nscan,
        "energies" => Dict(String(label) => result.energies[label]
                           for label in result.labels),
        "winner" => [String(result.winner[i, j])
                     for i in 1:(result.nscan), j in 1:(result.nscan)],
        "linear_boundaries" => Dict(
            "I_h_vs_polar" => _F6_PD_COEF_IH_VS_POLAR,
            "I_h_vs_FM" => _F6_PD_COEF_IH_VS_FM,
        ),
    )
    open(out_path, "w") do f
        JSON.print(f, payload, 2)
    end
    return out_path
end

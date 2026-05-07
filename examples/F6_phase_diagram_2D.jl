# F=6 mean-field phase diagram in the (g_10, g_12) plane (Round-3 Task 3).
#
# Scans 50×50 grid points with g_0 = g_2 = g_4 = g_6 = g_8 = 1 fixed and
# (g_10, g_12) ∈ [0.5, 1.5]². At each point compares the contact mean-field
# energy density of four candidate spinors:
#
#   polar     ζ = e_0                                       (uniaxial nematic)
#   FM        ζ = e_{+F}                                    (ferromagnetic)
#   cyclic    ζ = (e_{+F} + e^{i 2π/3} e_0 + e^{i 4π/3} e_{-F}) / √3
#   I_h       ζ = (0, √7/5, 0,...,0, √11/5, 0,...,0, -√7/5, 0)
#
# Per-spinor mean-field energy density:
#
#   ε_MF(ζ; g_S, n) = (n²/2) Σ_S g_S σ_S(ζ),
#       σ_S(ζ) = Σ_M | Σ_{m1,m2} ⟨S,M|F,m1; F,m2⟩ ζ_{m1} ζ_{m2} |²
#
# Overlays the parallel-session linearised phase boundary lines:
#   I_h vs polar:  +(20433/96577) δg_10 + (-56/391)   δg_12 = 0
#   I_h vs FM:     +(147/391)     δg_10 + (-4701/5681) δg_12 = 0
#
# Output: prints a small text grid + a JSON dump under `runs/F6_phase_diagram/`
# so the user can pull it into any plotting tool. No Plots.jl dependency,
# so this script runs in any Julia environment that has SpinorBEC loaded.

using SpinorBEC
using SpinorBEC: clebsch_gordan
using SpinorBEC.IcosahedralLHY: ZETA_F6_IH
using JSON
using Printf

const F = 6
const D = 2F + 1
const G_FIXED = (1.0, 1.0, 1.0, 1.0, 1.0)   # g_0, g_2, g_4, g_6, g_8
const NSCAN = 50
const G_RANGE = range(0.5, 1.5; length=NSCAN)

# Candidate spinors (component order m = +F, +F-1, ..., -F)
function candidate_spinors()::Dict{Symbol, Vector{ComplexF64}}
    polar = zeros(ComplexF64, D)
    polar[F + 1] = 1.0   # m=0 lives at index F+1 = 7

    fm = zeros(ComplexF64, D)
    fm[1] = 1.0          # m=+F at index 1

    cyclic = zeros(ComplexF64, D)
    inv_sqrt3 = 1.0 / sqrt(3.0)
    cyclic[1] = inv_sqrt3                            # m=+F
    cyclic[F + 1] = inv_sqrt3 * cis(2π / 3)         # m=0
    cyclic[D] = inv_sqrt3 * cis(4π / 3)             # m=-F

    Dict(:polar => polar, :FM => fm, :cyclic => cyclic, :I_h => copy(ZETA_F6_IH))
end

# σ_S(ζ) = ⟨ζ ⊗ ζ | P_S | ζ ⊗ ζ⟩
function sigma_S(F::Int, S::Int, ζ::AbstractVector{ComplexF64})::Float64
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

# Mean-field energy at unit density: ε(ζ; g_S) = (1/2) Σ_S g_S σ_S(ζ)
function mf_energy(ζ::AbstractVector{ComplexF64}, g_S::Vector{Float64})::Float64
    e = 0.0
    for (i, S) in enumerate(0:2:12)
        e += g_S[i] * sigma_S(F, S, ζ)
    end
    e / 2
end

# Linearised boundary coefficients (parallel-session derivation)
const COEF_IH_VS_POLAR = Dict(
    0 => 0.0,                  # δg_0 cancels (both share)
    2 => -14 / 143,
    4 => -252 / 2431,
    6 => 49 / 187,
    8 => -350 / 2717,
    10 => 20433 / 96577,
    12 => -56 / 391,
)
const COEF_IH_VS_FM = Dict(
    0 => 1 / 13,
    2 => 0.0,
    4 => 0.0,
    6 => 121 / 323,
    8 => 0.0,
    10 => 147 / 391,
    12 => -4701 / 5681,
)

# Boundary in the (δg_10, δg_12) slice with all other δg_S = 0
function linear_boundary_g10_g12(coefs::Dict{Int, Float64})
    a = coefs[10]
    b = coefs[12]
    # Boundary: a · δg_10 + b · δg_12 = 0, i.e. δg_12 = -(a/b) δg_10
    iszero(b) && return (slope=Inf, slope_inv=0.0)
    (slope=-a / b, slope_inv=-b / a)
end

function _g_S_vec(g10::Float64, g12::Float64)
    [G_FIXED[1], G_FIXED[2], G_FIXED[3], G_FIXED[4], G_FIXED[5], g10, g12]
end

function compute_phase_grid()
    spinors = candidate_spinors()
    labels = (:polar, :FM, :cyclic, :I_h)
    energies = Dict(label => zeros(NSCAN, NSCAN) for label in labels)
    winner = fill(:polar, NSCAN, NSCAN)
    for (i, g10) in enumerate(G_RANGE)
        for (j, g12) in enumerate(G_RANGE)
            g_S = _g_S_vec(g10, g12)
            best_label, best_e = first(labels), Inf
            for label in labels
                e = mf_energy(spinors[label], g_S)
                energies[label][i, j] = e
                if e < best_e
                    best_e, best_label = e, label
                end
            end
            winner[i, j] = best_label
        end
    end
    (; energies, winner, g10_range=collect(G_RANGE), g12_range=collect(G_RANGE),
        spinors, labels)
end

function print_winner_grid(winner::Matrix{Symbol})
    sym = Dict(:polar => "P", :FM => "F", :cyclic => "C", :I_h => "I")
    println("Phase grid (rows: g_10, columns: g_12; both ∈ [0.5, 1.5]):\n")
    print("       ")
    for j in 1:5:NSCAN
        @printf("%5.2f ", G_RANGE[j])
    end
    println()
    for i in 1:5:NSCAN
        @printf("%4.2f  ", G_RANGE[i])
        for j in 1:5:NSCAN
            print(sym[winner[i, j]], "    ")
        end
        println()
    end
    println("\nLegend: P=polar, F=FM, C=cyclic, I=I_h\n")
end

function summarize_boundaries(result)
    bp = linear_boundary_g10_g12(COEF_IH_VS_POLAR)
    bf = linear_boundary_g10_g12(COEF_IH_VS_FM)
    println("Parallel-session linearised boundaries (origin at g_S = 1):")
    @printf("  I_h vs polar :  δg_12 = %+8.4f · δg_10   (slope %+.4f)\n",
        bp.slope, bp.slope)
    @printf("  I_h vs FM    :  δg_12 = %+8.4f · δg_10   (slope %+.4f)\n",
        bf.slope, bf.slope)
    println()

    # Eu marker (1, 1) → δg = 0 → all candidates degenerate at the linearisation;
    # the actual MF winner depends on second-order corrections and ε_dd / DDI.
    @printf("Energy at Eu reference (g_10=1.0, g_12=1.0):\n")
    g_eu = _g_S_vec(1.0, 1.0)
    for label in result.labels
        ζ = result.spinors[label]
        e = mf_energy(ζ, g_eu)
        @printf("  %-7s : %+.6e\n", String(label), e)
    end
end

function dump_json(
    result; out_path::String=
    joinpath(dirname(@__DIR__), "runs", "F6_phase_diagram", "result.json")
)
    mkpath(dirname(out_path))
    payload = Dict(
        "F" => F,
        "g_fixed" => Dict(2k => G_FIXED[k + 1] for k in 0:4),
        "g_10_range" => result.g10_range,
        "g_12_range" => result.g12_range,
        "n_scan" => NSCAN,
        "energies" => Dict(String(label) => result.energies[label] for label in result.labels),
        "winner" => [String(result.winner[i, j]) for i in 1:NSCAN, j in 1:NSCAN],
        "linear_boundaries" => Dict(
            "I_h_vs_polar" => COEF_IH_VS_POLAR,
            "I_h_vs_FM" => COEF_IH_VS_FM,
        ),
    )
    open(out_path, "w") do f
        JSON.print(f, payload, 2)
    end
    println("Wrote $out_path  ($(filesize(out_path)) bytes)")
end

function main()
    println("=== F=6 mean-field phase diagram in (g_10, g_12) ===\n")
    result = compute_phase_grid()
    print_winner_grid(result.winner)
    summarize_boundaries(result)
    dump_json(result)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

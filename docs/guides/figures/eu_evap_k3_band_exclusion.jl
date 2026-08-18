# Does any physically-allowed K₃ reproduce the measured ¹⁵¹Eu BEC endpoint? (issue #75)
#
# The euv3 defaults hit the measured N_BEC = 5.02e4 at a FITTED K₃. This sweeps K₃ across
# and beyond the universal van-der-Waals band that Eu's (unmeasured) three-body rate is
# allowed to live in — K₃ = 3C ℏa⁴/m (Braaten–Hammer), C ∈ [0,67], a = 110a₀ ⇒ K₃ ≤ 1e-40
# m⁶/s — at both the shipped T₀ = 50 µK and the 2023-epoch T₀ = 18 µK, and records where
# each curve crosses the measurement. It also dumps the four anchor combinations with their
# η_start, because the loaded depth is the other half of the story: the shipped defaults
# give η_start = 2.07, below the eta_min = 4 floor (see docs/guides/evaporation_model.md).

using SpinorBEC
using Printf

const OUT = length(ARGS) >= 1 ? ARGS[1] : "k3_band_out"
mkpath(OUT)

const MEASURED_N_BEC = 5.02e4          # Miyazawa/Matsui et al. PRL 129, 223401 (2022)
const BAND_HI = 1.0e-40                # universal vdW top, C = 67 at a = 110a₀
const BAND_LO = 1.0e-42

function arm(T0, K3)
    s = evaporation_summary(run_euv3_evaporation(; T0=T0, K3=K3))
    (reached=s.reached_bec,
        N=(s.reached_bec && isfinite(s.N_BEC)) ? s.N_BEC : NaN,
        T=s.T_BEC_uK, eta=s.eta_start)
end

# --- sweep ---
K3s = 10 .^ range(-42.3, -39.3; length=25)
open(joinpath(OUT, "k3_sweep.csv"), "w") do io
    println(io, "K3_m6_per_s,T0_uK,eta_start,reached_bec,N_BEC,T_BEC_uK")
    for (T0, lbl) in ((50e-6, 50), (18e-6, 18)), k in K3s
        a = arm(T0, k)
        @printf(io, "%.6g,%d,%.5f,%d,%.6g,%.6g\n",
            k, lbl, a.eta, a.reached ? 1 : 0, a.N, a.T)
    end
end

# --- the four anchor combinations ---
d = euv3_defaults()
open(joinpath(OUT, "k3_anchors.csv"), "w") do io
    println(io, "label,T0_uK,K3_m6_per_s,eta_start,N_BEC,T_BEC_uK,ratio_to_measured")
    for (lbl, T0, K3) in (("shipped", 50e-6, d.K3),
        ("T0+K3", 18e-6, 1e-41),
        ("T0 only", 18e-6, d.K3),
        ("K3 only", 50e-6, 1e-41))
        a = arm(T0, K3)
        @printf(io, "%s,%.3g,%.6g,%.5f,%.6g,%.6g,%.5f\n",
            lbl, T0 * 1e6, K3, a.eta, a.N, a.T, a.N / MEASURED_N_BEC)
    end
end

# --- where does each curve cross the measurement? (log-log interpolation) ---
open(joinpath(OUT, "k3_crossings.csv"), "w") do io
    println(io, "T0_uK,K3_crossing_m6_per_s,band_hi_m6_per_s,factor_above_band")
    for (T0, lbl) in ((50e-6, 50), (18e-6, 18))
        pts = sort([(k, arm(T0, k).N) for k in K3s])
        cross = NaN
        for i in 1:(length(pts) - 1)
            (x1, y1), (x2, y2) = pts[i], pts[i + 1]
            (isfinite(y1) && isfinite(y2)) || continue
            if (y1 - MEASURED_N_BEC) * (y2 - MEASURED_N_BEC) < 0
                t = (log(MEASURED_N_BEC) - log(y1)) / (log(y2) - log(y1))
                cross = exp(log(x1) + t * (log(x2) - log(x1)))
            end
        end
        @printf(io, "%d,%.6g,%.6g,%.4f\n", lbl, cross, BAND_HI, cross / BAND_HI)
    end
end

println("wrote k3_sweep.csv, k3_anchors.csv, k3_crossings.csv to $OUT")

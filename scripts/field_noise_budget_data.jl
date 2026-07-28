# Emit the data behind docs/figs/field_noise_vs_weak_field_scale.png:
# a B_z ramp through the weak-field Eu window under the SHIELDED budget —
# permalloy shield with AC degaussing, so the AC terms sit well below the
# static residual.
#
# The figure separates the two error terms because they fail differently. The
# AC part (this module) barely textures the ramp at that level. The static
# residual is NOT modelled as noise: it is a different value of the field, so
# it enters as a set of chosen offsets — i.e. as a scan axis, which is how it
# should be measured.
#
# Units are LAB units — seconds, Hz, Gauss.
#
#   julia --project=. scripts/field_noise_budget_data.jl [out.csv]

using SpinorBEC
using SpinorBEC: FieldNoiseSpec, field_noise_waveform, evaluate, noise_rms

const DURATION = 0.200            # s
const B_START = 62.0e-6           # Gauss
const B_END = 30.0e-6             # Gauss

# Static residual after permalloy + degauss, as an explicit scan axis.
const OFFSETS = (-10.0e-6, 0.0, 10.0e-6)

# AC residual behind the shield: mains lines and the 1/f floor survive at the
# sub-µG level. Illustrative for the shielded regime — replace with the
# measured spectrum once it exists.
const AC = FieldNoiseSpec(;
    seed=11,
    lines=[(50.0, 3.0e-7), (150.0, 1.0e-7)],
    shape=:pink, rms=2.0e-7,
    f_lo=1.0, f_hi=500.0, f_corner=10.0, n_components=384,
)

out = length(ARGS) >= 1 ? ARGS[1] : "field_noise_budget.csv"
ts = range(0.0, DURATION; length=8001)
ramp(t) = B_START + (B_END - B_START) * (t / DURATION)

ac = field_noise_waveform(AC, DURATION)
println(stderr, "AC residual rms = $(round(noise_rms(ac) * 1e6; digits=3)) µG")

open(out, "w") do io
    println(io, "t_s,B_clean_G," *
                join(["B_off$(i)_G" for i in eachindex(OFFSETS)], ","))
    for t in ts
        vals = (ramp(t) + off + evaluate(ac, t) for off in OFFSETS)
        println(io, join((t, ramp(t), vals...), ","))
    end
end
println("wrote $out  (offsets µG: $(join(round.(collect(OFFSETS) .* 1e6; digits=1), ", ")))")

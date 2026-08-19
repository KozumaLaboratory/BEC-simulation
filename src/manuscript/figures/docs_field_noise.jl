# docs FIG-FIELD-NOISE: B_z ramp through the weak-field Eu window under the
# SHIELDED field-noise budget — permalloy shield with AC degaussing, so the AC
# terms sit well below the static residual. Output target (unchanged from the
# script pair this absorbed): docs/figs/field_noise_vs_weak_field_scale.png.
#
# The figure separates the two error terms because they fail differently. The
# AC part barely textures the ramp at that level. The static residual is NOT
# modelled as noise: it is a different value of the field, so it enters as a
# set of chosen offsets — i.e. as a scan axis, which is how it should be
# measured.
#
# Units are LAB units — seconds, Hz, Gauss.

function build_docs_field_noise(io::IO, paper::AbstractString,
    fig::AbstractString)
    duration = 0.200            # s
    b_start = 62.0e-6           # Gauss
    b_end = 30.0e-6             # Gauss

    # Static residual after permalloy + degauss, as an explicit scan axis.
    offsets = (-10.0e-6, 0.0, 10.0e-6)

    # AC residual behind the shield: mains lines and the 1/f floor survive at
    # the sub-µG level. Illustrative for the shielded regime — replace with
    # the measured spectrum once it exists.
    ac_spec = FieldNoiseSpec(;
        seed=11,
        lines=[(50.0, 3.0e-7), (150.0, 1.0e-7)],
        shape=:pink, rms=2.0e-7,
        f_lo=1.0, f_hi=500.0, f_corner=10.0, n_components=384,
    )

    ts = range(0.0, duration; length=8001)
    ramp(t) = b_start + (b_end - b_start) * (t / duration)
    ac = field_noise_waveform(ac_spec, duration)
    println(io, "AC residual rms = $(round(noise_rms(ac) * 1e6; digits=3)) µG")

    buf = IOBuffer()
    println(buf, "t_s,B_clean_G," *
                 join(["B_off$(i)_G" for i in eachindex(offsets)], ","))
    for t in ts
        vals = (ramp(t) + off + evaluate(ac, t) for off in offsets)
        println(buf, join((t, ramp(t), vals...), ","))
    end

    py = """
#!/usr/bin/env python3
\"\"\"Plot a B_z ramp through the weak-field Eu window under the shielded budget.

Reads the sibling CSV, writes the sibling .png (the docs/figs/ target).
\"\"\"
import csv

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Feature scale from the 2026-07-15 convergence-gated re-analysis of the
# weak-field Eu ground state (kappa-dependent order; B_eq = 61.9 uG at
# kappa = 1.8, <F_perp> drop near 40-42 uG). Used here only to set the
# vertical scale the field error has to be read against.
FEATURE_LO, FEATURE_HI = 40.0, 62.0

OFFSET_COLORS = ["#b5622a", "#7a5a9b", "#3f7a4d"]
OFFSET_LABELS = ["−10 µG", "0", "+10 µG"]

src = __file__.replace(".py", ".csv")
dst = __file__.replace(".py", ".png")

with open(src) as fh:
    rows = list(csv.DictReader(fh))
t = [float(r["t_s"]) * 1e3 for r in rows]                 # ms
ug = lambda key: [float(r[key]) * 1e6 for r in rows]      # Gauss -> uG
offs = [k for k in rows[0] if k.startswith("B_off")]

fig, ax = plt.subplots(figsize=(8.8, 5.3))

ax.axhspan(FEATURE_LO, FEATURE_HI, color="#6b8fb5", alpha=0.13, lw=0)
ax.annotate("weak-field feature window\\n(⟨F⊥⟩ drop → first-order jump)",
            xy=(0.015, 0.955), xycoords="axes fraction",
            ha="left", va="top", fontsize=9.5, color="#41618a")

clean = ug("B_clean_G")
for i, key in enumerate(offs):
    ax.plot(t, ug(key), color=OFFSET_COLORS[i % len(OFFSET_COLORS)], lw=1.5,
            alpha=0.9, label=f"static residual {OFFSET_LABELS[i]}")
ax.plot(t, clean, color="#22303c", lw=2.6, label="intended ramp")

ax.set_xlabel("time  [ms]")
ax.set_ylabel(r"\$B_z\$   [µG]")
ax.set_xlim(t[0], t[-1])
ax.set_ylim(10, 85)
ax.set_title("Permalloy shield + AC degauss: the limit is a rigid offset, "
             "not jitter\\n"
             "AC residual < 0.5 µG rms · static residual ≈ 10 µG",
             fontsize=11, loc="left")
ax.grid(alpha=0.22, lw=0.5)
ax.legend(frameon=False, loc="lower left", fontsize=9)

ax.annotate("curves are PARALLEL, not fuzzy: a hysteresis loop keeps its\\n"
            "width and only the absolute jump field shifts. So the residual\\n"
            "is a scan axis, not a noise term",
            xy=(0.985, 0.955), xycoords="axes fraction",
            ha="right", va="top", fontsize=9.5, color="#4a4a4a")

fig.tight_layout()
fig.savefig(dst, dpi=150, bbox_inches="tight")
print(f"wrote {dst}")
"""
    _emit_csv_py(io, paper, fig, String(take!(buf)), py;
        basename="field_noise_vs_weak_field_scale")
end

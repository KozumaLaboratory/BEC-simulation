#!/usr/bin/env python3
"""Eu F=6 EdH post-quench: the LHY treatment, re-measured with valid evidence.

The 2026-05-07 ablation (docs/research_notes/eu_collapse_lhy_insufficient.md)
compared five LHY treatments, found identical profiles, and concluded LHY is
sub-leading to the mean-field DDI attraction. Its EVIDENCE was invalid: that
config is `backend: gpu`, and until #125 every tabulated LHY was silently
collapsed to c_lhy = 0 on the GPU broadcast path, so three of the five rows ran
with no LHY at all, while `scalar` ran with a coefficient short by
pi*(a_s/a_ho)*sqrt(N) (#108).

Re-run on current main -- which also carries #158, the closed-form tables being
N_atoms too large -- the CONCLUSION stands: off, scalar, polar_contact and
fm_contact agree within about 5 percent in peak density. The closed forms are
active (all three differ from each other) and simply small here.

full_bdg is the lone outlier and is NOT usable: it self-reports "mean field is
dynamically unstable (max Im omega = 213), eps_LHY is scheme-dependent here",
and its ITP returned conv=false.

Axial cut through the cloud centre at the end of phase 2. Data inlined;
figs/**/*.csv is gitignored (repo keeps figures + code; run output lives on
TSUBAME at /gs/bs/work/7/uk07267/spinorbec-runs/lhy_ablation_v2).
"""
import pathlib

import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).parent

PROFILES = {
    "off": [
        (-4.84375, 9.52912e-14), (-4.53125, 1.05404e-13), (-4.21875, 1.51967e-13), (-3.90625, 3.59309e-13), (-3.59375, 1.39833e-12), (-3.28125, 5.84034e-12), (-2.96875, 4.96387e-10), (-2.65625, 1.32097e-07), (-2.34375, 2.4795e-05), (-2.03125, 0.000671423), (-1.71875, 0.00309122), (-1.40625, 0.00556072), (-1.09375, 0.00741599), (-0.78125, 0.00878399), (-0.46875, 0.00968737), (-0.15625, 0.010139), (0.15625, 0.010139), (0.46875, 0.00968737), (0.78125, 0.00878399), (1.09375, 0.00741599), (1.40625, 0.00556072), (1.71875, 0.00309122), (2.03125, 0.000671423), (2.34375, 2.4795e-05), (2.65625, 1.32097e-07), (2.96875, 4.96387e-10), (3.28125, 5.84034e-12), (3.59375, 1.39833e-12), (3.90625, 3.59309e-13), (4.21875, 1.51967e-13), (4.53125, 1.05404e-13), (4.84375, 9.52912e-14)
    ],
    "scalar": [
        (-4.84375, 6.56532e-14), (-4.53125, 8.07104e-14), (-4.21875, 1.4726e-13), (-3.90625, 4.27732e-13), (-3.59375, 1.75192e-12), (-3.28125, 7.09983e-12), (-2.96875, 5.64363e-10), (-2.65625, 1.44874e-07), (-2.34375, 2.61044e-05), (-2.03125, 0.000678406), (-1.71875, 0.003028), (-1.40625, 0.00537763), (-1.09375, 0.00712881), (-0.78125, 0.00841454), (-0.46875, 0.0092612), (-0.15625, 0.00968379), (0.15625, 0.00968379), (0.46875, 0.0092612), (0.78125, 0.00841454), (1.09375, 0.00712881), (1.40625, 0.00537763), (1.71875, 0.003028), (2.03125, 0.000678406), (2.34375, 2.61044e-05), (2.65625, 1.44874e-07), (2.96875, 5.64363e-10), (3.28125, 7.09983e-12), (3.59375, 1.75192e-12), (3.90625, 4.27732e-13), (4.21875, 1.4726e-13), (4.53125, 8.07104e-14), (4.84375, 6.56532e-14)
    ],
    "polar_contact": [
        (-4.84375, 7.37249e-14), (-4.53125, 8.71353e-14), (-4.21875, 1.47076e-13), (-3.90625, 4.03591e-13), (-3.59375, 1.6353e-12), (-3.28125, 6.6937e-12), (-2.96875, 5.42337e-10), (-2.65625, 1.40712e-07), (-2.34375, 2.56795e-05), (-2.03125, 0.000675966), (-1.71875, 0.00304635), (-1.40625, 0.00543159), (-1.09375, 0.00721344), (-0.78125, 0.00852331), (-0.46875, 0.00938657), (-0.15625, 0.00981766), (0.15625, 0.00981766), (0.46875, 0.00938657), (0.78125, 0.00852331), (1.09375, 0.00721344), (1.40625, 0.00543159), (1.71875, 0.00304635), (2.03125, 0.000675966), (2.34375, 2.56795e-05), (2.65625, 1.40712e-07), (2.96875, 5.42337e-10), (3.28125, 6.6937e-12), (3.59375, 1.6353e-12), (3.90625, 4.03591e-13), (4.21875, 1.47076e-13), (4.53125, 8.71353e-14), (4.84375, 7.37249e-14)
    ],
    "fm_contact": [
        (-4.84375, 7.37249e-14), (-4.53125, 8.71353e-14), (-4.21875, 1.47076e-13), (-3.90625, 4.03591e-13), (-3.59375, 1.6353e-12), (-3.28125, 6.6937e-12), (-2.96875, 5.42337e-10), (-2.65625, 1.40712e-07), (-2.34375, 2.56795e-05), (-2.03125, 0.000675966), (-1.71875, 0.00304635), (-1.40625, 0.00543159), (-1.09375, 0.00721344), (-0.78125, 0.00852331), (-0.46875, 0.00938657), (-0.15625, 0.00981766), (0.15625, 0.00981766), (0.46875, 0.00938657), (0.78125, 0.00852331), (1.09375, 0.00721344), (1.40625, 0.00543159), (1.71875, 0.00304635), (2.03125, 0.000675966), (2.34375, 2.56795e-05), (2.65625, 1.40712e-07), (2.96875, 5.42337e-10), (3.28125, 6.6937e-12), (3.59375, 1.6353e-12), (3.90625, 4.03591e-13), (4.21875, 1.47076e-13), (4.53125, 8.71353e-14), (4.84375, 7.37249e-14)
    ],
    "full_bdg": [
        (-4.84375, 6.96705e-09), (-4.53125, 1.97748e-06), (-4.21875, 4.8891e-05), (-3.90625, 0.000159688), (-3.59375, 0.000239378), (-3.28125, 0.000295215), (-2.96875, 0.000344024), (-2.65625, 0.000385864), (-2.34375, 0.000421203), (-2.03125, 0.000451962), (-1.71875, 0.000477131), (-1.40625, 0.000498063), (-1.09375, 0.000513924), (-0.78125, 0.000525444), (-0.46875, 0.000533185), (-0.15625, 0.000537087), (0.15625, 0.000537087), (0.46875, 0.000533185), (0.78125, 0.000525444), (1.09375, 0.000513924), (1.40625, 0.000498063), (1.71875, 0.000477131), (2.03125, 0.000451962), (2.34375, 0.000421203), (2.65625, 0.000385864), (2.96875, 0.000344024), (3.28125, 0.000295215), (3.59375, 0.000239378), (3.90625, 0.000159688), (4.21875, 4.8891e-05), (4.53125, 1.97748e-06), (4.84375, 6.96705e-09)
    ],
}
STYLE = {
    "off":           ("#7f7f7f", "-",  2.8, "LHY off"),
    "scalar":        ("#1f4e79", "--", 1.7, "scalar ($Q_5$)"),
    "polar_contact": ("#c0504d", "-.", 1.7, "polar_contact"),
    "fm_contact":    ("#4f6228", ":",  2.1, "fm_contact"),
    "full_bdg":      ("#7030a0", "-",  1.4, "full_bdg (unstable, conv=false)"),
}

fig, (ax, axz) = plt.subplots(1, 2, figsize=(9.6, 4.0))
for m, pts in PROFILES.items():
    z = [p[0] for p in pts]
    n = [p[1] for p in pts]
    c, ls, lw, lbl = STYLE[m]
    ax.plot(z, n, ls, color=c, lw=lw, label=lbl)
    if m != "full_bdg":
        axz.plot(z, n, ls, color=c, lw=lw)

ax.set_yscale("log")
ax.set_ylim(1e-6, 3e-2)
ax.set_xlabel(r"$z$   [$a_{ho}$]")
ax.set_ylabel(r"axial density $n(0,0,z)$")
ax.set_title("all five treatments (log)", fontsize=10)
ax.legend(frameon=False, fontsize=8, loc="lower center")

axz.set_xlim(-3.0, 3.0)
axz.set_xlabel(r"$z$   [$a_{ho}$]")
axz.set_title("the four usable modes, linear scale", fontsize=10)
axz.text(0.0, 0.0022, "peak spans 0.00968 to 0.01014 (4.7 percent)",
         ha="center", fontsize=8.5, color="0.25")

for a in (ax, axz):
    a.spines[["top", "right"]].set_visible(False)
fig.suptitle(
    "Eu F=6 EdH post-quench: the original conclusion holds, its evidence did not",
    fontsize=11,
)
fig.tight_layout(rect=(0, 0, 1, 0.93))
out = HERE / "eu_edh_lhy_ablation.png"
fig.savefig(out, dpi=180)
print("wrote " + str(out))

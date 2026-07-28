"""P2 completion Tasks 2+3: multi-Omega Delta-Fz + CW/CCW double difference.

HONEST observables: the endpoint Fz is a single-phase snapshot of a fast Larmor
oscillation (period ~1.6 at gamma*B=4), so every scalar here is the TIME MEAN
over t>=T_WIN with the oscillation amplitude shown as +/- std. The DDI-on CW run
depolarises catastrophically (|F| 6->2.3), so panel E (|F|(t)) is the decisive
one and the double difference is annotated as non-stationary.

Reads traj_p2_{ddi}_{p|m}{Omega}.csv (+ the Omega=0.85 traj_p2_{on,off}.csv).
Usage: python runs/eu_barnett_rotfield_clean/plot_p2_sweep.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")
os.makedirs(FIG, exist_ok=True)
T_WIN = 20.0
OMEGAS = [0.5, 0.65, 0.74, 0.8, 0.85]


def load(tag):
    p = os.path.join(HERE, f"traj_p2_{tag}.csv")
    return pd.read_csv(p) if os.path.exists(p) else None


def tag_for(kind, O):
    if abs(O - 0.85) < 1e-6:
        return kind  # original Omega=0.85 naming
    return f"{kind}_p{O:.2f}"


def tmean(df, col):
    if df is None:
        return np.nan, np.nan
    w = df[df["t"] >= T_WIN]
    return w[col].mean(), w[col].std()


on = {O: load(tag_for("on", O)) for O in OMEGAS}
off = {O: load(tag_for("off", O)) for O in OMEGAS}
fz_on = np.array([tmean(on[O], "Fz")[0] for O in OMEGAS])
fz_on_s = np.array([tmean(on[O], "Fz")[1] for O in OMEGAS])
fz_off = np.array([tmean(off[O], "Fz")[0] for O in OMEGAS])
fz_off_s = np.array([tmean(off[O], "Fz")[1] for O in OMEGAS])
lz_on = np.array([tmean(on[O], "Lz")[0] for O in OMEGAS])
dfz = fz_on - fz_off

fig = plt.figure(figsize=(14.5, 8.4))
gs = GridSpec(2, 3, figure=fig, hspace=0.40, wspace=0.34)

# --- A: time-mean Fz vs Omega (+/- Larmor oscillation) ---
axA = fig.add_subplot(gs[0, 0])
fs.style_ax(axA, zeroline=True)
axA.errorbar(OMEGAS, fz_off, yerr=fz_off_s, color=fs.OFF, marker="o", ms=6,
             capsize=3, label="DDI off (single-particle)")
axA.errorbar(OMEGAS, fz_on, yerr=fz_on_s, color=fs.NEG, marker="s", ms=6,
             capsize=3, label="DDI on")
axA.axvline(0.74, color=fs.POS, lw=1.2, ls=":", zorder=0)
axA.set_xlabel(r"$\Omega/\omega_\perp$")
axA.set_ylabel(r"time-mean $\langle F_z\rangle$")
axA.set_title("A  axial spin vs stir rate", loc="left")
axA.legend(fontsize=8.5)

# --- B: Delta-Fz vs Omega + vortex onset ---
axB = fig.add_subplot(gs[0, 1])
fs.style_ax(axB, zeroline=True)
axB.fill_between(OMEGAS, -fz_off_s, fz_off_s, color=fs.ZERO, alpha=0.18,
                 label="single-particle osc. band")
axB.plot(OMEGAS, dfz, color=fs.ACCENT, marker="D", ms=6,
         label=r"$\Delta F_z=\langle F_z^{on}\rangle-\langle F_z^{off}\rangle$")
axB.axvline(0.74, color=fs.POS, lw=1.2, ls=":", zorder=0)
axB.set_xlabel(r"$\Omega/\omega_\perp$")
axB.set_ylabel(r"$\Delta F_z$", color=fs.ACCENT)
axB.set_title("B  DDI excess M$_z$ vs vortex onset", loc="left")
axBr = axB.twinx()
axBr.plot(OMEGAS, lz_on, color=fs.POS, marker="^", ms=5, lw=1.8, alpha=0.85)
axBr.set_ylabel(r"mean $L_z$ (DDI on)", color=fs.POS)
axBr.grid(False)
axB.legend(loc="lower left", fontsize=8)

# --- C: CW-CCW double difference (time-mean) ---
axC = fig.add_subplot(gs[0, 2])
fs.style_ax(axC, zeroline=True)
onC, onC_s = tmean(load("on_p0.74"), "Fz")
onW, onW_s = tmean(load("on_m0.74"), "Fz")
offC, offC_s = tmean(load("off_p0.74"), "Fz")
offW, offW_s = tmean(load("off_m0.74"), "Fz")
d_on = onC - onW
d_off = offC - offW
ddouble = d_on - d_off
labels = ["on\nCCW", "on\nCW", "off\nCCW", "off\nCW"]
vals = [onC, onW, offC, offW]
errs = [onC_s, onW_s, offC_s, offW_s]
cols = [fs.NEG, fs.NEG, fs.OFF, fs.OFF]
bars = axC.bar(labels, vals, yerr=errs, color=cols, edgecolor=fs.INK,
               linewidth=0.8, capsize=4, error_kw=dict(lw=1.2))
for b, a in zip(bars, [0.95, 0.55, 0.95, 0.55]):
    b.set_alpha(a)
axC.set_ylabel(r"time-mean $\langle F_z\rangle$")
axC.set_title("C  CW-CCW double diff @ $\\Omega_c$", loc="left")
txt = (f"d_on  = {d_on:+.2f}\n"
       f"d_off = {d_off:+.2f}  (Omega-even)\n"
       f"DOUBLE = {ddouble:+.2f}\n"
       f"but CW std={onW_s:.2f} > signal\n"
       "+ CW |F| runaway (panel E)")
axC.text(0.97, 0.97, txt, transform=axC.transAxes, va="top", ha="right",
         family="monospace", fontsize=8.5,
         bbox=dict(boxstyle="round,pad=0.5", fc="#f5f6fa", ec="#d5d8e0"))

# --- D: Fz(t) for the four Omega_c runs ---
axD = fig.add_subplot(gs[1, 0])
fs.style_ax(axD, zeroline=True)
runs4 = [("on_p0.74", fs.NEG, "-", "on CCW"), ("on_m0.74", fs.NEG, "--", "on CW"),
         ("off_p0.74", fs.OFF, "-", "off CCW"), ("off_m0.74", fs.OFF, "--", "off CW")]
for tag, c, ls, lab in runs4:
    d = load(tag)
    if d is not None:
        axD.plot(d["t"], d["Fz"], color=c, ls=ls, lw=1.6, label=lab)
axD.axvline(T_WIN, color=fs.ZERO, lw=1.0, ls=":")
axD.set_xlabel("t"); axD.set_ylabel(r"$\langle F_z\rangle$")
axD.set_title("D  axial spin: fast Larmor oscillation", loc="left")
axD.legend(ncol=2, fontsize=8)

# --- E: |F|(t) — the decisive panel (CW depolarisation runaway) ---
axE = fig.add_subplot(gs[1, 1])
fs.style_ax(axE)
axE.axhline(6.0, color="#b8bcc8", lw=1.0, ls="--", zorder=0)
for tag, c, ls, lab in runs4:
    d = load(tag)
    if d is not None:
        axE.plot(d["t"], d["Fmag"], color=c, ls=ls, lw=1.8, label=lab)
axE.set_xlabel("t"); axE.set_ylabel(r"$|\langle F\rangle|$ (cloud)")
axE.set_ylim(0, 6.4)
axE.set_title("E  DDI-on CW depolarises (6→2.3)", loc="left")
axE.legend(ncol=2, fontsize=8)

# --- F: verdict ---
axF = fig.add_subplot(gs[1, 2])
axF.axis("off")
verdict = (
    "P2 Tasks 2-3 — verdict\n"
    "──────────────────────\n"
    "T2: DeltaFz(Omega) = -0.06..-0.20,\n"
    "    WEAK negative (DDI suppresses),\n"
    "    within single-particle osc. band.\n"
    "    No enhancement, no sharp Omega_c kink.\n\n"
    "T3: single-particle Fz is Omega-EVEN\n"
    "    (d_off=0). DDI-on CW depolarises\n"
    "    (|F| 6->2.3, panel E) -- dt-CONVERGED\n"
    "    (2e-4=4e-4 bit-identical) => PHYSICAL\n"
    "    chiral instability, but it is loss of\n"
    "    |F|, NOT a clean chiral net-M_z\n"
    "    (Fz std 1.25 > 0.60 double diff).\n\n"
    "=> No clean separable chiral net-M_z.\n"
    "   Single-stage stays dead; two-stage\n"
    "   remains the path (Task-1 mechanism)."
)
axF.text(0.0, 1.0, verdict, va="top", ha="left", family="monospace",
         fontsize=9.0, color=fs.INK,
         bbox=dict(boxstyle="round,pad=0.6", fc="#f5f6fa", ec="#d5d8e0"))

fig.suptitle("P2 single-stage Barnett: multi-$\\Omega$ excess + chiral double "
             "difference ($\\gamma B$=4, time-averaged)", y=0.99)
out = os.path.join(FIG, "p2_sweep.png")
fig.savefig(out)
print("wrote", out)
print(f"dFz(Omega) = {dict(zip(OMEGAS, np.round(dfz,3)))}")
print(f"double_diff @0.74 = {ddouble:+.3f}  (d_on={d_on:+.3f} d_off={d_off:+.3f}, "
      f"CW std={onW_s:.2f})")

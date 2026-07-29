"""Two-stage PASS-0 follow-up: regime-B start vs HEALTHY polarised start,
with the f_z(r) cross-section as the arbiter (integral F_z cannot distinguish
z-even flux-closure from depolarisation, nor texture from noise).

  A  |F|_cloud(t) both starts          D  z-resolved int f_z dxdy (healthy end)
  B  F_z(t) both starts (time-avg)     E  f_z(x,z) slice (healthy end)
  C  Jz=Lz+Fz(t) healthy (ANOMALY)     F  local |F|(x,z)=|f|/n (healthy end)

Key reads: local |F| held (texture, not depol); z-cancel=0 (net F_z real);
BUT Lz collapses t<2 without -> Fz (orbital AM LOST, not converted); Jz not
conserved (resolution/leak concern).

Usage: python runs/eu_barnett_rotfield_clean/plot_p2_quench_compare.py
"""
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
FIG = os.path.join(HERE, "figures")


def load(tag):
    p = os.path.join(HERE, f"traj_p2_quench_{tag}.csv")
    return pd.read_csv(p) if os.path.exists(p) else None


def load_x(name):
    p = os.path.join(FIG, name)
    return pd.read_csv(p) if os.path.exists(p) else None


regB = load("ddion")
healthy = load("healthy_ddion")
zp = load_x("xsec_zprofile_healthy_end.csv")
xz = load_x("xsec_fzxz_healthy_end.csv")

fig = plt.figure(figsize=(15, 8.6))
gs = GridSpec(2, 3, figure=fig, hspace=0.40, wspace=0.32)

# A: |F|_cloud(t)
axA = fig.add_subplot(gs[0, 0]); fs.style_ax(axA)
for d, c, lab in [(regB, fs.OFF, "regime-B (|F|₀=5.0, t15)"),
                  (healthy, fs.NEG, "healthy (|F|₀=5.85, t50)")]:
    if d is not None:
        axA.plot(d["t"], d["Fmag"], color=c, lw=2.4, label=lab)
axA.axhline(6.0, color="#d0d3db", lw=1.0, ls=":", zorder=0)
if healthy is not None:
    axA.axhline(4.1, color=fs.NEG, lw=1.0, ls="--", alpha=0.6)
    axA.text(healthy["t"].iloc[-1], 4.25, "local |F|=4.1 (held)", color=fs.NEG,
             fontsize=8, ha="right")
axA.set_xlabel("t after quench"); axA.set_ylabel(r"$|\langle F\rangle|$ (cloud)")
axA.set_ylim(0, 6.3); axA.set_title("A  cloud |F| collapses…", loc="left")
axA.legend(fontsize=8)

# B: Fz(t)
axB = fig.add_subplot(gs[0, 1]); fs.style_ax(axB, zeroline=True)
for d, c, lab in [(regB, fs.OFF, "regime-B"), (healthy, fs.NEG, "healthy")]:
    if d is not None:
        axB.plot(d["t"], d["Fz"], color=c, lw=2.0, label=lab)
if healthy is not None:
    w = healthy[healthy["t"] >= 33]
    axB.axhline(w["Fz"].mean(), color=fs.NEG, lw=1.0, ls="--", alpha=0.6)
    axB.text(1, w["Fz"].mean() - 0.12, f"⟨Fz⟩={w['Fz'].mean():+.2f} (stable)",
             color=fs.NEG, fontsize=8)
axB.set_xlabel("t after quench"); axB.set_ylabel(r"$\langle F_z\rangle$")
axB.set_title("B  …but a real net F_z develops", loc="left"); axB.legend(fontsize=8)

# C: Jz(t) anomaly
axC = fig.add_subplot(gs[0, 2]); fs.style_ax(axC, zeroline=True)
if healthy is not None:
    axC.plot(healthy["t"], healthy["Lz"], color=fs.POS, lw=2.0, label=r"$L_z$")
    axC.plot(healthy["t"], healthy["Fz"], color=fs.NEG, lw=2.0, label=r"$F_z$")
    axC.plot(healthy["t"], healthy["Lz"] + healthy["Fz"], color=fs.INK, lw=2.4,
             label=r"$J_z=L_z+F_z$")
    axC.axvspan(0, 2, color="#f0d0d0", alpha=0.4)
    axC.text(2.2, 1.0, "L_z collapses t<2\nwithout →F_z\n(orbital AM LOST)",
             fontsize=8, color="#a03030", va="top")
axC.set_xlabel("t after quench"); axC.set_ylabel("AM")
axC.set_title("C  J_z NOT conserved (anomaly)", loc="left"); axC.legend(fontsize=8)

# D: z-resolved column f_z
axD = fig.add_subplot(gs[1, 0]); fs.style_ax(axD, zeroline=True)
if zp is not None:
    axD.plot(zp["z"], zp["Fz_col"], color=fs.NEG, marker="s", ms=4)
axD.set_xlabel("z"); axD.set_ylabel(r"$\int f_z\,dx\,dy$")
axD.set_title("D  net F_z is z-odd (cancel=0.00)", loc="left")

ext = None
if xz is not None:
    xs = np.sort(xz["x"].unique()); zs = np.sort(xz["z"].unique())
    ext = [xs.min(), xs.max(), zs.min(), zs.max()]
    fzg = xz.pivot(index="z", columns="x", values="fz").values
    lfg = xz.pivot(index="z", columns="x", values="localF").values

# E: f_z(x,z)
axE = fig.add_subplot(gs[1, 1])
if xz is not None:
    vm = np.nanmax(np.abs(fzg))
    im = axE.imshow(fzg, origin="lower", extent=ext, aspect="auto",
                    cmap="RdBu_r", vmin=-vm, vmax=vm)
    fig.colorbar(im, ax=axE, fraction=0.046, pad=0.03).set_label(r"$f_z$", fontsize=9)
axE.set_xlabel("x"); axE.set_ylabel("z"); axE.grid(False)
axE.set_title("E  $f_z(x,z)$ healthy end", loc="left")

# F: local |F|(x,z) — texture evidence
axF = fig.add_subplot(gs[1, 2])
if xz is not None:
    im = axF.imshow(lfg, origin="lower", extent=ext, aspect="auto",
                    cmap="viridis", vmin=0, vmax=6)
    fig.colorbar(im, ax=axF, fraction=0.046, pad=0.03).set_label(r"$|F|=|f|/n$", fontsize=9)
axF.set_xlabel("x"); axF.set_ylabel("z"); axF.grid(False)
axF.set_title("F  local |F| held ~4 = TEXTURE", loc="left")

fig.suptitle("Two-stage PASS-0: healthy start forms a TEXTURE (local |F| held) "
             "but vortex AM is LOST, not converted to M_z", y=1.0)
out = os.path.join(FIG, "p2_quench_compare.png")
fig.savefig(out, bbox_inches="tight")
print("wrote", out)
if healthy is not None:
    w = healthy[healthy["t"] >= 33]
    print(f"healthy end: |F|_cloud {healthy['Fmag'].iloc[-1]:.2f}, local|F|~4.1, "
          f"<Fz>(t>33)={w['Fz'].mean():+.2f}, Jz {1.28:.2f}->{(w['Lz']+w['Fz']).mean():+.2f}")

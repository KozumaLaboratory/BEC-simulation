#!/usr/bin/env python3
"""Fig. 4 analogue for #336: Einstein-de Haas rotation of the F=6 torus.

Reads the CSVs `h6_edh.jl` writes. Two panels, matching the paper's Fig. 4(b):
  left  : L_z(t), f_z(t) and their sum J_z = L_z + f_z, which must stay at 0
  right : the mechanical rotation angle of the symmetry axis about z

  python3 runs/saito_li_torus/h7_edh_plot.py
"""
import pathlib
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUT = pathlib.Path(__file__).parent / "out"


def main():
    files = sorted(OUT.glob("edh_Bz*uG_n*.csv"))
    if not files:
        print(f"no edh_*.csv in {OUT} — run h6_edh.jl first")
        return
    fig, ax = plt.subplots(1, 2, figsize=(10.6, 4.2))
    colours = ["tab:blue", "tab:red", "tab:green"]
    for k, f in enumerate(files):
        d = np.genfromtxt(f, delimiter=",", names=True)
        # a short dt-convergence arm is plotted dashed, not as a third field
        dashed = d["t_ms"][-1] < 0.5 * max(
            np.genfromtxt(g, delimiter=",", names=True)["t_ms"][-1] for g in files)
        uG = f.stem.split("Bz")[1].split("uG")[0]
        c = colours[k % len(colours)]
        ls = "--" if dashed else "-"
        lbl = f"{uG} µG" + (", dt/2" if dashed else "")
        ax[0].plot(d["t_ms"], d["Lz"], ls, color=c, lw=1.6, label=f"$L_z$ {lbl}")
        ax[0].plot(d["t_ms"], d["fz"], ls, color=c, lw=1.2, alpha=0.55,
                   label=f"$f_z$ {lbl}")
        ax[0].plot(d["t_ms"], d["Jz"], ":", color=c, lw=1.4,
                   label=f"$J_z$ {lbl}")
        ax[1].plot(d["t_ms"], d["phi_deg"] - d["phi_deg"][0], ls, color=c,
                   lw=1.7, label=lbl)

    ax[0].axhline(0, color="0.6", lw=0.8, zorder=0)
    ax[0].set_xlabel("t  [ms]")
    ax[0].set_ylabel("angular momentum per atom  [ℏ]")
    ax[0].set_title("Einstein–de Haas ledger:  spin ↔ orbital")
    ax[0].legend(frameon=False, fontsize=7, ncol=3, loc="center right")
    ax[0].grid(alpha=0.25)

    ax[1].set_xlabel("t  [ms]")
    ax[1].set_ylabel("rotation of the symmetry axis about z  [deg]")
    ax[1].set_title("mechanical rotation of the torus")
    ax[1].legend(frameon=False, fontsize=8)
    ax[1].grid(alpha=0.25)

    fig.suptitle("Li–Saito Fig. 4 analogue:  F = 6, N = 15000, ε_dd = 1.3, "
                 "B_z switched on at t = 0", fontsize=10)
    fig.tight_layout()
    fig.savefig(OUT / "fig4_edh.png", dpi=160, bbox_inches="tight")
    print("  wrote fig4_edh.png")

    print(f"\n{'run':<14}{'t_end[ms]':>10}{'max|J_z|':>12}{'corr(f,L)':>11}"
          f"{'rot[deg]':>10}{'max edge':>11}{'norm drift':>12}")
    for f in files:
        d = np.genfromtxt(f, delimiter=",", names=True)
        a = d["fz"] - d["fz"].mean()
        b = d["Lz"] - d["Lz"].mean()
        corr = (a * b).sum() / np.sqrt((a * a).sum() * (b * b).sum())
        print(f"{f.stem.replace('edh_',''):<14}{d['t_ms'][-1]:10.2f}"
              f"{np.abs(d['Jz']).max():12.2e}{corr:11.5f}"
              f"{d['phi_deg'][-1]-d['phi_deg'][0]:10.2f}"
              f"{d['edge'].max():11.2e}"
              f"{np.abs(d['norm']-d['norm'][0]).max():12.2e}")


if __name__ == "__main__":
    main()

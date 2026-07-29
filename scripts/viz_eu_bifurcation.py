#!/usr/bin/env python3
"""Static bifurcation diagram for the weak-field Eu (F=6) texture transition.

    python scripts/viz_eu_bifurcation.py --data <branches.dat> [--out figs/...]

Why static, when `eu_adiabatic_ramp_protocol.jl` measures the same transition
dynamically: a ramp cannot separate bistability from lag without reaching the
adiabatic limit, and at these textures it does not — a 434 ms ramp (tau = 300
omega_ref^-1) still trails the ground state by ~1 in <F_perp>. The ground-state
branches carry no lag at all, so the bistable window and both spinodals read
straight off them.

Input is whitespace-separated `kappa branch B Fperp E grad`, one row per
converged ground state. Regenerate it from the B-scan continuation outputs
(data lives on TSUBAME; the repo keeps the figure and this script):

    { echo "#kappa branch B Fperp E grad"
      awk 'NR>1{print 1.8,"up",$2,$6,$3,$4}' figs/eu_beq_up_k1.8/frames.csv
      for d in eu_beqd_k1.8 eu_trapscan_k1.8 eu_trapscan_k1.8b; do
        awk 'NR>1{print 1.8,"dn",$2,$6,$3,$4}' figs/$d/frames.csv; done
      awk 'NR>1{print 0.8,"up",$2,$6,$3,$4}' figs/eu_beq_up_k0.8/frames.csv
      awk 'NR>1{print 0.8,"dn",$2,$6,$3,$4}' figs/eu_beq_dn_k0.8/frames.csv
    } > branches.dat

The claim under test, from the tricritical estimate kappa_tc in (0.9, 1.0):
kappa >= 1.0 is first order (two branches over a finite B window) and
kappa <= 0.9 is a crossover (one single-valued branch). The control is what
makes it falsifiable, so it gets equal billing rather than an inset.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path

import matplotlib as mpl
import matplotlib.pyplot as plt

mpl.rcParams.update({
    "figure.dpi": 130, "savefig.dpi": 130, "font.size": 10,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.alpha": 0.25, "legend.frameon": False,
})

# Branch identity is categorical -> two distinct hues, not a ramp.
C_UP, C_DN, C_SPIN = "#1f77b4", "#d62728", "#444444"


def load(path):
    out = defaultdict(list)
    for line in Path(path).read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        k, br, B, F, E, g = line.split()
        out[(float(k), br)].append((float(B), float(F), float(E), float(g)))
    return {k: sorted(v) for k, v in out.items()}


def spinodal(up, dn, tol=0.02):
    """Lowest B at which the two branches agree to `tol` — the upper spinodal.

    Above it the continuation that started on the flower branch has collapsed
    onto the axial one, so only a single state exists.
    """
    dn_at = {round(b, 2): f for b, f, *_ in dn}
    for b, f, *_ in up:
        for bb, ff in dn_at.items():
            if abs(bb - b) < 1.0 and abs(ff - f) < tol:
                return b
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", required=True)
    ap.add_argument("--out", default="figs/eu_bifurcation.png")
    a = ap.parse_args()
    d = load(a.data)

    kappas = sorted({k for k, _ in d})
    fig, axes = plt.subplots(1, len(kappas), figsize=(5.4 * len(kappas), 4.2))
    axes = [axes] if len(kappas) == 1 else list(axes)

    for ax, k in zip(axes, sorted(kappas, reverse=True)):
        up, dn = d.get((k, "up"), []), d.get((k, "dn"), [])
        for pts, c, lab in ((up, C_UP, "flower branch (seeded weak-field)"),
                            (dn, C_DN, "axial branch (seeded strong-field)")):
            if pts:
                ax.plot([p[0] for p in pts], [p[1] for p in pts],
                        color=c, lw=1.8, label=lab)

        # Bistable only if the branches are actually APART somewhere. Without
        # this the merge search returns the very first B for a crossover, where
        # they coincide from the start, and mislabels it "bistable below B_min".
        gap0 = (up[0][1] - min(dn, key=lambda p: abs(p[0] - up[0][0]))[1]
                if (up and dn) else 0.0)
        bs = spinodal(up, dn) if (up and dn and abs(gap0) > 0.1) else None
        if bs is not None:
            ax.axvline(bs, color=C_SPIN, ls=":", lw=1.2)
            ax.annotate(f"branches merge\nB ≈ {bs:.0f} µG",
                        xy=(bs, ax.get_ylim()[1] * 0.72),
                        xytext=(-8, 0), textcoords="offset points",
                        ha="right", fontsize=8.5, color=C_SPIN)
            ax.annotate(f"δ⟨F⊥⟩ = {gap0:.2f} at {up[0][0]:.0f} µG",
                        xy=(0.03, 0.06), xycoords="axes fraction", fontsize=8.5)
            title = f"κ = {k:g}  —  bistable below {bs:.0f} µG"
        else:
            # No merge point means the branches never separated in the first
            # place; say the measured bound rather than just "no loop".
            if up and dn:
                gaps = [abs(f - min(dn, key=lambda p: abs(p[0] - b))[1])
                        for b, f, *_ in up]
                ax.annotate(f"branches coincide everywhere\nmax |δ⟨F⊥⟩| = {max(gaps):.1e}",
                            xy=(0.03, 0.06), xycoords="axes fraction", fontsize=8.5)
            title = f"κ = {k:g}  —  single-valued (crossover control)"
        ax.set_title(title, fontsize=11)
        ax.set_xlabel("magnetic field  B  [µG]")

    axes[0].set_ylabel(r"transverse magnetisation  $\langle F_\perp \rangle$")
    axes[0].legend(loc="upper right", fontsize=8.5)
    fig.tight_layout()
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(a.out, bbox_inches="tight")
    print(f"wrote {a.out}")


if __name__ == "__main__":
    main()

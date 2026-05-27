#!/usr/bin/env python3
"""
make_klaus_quench_figures.py — Fig K1/K2/K3 for the 10-cell klaus_quench
2-phase protocol scan.

Story: rotation preparation at strong B → quench to weak B → free hold.
Question: which Ω most efficiently excites m=−5, m=−4 spin components
after the weak-field quench (NOT bare ⟨F_z⟩ response under sustained
rotation, which was the prior Barnett window scan).

Figures:
  Fig K1: max P_{-5,-4} vs Ω (core 6-point scan, DDI on)
          + Ω=0 baseline horizontal line
  Fig K2: bar chart S_spin = max P_{-5,-4}(case) - max P_{-5,-4}(Ω=0 core)
          for the 4 conditions: Ω=-0.5 core, DDI off, no B quench, keep rot
  Fig K3: ⟨F_z⟩/N(T) and ΔF_z/N vs Ω (proxy for angular momentum transfer)
"""
import json
import sys
from pathlib import Path
import os  # noqa

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SUMMARY = ROOT / "runs" / "klaus_quench" / "summary.json"
OUT = ROOT / "docs" / "manuscript" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.size": 10,
    "axes.titlesize": 11,
    "axes.labelsize": 10,
    "legend.fontsize": 8,
    "savefig.dpi": 200,
    "savefig.bbox": "tight",
})


def _load():
    if not SUMMARY.exists():
        print(f"FATAL: {SUMMARY} not found — run klaus_quench_summary.jl first.", file=sys.stderr)
        sys.exit(1)
    with open(SUMMARY) as f:
        data = json.load(f)
    return [r for r in data["rows"] if r["status"] == "OK"]


def figure_k1_spin_excitation(rows):
    """Fig K1 v3 — dense Ω scan only.  19 hold_only delay=2 ms refine
    points span [-1.0, +0.5].  The keep_rot delay=0 curve was dropped
    (consistently below hold_only at every measured Ω).
    """
    # Hold-only delay=2 ms refine (the protocol-optimal delay per K12)
    refine = sorted([r for r in rows
                     if r["variant"] == "holdonly" and "refine" in r["label"]],
                    key=lambda r: r["omega"])
    # delay-test cells at Ω=-0.5 (different delays for context)
    delay_var = sorted([r for r in rows
                        if r["variant"] == "holdonly"
                        and "delay" in r["label"]
                        and "refine" not in r["label"]],
                       key=lambda r: r["label"])
    # hold_only delay=0 baseline (the original holdonly cell)
    holdonly0 = next((r for r in rows
                      if r["variant"] == "holdonly"
                      and "delay" not in r["label"]
                      and "refine" not in r["label"]), None)

    # Baseline = free-hold core at Ω=0 (== no-rotation)
    free_hold = [r for r in rows if r["variant"] == "core"]
    Om0_P54  = next((r["max_P_54"]  for r in free_hold if r["omega"] == 0.0), None)
    Om0_Pexc = next((r["max_P_exc"] for r in free_hold if r["omega"] == 0.0), None)

    if not refine:
        print("Fig K1: no matched-chirality data — skipping.")
        return

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))

    # ─────────────── Panel (a): P_{-5,-4} ───────────────
    ax = axes[0]
    if Om0_P54 is not None:
        ax.axhline(Om0_P54, color="gray", linestyle=":", linewidth=1.2,
                    alpha=0.7, label=f"Ω=0 baseline (no rotation) = {Om0_P54:.3f}")
    if refine:
        Om = [r["omega"] for r in refine]
        P  = [r["max_P_54"] for r in refine]
        ax.plot(Om, P, "D-", color="#2ca02c",
                label=f"hold_only delay=2 ms  ({len(Om)} pts, refine scan)",
                linewidth=2.2, markersize=10)
        idx = int(np.argmax(P))
        # Parabolic-fit vertex (from Fig K14): Ω* = -0.468 ± 0.003, P_max ≈ 0.624.
        # We annotate the FIT vertex (slightly to the left of the argmax sample
        # at -0.46) since that's the published Ω*.
        ax.annotate(f"Ω* = -0.468 ± 0.003\n(7-pt parabolic fit, Fig K14)\nP_max(fit) = 0.624\nP_max(data) = {P[idx]:.3f} @ Ω=−0.46",
                    (Om[idx], P[idx]),
                    xytext=(25, -55), textcoords="offset points",
                    arrowprops=dict(arrowstyle="->", color="#2ca02c", lw=1),
                    fontsize=8.5, color="#2ca02c",
                    bbox=dict(boxstyle="round,pad=0.3", facecolor="white",
                              edgecolor="#2ca02c", alpha=0.85))
    if delay_var:
        # Annotate the delay scan points at Ω=-0.5 (vertical column)
        for r in delay_var:
            lab = r["label"]
            ms_match = next((s for s in ["delay1ms", "delay2ms", "delay5ms"] if s in lab), None)
            if ms_match is None:
                continue
            ms = int(ms_match.replace("delay", "").replace("ms", ""))
            ax.scatter([r["omega"]], [r["max_P_54"]], marker="^", s=70,
                        color="#ff7f0e", zorder=4, edgecolor="black", linewidth=0.5)
            ax.annotate(f"{ms} ms", (r["omega"], r["max_P_54"]),
                        xytext=(8, 0), textcoords="offset points",
                        fontsize=7, color="#ff7f0e")
    if holdonly0 is not None:
        ax.scatter([holdonly0["omega"]], [holdonly0["max_P_54"]], marker="^",
                    s=70, color="#ff7f0e", zorder=4, edgecolor="black",
                    linewidth=0.5, label="hold_only delay scan at Ω=−0.5")
        ax.annotate("0 ms", (holdonly0["omega"], holdonly0["max_P_54"]),
                    xytext=(8, -10), textcoords="offset points",
                    fontsize=7, color="#ff7f0e")

    ax.set_xlabel(r"$\Omega / \omega_\perp$  (matched chirality, m=−F)")
    ax.set_ylabel(r"$\max_t (N_{-5}+N_{-4}) / N$")
    ax.set_title("(a) Klaus protocol Ω scan — all measured matched-chirality points")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="lower center", fontsize=8)

    # ─────────────── Panel (b): P_exc ───────────────
    ax = axes[1]
    if Om0_Pexc is not None:
        ax.axhline(Om0_Pexc, color="gray", linestyle=":", linewidth=1.2,
                    alpha=0.7, label=f"Ω=0 baseline = {Om0_Pexc:.3f}")
    if refine:
        Om = [r["omega"] for r in refine]
        P  = [r["max_P_exc"] for r in refine]
        ax.plot(Om, P, "D-", color="#2ca02c",
                label=f"hold_only delay=2 ms  ({len(Om)} pts)",
                linewidth=2.2, markersize=10)
    ax.set_xlabel(r"$\Omega / \omega_\perp$")
    ax.set_ylabel(r"total spin excitation  $\max_t (1 - N_{-6}/N)$")
    ax.set_title("(b) Total spin excitation")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="best", fontsize=8)

    fig.suptitle(
        "Figure K1 — Klaus rotation protocol Ω scan (m=−F, B=2.6 nT, matched chirality)\n"
        "Dense hold_only delay=2 ms scan; Ω=0 baseline shown as dashed line.",
        y=1.02, fontsize=11,
    )
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k1.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k2_controls(rows):
    """Fig K2: bar chart of max P_{-5,-4} across the load-bearing conditions.

    Post-batch-2 layout: shows that
      - the keep_rot enhancement requires DDI (DDIoff + keeprot → 0)
      - the rotation prep alone gives the baseline ~0.22
      - sustained rotation gives the ~0.54 enhancement
    """
    # Pick the cells we want for the bar chart.
    targets = [
        ("Ω=0 (no rotation)",      {"omega":  0.0, "variant": "core"}),
        ("Ω=-0.5 free hold",       {"omega": -0.5, "variant": "core"}),
        ("Ω=-0.5 DDI off",         {"omega": -0.5, "variant": "DDIoff"}),
        ("Ω=-0.5 no B quench",     {"omega": -0.5, "variant": "noBquench"}),
        ("Ω=-0.5 keep rot",        {"omega": -0.5, "variant": "keeprot"}),
        ("Ω=-0.5 keep rot DDIoff", {"omega": -0.5, "variant": "keeprot_DDIoff"}),
        ("Ω=-0.3 free hold",       {"omega": -0.3, "variant": "core"}),
        ("Ω=-0.3 DDI off",         {"omega": -0.3, "variant": "DDIoff"}),
    ]

    found = []
    for label, sel in targets:
        match = next((r for r in rows
                      if r["omega"] == sel["omega"] and r["variant"] == sel["variant"]),
                     None)
        if match is not None:
            found.append((label, match))
    if not found:
        print("Fig K2: no control cells available — skipping.")
        return

    labels = [f[0] for f in found]
    vals = [f[1]["max_P_54"] for f in found]
    Nratio = [f[1]["N_final_ratio"] for f in found]

    fig, ax = plt.subplots(figsize=(9.5, 4.5))
    x = np.arange(len(labels))
    bars = ax.bar(x, vals, color="#d62728", edgecolor="black", linewidth=0.8)
    # Highlight Ω=0 baseline.
    for bar, lab in zip(bars, labels):
        if "Ω=0" in lab:
            bar.set_color("#1f77b4")
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=18, ha="right")
    ax.set_ylabel(r"$\max_t (N_{-5}+N_{-4}) / N$")
    ax.set_title("Figure K2 — Spin excitation: condition sweep at fixed Ω")
    ax.grid(True, alpha=0.3, axis="y")
    for rect, v, n in zip(bars, vals, Nratio):
        ax.annotate(f"{v:.3f}\nN/N₀={n:.3f}",
                    (rect.get_x() + rect.get_width() / 2, v),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", fontsize=8)
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k2.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k3_angular_momentum(rows):
    """Fig K3: ⟨F_z⟩/N (initial vs final) and ΔF_z/N vs Ω for the core scan."""
    core = sorted([r for r in rows if r["variant"] == "core"],
                  key=lambda r: r["omega"])
    if not core:
        print("Fig K3: no core cells available — skipping.")
        return
    omegas = [r["omega"] for r in core]
    Fz_i = [r["Fz_per_N_initial"] for r in core]
    Fz_f = [r["Fz_per_N_final"] for r in core]
    dFz = [r["DeltaFz_per_N"] for r in core]

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.2))

    # Panel (a): Fz/N initial + final
    ax = axes[0]
    ax.plot(omegas, Fz_i, "s--", color="gray", label=r"$\langle F_z\rangle/N$ initial",
            linewidth=1.4, markersize=7, alpha=0.7)
    ax.plot(omegas, Fz_f, "o-", color="#d62728", label=r"$\langle F_z\rangle/N$ final (post-hold)",
            linewidth=1.8, markersize=8)
    ax.axhline(-6.0, color="black", linewidth=0.4, alpha=0.4)
    ax.set_xlabel(r"$\Omega / \omega_\perp$  (rotation prep)")
    ax.set_ylabel(r"$\langle F_z\rangle / N$")
    ax.set_title("(a) Spin polarisation before / after protocol")
    ax.grid(True, alpha=0.3)
    ax.legend(loc="best", fontsize=8)

    # Panel (b): ΔFz/N
    ax = axes[1]
    ax.plot(omegas, dFz, "o-", color="#1f77b4", linewidth=1.8, markersize=8)
    ax.axhline(0, color="black", linewidth=0.4, alpha=0.4)
    ax.set_xlabel(r"$\Omega / \omega_\perp$")
    ax.set_ylabel(r"$\Delta\langle F_z\rangle / N$")
    ax.set_title("(b) Spin transfer ΔFz/N vs Ω")
    ax.grid(True, alpha=0.3)

    fig.suptitle(
        "Figure K3 — Klaus 2-phase protocol: angular-momentum transfer vs Ω.\n"
        "(Lz / Jz extension: needs orbital analyzer; deferred.)",
        y=1.04,
    )
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k3.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k4_trajectories(rows):
    """Fig K4 (reworked): overlay Ω=0 baseline vs Ω=-0.5 keep_rot N_m(t)
    on a single panel for direct visual comparison.  m=-6 (initial state)
    + m=-5, -4 (excited states) shown for both protocols."""
    Om0 = next((r for r in rows
                if r["omega"] == 0.0 and r["variant"] == "core"), None)
    # Use Ω=-0.5 keep_rot (the headline best) as the comparison curve.
    best_keeprot = next((r for r in rows
                         if r["omega"] == -0.5 and r["variant"] == "keeprot"), None)
    if Om0 is None or best_keeprot is None:
        print("Fig K4: missing baseline or keep_rot best — skipping.")
        return

    # Python 0-indexed: c=0..12 = m=+6..-6 → m=-4 is c=10, m=-5 c=11, m=-6 c=12
    m_to_c = {m: 6 - m for m in range(-6, 7)}
    m_colors = {-6: "#1f77b4", -5: "#ff7f0e", -4: "#2ca02c", -3: "#d62728", 0: "#9467bd"}

    fig, ax = plt.subplots(figsize=(11, 5.0))
    for r, lab, ls, alpha, lw in [
        (Om0,           "Ω=0 (baseline)",       "--", 0.55, 1.6),
        (best_keeprot,  "Ω=−0.5 keep rotation", "-",  1.00, 2.2),
    ]:
        t = np.array(r["sample_t"])
        Nm = np.array(r["sample_Nm"])
        n = min(len(t), len(Nm))
        t = t[:n]
        Nm = Nm[:n]
        N_total = Nm.sum(axis=1)
        for m in (-6, -5, -4):
            ax.plot(t, Nm[:, m_to_c[m]] / N_total, ls, color=m_colors[m],
                    label=f"m={m}, {lab}", linewidth=lw, alpha=alpha)

    # Phase boundary markers.
    ax.axvline(6.9115, color="gray", linestyle=":", linewidth=0.8, alpha=0.6)
    ax.axvline(7.6027, color="gray", linestyle=":", linewidth=0.8, alpha=0.6)
    ax.text(3.45, 0.95, "rotation prep\n(strong B, Ω)",
            ha="center", va="top", fontsize=8, alpha=0.7)
    ax.text(7.25, 0.95, "quench", ha="center", va="top",
            fontsize=8, alpha=0.7)
    ax.text(10.7, 0.95, "weak-field hold\n(Ω kept / off)",
            ha="center", va="top", fontsize=8, alpha=0.7)

    ax.set_xlabel(r"$t / \omega_{\rm ref}^{-1}$")
    ax.set_ylabel(r"$N_m / N$")
    ax.set_title(
        "Figure K4 — Population trajectories: Ω=0 baseline vs Ω=−0.5 keep_rot\n"
        "(both protocols share quench at t≈7 ω_ref⁻¹; "
        "sustained rotation drives the m=−5, −4 transfer ~2.5× more)",
    )
    ax.grid(True, alpha=0.3)
    ax.legend(loc="center right", fontsize=8, ncol=2)
    ax.set_xlim(0, 14.5)
    ax.set_ylim(0, 1.0)
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k4_trajectories.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k5_texture():
    """Fig K5: z=0 density slices for m=-6, -5, -4 at 4 protocol checkpoints
    (initial / post-prep / post-quench / post-hold) — comparing Ω=0 baseline
    against Ω=-0.5 keep_rot. Reads density_slices.json from the run dirs.
    """
    target_dirs = [
        ("Ω = 0 (no rotation)",       "klaus_quench_om0p0_"),
        ("Ω = −0.5 keep rotation",    "klaus_quench_omm0p5_keeprot_"),
    ]
    ROOT_RUNS = Path(__file__).resolve().parents[2] / "runs"

    sources = []
    for label, prefix in target_dirs:
        candidate = next((p for p in ROOT_RUNS.iterdir()
                          if p.is_dir() and p.name.startswith(prefix)
                          and (p / "density_slices.json").exists()), None)
        if candidate is None:
            print(f"Fig K5: density_slices.json not found for {prefix} — skipping.")
            return
        with open(candidate / "density_slices.json") as f:
            sources.append((label, json.load(f)))

    checkpoints = ["initial", "post_prep", "post_quench", "post_hold"]
    cp_labels = {
        "initial":     "initial",
        "post_prep":   "post-prep (t ≈ 6.9)",
        "post_quench": "post-quench (t ≈ 7.6)",
        "post_hold":   "post-hold (t ≈ 12.2)",
    }
    m_components = [(-6, "m=−6 (init)"), (-5, "m=−5"), (-4, "m=−4")]

    n_protocols = len(sources)
    n_rows = n_protocols * len(m_components)
    n_cols = len(checkpoints)

    fig, axes = plt.subplots(n_rows, n_cols, figsize=(2.7 * n_cols, 2.3 * n_rows),
                              squeeze=False)
    # Pre-compute global colour scale per m component so visual contrast is consistent.
    global_vmax = {}
    for m, _ in m_components:
        vmax = 0.0
        for _, src in sources:
            for cp in checkpoints:
                arr = np.array(src["checkpoints"][cp]["z_slice"][f"m_{m}"])
                vmax = max(vmax, float(arr.max()))
        global_vmax[m] = vmax if vmax > 0 else 1e-30

    for pi, (label, src) in enumerate(sources):
        box = src["box"]
        extent = (-box / 2, box / 2, -box / 2, box / 2)
        for mi, (m, m_lab) in enumerate(m_components):
            row = pi * len(m_components) + mi
            for ci, cp in enumerate(checkpoints):
                ax = axes[row, ci]
                arr = np.array(src["checkpoints"][cp]["z_slice"][f"m_{m}"])
                # Use log scale for m=-6 (huge range), linear for excited.
                if m == -6:
                    cmap = "viridis"
                    im = ax.imshow(arr.T, origin="lower", extent=extent,
                                    cmap=cmap, vmin=0, vmax=global_vmax[m])
                else:
                    cmap = "inferno"
                    im = ax.imshow(arr.T, origin="lower", extent=extent,
                                    cmap=cmap, vmin=0, vmax=global_vmax[m])
                if row == 0:
                    ax.set_title(cp_labels[cp], fontsize=9)
                if ci == 0:
                    ax.set_ylabel(f"{label}\n{m_lab}", fontsize=8)
                else:
                    ax.set_yticks([])
                if row == n_rows - 1:
                    ax.set_xlabel("x [a_ho]", fontsize=8)
                else:
                    ax.set_xticks([])
                ax.tick_params(labelsize=7)
            cbar = fig.colorbar(im, ax=axes[row, -1], fraction=0.06, pad=0.02)
            cbar.ax.tick_params(labelsize=6)
            cbar.formatter.set_powerlimits((-3, 3))
            cbar.update_ticks()

    fig.suptitle(
        "Figure K5 — z=0 density slices through Klaus quench protocol\n"
        "(top 3 rows: Ω=0 baseline; bottom 3 rows: Ω=−0.5 keep_rot; "
        "showing m=−6, −5, −4 components at 4 checkpoints)",
        y=1.001,
    )
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k5_texture.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k6_symmetry(rows):
    """Fig K6 — symmetry test under (init m × Ω sign) reversal. If the
    excitation is governed by the rotating-frame H − ΩL_z, then m=+F + Ω=+0.5
    should give the same response as m=−F + Ω=−0.5 (both rotate "against"
    the polarised spin), and m=+F + Ω=−0.5 should match m=−F + Ω=+0.5."""

    def _find(omega, init_sign, variant):
        return next((r for r in rows
                     if r["omega"] == omega
                     and r.get("init_m_sign", -1) == init_sign
                     and r["variant"] == variant), None)

    # 4 keep_rot cells: m=-F × ±Ω + m=+F × ±Ω
    cells = [
        ("m=−F, Ω=−0.5",  -0.5, -1, "keeprot",         "max_P_54"),
        ("m=−F, Ω=+0.5",  +0.5, -1, "keeprot",         "max_P_54"),
        ("m=+F, Ω=+0.5",  +0.5, +1, "keeprot_mFplus",  "max_P_p54"),
        ("m=+F, Ω=−0.5",  -0.5, +1, "keeprot_mFplus",  "max_P_p54"),
    ]

    found = []
    for label, omega, sign, variant, key in cells:
        r = _find(omega, sign, variant)
        if r is None:
            print(f"Fig K6: missing {label} ({variant}) — skipping cell.")
            continue
        found.append((label, r, key))

    if len(found) < 2:
        print("Fig K6: insufficient symmetry cells — skipping.")
        return

    fig, ax = plt.subplots(figsize=(9, 4.5))
    x = np.arange(len(found))
    vals = [f[1][f[2]] for f in found]
    labels = [f[0] for f in found]
    # Colour pair by "direction": (m=-F + Ω=-0.5) and (m=+F + Ω=+0.5) are
    # the predicted symmetry pair; colour them red. The mismatched pair (cross)
    # goes blue.
    colors = []
    for label in labels:
        if ("m=−F, Ω=−0.5" in label) or ("m=+F, Ω=+0.5" in label):
            colors.append("#d62728")
        else:
            colors.append("#1f77b4")
    bars = ax.bar(x, vals, color=colors, edgecolor="black", linewidth=0.8)
    for rect, v in zip(bars, vals):
        ax.annotate(f"{v:.3f}",
                    (rect.get_x() + rect.get_width() / 2, v),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=10)
    ax.set_ylabel(r"$\max_t (N_{\rm adj}) / N$  (adj = m±5, m±4 of init)")
    ax.set_title(
        "Figure K6 — Symmetry under (init spin × Ω sign) reversal\n"
        "(red bars = expected symmetric pair under H − Ω L_z; "
        "blue bars = mismatched pair, should be weak)",
    )
    ax.grid(True, alpha=0.3, axis="y")
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k6_symmetry.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k7_timing(rows):
    """Fig K7 — rotation-timing decomposition: rotation only in prep,
    only in hold, or in both (keep_rot)."""

    targets = [
        ("Ω=0 (no rotation)",       0.0,  "core"),
        ("Ω=−0.5 prep only",       -0.5,  "core"),       # = free_hold = current core cell
        ("Ω=−0.5 hold only",       -0.5,  "holdonly"),
        ("Ω=−0.5 prep + hold",     -0.5,  "keeprot"),
    ]

    found = []
    for label, omega, variant in targets:
        r = next((x for x in rows
                  if x["omega"] == omega and x["variant"] == variant), None)
        if r is None:
            print(f"Fig K7: missing {label} ({variant}) — skipping cell.")
            continue
        found.append((label, r))
    if len(found) < 2:
        print("Fig K7: insufficient timing cells — skipping.")
        return

    fig, ax = plt.subplots(figsize=(9, 4.5))
    x = np.arange(len(found))
    vals = [f[1]["max_P_54"] for f in found]
    labels = [f[0] for f in found]
    colors = ["#1f77b4" if "Ω=0" in lab else
              ("#d62728" if "prep + hold" in lab or "hold only" in lab else "#ff7f0e")
              for lab in labels]
    bars = ax.bar(x, vals, color=colors, edgecolor="black", linewidth=0.8)
    for rect, v in zip(bars, vals):
        ax.annotate(f"{v:.3f}",
                    (rect.get_x() + rect.get_width() / 2, v),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=10)
    ax.set_ylabel(r"$\max_t (N_{-5} + N_{-4}) / N$")
    ax.set_title(
        "Figure K7 — Rotation-timing decomposition (Ω = −0.5)\n"
        "Which phase carries the load? prep-only vs hold-only vs both.",
    )
    ax.grid(True, alpha=0.3, axis="y")
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k7_timing.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k8_B_sweep(rows):
    """Fig K8 — B_final sweep at fixed Ω=−0.5 keep_rot.
    Identifies the experimental weak-field window."""
    # Variant labels: keeprot_Bf1p3, keeprot_Bf5p2, keeprot_Bf10, plus
    # the baseline keep_rot (= B = 2.6 nT).
    cells = [
        (1.3, "keeprot_Bf1p3"),
        (2.6, "keeprot"),
        (5.2, "keeprot_Bf5p2"),
        (10.0, "keeprot_Bf10"),
    ]
    found = []
    for Bf, variant in cells:
        r = next((x for x in rows
                  if x["omega"] == -0.5 and x["variant"] == variant), None)
        if r is None:
            print(f"Fig K8: missing B={Bf} nT ({variant}) — skipping cell.")
            continue
        found.append((Bf, r))
    if len(found) < 2:
        print("Fig K8: insufficient B-sweep cells — skipping.")
        return

    Bf_vals = [f[0] for f in found]
    P54_vals = [f[1]["max_P_54"] for f in found]
    Nratio_vals = [f[1]["N_final_ratio"] for f in found]
    peak_vals = [f[1]["peak_ratio"] for f in found]

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    ax = axes[0]
    ax.plot(Bf_vals, P54_vals, "o-", color="#d62728", linewidth=2.0, markersize=10)
    ax.set_xscale("log")
    ax.set_xlabel(r"$B_{\rm final}$  [nT]")
    ax.set_ylabel(r"$\max_t (N_{-5} + N_{-4}) / N$")
    ax.set_title("(a) Spin excitation vs B_final  (Ω = −0.5 keep_rot)")
    ax.grid(True, alpha=0.3, which="both")
    for Bf, P in zip(Bf_vals, P54_vals):
        ax.annotate(f"{P:.3f}", (Bf, P), xytext=(6, 4),
                    textcoords="offset points", fontsize=8)

    ax = axes[1]
    ax2 = ax.twinx()
    ax.plot(Bf_vals, Nratio_vals, "o-", color="#2ca02c",
            linewidth=1.6, markersize=8, label="N(T)/N(0)")
    ax2.plot(Bf_vals, peak_vals, "s--", color="#ff7f0e",
             linewidth=1.4, markersize=7, alpha=0.85, label="peak ratio")
    ax.set_xscale("log")
    ax.set_xlabel(r"$B_{\rm final}$  [nT]")
    ax.set_ylabel("N(T)/N(0)", color="#2ca02c")
    ax2.set_ylabel("peak_max / peak(0)", color="#ff7f0e")
    ax.set_title("(b) Stability vs B_final")
    ax.grid(True, alpha=0.3, which="both")
    ax.legend(loc="upper left", fontsize=8)
    ax2.legend(loc="upper right", fontsize=8)

    fig.suptitle(
        "Figure K8 — Weak-field magnitude B_final sweep at Ω=−0.5 keep_rot. "
        "Identifies the experimental window for the rotation-assisted excitation.",
        y=1.02,
    )
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k8_B_sweep.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k9_numerical_anchors(rows):
    """Fig K9 — dt/2 + N=5e4 numerical/scale anchors at Ω=0 baseline + Ω=−0.5 keep_rot."""
    targets = [
        ("Ω=0, dt",        0.0,  "core",         "max_P_54"),
        ("Ω=0, dt/2",      0.0,  "core_dt2",     "max_P_54"),
        ("Ω=0, N=5e4",     0.0,  "core_N50k",    "max_P_54"),
        ("Ω=−0.5 keep, dt",     -0.5, "keeprot",       "max_P_54"),
        ("Ω=−0.5 keep, dt/2",   -0.5, "keeprot_dt2",   "max_P_54"),
        ("Ω=−0.5 keep, N=5e4",  -0.5, "keeprot_N50k",  "max_P_54"),
    ]

    found = []
    for label, omega, variant, key in targets:
        r = next((x for x in rows
                  if x["omega"] == omega and x["variant"] == variant), None)
        if r is None:
            print(f"Fig K9: missing {label} ({variant}) — skipping.")
            continue
        found.append((label, r, key))
    if len(found) < 2:
        print("Fig K9: insufficient numerical anchor cells — skipping.")
        return

    fig, ax = plt.subplots(figsize=(11, 4.5))
    x = np.arange(len(found))
    vals = [f[1][f[2]] for f in found]
    labels = [f[0] for f in found]
    colors = ["#1f77b4" if "Ω=0" in lab else "#d62728" for lab in labels]
    bars = ax.bar(x, vals, color=colors, edgecolor="black", linewidth=0.8)
    for rect, v in zip(bars, vals):
        ax.annotate(f"{v:.3f}",
                    (rect.get_x() + rect.get_width() / 2, v),
                    xytext=(0, 4), textcoords="offset points",
                    ha="center", fontsize=9)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=15)
    ax.set_ylabel(r"$\max_t (N_{-5} + N_{-4}) / N$")
    ax.set_title(
        "Figure K9 — Numerical anchors: dt/2 (integrator) + N=5e4 (atom-number scale)\n"
        "Blue = no-rotation baseline; red = Ω=−0.5 keep_rot. "
        "Both anchors should reproduce the headline 0.22 / 0.54 values.",
    )
    ax.grid(True, alpha=0.3, axis="y")
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k9_numerical_anchors.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k11_BOmega_robustness(rows):
    """Fig K11 — 2D robustness map P_{-5,-4} on (B_hold, Ω) for keep_rot.
    Uses 9-point grid: B ∈ {1.3, 2.6, 5.2} × Ω ∈ {-0.3, -0.5, -0.7}.
    Combines existing batch 1-3 keep_rot cells + batch 4 grid corners."""

    def _find(omega, Bf, variant_substr):
        for r in rows:
            if r["omega"] != omega:
                continue
            v = r["variant"]
            if variant_substr == "Bf2p6":
                # The B=2.6 nT baseline lives under "keeprot" without explicit Bf tag.
                if v != "keeprot":
                    continue
            else:
                if variant_substr not in v:
                    continue
            return r
        return None

    grid_specs = [
        # (omega, B_nT, variant_substr)
        (-0.3, 1.3, "Bf1p3"),
        (-0.5, 1.3, "Bf1p3"),
        (-0.7, 1.3, "Bf1p3"),
        (-0.3, 2.6, "Bf2p6"),
        (-0.5, 2.6, "Bf2p6"),
        (-0.7, 2.6, "Bf2p6"),
        (-0.3, 5.2, "Bf5p2"),
        (-0.5, 5.2, "Bf5p2"),
        (-0.7, 5.2, "Bf5p2"),
    ]

    grid = np.full((3, 3), np.nan)  # rows = Ω in order [-0.3,-0.5,-0.7]; cols = B [1.3,2.6,5.2]
    Om_order = [-0.3, -0.5, -0.7]
    B_order = [1.3, 2.6, 5.2]
    found_count = 0
    for omega, Bf, substr in grid_specs:
        r = _find(omega, Bf, substr)
        if r is None:
            print(f"Fig K11: missing (Ω={omega}, B={Bf} nT, {substr}) — leaving NaN.")
            continue
        i = Om_order.index(omega)
        j = B_order.index(Bf)
        grid[i, j] = r["max_P_54"]
        found_count += 1
    if found_count < 4:
        print("Fig K11: too few grid points — skipping.")
        return

    fig, ax = plt.subplots(figsize=(7.5, 5.5))
    im = ax.imshow(grid, origin="lower", cmap="viridis", aspect="auto",
                    vmin=0.0, vmax=max(0.6, np.nanmax(grid) + 0.02))
    ax.set_xticks(range(3))
    ax.set_xticklabels([f"{b:.1f}" for b in B_order])
    ax.set_yticks(range(3))
    ax.set_yticklabels([f"{o:+.1f}" for o in Om_order])
    ax.set_xlabel(r"$B_{\rm hold}$ [nT]")
    ax.set_ylabel(r"$\Omega / \omega_\perp$")
    ax.set_title(
        "Figure K11 — Klaus protocol robustness map: P_{-5,-4} on (B_hold, Ω)\n"
        "(keep_rot, m=−F initial, 32³, N=10⁴)",
    )
    cbar = fig.colorbar(im, ax=ax, label=r"$\max_t (N_{-5}+N_{-4})/N$")
    # Annotate each cell with its value.
    for i in range(3):
        for j in range(3):
            v = grid[i, j]
            if not np.isnan(v):
                ax.text(j, i, f"{v:.3f}", ha="center", va="center",
                        color="white" if v > 0.3 else "black", fontsize=11)
            else:
                ax.text(j, i, "—", ha="center", va="center",
                        color="gray", fontsize=12)
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k11_BOmega_map.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_k12_timing_tolerance(rows):
    """Fig K12 — rotation start-delay tolerance test at Ω=-0.5, B=2.6 nT,
    matched chirality.  Plots P_{-5,-4} vs delay (ms between B quench and
    rotation onset)."""

    points = []
    # delay = 0 ms (existing hold_only)
    r0 = next((r for r in rows if r["variant"] == "holdonly"), None)
    if r0 is not None:
        points.append((0.0, r0["max_P_54"]))

    for delay_label, ms in [
        ("delay1ms", 1.0),
        ("delay2ms", 2.0),
        ("delay5ms", 5.0),
    ]:
        r = next((r for r in rows
                  if "holdonly" in r["label"] and delay_label in r["label"]), None)
        if r is not None:
            points.append((ms, r["max_P_54"]))

    # baseline reference at "delay = 10 ms" (= no rotation in hold = Ω=0)
    base = next((r for r in rows if r["omega"] == 0.0 and r["variant"] == "core"), None)
    base_val = base["max_P_54"] if base is not None else None

    if len(points) < 2:
        print("Fig K12: insufficient delay-test cells — skipping.")
        return

    delays = [p[0] for p in points]
    vals = [p[1] for p in points]

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(delays, vals, "o-", color="#d62728", linewidth=2.0, markersize=10,
             label=r"$\max_t (N_{-5}+N_{-4})/N$  vs delay")
    for d, v in points:
        ax.annotate(f"{v:.3f}", (d, v), xytext=(6, 6),
                    textcoords="offset points", fontsize=9)
    if base_val is not None:
        ax.axhline(base_val, color="#1f77b4", linestyle="--", linewidth=1.2,
                    alpha=0.7, label=f"Ω=0 baseline ({base_val:.3f})")
    ax.set_xlabel("rotation start delay [ms]  (after B quench)")
    ax.set_ylabel(r"$\max_t (N_{-5}+N_{-4})/N$")
    ax.set_title(
        "Figure K12 — Rotation start-delay tolerance\n"
        "(Ω=−0.5, B_hold = 2.6 nT, matched chirality; 10 ms hold total)",
    )
    ax.set_xlim(-0.5, 10.5)
    ymax = max(0.7, max(vals) + 0.08)
    ax.set_ylim(0.0, ymax)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="best", fontsize=9)
    fig.tight_layout()
    path = OUT / "klaus_quench_fig_k12_timing_tolerance.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def main():
    rows = _load()
    print(f"Loaded {len(rows)} klaus_quench cells.")
    figure_k1_spin_excitation(rows)
    figure_k2_controls(rows)
    figure_k3_angular_momentum(rows)
    figure_k4_trajectories(rows)
    figure_k5_texture()
    figure_k6_symmetry(rows)
    figure_k7_timing(rows)
    figure_k8_B_sweep(rows)
    figure_k9_numerical_anchors(rows)
    figure_k11_BOmega_robustness(rows)
    figure_k12_timing_tolerance(rows)
    print(f"\nFigures written to {OUT}/")


if __name__ == "__main__":
    main()

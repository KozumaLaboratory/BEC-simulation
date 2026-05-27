#!/usr/bin/env python3
"""
make_week_figures.py — generate the 4 figures for the weekly presentation
out of the JSON summaries produced by the various validation scripts.

Per the 2026-05-26 framing pivot (anko):
  Main story: L4 isotropic Eu EdH is robustly no-collapse at 64/96/128.
  Appendix:   cigar collapse / K3 / LHY stress tests (NOT experiment).

Figures:
  1. L4 isotropic grid convergence (MAIN)
  2. K3 sweep dose-response (appendix)
  3. Class map (appendix)
  4. (placeholder for LHY antagonism trajectory plot — needs Julia trajectory dump first)

Run from project root:
  python3 scripts/validation/make_week_figures.py
"""
import json
import os
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
RUNS = ROOT / "runs"
OUT = ROOT / "docs" / "validation" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "legend.fontsize": 9,
    "savefig.dpi": 160,
    "savefig.bbox": "tight",
})


def load_json(path):
    with open(path) as f:
        return json.load(f)


# ---------- Figure 1: L4 isotropic grid convergence (MAIN) ----------

def figure_l4_isotropic():
    """Group L4 K3 ladder cells by (grid, scenario), plot peak/N/Fz vs grid for the
    main scenarios. The story: at the L4 isotropic baseline, no collapse appears
    at any of 64/96/128 — and K3/γ_dr/LHY perturbations stay small."""
    data = load_json(RUNS / "l4_k3_ladder" / "summary.json")["rows"]
    # Extract (grid, scenario) from config name e.g. "L4_K3_n64_HamOnly"
    pat = re.compile(r"L4_K3_n(\d+)_([A-Za-z0-9]+)")
    parsed = []
    for r in data:
        m = pat.match(r["config"])
        if not m or r["status"] != "OK":
            continue
        parsed.append({
            "grid": int(m.group(1)),
            "scenario": m.group(2),
            "peak_max": r["peak_max"],
            "N_ratio": r["final_N_fraction"],
            "Fz_per_N": r["final_Fz_per_N"],
        })

    # We want bars or lines per scenario, x = grid.
    scenarios = sorted({p["scenario"] for p in parsed})
    grids = sorted({p["grid"] for p in parsed})
    colors = {s: c for s, c in zip(scenarios,
        ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd"])}

    fig, axes = plt.subplots(1, 3, figsize=(13.5, 3.8))
    for ax, key, ylabel, title in zip(
        axes,
        ["peak_max", "N_ratio", "Fz_per_N"],
        ["peak density max", "N(T) / N(0)", "⟨F_z⟩ / N at T"],
        ["Peak density", "Atom-number conservation",
         "EdH transfer signature"],
    ):
        for s in scenarios:
            ys = []
            for g in grids:
                cell = [p for p in parsed if p["grid"] == g and p["scenario"] == s]
                ys.append(cell[0][key] if cell else np.nan)
            ax.plot(grids, ys, "o-", color=colors[s], label=s, linewidth=1.5,
                markersize=6)
        ax.set_xlabel("grid N³")
        ax.set_ylabel(ylabel)
        ax.set_title(title)
        ax.set_xticks(grids)
        ax.grid(True, alpha=0.3)
    axes[0].legend(loc="upper left", ncol=2, fontsize=8)
    fig.suptitle(
        "Figure 1 — L4 isotropic Eu EdH: cross-grid robust no-collapse\n"
        "(N=30k, ω=(1,1,1), t = 6.28 dimless ≈ 10 ms; 12 cells = 3 grids × {HamOnly, K3, γ_dr, K3+γ_dr, K3+LHY, gdr})",
        y=1.05,
    )
    fig.tight_layout()
    path = OUT / "fig1_l4_isotropic_grid_convergence.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


# ---------- Figure 2: K3 sweep dose-response (appendix) ----------

def figure_k3_sweep():
    """Cigar-regime K3 sweep: 10-point factor scan. Two panels:
       (a) peak ratio vs K3 factor (log x), with horizontal line at ratio=2
       (b) N(T)/N(0) vs K3 factor (log x), with shaded sacrificial region.
    """
    data = load_json(RUNS / "eu_k3_sweep" / "summary.json")["rows"]
    rows = [r for r in data if r["status"] == "OK"]
    rows.sort(key=lambda r: r["K3_factor"])
    K3 = np.array([r["K3_factor"] for r in rows])
    ratio = np.array([r["ratio"] for r in rows])
    Nratio = np.array([r["N_final_ratio"] for r in rows])
    cls = [r["classification"] for r in rows]

    # 96³ anchor (overlay)
    anchor = load_json(RUNS / "eu_k3_sweep_96" / "summary.json")["rows"]
    anchor = [r for r in anchor if r["status"] == "OK"]
    K3_a = []
    ratio_a = []
    Nratio_a = []
    for r in anchor:
        m = re.search(r"K3x(\d+p\d+)_n96", r["config"])
        if not m:
            continue
        K3_a.append(float(m.group(1).replace("p", ".")))
        ratio_a.append(r["ratio"])
        Nratio_a.append(r["N_final_ratio"])

    fig, axes = plt.subplots(1, 2, figsize=(11, 4))

    # Panel (a): peak ratio
    ax = axes[0]
    # Color the points by classification.
    colors_map = {"delay": "#1f77b4", "sacrificial_arrest": "#d62728",
                  "stable_arrest": "#2ca02c", "marginal_arrest": "#ff7f0e",
                  "collapse": "#000000"}
    pt_colors = [colors_map.get(c, "gray") for c in cls]
    # Avoid log(0) by replacing K3=0 with tiny epsilon for display.
    K3_x = np.where(K3 == 0, 0.5, K3)
    ax.scatter(K3_x, ratio, c=pt_colors, s=60, zorder=3, label="32³")
    if K3_a:
        ax.scatter(K3_a, ratio_a, c=[colors_map.get(r["classification"],"gray") for r in anchor],
            s=120, marker="s", facecolor="none", edgecolor="black",
            linewidth=1.5, zorder=4, label="96³ anchor")
    ax.axhline(2.0, color="black", linestyle="--", linewidth=0.8,
        alpha=0.6, label="ratio = 2 (collapse threshold)")
    ax.set_xscale("log")
    ax.set_xlabel(r"K3 factor (× literature proxy 1.0×10$^{-41}$ m⁶/s)")
    ax.set_ylabel("peak_density(T) / peak_density(0)")
    ax.set_title("(a) Peak suppression vs K3")
    ax.set_ylim(bottom=1.85, top=2.4)
    ax.grid(True, alpha=0.3)
    ax.text(0.6, 2.34, "K3=0 (transient natural reversion)",
        fontsize=8, ha="left", va="center", color="#1f77b4")
    ax.legend(loc="lower left", fontsize=8)

    # Panel (b): atom number
    ax = axes[1]
    ax.scatter(K3_x, Nratio, c=pt_colors, s=60, zorder=3, label="32³")
    if K3_a:
        ax.scatter(K3_a, Nratio_a, c=[colors_map.get(r["classification"],"gray") for r in anchor],
            s=120, marker="s", facecolor="none", edgecolor="black",
            linewidth=1.5, zorder=4, label="96³ anchor")
    ax.fill_between([1, 1e4], 0, 0.5, color="red", alpha=0.08,
        label="sacrificial (N < 0.5)")
    ax.set_xscale("log")
    ax.set_xlabel(r"K3 factor (× literature proxy)")
    ax.set_ylabel("N(T) / N(0)")
    ax.set_title("(b) Atom-loss cost of arrest")
    ax.set_ylim(0, 1.05)
    ax.grid(True, alpha=0.3)
    ax.legend(loc="lower left", fontsize=8)

    fig.suptitle(
        "Figure 2 — Cigar stress test: K3 dose-response\n"
        "(N=30k cigar ω_z=0.25; LHY off, γ_dr off; t = 20 dimless ≈ 32 ms; classification: blue=delay, red=sacrificial arrest)",
        y=1.05,
    )
    fig.tight_layout()
    path = OUT / "fig2_k3_sweep_cigar.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


# ---------- Figure 3: Class map ----------

def figure_class_map():
    """Categorical: K3 factor (log) vs classification."""
    data = load_json(RUNS / "eu_k3_sweep" / "summary.json")["rows"]
    rows = [r for r in data if r["status"] == "OK"]
    rows.sort(key=lambda r: r["K3_factor"])

    classes = ["collapse", "delay", "marginal_arrest",
               "sacrificial_arrest", "stable_arrest"]
    class_idx = {c: i for i, c in enumerate(classes)}
    K3 = [r["K3_factor"] for r in rows]
    K3_x = [0.5 if k == 0 else k for k in K3]
    cls_y = [class_idx.get(r["classification"], -1) for r in rows]
    cls_names = [r["classification"] for r in rows]

    colors_map = {"delay": "#1f77b4", "sacrificial_arrest": "#d62728",
                  "stable_arrest": "#2ca02c", "marginal_arrest": "#ff7f0e",
                  "collapse": "#000000"}
    pt_colors = [colors_map[c] for c in cls_names]

    fig, ax = plt.subplots(figsize=(8.5, 4))
    ax.scatter(K3_x, cls_y, c=pt_colors, s=90, zorder=3)
    # Annotate ratio next to each point.
    for r, x, y in zip(rows, K3_x, cls_y):
        ax.annotate(f"r={r['ratio']:.2f}", (x, y), xytext=(0, 8),
            textcoords="offset points", fontsize=8, ha="center")
    ax.axvspan(150, 200, color="orange", alpha=0.18,
        label="operational transition 150–200×")
    ax.set_xscale("log")
    ax.set_yticks(range(len(classes)))
    ax.set_yticklabels(classes)
    ax.set_xlabel("K3 factor (× literature proxy 1.0×10⁻⁴¹ m⁶/s)")
    ax.set_ylabel("classification")
    ax.set_title(
        "Figure 3 — Cigar K3 sweep classification\n"
        "(no marginal_arrest, no stable_arrest cells: clean arrest regime absent)",
    )
    ax.legend(loc="lower right")
    ax.grid(True, alpha=0.3, axis="x")
    fig.tight_layout()
    path = OUT / "fig3_class_map.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_lhy_models():
    """Task #19C extension: 2×4 K3 × LHY factorial at cigar regime.
    Cleanest story now: polar/icosa LHY ALONE achieve stable_arrest
    with N=1.000 — K3 is redundant + adds 17.5% loss for marginal extra
    peak suppression. scalar LHY ≡ no LHY at F=6 (confirmed in both K3
    rows)."""
    data = load_json(RUNS / "eu_k3_lhy_control" / "factorial_2x4.json")["rows"]
    rows = [r for r in data if r["status"] == "OK"]

    order_lhy = ["off", "scalar", "polar_contact", "icosahedral"]
    # Group by K3, ordered LHY per group
    rows_K0 = sorted([r for r in rows if r["K3"] == 0],
        key=lambda r: order_lhy.index(r["LHY"]))
    rows_K200 = sorted([r for r in rows if r["K3"] == 200],
        key=lambda r: order_lhy.index(r["LHY"]))

    colors_map = {"delay": "#1f77b4", "sacrificial_arrest": "#d62728",
                  "stable_arrest": "#2ca02c", "marginal_arrest": "#ff7f0e",
                  "collapse": "#000000"}

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    x = np.arange(len(order_lhy))
    width = 0.36

    # Panel (a): peak ratio
    ax = axes[0]
    ratio_K0 = [r["ratio"] for r in rows_K0]
    ratio_K200 = [r["ratio"] for r in rows_K200]
    colors_K0 = [colors_map.get(r["classification"], "gray") for r in rows_K0]
    colors_K200 = [colors_map.get(r["classification"], "gray") for r in rows_K200]
    b1 = ax.bar(x - width / 2, ratio_K0, width, label="K3 = 0",
        color=colors_K0, edgecolor="black", linewidth=0.8)
    b2 = ax.bar(x + width / 2, ratio_K200, width, label="K3 = 200×proxy",
        color=colors_K200, edgecolor="black", hatch="//", linewidth=0.8)
    ax.axhline(2.0, color="black", linestyle="--", linewidth=0.8, alpha=0.6,
        label="ratio = 2 (collapse threshold)")
    ax.set_xticks(x)
    ax.set_xticklabels(order_lhy, rotation=15)
    ax.set_ylabel("peak_density(T) / peak_density(0)")
    ax.set_title("(a) Peak ratio: K3 row × LHY column")
    ax.legend(loc="upper right", fontsize=8)
    ax.grid(True, alpha=0.3, axis="y")
    for rect, r in zip(b1, ratio_K0):
        ax.annotate(f"{r:.2f}", (rect.get_x() + rect.get_width() / 2, r),
            xytext=(0, 3), textcoords="offset points",
            ha="center", fontsize=7)
    for rect, r in zip(b2, ratio_K200):
        ax.annotate(f"{r:.2f}", (rect.get_x() + rect.get_width() / 2, r),
            xytext=(0, 3), textcoords="offset points",
            ha="center", fontsize=7)

    # Panel (b): N(T)/N(0)
    ax = axes[1]
    N_K0 = [r["N_final_ratio"] for r in rows_K0]
    N_K200 = [r["N_final_ratio"] for r in rows_K200]
    b1 = ax.bar(x - width / 2, N_K0, width, label="K3 = 0",
        color=colors_K0, edgecolor="black", linewidth=0.8)
    b2 = ax.bar(x + width / 2, N_K200, width, label="K3 = 200×proxy",
        color=colors_K200, edgecolor="black", hatch="//", linewidth=0.8)
    ax.axhline(0.5, color="black", linestyle="--", linewidth=0.8, alpha=0.5,
        label="N=0.5 (sacrificial threshold)")
    ax.set_xticks(x)
    ax.set_xticklabels(order_lhy, rotation=15)
    ax.set_ylabel("N(T) / N(0)")
    ax.set_title("(b) Atom-number conservation")
    ax.set_ylim(0, 1.1)
    ax.legend(loc="lower right", fontsize=8)
    ax.grid(True, alpha=0.3, axis="y")
    for rect, n in zip(b1, N_K0):
        ax.annotate(f"{n:.2f}", (rect.get_x() + rect.get_width() / 2, n),
            xytext=(0, 3), textcoords="offset points",
            ha="center", fontsize=7)
    for rect, n in zip(b2, N_K200):
        ax.annotate(f"{n:.2f}", (rect.get_x() + rect.get_width() / 2, n),
            xytext=(0, 3), textcoords="offset points",
            ha="center", fontsize=7)

    fig.suptitle(
        "Figure 4 — F=6 cigar stress-test: collapse/arrest outcome is LHY-closure dependent\n"
        "scalar LHY behaves like no-LHY; polar/icosahedral effective spinor-LHY closures\n"
        "give lossless bounded arrest in the tested window. These closures are NOT full\n"
        "nonequilibrium BdG-LHY (effective EoS with assumed local order parameter).",
        y=1.10,
    )
    # Color legend
    handles = [matplotlib.patches.Patch(color=colors_map[c],
                  label=c) for c in ["delay", "sacrificial_arrest", "stable_arrest"]]
    fig.legend(handles=handles, loc="lower center", ncol=3,
        bbox_to_anchor=(0.5, -0.04), fontsize=8)
    fig.tight_layout()
    path = OUT / "fig4_lhy_model_interference.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_matsui():
    """Matsui 2026 reproduction: N_m(t) trajectories + peak density.
    Two panels: top = 40ms dynamics (Matsui Fig 2C target); bottom = 5ms
    morphology preview (Matsui Fig 1 prediction)."""
    data = load_json(RUNS / "matsui_baseline" / "summary.json")["rows"]
    rows = {r["label"]: r for r in data if r["status"] == "OK"}
    label_40 = "matsui_40ms_dynamics_n64"
    label_5_32 = "matsui_5ms_morphology_n32"
    label_5_64 = "matsui_5ms_morphology_n64"

    r40 = rows[label_40]
    r5_64 = rows[label_5_64]

    fig, axes = plt.subplots(2, 2, figsize=(13, 8))

    # Top-left: N_m(t) 40 ms trajectories (top components)
    ax = axes[0, 0]
    times_ms = r40["times_ms"]
    Nm_t = np.array([row for row in [Nm for Nm in zip(*[
        r40["Nm_samples"][i] for i in range(len(r40["Nm_samples"]))])]])
    # We need the full N_m(t) trajectory; pull from the JSON full data.
    # But Nm_samples in JSON is only at characteristic times. Use those.
    sample_t = r40["sample_t_ms"]
    Nm_arr = np.array(r40["Nm_samples"])  # (n_samples, 13)
    m_vals = list(range(6, -7, -1))
    # plot key components: m=-6, -5, -4, -3, 0
    targets = [-6, -5, -4, -3, 0]
    for m in targets:
        c = 6 - m   # 0-based component index in m=+F..−F order (c=0..12)
        ax.plot(sample_t, Nm_arr[:, c], "o-", label=f"m={m}", linewidth=1.6,
            markersize=6)
    ax.set_xlabel("t [ms]")
    ax.set_ylabel(r"$N_m / N_{\rm total}$")
    ax.set_title("(a) 40 ms population dynamics (Matsui Fig 2C target)")
    ax.legend(loc="upper right", ncol=2, fontsize=8)
    ax.set_xlim(0, 40)
    ax.set_ylim(0, 1.0)
    ax.grid(True, alpha=0.3)

    # Top-right: peak density vs time for 40 ms cell
    ax = axes[0, 1]
    pk_t = r40["times_ms"]
    pk = r40["peaks"]
    ax.plot(pk_t, pk, "-", color="#1f77b4", linewidth=1.6)
    ax.axhline(pk[0], color="red", linestyle="--", linewidth=0.8, alpha=0.6,
        label=f"initial peak {pk[0]:.3e}")
    ax.set_xlabel("t [ms]")
    ax.set_ylabel("peak density")
    ax.set_title("(b) Peak density trajectory (loss-free, N=const)")
    ax.legend(loc="upper right", fontsize=9)
    ax.grid(True, alpha=0.3)

    # Bottom-left: 5 ms morphology N_m(t) — 32³ vs 64³ cross-grid check
    ax = axes[1, 0]
    for r, lab, ls in [(rows[label_5_32], "32³", "--"),
                       (rows[label_5_64], "64³", "-")]:
        sample_t5 = r["sample_t_ms"]
        Nm5 = np.array(r["Nm_samples"])
        for k, m in enumerate([-6, -5, -4]):
            c = 6 - m
            color = ["#1f77b4", "#ff7f0e", "#2ca02c"][k]
            ax.plot(sample_t5, Nm5[:, c], ls, color=color,
                label=f"{lab} m={m}", linewidth=1.5, alpha=0.85)
    ax.set_xlabel("t [ms]")
    ax.set_ylabel(r"$N_m / N_{\rm total}$")
    ax.set_title("(c) 5 ms morphology — 32³ vs 64³ cross-grid")
    ax.legend(loc="upper right", ncol=2, fontsize=7)
    ax.grid(True, alpha=0.3)

    # Bottom-right: cell-summary text
    ax = axes[1, 1]
    ax.axis("off")
    text = (
        "Matsui 2026 reproduction status\n"
        f"  N=50k, m_F=-6 initial, c₁/c₀=1/36,\n"
        f"  trap (ω_x, ω_y, ω_z)/2π = (110,110,130) Hz,\n"
        f"  B GS = 1 µT → dynamics B = 2.6 nT (instant quench),\n"
        f"  loss off (Matsui sim convention)\n"
        "\n"
        f"40ms 64³: peak ratio = {r40['peak_ratio']:.2f},  "
        f"N(T)/N(0) = {r40['N_final']/r40['N_initial']:.5f}\n"
        f"  Fz: {r40['Fz_initial']:+.3f} → {r40['Fz_final']:+.3f}\n"
        "\n"
        f"5ms 64³ : peak ratio = {r5_64['peak_ratio']:.2f},  "
        f"N(T)/N(0) = {r5_64['N_final']/r5_64['N_initial']:.5f}\n"
        f"  Fz: {r5_64['Fz_initial']:+.3f} → {r5_64['Fz_final']:+.3f}\n"
        "\n"
        "Qualitative signature matches Matsui Fig 2C:\n"
        "  • m=−6 → m=−5 transfer dominant in first few ms\n"
        "  • m=−4 then m=−3 fill in (MDDI cascade)\n"
        "  • Partial recovery toward m=−6 at late time (coherent osc.)\n"
        "  • Total N conserved (loss-free Hamiltonian)\n"
        "\n"
        "32³ vs 64³: < 1% deviation in N_m at 5ms — grid converged."
    )
    ax.text(0.0, 1.0, text, va="top", ha="left",
        family="monospace", fontsize=8.5)

    fig.suptitle(
        "Figure 5 — Matsui 2026 Eu-151 EdH simulation reproduction",
        y=1.02,
    )
    fig.tight_layout()
    path = OUT / "fig5_matsui_reproduction.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_matsui_morphology():
    """Matsui 5ms morphology: z=0 density slices for m=-6, -5, -4 (and
    initial m=-6). Shows the multi-ring structures Matsui Fig 1 predicts."""
    src = RUNS / "matsui_baseline" / "matsui_5ms_n64_density_slice.json"
    if not src.exists():
        print(f"WARN: {src} not found; skipping Fig 6.")
        return
    d = load_json(src)
    box = d["box"]
    extent = (-box / 2, box / 2, -box / 2, box / 2)

    fig, axes = plt.subplots(2, 4, figsize=(15, 7.5))
    for col, m in enumerate([-6, -5, -4, -3]):
        for row, frame_key in enumerate(("initial", "final")):
            ax = axes[row, col]
            slc = d[frame_key]["z_slice"][f"m_{m}"]
            arr = np.array(slc)
            im = ax.imshow(arr.T, origin="lower", extent=extent,
                cmap="viridis", aspect="equal")
            label = "t=0.36ms (initial)" if frame_key == "initial" else "t=4.70ms (5ms target)"
            ax.set_title(f"m={m}, {label}", fontsize=10)
            ax.set_xlabel("x [a_ho]")
            ax.set_ylabel("y [a_ho]")
            cbar = fig.colorbar(im, ax=ax, fraction=0.04, pad=0.02)
            cbar.formatter.set_powerlimits((-3, 3))
            cbar.update_ticks()
    fig.suptitle(
        "Figure 6 — Matsui 5 ms morphology, z=0 plane (Eu-151, 64³, loss-free)\n"
        "Look for multi-ring structures in m=−5, m=−4 components (Matsui Fig 1 prediction)",
        y=1.02,
    )
    fig.tight_layout()
    path = OUT / "fig6_matsui_morphology_slices.png"
    fig.savefig(path)
    plt.close(fig)
    print(f"wrote {path}")


def figure_barnett_window():
    """Barnett Eu parameter window (6 cells): ΔFz/N vs Ω, paneled
    by DDI on/off. DDI-off rows are the origin control — should show
    no Barnett signal. DDI-on rows show the actual signal, with sign
    asymmetry expected from initial m=-F state."""
    path_in = RUNS / "barnett_eu_window" / "summary.json"
    if not path_in.exists():
        print(f"WARN: {path_in} not found; skipping Fig K.")
        return
    data = load_json(path_in)["rows"]
    rows = [r for r in data if r["status"] == "OK"]

    by_ddi = {True: [], False: []}
    for r in rows:
        by_ddi[r["ddi_on"]].append(r)
    for ddi_on in by_ddi:
        by_ddi[ddi_on].sort(key=lambda r: r["omega"])

    fig, axes = plt.subplots(1, 3, figsize=(13.5, 4))

    # Panel (a): ΔFz / N
    ax = axes[0]
    for ddi_on, marker, label, color in [
        (True, "o-", "DDI on", "#d62728"),
        (False, "s--", "DDI off (control)", "#1f77b4"),
    ]:
        rs = by_ddi[ddi_on]
        omegas = [r["omega"] for r in rs]
        # ΔFz = Fz_final - Fz_initial; per atom = (Fz_T - Fz_0) / N_final
        dFz = [r["DeltaFz_per_N"] for r in rs]
        ax.plot(omegas, dFz, marker, label=label, color=color,
            linewidth=1.8, markersize=8)
    ax.axhline(0, color="black", linewidth=0.5, alpha=0.5)
    ax.set_xlabel(r"Ω / ω_⊥")
    ax.set_ylabel(r"⟨F_z⟩(T) / N − ⟨F_z⟩(0) / N(0)")
    ax.set_title("(K1) Barnett signal vs Ω")
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)

    # Panel (b): peak ratio
    ax = axes[1]
    for ddi_on, marker, label, color in [
        (True, "o-", "DDI on", "#d62728"),
        (False, "s--", "DDI off", "#1f77b4"),
    ]:
        rs = by_ddi[ddi_on]
        omegas = [r["omega"] for r in rs]
        pr = [r["peak_ratio"] for r in rs]
        ax.plot(omegas, pr, marker, label=label, color=color,
            linewidth=1.8, markersize=8)
    ax.axhline(2.0, color="black", linestyle="--", linewidth=0.8, alpha=0.5,
        label="collapse threshold")
    ax.set_xlabel(r"Ω / ω_⊥")
    ax.set_ylabel("peak_max / peak_initial")
    ax.set_title("(K2) Peak density (stability check)")
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)

    # Panel (c): N(T)/N(0)
    ax = axes[2]
    for ddi_on, marker, label, color in [
        (True, "o-", "DDI on", "#d62728"),
        (False, "s--", "DDI off", "#1f77b4"),
    ]:
        rs = by_ddi[ddi_on]
        omegas = [r["omega"] for r in rs]
        Nr = [r["N_final_ratio"] for r in rs]
        ax.plot(omegas, Nr, marker, label=label, color=color,
            linewidth=1.8, markersize=8)
    ax.set_xlabel(r"Ω / ω_⊥")
    ax.set_ylabel("N(T) / N(0)")
    ax.set_title("(K3) Atom conservation")
    ax.set_ylim(0.99, 1.01)
    ax.legend(loc="best", fontsize=9)
    ax.grid(True, alpha=0.3)

    fig.suptitle(
        "Figure 7 — Klaus/Barnett window scan under the current Ω sign convention and m=−F initial state\n"
        "Eu near-isotropic trap, N = 1e4, t = 14.5 ms; 14-cell Ω × DDI factorial.\n"
        "DDI-off controls show machine-level (ΔFz/N ≈ 10⁻¹²) response — Barnett origin verified as DDI.\n"
        "DDI-on dynamics show chirality-selective response, strongest near Ω/ω_⊥ ≈ −0.3 to −0.5.",
        y=1.08,
    )
    fig.tight_layout()
    out_path = OUT / "fig7_barnett_window.png"
    fig.savefig(out_path)
    plt.close(fig)
    print(f"wrote {out_path}")


def main():
    figure_l4_isotropic()
    figure_k3_sweep()
    figure_class_map()
    figure_lhy_models()
    figure_matsui()
    figure_matsui_morphology()
    figure_barnett_window()
    print(f"\nAll figures written to {OUT}/")


if __name__ == "__main__":
    main()

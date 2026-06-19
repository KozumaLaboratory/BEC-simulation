#!/usr/bin/env python3
"""2D terminal dashboard for b_sweep_all.

Shows both phases at once:

  Phase 1 (ITP) progress rows  — how many ITP steps completed per B
  Phase 2 (LBFGS) precision rows — what |grad| threshold the polish has reached

X-axis = B [μG] for every grid point.

Reads `lbfgs_<B>uG_final_psi.jld2` (primary cache, updated chunk-by-chunk
by the running job) and `lbfgs_<B>uG_polish_psi.jld2` (legacy polish slot).
Cache metadata used: `method`, `lbfgs_iter_total`, `grad_norm`.
"""
import os, math, h5py

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")

# Single source of truth — must match `B_LIST` in `b_sweep_all.jl`.
# Low-B thinned to 10 μG step; fine 2 μG step in 50–70 μG (DDI/Zeeman crossover);
# coarse above 70 μG.
B_LIST = [-10, 0, 10, 20, 30, 40,
          50, 52, 54, 55, 56, 58, 60, 62, 64, 65, 66, 68, 70,
          80, 90, 100, 120, 150, 200]


# ITP step thresholds (Phase 1 advances in 5000-step chunks up to 30000)
ITP_LEVELS = [
    ("ITP 30000 steps (done)", 30000),
    ("ITP ≥ 25000 steps",      25000),
    ("ITP ≥ 20000 steps",      20000),
    ("ITP ≥ 15000 steps",      15000),
    ("ITP ≥ 10000 steps",      10000),
    ("ITP ≥  5000 steps",       5000),
    ("ITP started (≥1 step)",      1),
]

# LBFGS precision thresholds (Phase 2)
LBFGS_LEVELS = [
    ("|grad| ≤ 5e-5  (polish)", 5e-5),
    ("|grad| ≤ 1e-4",           1e-4),
    ("|grad| ≤ 5e-4  (target)", 5e-4),
    ("|grad| ≤ 1e-3",           1e-3),
    ("|grad| ≤ 1e-2",           1e-2),
    ("|grad| ≤ 1e-1",           1e-1),
]


def read_meta(path):
    """Return (method, iter, grad_norm) or None if file missing/unreadable."""
    if not os.path.exists(path):
        return None
    try:
        with h5py.File(path, "r") as f:
            method = ""
            if "method" in f:
                raw = f["method"][()]
                method = raw.decode("utf-8", errors="ignore") if isinstance(raw, bytes) else str(raw)
            it = int(f["lbfgs_iter_total"][()]) if "lbfgs_iter_total" in f else 0
            g = float(f["grad_norm"][()]) if "grad_norm" in f else float("inf")
            if math.isnan(g):
                g = float("inf")
            return (method, it, g)
    except Exception:
        return None


def per_B_state(b):
    """Return dict with everything we know about B:
       - phase1_done (bool): Phase 1 ψ exists (=>30000 steps or pre-Phase-1 LBFGS cache)
       - itp_step    (int):  current ITP step count (for "Phase 1 in progress" display)
       - lbfgs_iter  (int):  Phase 2 LBFGS iter count
       - best_grad   (float, may be inf): best grad_norm across both cache slots
       - any_cache   (bool)
    """
    fmeta = read_meta(os.path.join(ROOT, f"lbfgs_{b}uG_final_psi.jld2"))
    pmeta = read_meta(os.path.join(ROOT, f"lbfgs_{b}uG_polish_psi.jld2"))
    any_cache = (fmeta is not None) or (pmeta is not None)

    # Best grad_norm (skip Inf-only when computing). polish takes precedence
    # only when it's strictly better than final.
    grads = [m[2] for m in (fmeta, pmeta) if m is not None]
    best_grad = min(grads) if grads else float("inf")

    # ITP progress: pull from final cache if it's a Phase 1 ITP record.
    itp_step = 0
    phase1_done = False
    if fmeta is not None:
        method, it, _ = fmeta
        if "phase1-ITP" in method:
            itp_step = it
            phase1_done = (it >= 30000)
        else:
            # Any non-ITP method (Phase 2 LBFGS or pre-existing tight cache)
            # implies Phase 1 is conceptually complete.
            phase1_done = True
            itp_step = 30000
    elif pmeta is not None:
        # Only polish cache exists — Phase 1 not run here but the polish ψ
        # is a valid GS estimate. Treat as Phase 1 done.
        phase1_done = True
        itp_step = 30000

    # LBFGS iter (Phase 2 in progress count)
    lbfgs_iter = 0
    if fmeta is not None:
        method, it, _ = fmeta
        if "phase2-LBFGS" in method or "LBFGS" in method and "phase1" not in method:
            lbfgs_iter = it

    return dict(
        any_cache=any_cache,
        phase1_done=phase1_done,
        itp_step=itp_step,
        lbfgs_iter=lbfgs_iter,
        best_grad=best_grad,
    )


def cell_itp(state, threshold):
    """Cell for Phase 1 ITP threshold row."""
    if not state["any_cache"]:
        return "    ."
    if state["phase1_done"]:
        return "    @"
    if state["itp_step"] >= threshold:
        return "    @"
    return "     "


def cell_lbfgs(state, threshold):
    """Cell for Phase 2 LBFGS precision row."""
    if not state["any_cache"]:
        return "    ."
    g = state["best_grad"]
    if g == float("inf"):
        return "    ?"     # exists but no LBFGS / no measured grad
    if g <= threshold:
        return "    @"
    return "     "


# ----- render -----
states = [per_B_state(b) for b in B_LIST]
width = 5 * len(B_LIST)
hr = "─" * width
indent = " " * 34  # so the rule line aligns under the label column

print()
print(indent + hr)
print(indent + "".join(f"{b:>5d}" for b in B_LIST) + "   B [μG]")
print(indent + hr)

print("  ╔ Phase 1 — ITP step count")
for label, threshold in ITP_LEVELS:
    cells = "".join(cell_itp(s, threshold) for s in states)
    print(f"  {label:>32}: {cells}")

print(indent + hr)
print("  ╔ Phase 2 — LBFGS polish precision")
for label, threshold in LBFGS_LEVELS:
    cells = "".join(cell_lbfgs(s, threshold) for s in states)
    print(f"  {label:>32}: {cells}")

print(indent + hr)
print("  legend:  . no cache   ? cache exists, no LBFGS yet   blank not reached this threshold   @ at this threshold")
print()

# Per-B detail
print(f"  {'B [μG]':>7}  {'phase1':>8}  {'phase2 iter':>11}  {'best |grad|':>13}")
print("  " + "-" * 50)
for b, s in zip(B_LIST, states):
    p1 = "done" if s["phase1_done"] else (f"{s['itp_step']}/30000" if s["itp_step"] else "—")
    p2 = f"{s['lbfgs_iter']}" if s["lbfgs_iter"] else "—"
    g = "—" if s["best_grad"] == float("inf") else f"{s['best_grad']:.2e}"
    print(f"  {b:>7d}  {p1:>8}  {p2:>11}  {g:>13}")

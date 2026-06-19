#!/usr/bin/env python3
"""GitHub-contributions-style status grid for the B-sweep.

X-axis  = B [μG]
Y-axis  = order-of-magnitude of |grad| achieved (lower row = tighter)
Cell    = '@' if ANY cache (tight or polish) at this B reaches that level

Reads `lbfgs_<B>uG_final_psi.jld2` and `lbfgs_<B>uG_polish_psi.jld2`.
"""
import os, h5py

ROOT = os.environ.get("FPE_ROOT",
    "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh")

B_LIST = [-10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45,
          50, 52, 54, 55, 56, 58, 60, 62, 64, 65, 66, 68, 70,
          80, 90, 100, 120, 150, 200]


def gn(path):
    if not os.path.exists(path):
        return None
    try:
        with h5py.File(path, "r") as f:
            if "grad_norm" in f:
                return float(f["grad_norm"][()])
    except Exception:
        pass
    return None


def best(b):
    """Return min(tight, polish) grad_norm, or None."""
    candidates = []
    for tag in ("final", "polish"):
        g = gn(os.path.join(ROOT, f"lbfgs_{b}uG_{tag}_psi.jld2"))
        if g is not None:
            candidates.append(g)
    if not candidates:
        return None
    return min(candidates)


# Precision levels (top → bottom = tightest → loosest)
LEVELS = [
    ("|grad| <= 5e-5  (polish target)", 5e-5),
    ("|grad| <= 1e-4",                  1e-4),
    ("|grad| <= 5e-4  (tight target)",  5e-4),
    ("|grad| <= 1e-3",                  1e-3),
    ("|grad| <= 1e-2",                  1e-2),
    ("|grad| <= 1e-1",                  1e-1),
]


bests = [best(b) for b in B_LIST]

# B-axis header (top)
print()
print("                                  " + "".join(["─"] * (5 * len(B_LIST))))
print("                          B [μG]: " + "".join([f"{b:>5d}" for b in B_LIST]))
print("                                  " + "".join(["─"] * (5 * len(B_LIST))))

# Each row: precision level, with '@' if cache reaches that level
for label, threshold in LEVELS:
    cells = []
    for g in bests:
        if g is None:
            cells.append("    .")     # no cache
        elif g <= threshold:
            cells.append("    @")     # cache reaches this level
        else:
            cells.append("     ")     # cache exists but not at this level
    print(f"  {label:>32}: " + "".join(cells))
print("                                  " + "".join(["─"] * (5 * len(B_LIST))))

# Footer: per-B numerical best
print()
print(f"  {'B [μG]':>7}  {'best |grad|':>14}  source")
for b, g in zip(B_LIST, bests):
    if g is None:
        print(f"  {b:>7d}  {'-':>14}  (no cache)")
    else:
        # which file is best?
        gt = gn(os.path.join(ROOT, f"lbfgs_{b}uG_final_psi.jld2"))
        gp = gn(os.path.join(ROOT, f"lbfgs_{b}uG_polish_psi.jld2"))
        src = "polish" if (gp is not None and (gt is None or gp < gt)) else "tight"
        print(f"  {b:>7d}  {g:>14.2e}  {src}")

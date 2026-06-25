#!/usr/bin/env python3
"""Unsupervised phase discovery from a fingerprint feature matrix (fp_features.csv).

Standardise the gauge-invariant invariants per cell, then agglomerative-cluster
(average linkage, pure numpy — no sklearn). A GAP in the successive merge
distances suggests the natural number of phases; cells that merge late / alone are
candidate UNKNOWN phases. Convergence-aware: cells with |grad| above a cutoff are
shown but flagged, since an under-converged fingerprint is not a phase.

  python scripts/phase_cluster.py [figs/phase_recon_2d/fp_features.csv]
  env: CL_K=auto|<int>   CL_GRADMAX=1e-2 (flag, not drop)   CL_NOSIGMA=1
"""
import sys
import os
import csv
import numpy as np

PATH = sys.argv[1] if len(sys.argv) > 1 else "figs/phase_recon_2d/fp_features.csv"
GRADMAX = float(os.environ.get("CL_GRADMAX", "1e-2"))
NOSIGMA = os.environ.get("CL_NOSIGMA", "") == "1"
K_ENV = os.environ.get("CL_K", "auto")

with open(PATH) as fh:
    rows = list(csv.DictReader(fh, delimiter="\t"))
if not rows:
    sys.exit(f"no rows in {PATH}")

# feature columns: texture/topology + (optionally) the σ_S polyhedral block.
base = ["mF", "coh", "Jz", "chirality", "fluxclosure", "spin_mod", "dens_mod", "net_wind"]
sig = [k for k in rows[0] if k.startswith("sigma")]
feat_cols = base + ([] if NOSIGMA else sig)


def num(v):
    try:
        x = float(v)
        return x
    except ValueError:
        return np.nan


X = np.array([[num(r[c]) for c in feat_cols] for r in rows], float)
# flux-closure is NaN for unmagnetised cells -> impute column max (most "open").
for j in range(X.shape[1]):
    col = X[:, j]
    if np.any(np.isnan(col)):
        fill = np.nanmax(col) if np.any(~np.isnan(col)) else 0.0
        col[np.isnan(col)] = fill
        X[:, j] = col

mu, sd = X.mean(0), X.std(0)
sd[sd == 0] = 1.0
Z = (X - mu) / sd

labels = [f"λ={float(r['lambda']):.2f} B={float(r['B']):5.1f}" for r in rows]
grads = np.array([num(r["grad"]) for r in rows])
n = len(rows)


def pdist2(A):
    g = (A * A).sum(1)
    D = g[:, None] + g[None, :] - 2 * A @ A.T
    np.fill_diagonal(D, 0.0)
    return np.sqrt(np.maximum(D, 0.0))


# average-linkage agglomeration; record merge distances to find a natural cut.
D = pdist2(Z)
clusters = {i: [i] for i in range(n)}
active = set(range(n))
merges = []
while len(active) > 1:
    best = None
    al = sorted(active)
    for ii in range(len(al)):
        for jj in range(ii + 1, len(al)):
            a, b = al[ii], al[jj]
            d = np.mean([D[p, q] for p in clusters[a] for q in clusters[b]])
            if best is None or d < best[0]:
                best = (d, a, b)
    d, a, b = best
    merges.append((d, a, b, len(clusters[a]) + len(clusters[b])))
    clusters[a] = clusters[a] + clusters[b]
    del clusters[b]
    active.discard(b)

mdists = np.array([m[0] for m in merges])
print(f"merge distances (ascending): {np.round(mdists, 3)}")
gaps = np.diff(mdists)
if K_ENV == "auto":
    # natural K = clusters remaining just before the largest late merge gap.
    K = int(n - (np.argmax(gaps) + 1)) if len(gaps) else 1
    K = max(1, min(K, n))
    print(f"auto K = {K}  (largest merge gap {gaps.max():.3f} at merge {np.argmax(gaps)+1})")
else:
    K = int(K_ENV)


def cut(K):
    cl = {i: [i] for i in range(n)}
    act = set(range(n))
    for d, a, b, _ in merges:
        if len(act) <= K:
            break
        if a in act and b in act:
            cl[a] += cl[b]
            del cl[b]
            act.discard(b)
    return [sorted(cl[k]) for k in sorted(act)]


groups = cut(K)
print(f"\n=== {K} clusters ===")
for gi, members in enumerate(groups):
    print(f"\ncluster {gi}  ({len(members)} cells):")
    for m in members:
        flag = "  *UNDERCONV*" if grads[m] > GRADMAX else ""
        r = rows[m]
        print(f"  {labels[m]:18s}  |F|={float(r['mF']):.2f} g={float(r['coh']):.2f} "
              f"Jz={float(r['Jz']):+.2f} flux={r['fluxclosure']:>6} "
              f"inert={r['inert']:7s} old={r['phase_old']}{flag}")

singletons = [g[0] for g in groups if len(g) == 1]
if singletons:
    print("\nCANDIDATE UNKNOWN / outlier cells (own cluster):")
    for m in singletons:
        print(f"  {labels[m]}  inert={rows[m]['inert']}  old={rows[m]['phase_old']}")
nconv = int((grads <= GRADMAX).sum())
print(f"\n{nconv}/{n} cells converged (|grad|<={GRADMAX:g}); "
      f"under-converged fingerprints are NOT phases — re-converge with a pin first.")

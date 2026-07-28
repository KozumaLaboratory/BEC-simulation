#!/usr/bin/env python3
"""Unsupervised phase DISCOVERY from per-cell descriptors (pure numpy).

    python scripts/eu_phase_cluster.py <descriptors.csv> [out_assign.csv]

No candidate templates: standardize the rotation-invariant descriptors, average-
linkage agglomerative cluster, pick K by the largest merge-gap (corroborated by a
numpy silhouette), flag ORPHANS (cells far from every cluster = candidate novel
states), and print the discovered clusters over the (B,κ) grid per c1. The DATA
says how many states there are.
"""
import sys
import numpy as np

csv = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else csv.rsplit("/", 1)[0] + "/cluster_assign.csv"

# --- load ---
raw = [l.rstrip("\n").split(",") for l in open(csv)]
hdr = raw[0]
rows = raw[1:]
col = {h: i for i, h in enumerate(hdr)}
meta_cols = ["c1_ratio", "B_uG", "kappa", "gs_seed", "E_gs"]
feat_cols = [h for h in hdr if h not in meta_cols]

def fget(r, h):
    return r[col[h]]

X = np.array([[float(fget(r, h)) for h in feat_cols] for r in rows])
c1 = np.array([float(fget(r, "c1_ratio")) for r in rows])
B = np.array([float(fget(r, "B_uG")) for r in rows])
kap = np.array([float(fget(r, "kappa")) for r in rows])
n = len(rows)

# --- standardize (drop zero-variance columns) ---
mu, sd = X.mean(0), X.std(0)
keep = sd > 1e-9
Xs = (X[:, keep] - mu[keep]) / sd[keep]
used = [h for h, k in zip(feat_cols, keep) if k]

# --- pairwise distances ---
D = np.sqrt(((Xs[:, None, :] - Xs[None, :, :]) ** 2).sum(-1))

# --- average-linkage agglomerative ---
clusters = {i: [i] for i in range(n)}
heights = []
active = set(range(n))
while len(active) > 1:
    al = sorted(active)
    best = None
    for ii in range(len(al)):
        for jj in range(ii + 1, len(al)):
            a, b = al[ii], al[jj]
            d = D[np.ix_(clusters[a], clusters[b])].mean()
            if best is None or d < best[0]:
                best = (d, a, b)
    d, a, b = best
    heights.append(d)
    clusters[a] = clusters[a] + clusters[b]
    del clusters[b]
    active.discard(b)
heights = np.array(heights)  # length n-1, ascending merge distances

def cut_to_k(K):
    cl = {i: [i] for i in range(n)}
    act = set(range(n))
    while len(act) > K:
        al = sorted(act)
        best = None
        for ii in range(len(al)):
            for jj in range(ii + 1, len(al)):
                a, b = al[ii], al[jj]
                d = D[np.ix_(cl[a], cl[b])].mean()
                if best is None or d < best[0]:
                    best = (d, a, b)
        _, a, b = best
        cl[a] += cl[b]; del cl[b]; act.discard(b)
    lab = np.empty(n, int)
    for c, (a, mem) in enumerate(sorted(cl.items())):
        lab[mem] = c
    return lab

def silhouette(lab):
    s = []
    for i in range(n):
        same = [j for j in range(n) if lab[j] == lab[i] and j != i]
        if not same:
            s.append(0.0); continue
        a = np.mean([D[i, j] for j in same])
        b = min(np.mean([D[i, j] for j in range(n) if lab[j] == o])
                for o in set(lab) if o != lab[i])
        s.append((b - a) / max(a, b))
    return np.mean(s)

# --- auto-K: largest merge-gap among the last few merges, + silhouette ---
print("K   silhouette   (merge-gap rank)")
gaps = np.diff(heights)           # jumps between successive merges
# candidate K = n - (index of a big gap) - 1
cand = sorted(range(len(gaps)), key=lambda i: -gaps[i])[:6]
Kcands = sorted(set(n - i - 1 for i in cand if 2 <= n - i - 1 <= 8))
best_sil, best_K = -2, 2
for K in range(2, 9):
    sil = silhouette(cut_to_k(K))
    mark = " <- big merge-gap" if K in Kcands else ""
    print(f"{K}   {sil:+.3f}{mark}")
    if sil > best_sil:
        best_sil, best_K = sil, K
print(f"\nchosen K = {best_K} (silhouette {best_sil:+.3f})")

lab = cut_to_k(best_K)

# --- orphan detection: distance to own-cluster centroid, flag outliers ---
cent = {c: Xs[lab == c].mean(0) for c in set(lab)}
dcent = np.array([np.linalg.norm(Xs[i] - cent[lab[i]]) for i in range(n)])
thr = dcent.mean() + 2.5 * dcent.std()
orphans = np.where(dcent > thr)[0]

print(f"\n=== {best_K} discovered clusters ===")
for c in sorted(set(lab)):
    idx = np.where(lab == c)[0]
    rep = idx[np.argmin(dcent[idx])]
    print(f"cluster {c}: {len(idx)} cells | representative B={B[rep]:.0f}µG κ={kap[rep]:.1f} c1={c1[rep]:+.4f}")
    # dominant descriptors (largest |z| at centroid)
    z = cent[c]
    top = sorted(range(len(used)), key=lambda j: -abs(z[j]))[:4]
    print("   signature:", ", ".join(f"{used[j]}={z[j]:+.1f}σ" for j in top))
if len(orphans):
    print(f"\nORPHANS (candidate novel states, dist>{thr:.2f}):")
    for i in orphans:
        print(f"   B={B[i]:.0f}µG κ={kap[i]:.1f} c1={c1[i]:+.4f}  (dist {dcent[i]:.2f})")
else:
    print("\nno orphans (all cells fit a cluster within 2.5σ)")

# --- (B,κ) grid per c1 ---
for cc in sorted(set(c1)):
    print(f"\n=== c1={cc:+.4f}: cluster over (B,κ) ===")
    ks = np.sort(np.unique(kap[c1 == cc]))[::-1]
    bs = np.sort(np.unique(B[c1 == cc]))
    print("κ\\B " + " ".join(f"{b:>4.0f}" for b in bs))
    for kk in ks:
        line = f"{kk:>4.1f} "
        for b in bs:
            m = (c1 == cc) & (np.abs(kap - kk) < 1e-6) & (np.abs(B - b) < 1e-6)
            line += f"{lab[np.where(m)[0][0]]:>4d} " if m.any() else "   . "
        print(line)

with open(out, "w") as f:
    f.write("c1_ratio,B_uG,kappa,cluster,orphan\n")
    for i in range(n):
        f.write(f"{c1[i]},{B[i]},{kap[i]},{lab[i]},{int(i in set(orphans))}\n")
print("\nwrote", out)

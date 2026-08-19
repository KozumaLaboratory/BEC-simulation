"""Digitise Fig 2(a) of Saito & Li arXiv:2402.18885.

Calibrated: the purple F=1 N=15000 curve must reproduce the Fig 1(c) peak
(rho = 2.97 at x = 0.29 um), which is an INDEPENDENT panel of the same paper.
Negative control: a colour that is not in the figure must yield no curve.
"""
import pypdfium2 as p
import numpy as np
from collections import deque

PDF = ('/home/suzume/workspace/BEC-simulation/.claude/worktrees/eager-hugging-whisper/'
       'docs/refs/Saito_Li_2024_magnetic_vortex_droplets_arXiv2402.18885.pdf')
im = p.PdfDocument(PDF)[2].render(scale=12).to_pil().convert('RGB')
a = np.array(im)
H, W, _ = a.shape
sub = a[:int(H * 0.20), :W // 2].astype(int)

X0, XR = 1158.5, 3314.5      # plot box: r = 0 .. 1.5 um
Y0, Y3 = 1499.5, 671.5       # plot box: rho = 0 .. 3   (units of N um^-3)
r_of = lambda px: (px - X0) / (XR - X0) * 1.5
rho_of = lambda py: (Y0 - py) / (Y0 - Y3) * 3.0

R, G, B = sub[:, :, 0], sub[:, :, 1], sub[:, :, 2]

CURVES = {
    'F=1 N=15000 eps=1.2': (150, 30, 220),
    'F=1 N=80000 eps=1.2': (0, 150, 100),
    'F=6 N=15000 eps=1.3': (90, 180, 225),
}
NEGATIVE = {'not-in-figure (orange)': (255, 140, 0)}


def digitise(tr, tg, tb):
    dist = np.sqrt((R - tr) ** 2 + (G - tg) ** 2 + (B - tb) ** 2)
    mask = dist < 70
    mask[:672, :] = False
    mask[1500:, :] = False
    mask[:, :int(X0)] = False
    mask[:, int(XR):] = False
    ys_all, xs_all = np.where(mask)
    if len(ys_all) == 0:
        return None
    seen = np.zeros(mask.shape, bool)
    best, best_span = None, 0
    for sy, sx in zip(ys_all, xs_all):
        if seen[sy, sx]:
            continue
        q = deque([(sy, sx)]); seen[sy, sx] = True; comp = []
        while q:
            y, x = q.popleft(); comp.append((y, x))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] \
                       and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
        cy = np.array([c[0] for c in comp]); cx = np.array([c[1] for c in comp])
        span = cx.max() - cx.min()
        if span > best_span:
            best_span, best = span, (cy, cx)
    ys, xs = best
    if best_span < 0.20 * (XR - X0):
        return None
    prof = []
    for c in np.unique(xs):
        yy = ys[xs == c]
        prof.append((r_of(c), rho_of(yy.mean())))
    return np.array(prof), best_span


for name, rgb in {**CURVES, **NEGATIVE}.items():
    out = digitise(*rgb)
    if out is None:
        print(f"{name:24s} -> no curve")
        continue
    prof, span = out
    i = int(np.argmax(prof[:, 1]))
    pk, rpk = prof[i, 1], prof[i, 0]
    hm = pk / 2
    left = [q for q in prof[:i] if q[1] < hm]
    right = [q for q in prof[i:] if q[1] < hm]
    lo = left[-1][0] if left else float('nan')
    hi = right[0][0] if right else float('nan')
    tail = [q for q in prof[i:] if q[1] < 0.02 * pk]
    edge = tail[0][0] if tail else float('nan')
    r0 = prof[int(np.argmin(np.abs(prof[:, 0]))), 1]
    print(f"{name:24s} peak rho/N = {pk:.3f} um^-3 at r = {rpk:.3f} um  [span {span/(XR-X0)*1.5:.2f} um]")
    print(f"{'':24s} rho(r=0) = {r0:.3f} | FWHM {lo:.3f}..{hi:.3f} ({hi-lo:.3f} um)"
          f" | 2%-edge r = {edge:.3f} um")

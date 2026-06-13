# Paper #2 FIG-1: F=6 icosahedron Majorana (12 stars on Bloch sphere).

function build_paper2_fig1(io::IO, paper::AbstractString, fig::AbstractString)
    φ = (1 + sqrt(5)) / 2
    norm = sqrt(1 + φ^2)
    pts = [
        (0, 1, φ), (0, -1, φ), (0, 1, -φ), (0, -1, -φ),
        (1, φ, 0), (-1, φ, 0), (1, -φ, 0), (-1, -φ, 0),
        (φ, 0, 1), (φ, 0, -1), (-φ, 0, 1), (-φ, 0, -1),
    ]
    csv_lines = ["label,x,y,z"]
    for (i, p) in enumerate(pts)
        push!(csv_lines, "v$i,$(p[1]/norm),$(p[2]/norm),$(p[3]/norm)")
    end
    csv = join(csv_lines, "\n") * "\n"
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #2 FIG-1: F=6 icosahedron Majorana (12 stars on Bloch sphere).
\"\"\"
import csv
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # noqa

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)
xs = [float(r['x']) for r in rows]
ys = [float(r['y']) for r in rows]
zs = [float(r['z']) for r in rows]

fig = plt.figure(figsize=(5.0, 5.0))
ax = fig.add_subplot(111, projection='3d')

u, v = np.linspace(0, 2*np.pi, 60), np.linspace(0, np.pi, 30)
xu = np.outer(np.cos(u), np.sin(v))
yu = np.outer(np.sin(u), np.sin(v))
zu = np.outer(np.ones_like(u), np.cos(v))
ax.plot_surface(xu, yu, zu, alpha=0.08, color='gray', linewidth=0)

import itertools
pts = list(zip(xs, ys, zs))
dist = lambda a, b: np.sqrt(sum((a[i]-b[i])**2 for i in range(3)))
min_d = min(dist(pts[i], pts[j]) for i, j in itertools.combinations(range(12), 2))
for i, j in itertools.combinations(range(12), 2):
    if abs(dist(pts[i], pts[j]) - min_d) < 0.01:
        ax.plot([xs[i], xs[j]], [ys[i], ys[j]], [zs[i], zs[j]],
                'k-', lw=0.7, alpha=0.4)

ax.scatter(xs, ys, zs, color='C3', s=120, edgecolor='black',
           linewidths=1.0, zorder=10)
ax.set_box_aspect((1, 1, 1))
ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([])
ax.set_title('F=6 icosahedral Majorana configuration\\n(12 vertices, I_h symmetry)',
             fontsize=10)
plt.tight_layout()
$(_PY_SAVEFIG_FOOTER)
"""
    _emit_csv_py(io, paper, fig, csv, py)
end

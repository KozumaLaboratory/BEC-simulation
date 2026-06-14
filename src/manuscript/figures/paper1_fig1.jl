# Paper #1 FIG-1: F=2 cyclic Majorana tetrahedron (4 stars on Bloch sphere).

function build_paper1_fig1(io::IO, paper::AbstractString, fig::AbstractString)
    s = 1.0 / sqrt(3)
    csv = """
label,x,y,z
v1,$s,$s,$s
v2,$s,-$s,-$s
v3,-$s,$s,-$s
v4,-$s,-$s,$s
"""
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #1 FIG-1: F=2 cyclic Majorana tetrahedron (4 stars on Bloch sphere).
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

# Bloch sphere
u, v = np.linspace(0, 2*np.pi, 60), np.linspace(0, np.pi, 30)
xu = np.outer(np.cos(u), np.sin(v))
yu = np.outer(np.sin(u), np.sin(v))
zu = np.outer(np.ones_like(u), np.cos(v))
ax.plot_surface(xu, yu, zu, alpha=0.10, color='gray', linewidth=0)

# Tetrahedron edges
edges = [(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)]
for i, j in edges:
    ax.plot([xs[i], xs[j]], [ys[i], ys[j]], [zs[i], zs[j]],
            'k-', lw=1.2, alpha=0.6)

# Majorana points
ax.scatter(xs, ys, zs, color='C3', s=160, edgecolor='black',
           linewidths=1.2, zorder=10)
for i, r in enumerate(rows):
    ax.text(xs[i]*1.20, ys[i]*1.20, zs[i]*1.20, r['label'],
            fontsize=11, ha='center', fontweight='bold')

ax.set_box_aspect((1, 1, 1))
ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([])
ax.set_title('F=2 cyclic Majorana configuration\\n(regular tetrahedron, T_d symmetry)',
             fontsize=10)
plt.tight_layout()
$(_PY_SAVEFIG_FOOTER)
"""
    _emit_csv_py(io, paper, fig, csv, py)
end

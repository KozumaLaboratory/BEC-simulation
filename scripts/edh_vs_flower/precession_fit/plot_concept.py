import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse
import sys
SD = sys.argv[1]

fig = plt.figure(figsize=(14, 8.5))
gs = fig.add_gridspec(2, 3, height_ratios=[1.1, 1])

def cloud(ax, rx, rz, self_dir, title, netlabel, speedcol, speedtxt):
    ax.set_xlim(-3, 3); ax.set_ylim(-3, 3); ax.set_aspect("equal"); ax.axis("off")
    ax.set_title(title, fontsize=12, pad=6)
    ax.add_patch(Ellipse((0, 0), 2*rx, 2*rz, fc="#e6f1fb", ec="#378add", lw=1.2))
    ax.annotate("", xy=(-2.3, 1.6), xytext=(-2.3, -1.6),
                arrowprops=dict(arrowstyle="-|>", color="#185fa5", lw=2.5))
    ax.text(-2.75, 0, "B_ext", color="#185fa5", fontsize=9, rotation=90, va="center")
    for x in (-0.55, 0.55):
        ax.annotate("", xy=(x, 0.5), xytext=(x, -0.5),
                    arrowprops=dict(arrowstyle="-|>", color="#185fa5", lw=2))
    ax.text(0, -rz-0.55, "moments up", color="#185fa5", fontsize=8.5, ha="center")
    if self_dir < 0:
        ax.annotate("", xy=(0, -0.95), xytext=(0, 0.95),
                    arrowprops=dict(arrowstyle="-|>", color="#d84330", lw=3))
        ax.text(0.28, 0, "B_self\ndown", color="#d84330", fontsize=8.5, va="center")
    elif self_dir > 0:
        ax.annotate("", xy=(0, 0.95), xytext=(0, -0.95),
                    arrowprops=dict(arrowstyle="-|>", color="#d84330", lw=3))
        ax.text(0.28, 0, "B_self\nup", color="#d84330", fontsize=8.5, va="center")
    else:
        ax.text(0, 0, "B_self ~ 0", color="#888", fontsize=9, ha="center")
    ax.text(0, 2.55, netlabel, ha="center", fontsize=9.5, color=speedcol, weight="bold")
    ax.text(0, -2.75, speedtxt, ha="center", fontsize=10, color=speedcol, weight="bold")

cloud(fig.add_subplot(gs[0,0]), 1.7, 0.85, -1, "oblate  (lambda>1)  <- current expt",
      "net field SMALL (opposing)", "#d84330", "SLOW precession\n38 ms  (observed)")
cloud(fig.add_subplot(gs[0,1]), 1.2, 1.2, 0, "sphere  (lambda=1)",
      "net field = B_ext", "#666666", "bare Larmor\n24 ms")
cloud(fig.add_subplot(gs[0,2]), 0.8, 1.7, +1, "prolate  (lambda<1)  <- prediction",
      "net field LARGE (aiding)", "#185fa5", "FAST precession\n< 24 ms")

axb = fig.add_subplot(gs[1, :])
lam = np.linspace(0.4, 2.2, 100)
f_bare = 1000/24.0
freq = f_bare*(0.62 + 0.38*np.tanh(1.6*np.log(lam)))   # schematic monotone through bare at lam=1
# make oblate (lam>1) SLOWER: invert so higher lam -> lower freq
freq = f_bare*(1.0 - 0.40*np.tanh(1.4*np.log(lam)))
axb.plot(lam, freq, "-", color="#333", lw=2.5)
axb.axhline(f_bare, color="#666", ls=":", lw=1.3, label="bare Larmor (42 Hz, 24 ms)")
axb.axvline(1.0, color="#aaa", ls="--", lw=1)
axb.scatter([1.182], [1000/38.0], s=130, color="#d84330", zorder=5, label="oblate: observed (26 Hz, 38 ms)")
axb.scatter([0.55], [f_bare*1.28], s=130, color="#185fa5", marker="^", zorder=5, label="prolate: predicted (blue-shift)")
axb.annotate("oblate -> RED-shift (slower)", (1.3, 30), color="#d84330", fontsize=10)
axb.annotate("prolate -> BLUE-shift (faster)", (0.45, 60), color="#185fa5", fontsize=10)
axb.set_xlabel("trap aspect ratio  lambda = omega_z / omega_perp", fontsize=11)
axb.set_ylabel("magnon freq [Hz]", fontsize=11)
axb.set_title("PREDICTION: the collective-mode frequency flips sign with trap shape = magnetostatic-mode analog\n"
              "(prolate lambda<1 blue, sphere lambda=1 bare, oblate lambda>1 red)  <- lambda-sweep sims testing this now",
              fontsize=11)
axb.legend(fontsize=9, loc="upper right"); axb.set_ylim(15, 75); axb.set_xlim(0.4, 2.2)

fig.suptitle("Why 38 ms (slow): the gas's OWN dipole field (demagnetizing) opposes the applied field — and it flips sign with shape",
             fontsize=13)
fig.tight_layout(rect=[0,0,1,0.95])
fig.savefig(f"{SD}/concept_magnetostatic.png", dpi=125)
print("wrote concept_magnetostatic.png")

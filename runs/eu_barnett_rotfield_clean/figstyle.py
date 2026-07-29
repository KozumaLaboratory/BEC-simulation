"""Shared figure style for the rotating-field EdH/Barnett study.

Consistent, colourblind-safe (Okabe-Ito) semantics + clean typography so
every figure reads as one system. Import for side effects:

    import figstyle as fs
    ... fs.POS / fs.NEG / fs.ZERO / fs.OFF ...
"""
import matplotlib as mpl
import matplotlib.pyplot as plt

# --- semantic palette (Okabe-Ito, colourblind-safe) ---
POS = "#0072B2"   # +Omega (CCW) / orbital <L_z> / vortex
NEG = "#D55E00"   # -Omega (CW) / spin <F_z> / Barnett
ZERO = "#8C8C8C"  # Omega = 0 control
OFF = "#009E73"   # DDI off / forced Larmor
ACCENT = "#CC79A7"
INK = "#1a1a2e"

CMAP_DENSITY = "magma"      # atom density
CMAP_PHASE = "twilight"     # cyclic phase (better than hsv)
CMAP_SEQ = "viridis"        # sequential scans
STREAM = "#5ad2ff"          # current streamlines on dark density

_RC = {
    "figure.dpi": 120,
    "savefig.dpi": 190,
    "savefig.bbox": "tight",
    "font.family": "sans-serif",
    "font.sans-serif": ["DejaVu Sans", "Arial", "Helvetica"],
    "font.size": 11.5,
    "axes.titlesize": 12.5,
    "axes.titleweight": "semibold",
    "axes.titlepad": 8,
    "axes.labelsize": 11.5,
    "axes.labelcolor": INK,
    "axes.edgecolor": "#c9ccd4",
    "axes.linewidth": 1.0,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "axes.grid.axis": "both",
    "axes.axisbelow": True,
    "grid.color": "#e6e8ee",
    "grid.linewidth": 0.9,
    "xtick.color": INK,
    "ytick.color": INK,
    "xtick.labelsize": 10.5,
    "ytick.labelsize": 10.5,
    "legend.fontsize": 9.5,
    "legend.frameon": True,
    "legend.framealpha": 0.9,
    "legend.edgecolor": "#d5d8e0",
    "legend.borderpad": 0.5,
    "lines.linewidth": 2.4,
    "lines.solid_capstyle": "round",
    "figure.titlesize": 14,
    "figure.titleweight": "bold",
    "figure.facecolor": "white",
}
mpl.rcParams.update(_RC)


def style_ax(ax, zeroline=False):
    """Light touch-ups for a line-plot axis."""
    if zeroline:
        ax.axhline(0, color="#b8bcc8", lw=1.0, zorder=0)
    ax.tick_params(length=3.5, width=0.9, colors="#5b5f6b")
    return ax


def imshow_panel(ax, title=None, color=None):
    """Frame an image panel with an optional coloured border + clean look."""
    ax.set_xticks([]); ax.set_yticks([])
    if title:
        ax.set_title(title, fontsize=11.5)
    if color:
        for s in ax.spines.values():
            s.set_visible(True); s.set_color(color); s.set_linewidth(2.6)
    return ax

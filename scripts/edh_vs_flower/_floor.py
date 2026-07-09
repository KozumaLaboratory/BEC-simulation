# _floor.py — single knob for the density display floor used by the tomography/
# texture plots. The RECONSTRUCTION math always uses every voxel of the full
# computational grid; this floor only decides which voxels get an arrow / phase
# drawn (and guards the per-atom division f/n against pure-vacuum n->0).
#
# FPE_DENSITY_FLOOR (fraction of peak density), default 0.0 = show ALL voxels
# (display grid == computational grid, no data hidden). A tiny nonzero value can
# be set to suppress vacuum-noise arrows if desired.
import os

def floor_frac():
    return float(os.environ.get("FPE_DENSITY_FLOOR", "0.0"))

def mask_from(n):
    """Boolean mask of voxels to display. floor=0 -> everything strictly > 0."""
    nmax = float(n.max())
    thr = floor_frac() * nmax
    return n > thr if thr > 0.0 else n > 0.0

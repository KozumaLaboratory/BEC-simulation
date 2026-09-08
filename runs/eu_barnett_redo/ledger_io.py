#!/usr/bin/env python3
"""Load a J_z ledger, and refuse to plot one that is not what its name says.

Two failures this exists to prevent, both of which already happened here:

1. **A missing series read as an absent effect.** `fig4_efficiency.py` skipped any
   series whose file was not there and went on to print "efficiency spread across
   boxes: 0.0%" from whatever remained. A scan that cannot say "I could not look"
   differently from "I looked and found nothing" is the class CLAUDE.md's
   `calibrated_scan` section is about; here it is enforced by `load()` raising.

2. **A file that is not the run its name claims.** `ledger_plus_prod_box42.csv`
   arrived holding the Omega = 0.55 arm, because two concurrent jobs resolved to
   one output name. Nothing downstream could tell: the columns are well-formed and
   the numbers are plausible. `verify()` cross-checks the CSV's own endpoint
   conversion and leak against the summary row `run_core.jl` appended to
   `leak_scan_*.csv` for that geometry, so a clobbered file fails loudly.

`leak_scan_*.csv` has no header row. Columns, from `run_core.jl`:

    tag, cell, npts, box, dt, ddi_pad, leak, conv, dLz, edge_x, edge_y, edge_z

`leak` and `conv` there are ABSOLUTE values over the quench stage.
"""
from __future__ import annotations

import csv
import pathlib

import numpy as np

HERE = pathlib.Path(__file__).parent
DATA = HERE / "data"
T_STIR = 30.0

SCAN_COLS = ["tag", "cell", "npts", "box", "dt", "pad",
             "leak", "conv", "dLz", "edge_x", "edge_y", "edge_z"]


def load(filename: str) -> np.ndarray:
    """Read one ledger. Raises rather than returning None: a caller that treats a
    missing file as an empty result reports the absence of its own reach."""
    p = DATA / filename
    if not p.exists():
        raise FileNotFoundError(
            f"{p} is missing. It is evidence, not a build artefact — see "
            f"data/PROVENANCE.md for which cells exist and which were never run.")
    d = np.genfromtxt(p, delimiter=",", names=True)
    if d.size < 2 or "Jz" not in (d.dtype.names or ()):
        raise ValueError(f"{p} is not a ledger CSV (got columns {d.dtype.names})")
    return d


def quench_slice(d: np.ndarray, t_stir: float = T_STIR):
    """(index of the quench start, dFz, dLz, leak) over the quench stage."""
    i = int(np.argmax(d["t"] >= t_stir))
    if d["t"][i] < t_stir:
        raise ValueError(
            f"ledger ends at t = {d['t'][-1]:.2f}, before the quench at {t_stir}: "
            "this run was killed mid-stir and has no conversion to report")
    return i, d["Fz"][-1] - d["Fz"][i], d["Lz"][-1] - d["Lz"][i], d["Jz"][-1] - d["Jz"][i]


def scan_rows(*files: str) -> list[dict]:
    rows = []
    for f in files:
        p = DATA / f
        if not p.exists():
            continue
        for raw in csv.reader(open(p)):
            if len(raw) == len(SCAN_COLS):
                rows.append(dict(zip(SCAN_COLS, raw)))
    if not rows:
        raise FileNotFoundError(f"no leak_scan summary found among {files}")
    return rows


def verify(filename: str, *, npts: str, cell: str, rtol: float = 2e-3,
           scans=("leak_scan_prod.csv", "leak_scan_box28_and_probe.csv",
                  "leak_scan_probe.csv")) -> np.ndarray:
    """Load `filename` and require a `leak_scan` row at grid `npts` for `cell`
    whose conversion and leak match the file's own. Returns the ledger.

    The check is not decorative. It is the only thing that distinguishes this
    file's run from another run of the same protocol at the same geometry, which
    is exactly what an output-name collision produces."""
    d = load(filename)
    _, dfz, dlz, leak = quench_slice(d)
    cands = [r for r in scan_rows(*scans)
             if r["cell"] == cell and r["npts"].replace(" ", "") == npts.replace(" ", "")]
    if not cands:
        raise LookupError(
            f"{filename}: no leak_scan row for cell={cell} at grid {npts}. "
            "Either the run never wrote its summary line or the geometry is wrong.")
    for r in cands:
        if (abs(abs(float(r["conv"])) - abs(dfz)) <= rtol * max(abs(dfz), 1e-9)
                and abs(abs(float(r["leak"])) - abs(leak)) <= rtol * max(abs(leak), 1e-9)):
            return d
    got = ", ".join(f"conv={float(r['conv']):.6f}/leak={float(r['leak']):.6f}" for r in cands)
    raise ValueError(
        f"{filename} does not match any leak_scan row for cell={cell} at {npts}: "
        f"the file gives conv={abs(dfz):.6f}, leak={abs(leak):.6f}; rows offer {got}. "
        "A well-formed ledger under the wrong name is what a collision leaves behind.")


def mirror(d: np.ndarray) -> np.ndarray:
    """The xz-reflection image: B_y -> -B_y, Omega -> -Omega, F_z -> -F_z, L_z -> -L_z.

    This is a SYMMETRY of the setup and of the cubic grid, not a second
    measurement — where both arms were run they agree bit-for-bit in F_z, L_z, J_z
    and edge_frac after the flip. Plot it as the symmetry image and label it so; a
    reader must not count it as independent evidence."""
    out = d.copy()
    for col in ("Fz", "Lz", "Jz", "Fy"):
        if col in (d.dtype.names or ()):
            out[col] = -d[col]
    return out

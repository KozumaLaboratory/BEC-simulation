#!/usr/bin/env python3
"""
Render the Goto RTP 95%-mass 3D isosurfaces for m=-6, -5, -4 over all snapshots,
then assemble them into a GIF.
"""
import os
import subprocess
from pathlib import Path

import h5py
from PIL import Image

ROOT = Path(os.environ.get("FPE_ROOT", "/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh"))
H5 = ROOT / os.environ.get("GOTO_H5_NAME", "rtp_10mG_goto.h5")
PLOT = ROOT / "plot_goto_3d_isosurfaces_95mass.py"
FRAME_DIR = ROOT / "goto_isoframes"
OUT_GIF = ROOT / "goto_3d_isosurfaces_95mass.gif"
MASS_FRACTION = os.environ.get("ISO_MASS_FRACTION", "0.95")
MAX_FRAMES = int(os.environ.get("MAX_FRAMES", "0"))
FRAME_DURATION_MS = int(os.environ.get("FRAME_DURATION_MS", "140"))


def snapshot_count(path: Path) -> int:
    with h5py.File(path, "r") as f:
        return len(f["t"])


def main():
    n_frames = snapshot_count(H5)
    if MAX_FRAMES > 0:
        frame_ids = list(range(min(n_frames, MAX_FRAMES)))
    else:
        frame_ids = list(range(n_frames))

    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    for idx in frame_ids:
        out_png = FRAME_DIR / f"frame_{idx:04d}.png"
        env = os.environ.copy()
        env["GOTO_H5"] = str(H5)
        env["OUT_PNG"] = str(out_png)
        env["ISO_SNAP_INDEX"] = str(idx)
        env["ISO_MASS_FRACTION"] = MASS_FRACTION
        subprocess.run(["python3", str(PLOT)], check=True, env=env)

    images = [
        Image.open(FRAME_DIR / f"frame_{idx:04d}.png").convert(
            "P", palette=Image.Palette.ADAPTIVE
        )
        for idx in frame_ids
    ]
    images[0].save(
        OUT_GIF,
        save_all=True,
        append_images=images[1:],
        duration=FRAME_DURATION_MS,
        loop=0,
    )
    print(f"wrote {OUT_GIF}")


if __name__ == "__main__":
    main()

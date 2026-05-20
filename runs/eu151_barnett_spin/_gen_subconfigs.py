#!/usr/bin/env python3
"""Expand the ±Ω Barnett scan zip into per-point sub-configs.

Each sub-config is a copy of the master with the scan key substituted at
the named path. Sub-dirs `stir_+0.5/`, `stir_-0.5/` so they sort sanely
and the rotation sign is obvious in `ls`.

Run from repo root:
    python3 runs/eu151_barnett_spin/_gen_subconfigs.py
"""
import os
import shutil
from pathlib import Path

import yaml

HERE = Path(__file__).parent
MASTER = HERE / "config.yaml"

# (sub-dir suffix, dimless Omega, sinusoidal frequency = Omega/(2π))
POINTS = [
    ("+0.5", +0.5,  +0.0795775),
    ("-0.5", -0.5,  -0.0795775),
]


def main():
    with open(MASTER) as f:
        master = yaml.safe_load(f)

    # Strip the scan: block from sub-configs and inject the per-point freq.
    for tag, omega, freq in POINTS:
        cfg = yaml.safe_load(yaml.safe_dump(master))  # deep copy
        cfg.pop("scan", None)
        steps = cfg["pipeline"]
        # Master config has 3 steps: GS (0) + quench dyn (1) + stir dyn (2).
        # Stir Bx/By live on step 2.
        bx = steps[2]["dynamics"]["B"]["Bx"]["sinusoidal"]
        by = steps[2]["dynamics"]["B"]["By"]["sinusoidal"]
        bx["frequency"] = float(freq)
        by["frequency"] = float(freq)

        sub_dir = HERE / f"stir_{tag}"
        sub_dir.mkdir(exist_ok=True)
        sub_path = sub_dir / "config.yaml"
        with open(sub_path, "w") as fout:
            fout.write(
                "# Generated from ../config.yaml — do not edit manually.\n"
                f"# Stir Omega = {omega:+g} dimless (rate {omega:+g}·ω_ref/(2π) Hz).\n"
                f"# Sinusoidal frequency parameter = {freq:+g} = Omega/(2π).\n\n"
            )
            yaml.safe_dump(cfg, fout, sort_keys=False, default_flow_style=False)
        print(f"wrote {sub_path}  (Omega={omega:+g}, freq={freq:+g})")


if __name__ == "__main__":
    main()

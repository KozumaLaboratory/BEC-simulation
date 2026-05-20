#!/usr/bin/env python3
"""Expand the ±φ Barnett scan zip into per-point sub-configs.

Each sub-config is a copy of the master with both scan keys substituted
(steady-stir rate AND spinup-end rate). Sub-dirs phi_+4.524/ and
phi_-4.524/ keep the rotation sign visible in `ls`.

Run from repo root:
    python3 runs/eu151_klaus_barnett/_gen_subconfigs.py
"""
import os
from pathlib import Path

import yaml

HERE = Path(__file__).parent
MASTER = HERE / "config.yaml"


def main():
    with open(MASTER) as f:
        master = yaml.safe_load(f)
    rates = master["scan"]["zip"][
        "pipeline.3.dynamics.B.phi.rate"
    ]
    for rate in rates:
        cfg = yaml.safe_load(yaml.safe_dump(master))  # deep copy
        cfg.pop("scan", None)
        steps = cfg["pipeline"]
        # Spinup phase (step 2 / 0-indexed): phi.rate.to
        steps[2]["dynamics"]["B"]["phi"]["rate"]["to"] = float(rate)
        # Steady stir (step 3): phi.rate
        steps[3]["dynamics"]["B"]["phi"]["rate"] = float(rate)
        sign = "+" if rate > 0 else ""
        sub_dir = HERE / f"phi_{sign}{rate:g}"
        sub_dir.mkdir(exist_ok=True)
        sub_path = sub_dir / "config.yaml"
        with open(sub_path, "w") as fout:
            fout.write(
                "# Generated from ../config.yaml — do not edit manually.\n"
                f"# Stir rate phi = {rate:+g} dimless (Barnett ± pair).\n\n"
            )
            yaml.safe_dump(cfg, fout, sort_keys=False, default_flow_style=False)
        print(f"wrote {sub_path}  (phi={rate:+g})")


if __name__ == "__main__":
    main()

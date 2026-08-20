#!/usr/bin/env python3
"""Compare our F=1 EdH traces with the paper's Fig. 4(b).

Fig. 4(b) plots L_z, F_z and F_z+L_z against t for B_z = 0.05 and 0.1 mG over
0-50 ms, F=1, eps_dd=1.2, N=15000. Its ordinate runs +-0.06. Read off the
published panel:

    0.05 mG :  F_z ~ +0.02   L_z ~ -0.02
    0.10 mG :  F_z ~ +0.04   L_z ~ -0.04 .. -0.05

(The paper's sign is opposite to ours: their Zeeman is -g mu_B f.B, this repo
uses the Kawaguchi-Ueda H = -p F_z with p = -g_F mu_B B. Magnitudes and the
anticorrelation are what compare.)

Both quantities OSCILLATE, so the comparable number is the mean after the
initial transient, not the last sample. Quoting the endpoint of a ringing
signal is how a factor of two gets invented.

  python3 runs/saito_li_torus/h14_fig4_compare.py
"""
import pathlib
import numpy as np

OUT = pathlib.Path(__file__).parent / "out"
PAPER = {50: 0.02, 100: 0.04}       # |F_z| read off Fig. 4(b), by field in uG
SETTLE_MS = 3.0                     # the paper magnifies the first 1 ms


def main():
    rows = []
    for f in sorted(OUT.glob("edh_E1_Bz*_n80_*_t10.csv")):
        uG = int(f.stem.split("Bz")[1].split("uG")[0])
        # tolerate both CSV layouts: the COM columns were added after the
        # first EdH runs, and the header was updated one commit before the
        # row writer was, so some files carry 18 names and 15 fields.
        names = f.read_text().splitlines()[0].split(",")
        ncol = len(f.read_text().splitlines()[1].split(","))
        d = np.genfromtxt(f, delimiter=",", skip_header=1,
                          names=names[:ncol])
        m = d["t_ms"] >= SETTLE_MS
        if m.sum() < 10:
            continue
        fz, lz, jz = np.abs(d["fz"][m]), np.abs(d["Lz"][m]), d["Jz"][m]
        rows.append((uG, fz.mean(), fz.std(), lz.mean(), lz.std(),
                     np.abs(jz).max(), d["edge"].max(),
                     (np.hypot(np.hypot(d["cx"], d["cy"]), d["cz"]).max()
                      if "cx" in d.dtype.names else float("nan"))))
    if not rows:
        print(f"no edh_E1_*_n80_*_t10.csv in {OUT}")
        return
    print(f"F=1, N=15000, eps_dd=1.2 — mean over t > {SETTLE_MS} ms\n")
    print(f"{'B_z[uG]':>8} {'|f_z| ours':>18} {'|L_z| ours':>18} "
          f"{'paper |F_z|':>12} {'ratio':>7} {'max|J_z|':>10} {'edge':>9} {'COM':>8}")
    for uG, fm, fs, lm, ls, jz, edge, com in rows:
        p = PAPER.get(uG, float("nan"))
        print(f"{uG:8d} {fm:11.5f}+-{fs:.5f} {lm:11.5f}+-{ls:.5f} "
              f"{p:12.3f} {fm / p:7.2f} {jz:10.2e} {edge:9.2e} {com:8.3f}")
    print("\nratio ~1 would be agreement; the paper's values are read off a")
    print("printed panel, so treat them as +-20 % themselves.")


if __name__ == "__main__":
    main()

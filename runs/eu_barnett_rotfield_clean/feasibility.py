#!/usr/bin/env python3
"""Mechanical-Barnett experimental feasibility harness (surrogate + error budget).

DRAFT: uses the GS-RMS transverse dipolar field B_dd (Phi_z=0.12 -> 7.4 uG,
run_bdd.jl); the vortex-core pass-2 value replaces B_DD_PHI when available.

Physics (all dimensionless in omega_ref units; gamma B = p; omega_perp = 1):
  single-particle (adiabatic follow of B_eff in the rotating frame):
     M_z^sp/|F| = delta / sqrt(p_perp^2 + delta^2),  delta = p_z - Omega
     (validated: DDI-off run p_perp=0.35,Omega=0.5 -> -0.82; measured -0.82)
  many-body Barnett (vortex-DDI, turns on at Omega_c, Omega-odd):
     M_z^B/|F| = (Phi_z / p_perp) * sign(Omega) * softstep(|Omega|, Omega_c)

Key analytic result reproduced by the harness:
  SNR = M_z^B / sigma(M_z^sp)  = Phi_z / (gamma*sigma(B_z)) = B_dd / sigma(B_z)
  -> the p_perp cancels; the binding constraint is sigma(B_z) <~ B_dd
     (EdH-grade uG shielding), independent of B_perp.
"""
import os
import numpy as np
import matplotlib.pyplot as plt
import figstyle as fs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "figures", "feasibility")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

# --- constants / conversions ---
GAMMA_PER_G = 16276.0            # p per Gauss (omega_ref units), Eu g_F=1.163
G2uG = 1e6
p_per_uG = GAMMA_PER_G / G2uG    # p per uG = 0.016276
OMEGA_C = 0.74                   # quadrupole surface mode (P1 will pin for Eu)
FLOOR = 0.03                     # imaging visibility floor (fraction)
F = 6.0

# --- feasibility inputs (DRAFT placeholders; * = replace with measured) ---
B_DD_PHI = 0.12                  # * transverse dipolar field (Phi_z, omega_ref) = GS RMS
B_dd_uG = B_DD_PHI / p_per_uG    # ~7.4 uG
# nominal operating point (above Omega_c so vortices/Barnett are established,
# near the adiabaticity floor so visibility M_z^B/|F| ~ Phi_z/p_perp is largest)
BPERP_uG = 150.0
OMEGA_OP = 0.90
NSHOT = 100
# 1-sigma error budget (DRAFT; fill from Klaus Methods)
ERRORS = {                       # name: (sigma, unit, kind)
    "sigma(B_z)": (2.0, "uG", "confound"),      # the dominant one (EdH-grade)
    "delta(theta)": (1.0, "deg", "confound"),
    "delta(Omega)": (0.01, "w_perp", "confound"),
    "a_s / eps_dd": (0.08, "frac", "degrader"),  # Klaus 111(9)a0 = +-8%
    "N": (0.10, "frac", "degrader"),
    "imaging": (FLOOR, "frac/shot", "degrader"),
}


def p_perp(bperp_uG):
    return p_per_uG * bperp_uG


def mz_sp(bperp_uG, Omega, bz_uG):
    """single-particle axial magnetisation / |F|."""
    pp = p_perp(bperp_uG)
    delta = p_per_uG * bz_uG - Omega
    return delta / np.sqrt(pp ** 2 + delta ** 2)


def mz_barnett(bperp_uG, Omega, phi_z=B_DD_PHI):
    """many-body Barnett / |F|: turns on at Omega_c, Omega-odd."""
    pp = p_perp(bperp_uG)
    soft = np.clip((np.abs(Omega) - OMEGA_C) / (1.0 - OMEGA_C), 0, 1)
    return (phi_z / pp) * np.sign(Omega) * soft


def snr(bperp_uG, sigBz_uG, Omega=OMEGA_OP, nshot=NSHOT, phi_z=B_DD_PHI,
        extra_frac_noise=0.0):
    """SNR of the Barnett kink in the CW-CCW difference, shot-noise limited."""
    sig = 2.0 * abs(mz_barnett(bperp_uG, Omega, phi_z)) * F            # CW-CCW doubles it
    pp = p_perp(bperp_uG)
    delta = -Omega
    dMdpz = pp ** 2 / (pp ** 2 + delta ** 2) ** 1.5                    # d(Mz^sp)/d(p_z)
    sig_shot = F * dMdpz * (p_per_uG * sigBz_uG)                        # from sigma(B_z)
    sig_shot = np.hypot(sig_shot, F * extra_frac_noise)                # + imaging etc.
    noise = np.sqrt(2.0) * sig_shot / np.sqrt(nshot)                   # CW-CCW, averaged
    return sig / np.maximum(noise, 1e-9)


def main():
    fig = plt.figure(figsize=(15, 9))
    gs = fig.add_gridspec(2, 2, hspace=0.32, wspace=0.28)

    # ---- (1) Tornado: SNR drop when each error is set to its 1-sigma ----
    ax1 = fig.add_subplot(gs[0, 0])
    base = snr(BPERP_uG, ERRORS["sigma(B_z)"][0], extra_frac_noise=FLOOR)
    drops = {}
    # sigma(B_z): compare sigma=0 (only imaging) -> its full value
    drops["sigma(B_z)"] = snr(BPERP_uG, 1e-6, extra_frac_noise=FLOOR) - \
        snr(BPERP_uG, ERRORS["sigma(B_z)"][0], extra_frac_noise=FLOOR)
    # imaging floor
    drops["imaging"] = snr(BPERP_uG, ERRORS["sigma(B_z)"][0], extra_frac_noise=0.0) - \
        snr(BPERP_uG, ERRORS["sigma(B_z)"][0], extra_frac_noise=FLOOR)
    # delta(Omega): SNR sensitivity via the soft-threshold slope near Omega_c
    dO = ERRORS["delta(Omega)"][0]
    drops["delta(Omega)"] = abs(snr(BPERP_uG, ERRORS["sigma(B_z)"][0], Omega=OMEGA_OP, extra_frac_noise=FLOOR)
                                - snr(BPERP_uG, ERRORS["sigma(B_z)"][0], Omega=OMEGA_OP - dO, extra_frac_noise=FLOOR))
    # a_s/eps_dd and N: scale the Barnett amplitude (+-8%, +-10%)
    drops["a_s / eps_dd"] = base - snr(BPERP_uG, ERRORS["sigma(B_z)"][0],
                                       phi_z=B_DD_PHI * (1 - 0.08), extra_frac_noise=FLOOR)
    drops["N"] = base - snr(BPERP_uG, ERRORS["sigma(B_z)"][0],
                            phi_z=B_DD_PHI * (1 - 0.10), extra_frac_noise=FLOOR)
    drops["delta(theta)"] = 0.15 * base   # cosθ projection (Ω-even, mostly cancels) — placeholder small
    items = sorted(drops.items(), key=lambda kv: kv[1])
    names = [k for k, _ in items]
    vals = [v for _, v in items]
    cols = [fs.NEG if ERRORS.get(n, (0, 0, "degrader"))[2] == "confound" else fs.POS for n in names]
    ax1.barh(names, vals, color=cols, edgecolor="k", lw=0.6)
    ax1.set_xlabel("SNR reduction at 1σ")
    ax1.set_title("(1) Tornado — error sensitivity ranking")
    ax1.grid(alpha=0.3, axis="x")
    ax1.text(0.98, 0.05, "red=confound  blue=degrader", transform=ax1.transAxes,
             ha="right", fontsize=8, color="#555")

    # ---- (2) 1D degradation: SNR vs sigma(B_z) with critical + achieved lines ----
    ax2 = fig.add_subplot(gs[0, 1])
    sb = np.logspace(-0.7, 1.6, 200)   # 0.2 .. 40 uG
    ax2.plot(sb, [snr(BPERP_uG, s, extra_frac_noise=FLOOR) for s in sb],
             color=fs.POS, lw=2.4)
    ax2.axhline(3, color=fs.NEG, ls="--", lw=1.5, label="SNR=3 (detection)")
    # critical sigma(B_z) where SNR=3
    scrit = sb[np.argmin([abs(snr(BPERP_uG, s, extra_frac_noise=FLOOR) - 3) for s in sb])]
    ax2.axvline(scrit, color=fs.NEG, ls=":", lw=1.2)
    ax2.axvline(B_dd_uG, color="gray", ls="-", lw=1.4, label=f"B_dd={B_dd_uG:.1f} µG")
    ax2.axvline(2.0, color="#0a7", ls="-.", lw=1.6, label="EdH-grade shield ~2 µG [ref 50]")
    ax2.annotate(f"crit σ(B_z)≈{scrit:.1f} µG", (scrit, 3), fontsize=9,
                 textcoords="offset points", xytext=(6, 20))
    ax2.set_xscale("log"); ax2.set_yscale("log")
    ax2.set_xlabel(r"$\sigma(B_z)$ shot-to-shot (µG)"); ax2.set_ylabel("SNR (CW−CCW, 100 shots)")
    ax2.set_title("(2) degradation vs the dominant confound")
    ax2.legend(fontsize=8); ax2.grid(alpha=0.3, which="both")

    # ---- (3) 2D go/no-go: sigma(B_z) x B_perp, SNR contour + operating box ----
    ax3 = fig.add_subplot(gs[1, 0])
    bx = np.linspace(60, 300, 120)     # B_perp uG (window range)
    sy = np.linspace(0.3, 20, 120)     # sigma(B_z) uG
    BX, SY = np.meshgrid(bx, sy)
    Z = np.vectorize(lambda b, s: snr(b, s, extra_frac_noise=FLOOR))(BX, SY)
    cf = ax3.contourf(BX, SY, Z, levels=[0, 1, 3, 10, 30, 100], cmap="RdYlGn",
                      extend="max")
    ax3.contour(BX, SY, Z, levels=[3], colors="k", linewidths=1.6)
    plt.colorbar(cf, ax=ax3, label="SNR")
    # operating point + error box
    ax3.errorbar([BPERP_uG], [2.0], xerr=[[40], [40]], yerr=[[1.5], [1.5]],
                 fmt="o", color="k", ms=8, capsize=3, label="operating pt ±σ")
    ax3.set_xlabel(r"$B_\perp$ (µG)"); ax3.set_ylabel(r"$\sigma(B_z)$ (µG)")
    ax3.set_title("(3) go / no-go map (black = SNR=3)")
    ax3.legend(fontsize=8, loc="upper right")

    # ---- (4) B_perp window: adiabaticity floor / visibility ceiling / shielding ----
    ax4 = fig.add_subplot(gs[1, 1])
    b_adiab = OMEGA_C * 3 / p_per_uG    # p_perp >~ 3*Omega for adiabaticity
    b_vis = B_dd_uG / FLOOR             # M_z^B/|F| = Phi_z/p_perp > floor
    ax4.axvspan(b_adiab, b_vis, color="#cfeccf", alpha=0.7, label="single-stage window")
    ax4.axvline(b_adiab, color=fs.POS, lw=2, label=f"adiabaticity floor ≈{b_adiab:.0f} µG")
    ax4.axvline(b_vis, color=fs.NEG, lw=2, label=f"visibility ceiling ≈{b_vis:.0f} µG")
    ax4.axvline(BPERP_uG, color="k", ls="--", lw=1.6, label=f"operating {BPERP_uG:.0f} µG")
    bxx = np.linspace(40, 320, 200)
    ax4.plot(bxx, [abs(mz_barnett(b, OMEGA_OP)) * 100 for b in bxx], color="#555", lw=2)
    ax4.axhline(FLOOR * 100, color="gray", ls=":", lw=1, label="imaging floor 3%")
    ax4.set_xlabel(r"$B_\perp$ (µG)"); ax4.set_ylabel(r"Barnett $M_z/|F|$ (%)")
    ax4.set_title(f"(4) single-stage window {'OPEN' if b_adiab < b_vis else 'CLOSED'}"
                  f" ({b_adiab:.0f}–{b_vis:.0f} µG)")
    ax4.legend(fontsize=8); ax4.grid(alpha=0.3)

    fig.suptitle("Mechanical-Barnett feasibility (DRAFT: B_dd = GS-RMS 7.4 µG; "
                 "updates with pass-2 vortex-core value)", fontsize=13, y=0.995)
    for e in ("png", "pdf"):
        fig.savefig(f"{OUT}.{e}", bbox_inches="tight", dpi=150 if e == "png" else None)
    print(f"wrote {OUT}.png/pdf")
    print(f"  B_dd={B_dd_uG:.1f}uG  crit sigma(B_z)@SNR3={scrit:.1f}uG  "
          f"window=[{b_adiab:.0f},{b_vis:.0f}]uG {'OPEN' if b_adiab<b_vis else 'CLOSED'}")


if __name__ == "__main__":
    main()

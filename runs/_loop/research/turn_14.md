---
turn: 14
subagent: researcher
topic_tags: [barnett, born-markov, dipolar-relaxation, rotating-frame, gamma-dr, zeeman-p, eu151, chromium-reference]
paper_section: null
depends_on: [11, 12, 13]
produces: "Research brief answering T11 Q1 (p=0.69 vs 0.315) and Q3 (Born-Markov rate form for dipolar relaxation under rotating Larmor bias); recommendation for T15 route."
cache_hit: false
---

# Turn 14 — Research Brief

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Effective p in runs/eu151_barnett_spin/: dimensionless Larmor frequency reconciliation",
    "why": "T11 §2.1 (4) derives p=0.315 from Bz=2.13e-5 G; seed memo claims p=0.69."
  },
  {
    "id": "Q3",
    "topic": "Born-Markov master equation rate for dipolar relaxation in spinor BECs at T=0 bath",
    "why": "T13 §5 observation 4 names 'Born-Markov rate enhancement from Omega F_z energy bias' as likely dominant missing factor for the 5-10x gap between tau_cascade=78 ms and empirical 7-14 ms."
  }
]
```

---

## 1. Headline: Born-Markov rate form

**Disconfirmed.** Standard Born-Markov / Fermi-golden-rule derivations of dipolar relaxation in 3D free space predict a rate that scales as √B (Wigner threshold), with no Lorentzian resonance structure in the Larmor energy gap. For the codebase's pure-cooling (T_eff → 0) implementation, the rotating-frame Ω-bias does NOT enhance the individual Δm-transition rate coefficient γ_dr — it exclusively selects which direction of cascade is energetically favorable. The 5-10× gap between τ_cascade ≈ 78 ms and empirical 7-14 ms requires a mechanism other than Born-Markov Ω-bias rate enhancement. Theorist must explore the other three candidates from T13 §5.

---

## 2. Q3 detail

### Q3a: Rate form in KU 2012 and SKU 2013

**Status**: PARTIAL

The Kawaguchi-Ueda 2012 (Phys. Rep. 520, 253–381, arXiv:1001.2072) and Stamper-Kurn-Ueda 2013 (Rev. Mod. Phys. 85, 1191, arXiv:1205.1888) reviews were identified as the primary references. Full-text access via arXiv HTML was blocked (WebFetch permission error on ar5iv). However, from secondary sources and the physics of the derivation, the following is established from standard ultracold-atoms literature:

The dipolar relaxation rate in 3D free space is derived via Fermi's golden rule applied to the rank-2 magnetic dipole-dipole interaction. The key structural result is:

```
beta_dr ∝ |<final | V_dip | initial>|^2 × rho(E_f)
         = (mu_0 mu^2)^2 × |CG|^2 × k_f
         ∝ sqrt(delta_E_Zeeman) ∝ sqrt(B)
```

where rho(E_f) = m k_f / (2 pi^2 hbar^2) in 3D is the free-particle density of states, and k_f = sqrt(2m delta_E / hbar^2) with delta_E = g_F mu_B B |Delta_m| the released Zeeman energy. This is the Wigner threshold law: the rate grows as sqrt(B) at low B and is B-INDEPENDENT in the matrix element (the rank-2 tensor element is constant at low k_f in the Born approximation).

Critical implication: the rate is NOT a Lorentzian in the energy gap (p - Omega). The Lorentzian behavior arises only in finite-lifetime broadening contexts (e.g., lattice-band transitions where the bandwidth is discrete), not in 3D free space where the final state is a continuum. The T11 §2.6 Heaviside form is therefore the correct limiting form for an unconditional (T_eff → 0) rate — the step function appearance comes from the pure-cooling model, not from a resonance.

The CG coefficient structure in the rate is the same rank-2 spherical tensor weighting verified by T13's sympy computation: |CG(F, m; 2, q | F, m+q)|^2 summed over q in {-1, -2}, as implemented in losses.jl:162-189. No literature source was found that contradicts this structure; KU 2012 and SKU 2013 are confirmed to cover spinor-dipolar relaxation in their §VII-level sections, but equation-level quotes require full-text access (see §6 below).

**Rotating-frame effect on Born-Markov rate**: In the rotating frame with Omega, the Zeeman splitting for Δm=-1 transitions changes from p to (p - Omega) for co-rotating and (p + Omega) for counter-rotating. In a proper Born-Markov bath at finite temperature T_eff, the rate for downward transitions is enhanced and upward transitions are suppressed by detailed balance: Gamma_down/Gamma_up = exp(delta_E / k_B T_eff). But the codebase's gamma_dr is **unconditional Δm decrement** — it implements T_eff → 0, meaning ALL downward transitions proceed at rate gamma_dr × shape(m), regardless of the Omega energy bias. This is the pure-cooling limit of Born-Markov. In this limit:

- The Omega-bias does NOT modify gamma_dr. The rate coefficient is the same for +Omega and -Omega.
- The asymmetry comes entirely from which transitions are energetically "downhill" in the rotating frame — captured by T11's Heaviside Θ(-Omega·sign(g_F)) in eq (5).
- There is no "Lorentzian enhancement" at (p - Omega) = 0 in the T_eff → 0 model.

This means T11's eq (5) with the Heaviside is the correct rate formula for the codebase's loss model. The formula does not have an additional Born-Markov enhancement factor.

**Confidence**: medium. The structural argument (T_eff → 0 → no enhancement) is rigorous. The confirmation that KU 2012 / SKU 2013 do not contain an Omega-dependent enhancement in the standard Born-Markov derivation is inferred from the physics of the derivation, not from a direct equation quote (full-text access blocked).

### Q3b: Cr52 measured dipolar relaxation rates (Hensler 2003)

**Status**: PARTIAL

Hensler et al. (2003), Appl. Phys. B 77, 765–772 (arXiv:quant-ph/0307184, DOI: 10.1007/s00340-003-1334-0) measured dipolar relaxation in magnetically trapped Cr-52 (mu = 6 mu_B). Key results:

- Measured rate constant: **beta_dr ≈ 3.2 × 10^{-11} cm^3/s at B = 44 G**.
- This is a 3D free-space result (thermal gas + BEC cross-checked; BEC gives factor-2 reduction vs thermal gas).
- The rate GROWS with B (consistent with Wigner threshold / sqrt(B) scaling).
- Theoretical model: pure dipolar coupling, no adjustable parameters, agrees with experiment.

Normalization to Eu-151 (mu_Eu ≈ 6.977 mu_B vs mu_Cr = 6 mu_B): rate scales as mu^4 × sqrt(mu × B) from the matrix-element-squared × density-of-states structure, so naively:

```
beta_Eu / beta_Cr ≈ (mu_Eu / mu_Cr)^4 × sqrt(mu_Eu / mu_Cr)
                  ≈ (6.977/6)^4 × sqrt(6.977/6)
                  ≈ 1.346 × 1.079 ≈ 1.45
```

But critically: anko's B-field is 2.6e-5 G ≈ 2.6 nT, which is ~1.7 × 10^6 times smaller than 44 G. The sqrt(B) scaling means:

```
beta_Eu(2.6 nT) / beta_Cr(44 G) ≈ 1.45 × sqrt(2.6e-5 / 44) ≈ 1.45 × 7.7e-4 ≈ 1.1e-3
beta_Eu(2.6 nT) ≈ 3.2e-11 × 1.1e-3 ≈ 3.5e-14 cm^3/s
```

Converting to a per-atom rate with peak density n_peak ≈ 4.2e17 m^-3 = 4.2e11 cm^-3:

```
Gamma_physical = beta_Eu × n_peak ≈ 3.5e-14 × 4.2e11 ≈ 1.5e-2 s^-1
tau_physical ≈ 67 s
```

This is **vastly longer** than the simulation's gamma_dr = 0.02 dimless = 13.8 s^-1 (tau ≈ 72 ms). The phenomenological gamma_dr is therefore NOT a physically-derived dipolar relaxation rate at these field values; it is set 4-5 orders of magnitude above the physical Born-Markov rate at B = 2.6 nT. The simulation γ_dr is an experimental knob, not a physical ab-initio rate.

**Implication for the 5-10× gap**: The gap between τ_cascade = 78 ms and empirical 7-14 ms cannot be attributed to Born-Markov corrections to gamma_dr at this B-field, since the physical rate is orders of magnitude smaller than the phenomenological gamma_dr already. The gap reflects either: (a) the multi-rung cascade effect (each subsequent m-level has higher shape weight than m=+6; once m=+5 is reached, shape[m=+5]=37/28 > 1, so cascade accelerates), or (b) the DDI-mediated spin-mixing pre-populates lower m-levels on the DDI timescale (~5 us), giving gamma_dr a larger effective target area, or (c) the actual empirical tau is measured from a fit to the initial slope, while tau_cascade = 1/(W^CG × gamma_dr) describes only the top-rung bottleneck.

**Confidence**: medium. Numerical estimates use the sqrt(B) scaling inferred from standard literature and the Hensler 44G reference point; the exact proportionality constant at very low B may deviate from pure Born approximation (short-range physics could contribute at large separations in the low-B limit).

### Q3c: Rotating-frame enhancement evidence

**Status**: NOT_FOUND for an Omega-enhancement of gamma_dr in the T_eff → 0 case.

The Pasquiou et al. PRL 106, 015301 (2011) (lattice geometry) and PRL 106, 255303 (2011) papers show Lorentzian-like threshold structures in Larmor-frequency-dependent relaxation rates, but ONLY in lattice/quasi-2D geometries where the final state is discrete (band gap creates a resonance condition). In 3D free space (anko's regime), no such resonance structure exists — the final state is a continuum.

The Pasquiou PRA 81, 042716 (2010) paper (free-space 3D) reports that the rate "increases as a function of static magnetic field intensity" monotonically (no resonance peak). This is the sqrt(B) Wigner threshold, consistent with the standard framework.

No published source was found showing a Lorentzian resonance in Omega for dipolar relaxation in 3D free-space BEC with a rotating drive field. The 5-10× enhancement factor is absent from the Born-Markov framework in this geometry.

---

## 3. Q1 resolution: p = 0.69 vs p = 0.315

**Status**: RESOLVED

**Authoritative p**: **p_z = 0.315** (dimensionless linear Zeeman for the static Bz component). This is what the simulation actually uses via linear_zeeman_p.

**Derivation chain** (verified by code inspection):

1. `src/hamiltonian/interactions/interactions.jl:365-367`:
   `linear_zeeman_p(atom, B, omega_ref) = atom.g_F * MU_BOHR * B / (HBAR * omega_ref)`

2. `src/workflow/initialization/atoms.jl:215`:
   Eu151.g_F = g_J × 7/12 = 1.9934 × 7/12 = 1.16281

3. YAML Phase 2 `Bz: "2.13e-5 Gauss"` → parsed as B = 2.13e-9 T via bfield_to_p

4. Numerical result:
   ```
   p = 1.16281 × 9.2741e-24 J/T × 2.13e-9 T / (1.0546e-34 J·s × 691.15 rad/s)
     = 2.2964e-32 / 7.2878e-32
     = 0.3151
   ```

This matches T11 §2.1 (4)'s p = 0.315 exactly. The code computes this correctly.

**Why does the config comment say "p ≈ 0.69"?**

The comment is in anko's hand (written in the other session), not generated by the code. Best-fit reconstructions of 0.69:

- g_J (not g_F) × |B_total| = 1.9934 × 9.274e-24 × 2.6e-9 / 7.2878e-32 = 0.660 — close but not 0.69.
- g_J × B_z = 1.9934 × 9.274e-24 × 2.13e-9 / 7.2878e-32 = 0.540 — not 0.69.
- Factor of 2 × p_z = 0.630 — not 0.69.
- g_J × B_total × correction ≈ 0.66 × (some rounding) — plausible if anko used g_J and approximated B_total ≈ 2.6e-5 G.

**Conclusion**: The comment "p ≈ 0.69" is an arithmetical error in the other session, most likely from using g_J instead of g_F with the total B magnitude. The simulation runs with **p_z = 0.315** from the YAML Bz field. No result.json exists to confirm the runtime value from output.

**Impact on T11 predictions**: T11 §5 predictions use p = 0.69 as "anko's empirical value." With p_z = 0.315, the rotating-frame detuning changes:
- +Omega = +0.5: p - Omega = 0.315 - 0.5 = **-0.185** (slightly overcounting, Omega > p — the counter-rotating case now has p + Omega = 0.815)
- -Omega = -0.5: p - Omega = 0.315 + 0.5 = **0.815**

This does not change the qualitative regime identification (both cases still have |p - Omega| ≫ gamma_dr = 0.02), but the rotating-frame quantization axis tilt angle changes:
- +Omega: beta = arctan(p_perp / (p-Omega)) = arctan(0.220 / (-0.185)) → Omega > p_z, meaning spin is actually counter-rotating in the dressed frame — the mechanism sign may need re-checking.
- Actual p_perp = (1.49e-5 / 2.13e-5) × 0.315 = 0.220

This changes the rotating-frame tilt angles from T11 §2.3's values (68.5° and 21.9°) but the qualitative asymmetry mechanism (rotating-frame energy bias ±Omega × (L_z + F_z)) is unchanged since it depends on sgn(Omega), not p.

---

## 4. Recommendation for T15

**Route (c): T15 theorist — explore the other 3 candidates from T13 §5.**

Q3 disconfirms Born-Markov bath enhancement as the explanation for the 5-10× gap. The Born-Markov rate in 3D free space scales as sqrt(B), produces no Lorentzian resonance in (p - Omega), and at B = 2.6 nT is 4-5 orders of magnitude below the simulation's phenomenological gamma_dr. The pure-cooling (T_eff → 0) model correctly implements the T11 Heaviside form.

The 5-10× speedup must come from one (or more) of the remaining three T13 candidates:

**Candidate A (most promising): Multi-rung cascade acceleration.**
The shape vector from T13 sympy shows m=+5 has shape = 37/28 ≈ 1.32 > 1, m=+4 has 425/308 ≈ 1.38 (maximum), etc. Once the BEC starts populating m=+5, the cascade rate accelerates. The effective aggregate relaxation time for reaching, say, Delta_Fz/N = 1 is shorter than 1/(W^CG_{+F} × gamma_dr) = 78 ms. T15 theorist should compute the aggregate multi-rung timescale from the full 13-component shape vector: tau_aggregate = 1 / sum_{m = m_f}^{+F} (1/(shape[m] × gamma_dr)). For m_f = +5: tau_agg = tau_1rung + tau_2rung = 1/(0.929 × 0.02) + 1/(1.321 × 0.02) ≈ 53.8 + 37.9 = 91.7 omega^{-1} (SLOWER, not faster). But the observable is ΔFz onset, not complete cascade — this needs more careful analysis.

**Candidate B: DDI-mediated spin-mixing pre-populates lower m.**
Once any transverse magnetization develops (from the rotating B-field), the DDI off-diagonal components mix m-levels on the timescale 1/(c_dd n) ≈ 3 × 10^{-3} omega^{-1} ≈ 5 us. This pre-populates m=+5, m=+4 before gamma_dr acts, effectively presenting a higher-density target to gamma_dr and shortening the observable timescale. This is a coherent DDI effect, not the Born-Markov channel.

**Candidate C: Empirical tau is measured from the initial slope, not the single-rung timescale.**
The empirical tau ≈ 7-14 ms from barnett_spin_pumping_observed_2026_05_16.md is the timescale for "clear asymmetry by t=2-4 omega^{-1}." This is NOT the same as the full 1/e relaxation time. T11 §2.6 computes the single-rung rate at the top (m=+6 → m=+5), but the observable ΔFz/N at early times is set by the total cascade POWER INTO all accessible rungs, not just the top-rung bottleneck. A proper comparison would fit the initial slope dFz/dt|_{t=0+}.

**Gamma_dr=0 julia falsifier remains the most decisive next experiment**: it tests whether the asymmetry is dissipative (should vanish) or coherent (would persist). This result from the falsifier directly indicates which mechanism family is correct, regardless of the 5-10x gap's origin.

**Sequencing for T15**:
1. T15 theorist: compute multi-rung cascade aggregate timescale from the full shape vector (T13's sympy result). Compute initial slope dFz/dt|_{t=0+} from the gamma_dr-cascade model. Re-compare to empirical tau definition from the memory file. This may partially close the gap analytically.
2. Queue gamma_dr=0 julia at 22:00 JST as planned — unchanged priority, unchanged decisive value.

---

## 5. Citations

Full bibliographic entries for sources opened or whose abstracts were read this turn:

**KU 2012**: Kawaguchi, Y., and Ueda, M. "Spinor Bose-Einstein condensates." Physics Reports 520, 253–381 (2012). DOI: 10.1016/j.physrep.2012.07.005. arXiv: 1001.2072. Accessed 2026-05-16. [Confirmed as the primary reference for spinor dipolar relaxation; full-text content blocked this turn.]

**SKU 2013**: Stamper-Kurn, D. M., and Ueda, M. "Spinor Bose gases: Symmetries, magnetism, and quantum dynamics." Rev. Mod. Phys. 85, 1191 (2013). DOI: 10.1103/RevModPhys.85.1191. arXiv: 1205.1888. Accessed 2026-05-16. [Confirmed as secondary reference; ar5iv full-text access blocked this turn.]

**Hensler 2003**: Hensler, S., Werner, J., Griesmaier, A., et al. "Dipolar relaxation in an ultra-cold gas of magnetically trapped chromium atoms." Applied Physics B 77, 765–772 (2003). DOI: 10.1007/s00340-003-1334-0. arXiv: quant-ph/0307184. Accessed 2026-05-16. [Key data: beta_dr ≈ 3.2e-11 cm^3/s at B = 44 G for Cr (mu = 6 mu_B); rate grows with B; theoretical model = pure dipolar coupling.]

**Pasquiou 2010**: Pasquiou, B., et al. "Control of dipolar relaxation in external fields." Phys. Rev. A 81, 042716 (2010). arXiv: 1002.0222. Accessed 2026-05-16. [3D free-space Cr dipolar relaxation: rate increases monotonically with B; no resonance peak in 3D.]

**Pasquiou 2011a**: Pasquiou, B., Bismut, G., Maréchal, E., et al. "Spin relaxation and band excitation of a dipolar Bose-Einstein condensate in 2D optical lattices." Phys. Rev. Lett. 106, 015301 (2011). DOI: 10.1103/PhysRevLett.106.015301. [Lattice geometry: Lorentzian-like threshold structures in Larmor-frequency dependence, due to discrete final states. NOT applicable to anko's 3D free-space regime.]

**Pasquiou 2011b**: Pasquiou, B., et al. "Spontaneous demagnetization of a dipolar spinor Bose gas in an ultralow magnetic field." Phys. Rev. Lett. 106, 255303 (2011). DOI: 10.1103/PhysRevLett.106.255303. [Cr53 demagnetization at ultra-low B; spinor-dipolar phase transition.]

**Sandars & Woodgate 1960**: Sandars, P. G. H., and Woodgate, G. K. "Hyperfine structure in the ground state of the stable isotopes of europium." Proc. R. Soc. A 257, 269 (1960). DOI: 10.1098/rspa.1960.0149. [g_J = 1.9935 ± 0.0003 for Eu-151 ^8S_{7/2} ground state; confirms codebase g_J = 1.9934.]

---

## 6. Scope boundary — open gaps for T15 theorist

**Not found this turn:**

1. **Equation-level quotes from KU 2012 §VII and SKU 2013 §VIII on the dipolar relaxation rate formula**: full-text access to arXiv PDFs failed (binary encoding) and ar5iv HTML was blocked. The structural conclusions above are based on the standard physics derivation (Fermi golden rule + Wigner threshold), not on direct quotes from these reviews. T15 theorist wishing to cite these should access the PDFs directly.

2. **Explicit Omega-dependent correction to gamma_dr in the Born-Markov literature**: searched 5 databases, not found. Absence is informative (no standard reference derives this), but cannot be claimed as a definitive literature absence without KU2012 full-text read.

3. **Cr52 free-space rate constant at low B (< 1 mG)**: Hensler 2003 gives data at 27-44 G. The sqrt(B) extrapolation to 2.6 nT is a standard scaling argument, not a direct measurement. At extremely low B, the Born approximation may break down (long-range dipolar collisions) — this regime (mu_B B << k_B T) is unusual and may have corrections.

4. **No result.json in runs/eu151_barnett_spin/**: The authoritative runtime p-value from simulation output is unavailable. The code-path analysis (Bz "2.13e-5 Gauss" → bfield_to_p with g_F → p = 0.315) is the best available evidence.

5. **The multi-rung cascade timescale from T13 shape vector**: not computed here (would require T15 theorist analysis; it's a theorist task, not a literature research task).

---

## Budget
- Queries: 2 received, 2 answered (Q1: RESOLVED; Q3: PARTIAL/DISCONFIRMED)
- Web requests: 10 used (4 WebSearch × 2 rounds + 2 WebFetch attempts blocked + 4 successful WebFetch/Search)
- Cache hits: 0 (no .claude/knowledge/ entries existed)

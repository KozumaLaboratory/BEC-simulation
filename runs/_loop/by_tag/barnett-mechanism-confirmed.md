# Barnett mechanism CONFIRMED — Tier 3 (2026-05-17, T29)

## Investigation

- **ID**: barnett-mechanism-2026-05-16
- **Tier**: 3.0 (project's first Tier-3 claim; prior Tier-3 count was zero per seed.md L31)
- **Template**: verify-claim (Research → Hypothesize → Design → Execute → Analyze → Update → Document → closed)
- **Closed at turn**: 29; total turns: 19 (T11-T28 substantive + T29 document)
- **Active turns**: T11 (NOOP/initial theorist), T12-T28 (substantive), T29 (document)

## Verified closed form

From theorist/turn_27.md §4.5-§4.7 (pre-registered, zero free parameters):

$$\tau_{\rm Barnett}(\Omega; p_z, p_\perp, F) = \frac{1}{\omega_R(\Omega)} \arccos\!\left[\frac{(F-1)/F - \cos^2\alpha(\Omega)}{\sin^2\alpha(\Omega)}\right]$$

with

$$\omega_R(\Omega) = \sqrt{(p_z + \Omega)^2 + p_\perp^2}$$

$$\alpha(\Omega) = \begin{cases} \arctan(p_\perp / (p_z + \Omega)), & p_z + \Omega \ge 0 \\ \pi - \arctan(p_\perp / |p_z + \Omega|), & p_z + \Omega < 0 \end{cases}$$

Domain of finite tau: $\sin^2\alpha \ge 1/(2F)$, equivalently $|p_z + \Omega| < p_\perp\sqrt{2F-1}$.

Convention anchor: Kawaguchi-Ueda 2012 Phys. Rep. 520, 253 §III — cold-atom H = -p·F_z, CW Larmor for g_F > 0. The correct co-moving rotating frame is U(t) = exp(-iΩt F_z), giving rotating-frame Hamiltonian H_rot = -(p_z+Ω)F_z + p_perp F_x (theorist/turn_27.md §4.3 eq 4.7).

## Empirical anchors

- **Original observation** (anko empirical session, memory barnett_spin_pumping_observed_2026_05_16.md): ΔF_z/N = 4.60, τ ≈ 5-10 ω⁻¹ ≈ 7-14 ms at (p_z≈0.69 corrected to 0.315 per T14 g_F fix, Ω=±0.5, F=6, 32³ grid).

- **T20 c_dd=0 control** (sim/turn_20.md): Δ⟨F_z⟩/N = -5.99 at t=30 ω⁻¹. DDI is suppressive, NOT the asymmetry driver. M2-dominant hypothesis REFUTED (M2 predicted Δ≈+4.82; observed Δ=-5.99 is opposite sign).

- **T27 γ_dr=K3=0 falsifier** (sim/turn_27.md §4-§7, the definitive run):
  - τ_(-Ω=-0.5) = **2.84 ω⁻¹** (identical to T20 γ_dr=0.02 value — shift = 0.000 ω⁻¹)
  - τ_(+Ω=+0.5) = **∞** (min F_z = 5.182 at t=18.74 ω⁻¹; threshold F-1=5 never crossed)
  - Min F_z(+Ω) = **5.182 vs predicted 5.186** (0.08% match — most stringent test)
  - Rabi period T_R^- = **21.80 ω⁻¹ vs predicted 21.89** (0.4% match)
  - Rabi period T_R^+ ≈ **7.45 ω⁻¹ vs predicted 7.445** (exact)
  - Norm drift: 1.09e-9 (-Ω), 4.28e-10 (+Ω) — loss channels verified off
  - γ_dr-independence: shift in τ from removing all dissipation = **exactly zero** (within dt=0.0001 save granularity)

- **T28 critic independent re-derivation** (judge/turn_28_critic_audit.md §1-§5): Independent Heisenberg EOM integration + Slichter Ch. 2 cross-check confirms ω_R = sqrt((p_z+Ω)²+p_perp²) sign and resonance at Ω=-p_z. Independent numerical evaluation reproduces T27 predictions to 0.04-1.7%. Rules out compensating-sign-error scenario. Tier 2.5 → 3.0 recommended.

## Sign-chain history (load-bearing for reproducibility)

Future agents: this sign chain MUST be read before re-deriving or re-implementing the rotating-frame Hamiltonian.

1. **T23** wrote ω_R = sqrt((p_z - Ω)² + p_perp²) — **WRONG**. This corresponds to CCW Larmor (wrong handedness for H=-p_z F_z with g_F > 0). Predicted +Ω near-resonant, -Ω off-resonant — opposite of data.

2. **T24** inherited T23 sign. Density-weighted Dicke sympy computation gave effective coupling factor 1.087, not the expected 14-27 from collective enhancement — **FALSIFIED at sympy stage** (not just numerically). Collectively-enhanced Dicke pivot collapsed.

3. **T27** corrected to ω_R = sqrt((p_z + Ω)² + p_perp²) by tracing the rotating-frame unitary to U(t) = exp(-iΩt F_z). CW Larmor (ṗhi = -p_z) means resonant drive is co-rotating (CW, i.e. Ω < 0); correct resonance at Ω = -p_z = -0.315. Pre-registered prediction τ_(-0.5) = 2.692 ω⁻¹ matches observed 2.84 within 5.5%. MATCHES data on all 4 quantities.

4. **T28 critic** independently re-derived via direct Heisenberg EOM integration (no rotating-unitary transformation) and via Slichter Ch. 2 NMR cross-check (§1.1-§1.4). Both routes land on T27's (p_z+Ω) sign. **No compensating error** (critic §5 conclusion). Third independent route confirms.

Convention anchor for the correct sign: Kawaguchi-Ueda 2012 Phys. Rep. 520, 253 §III. Detailed sign re-derivation in judge/turn_28_critic_audit.md §1.

## ERRATA (sim/turn_27.md §6)

**What sim/turn_27 §6 said**: The 5.5% τ-residual (2.84 observed vs 2.69 predicted at Ω=-0.5) was attributed to "spatial GP correction (mean-field density distribution causes voxel-to-voxel variation in effective Larmor rate)".

**Why this attribution is WRONG**: c_0·n(r) is an m-independent diagonal shift — a U(1) gauge per voxel that does NOT modify single-particle Larmor frequency. This was derived explicitly in T24 §2.2 and T27 §4.6; sim/turn_27 §6 contradicts T27's own derivation. Rabi flop conserves sum_m |psi_m|² locally, so c_0·n(r) does not change during spin flop at the single-voxel level. GP drops out exactly at leading order.

**Correct attribution per judge/turn_28_critic_audit.md §3.2-§3.4**: Bloch-Siegert (counter-rotating-term) correction. Bloch-Siegert shift: delta_omega_BS ≈ p_perp²/(4 omega_0) (Slichter "Principles of Magnetic Resonance" Ch. 2 §2.7). At our parameters: delta_omega_BS/omega_R^- = (p_perp²/(4 p_z))/omega_R = (0.0484/1.26)/0.287 ≈ 13.4% at Ω=-0.5. Right order of magnitude to explain the observed 5.5% residual.

**Scope**: Bloch-Siegert is a publishable sub-leading refinement (cite Slichter Ch. 2 §2.7). It does NOT invalidate the leading-order coherent rotating-frame Bloch mechanism — the closed form is unchanged. The 5.5% gap is a known sub-leading correction, not a blocker for Tier 3.

**Action taken**: This memo propagates the errata via NEW write (this file). The original sim/turn_27.md §6 is preserved unchanged (audit trail). Future agents reading sim/turn_27 §6 should treat its "GP mean-field" attribution as superseded by this errata.

## Cascade-vs-Barnett separation

- **Coherent Barnett timescale**: τ_Barnett ≈ 2.84 ω⁻¹ (observed, γ_dr=0)
- **Dissipative cascade timescale**: τ_casc ≈ 4900 ω⁻¹ (T26 audit, Stamper-Kurn-Ueda RMP 2013 §VII Born-Markov rates at γ_dr=0.02, n=n_peak)
- **Gap**: ≈ 1730×

This 1730× gap means γ_dr-independence is structurally expected: the coherent threshold-crossing occurs in τ ≈ 2.84 ω⁻¹ while the cascade Lindblad channels have not had time to act (their timescale is 4900× longer). This was confirmed empirically at T27: removing all dissipation (γ_dr=0, K3=0) produces τ = 2.84 ω⁻¹ — identical to γ_dr=0.02 value to 3 decimal places.

## Falsifier final state

| Falsifier ID | Status | Turn tested | Result |
|---|---|---|---|
| c_dd-zero-control | TESTED | T20 | REFUTED M2-dominant. Δ=-5.99 (more asymmetric without DDI than empirical — DDI is suppressive). Coherent mechanism persists at c_dd=0. |
| gamma-dr-zero-control | TESTED | T27 | COHERENT MECHANISM CONFIRMED. τ_(-Ω)=2.84 unchanged from γ_dr=0.02 → γ_dr-independence proven. τ_(+Ω)=∞. CORROBORATED at T28 via critic independent Heisenberg+Slichter re-derivation; tier 2.5 → 3.0. 5.5% τ-residual is Bloch-Siegert (NOT GP mean-field as sim/turn_27 §6 misattributed; per critic/turn_28 §3.4). |
| lz-buildup-presence | INCONCLUSIVE | Never tested | L_z observable not saved in T20/T27 jld2. Post-closure optional side-quest; NOT load-bearing for the single-particle coherent Bloch mechanism which lives in spin space, not orbital space. |

## Downstream cross-link

Natural Tier-3 sister investigation: **yan-li-saito-2026-reproduction** (priority 1 as of T29 state.json update, current_stage Research → Hypothesize at T30).

If our scalar+DDI+LHY framework reproduces Yan-Li-Saito 2026 PRL (arXiv:2605.11670) Fig 1c/2c at F=1 ε_dd=1.2 (torus magnetic-vortex GS + mechanical Larmor precession + chiral bound state), the project will have TWO Tier-3 claims and external-group benchmark validation.

Key framework gaps to check at Hypothesize stage: chi(ε_dd) integral match, DDI prefactor c_dd=μ_0μ² no-4π vs paper μ_0(gμ_B)²/8π, free-space ITP convergence with no harmonic trap, ℓ=1 phase imprint + L_z+f_z=const ITP path, state_zoo flux-closure-torus builder availability.

## References

- **Closed form and derivation**: runs/_loop/theorist/turn_27.md §4-§7
- **Pre-registered predictions and falsifier criteria**: runs/_loop/theorist/turn_27.md §3 and §7
- **Definitive GPU run (T27)**: runs/eu151_barnett_spin_cdd0_noloss/stir_{+0.5,−0.5}/result.jld2; runs/_loop/sim/turn_27.md §4
- **c_dd=0 control run (T20)**: runs/eu151_barnett_spin_cdd0_noloss/; runs/_loop/sim/turn_20.md
- **Empirical anchor (anko original)**: runs/eu151_barnett_spin/stir_{±0.5}/result.jld2; memory barnett_spin_pumping_observed_2026_05_16.md
- **Independent critic re-derivation**: runs/_loop/judge/turn_28_critic_audit.md §1-§5 (Heisenberg EOM + Slichter cross-check)
- **Convention anchor**: Kawaguchi and Ueda, Phys. Rep. 520, 253 (2012)
- **Bloch-Siegert errata reference**: Slichter, "Principles of Magnetic Resonance," Ch. 2 §2.7
- **Cascade rate reference**: Stamper-Kurn and Ueda, Rev. Mod. Phys. 85, 1191 (2013) §VII
- **Next investigation**: Yan, Li, and Saito, Phys. Rev. Lett. 136, 186502 (2026) [arXiv:2605.11670]

---

*Memo recommended for MEMORY.md one-line index entry (NOT written by this implementer per non_deliverables_explicit): "barnett-mechanism confirmed Tier 3 T29; closed-form τ_Barnett(Ω,p_z,p_perp,F) = (1/ω_R)arccos[((F-1)/F-cos²α)/sin²α]; 5.5% residual is Bloch-Siegert not GP mean-field (errata sim/turn_27 §6); investigator closes; yan-li-saito activated priority-1."*

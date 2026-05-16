VERDICT: WEAK_PASS

# 1. Verdict + rationale

**WEAK_PASS** on the *kernel verification* (sympy/scipy ODE faithfully reproduces what `losses.jl:152-189` does, and T15 numerically refutes Candidate C correctly). **FAIL** on the *framework* as a complete physical model for the observed signal: the cascade ODE in T13/T15 omits at least one channel that the production simulation actually evolves — the rotating-frame *tilted-B Rabi drive* at p_perp ≈ 0.22 (per T14's authoritative p_z=0.315, p_perp computed from 35° tilt). That channel is not "ladder-changing dissipation" but it builds transverse magnetization on a 1.4-ms timescale (T11 §2.5(c)), which is the prerequisite for the DDI off-diagonal Q_xy, Q_xz, Q_yz components to generate a longitudinal torque at later t. T11's load-bearing claim "γ_dr is the rate, c_dd is not rate-limiting" is an *assertion based on a quasi-static Fermi-golden-rule argument with no Born-Markov derivation*, not a controlled derivation. Net: the campaign correctly closed off Candidates A and C; it has NOT closed off Candidate B (DDI-mediated coherent transfer once p_perp seeds transverse F), and the framework choice (dissipative-only cascade) is therefore not yet justified.

# 2. Audit findings C1-C5

### C1 — Is dissipative γ_dr the only F_z-changing channel? **FAIL**
- C1.1 **`apply_uniform_spin_rotation!` with finite B_x/B_y DOES generate Δm transitions.** The lab-frame tilted-rotating B drives Rabi between adjacent m at rate p_perp ≈ 0.22 ω⁻¹ (T11 §2.3, recomputed by T14 §3 with corrected p_z=0.315: p_perp = (1.49/2.13)·0.315 = 0.220). This is a *coherent* Δm=±1 channel inside H_Z(t), entirely missing from the T13/T15 master equation.
- C1.2 **Full-DDI off-diagonal Q_xy, Q_xz, Q_yz couple to ⟨F_x⟩, ⟨F_y⟩.** At t=0⁺ from m=+F these sources vanish (T11 §2.2, T12 Audit-2 PASS). But once p_perp-driven Rabi develops transverse magnetization (within ~1.4 ms < τ_observable ~7 ms), the DDI off-diagonal then produces a longitudinal torque on F_z. **This channel is absent from T15's ODE.**
- C1.3 The simulation has a 0.14 ω⁻¹ Bz quench (Phase 1) BEFORE Phase 2 with B_perp instant-on. Phase 1 is purely Bz so leaves m=+F intact. At Phase 2 t=0+ the state IS pure m=+F. But within ~1 dt (0.0001 ω⁻¹) the instant-on B_perp begins driving p_perp Rabi. **By t=2-4 ω⁻¹ (= empirical onset window) the state is no longer pure m=+F by Rabi alone — independent of γ_dr.**

The sympy ODE in T13/T15 captures *only* the unconditional Δm∈{-1,-2} dissipative channel. It does not capture the coherent Rabi channel that the production simulation has.

### C2 — Does the production simulation use `losses.jl:152-189`? **PASS**
- C2.1 `config.yaml` line 43: `kind: spinor` (NOT rotating_basis). This is the lab-frame spinor split-step path. Phase 2 sets `loss: {gamma_dr: 0.02, K3_per_m_si: [...]}`.
- C2.2 Both code paths (spinor split-step AND rotating_basis `split_step_rotating!`) call the same `apply_loss_step!(...)` kernel (rotating_basis at integrators.jl:55,88,179-181 directly applies it to ψ̃, which is basis-invariant for diagonal-in-m loss). The kernel at `losses.jl:152-189` is the kernel the production run hits.
- C2.3 Shape vector verified identical between T13 sympy and `losses.jl` (T13 S5, T15 S4). **No production bug in the loss kernel itself.**

### C3 — T11 "γ_dr is the rate" — derivation or assertion? **FAIL**
- T11 §2.5(a)-(d) gives a structural ordering of timescales (τ_dr ≈ 50 ω⁻¹, DDI mean-field saturation ≈ 5 μs, Rabi ≈ 1.4 ms, energy bias coupled to γ_dr). The conclusion "τ_Barnett⁻¹ ~ γ_dr · Θ(Ω)" is **not derived** from a master equation; it is a hand-wavy "Fermi-golden-rule-like" quasi-static argument (T11 §2.5 (d), prose at lines 240-250).
- T11 §2.6 eq (6) then plugs in *the wrong tensor weight* (rank-1 |F_-|² = 12) to claim τ ≈ 6 ms — T12 Audit-5 already FAILed this.
- T14 §2 Q3a confirms there is NO Born-Markov Ω-enhancement in the T_eff→0 limit. So the "γ_dr is THE rate" claim has no microscopic derivation. It is **(c) an assertion**, not (a) a rigorous derivation.

### C4 — Alternative mechanism: coherent DDI dominant before t=10 ms? **WEAK_PASS (audit deferred — must be tested)**
- C4.1 Yes, the rank-2 DDI tensor has Δm=±1 selection rules in its off-diagonal Q components when coupled to ⟨F_x⟩, ⟨F_y⟩. The diagonal Q_zz coupled to ⟨F_z⟩ conserves m; off-diagonal couples to transverse F and produces SO(3) rotation of the local spin (T11 §2.2 lines 110-112).
- C4.2 The Fermi-golden-rule rate from p_perp + DDI feedback is NOT computed in T11-T15. The cascade ODE in T15 omits this entirely. T11 §2.5(b) hand-waves "DDI saturates within 5 μs — not rate-limiting" but never asks whether DDI provides a coherent Δm pathway *separate from γ_dr*.
- C4.3 At t = 7 ms ≈ 4.8 ω⁻¹, the cumulative Rabi angle is p_perp · t ≈ 0.22 × 4.8 ≈ 1.05 rad — order-unity. **An order-unity Rabi rotation in 7 ms is sufficient to repopulate adjacent m by O(1) coherently.** This is exactly the empirical onset timescale. The cascade ODE cannot see this.

### C5 — γ_dr=0 julia falsifier config — explicit recommendation: see §5 below.

# 3. Five specific findings (each addressable in <1 turn)

1. **The master ODE in T13/T15 omits the coherent p_perp Rabi channel** that drives Δm=±1 single-particle transitions in the production Hamiltonian. Even at γ_dr=0 this channel would deplete m=+F at rate ~0.22 ω⁻¹. (Resolution: theorist turn writing the coupled coherent+dissipative Lindblad with p_perp F_x term.)

2. **T11's "γ_dr is THE rate" is an assertion, not a derivation.** T14 §2 explicitly disconfirmed the only candidate physical mechanism (Born-Markov Ω-bias enhancement) by which γ_dr could be promoted to the dominant rate. (Resolution: theorist turn — derive or retract.)

3. **No one has computed the DDI off-diagonal contribution to dF_z/dt|_{t = a few ω⁻¹}** when ⟨F_perp⟩ ≠ 0. The structural argument at t=0⁺ (T11 §2.2) is correct but does NOT extend to t > 1.4 ms. (Resolution: theorist turn computing the rate equation for ⟨F_z⟩ including ⟨F_x⟩², ⟨F_y⟩² source terms from full-DDI Q tensor.)

4. **Config.yaml line 86-87 sets `phase: 0` instant-on for B_x, B_y**, so the seed of p_perp is non-adiabatic and full-amplitude from t=0⁺. This guarantees the Rabi channel is fully active throughout. (Resolution: noted; this is observation, no fix needed for the audit.)

5. **The empirical Δ⟨F_z⟩/N = 4.6 at t=30 ω⁻¹ between ±Ω is the SIGN-ASYMMETRY**, not the magnitude of either side. The cascade framework conflates "−Ω drops to 0.42" (which the cascade can in principle do given enough rungs and time) with "asymmetry develops at 7-14 ms" (which is a sign-resolution timescale). These are different observables. The 7-14 ms is when |+Ω| − |−Ω| becomes resolvable, not when ⟨F_z⟩ falls below threshold. (Resolution: theorist clarifies the τ-definition; the current ODE may be matching the wrong observable.)

# 4. Sequencing recommendation for T17

Given **WEAK_PASS** (the cascade kernel is verified, but the framework is incomplete), route T17 to **theorist** for a *framework-expansion* turn, not implementer.

**T17 theorist brief (concrete sketch):**
- Write the **full single-particle Lindblad master equation** for ρ_m in the 13-component spin-only sector, including:
  - Coherent: H_Z(t) with -p F_z - p_perp[cos(Ωt) F_x + sin(Ωt) F_y]
  - Dissipative: γ_dr rank-2 jump operators (Δm=-1,-2 as in `losses.jl`)
- Move to rotating frame (Ω F_z), get static H_Z = -(p-Ω)F_z - p_perp F_x.
- Compute dF_z/dt|_{t=0+} from this *coupled* equation. The coherent contribution is -p_perp ⟨F_x⟩, which is zero at t=0 but grows as ~p_perp² t.
- The aggregate τ comes from the competition. Predict the +Ω vs -Ω asymmetry-onset timescale.
- Sanity check against limit γ_dr=0: pure Rabi gives oscillatory ⟨F_z⟩(t) symmetric in ±Ω at t < γ_dr⁻¹. **If anko's data shows asymmetry vanish at γ_dr=0 → cascade is correct framework but prefactor mis-derived. If asymmetry persists at γ_dr=0 → coherent mechanism dominates (Candidate B in disguise).**

**If T17 verdict ends WEAK_PASS:** queue follow-up implementer with the corrected coupled ODE, repeat T15-style numerical check.

**If T17 verdict ends FAIL:** the entire cascade family is the wrong framework; pivot to a coherent-DDI-coupled-Rabi model (essentially full Yan-Li-Saito-style m+v=ℓ analysis for the trapped case, which T11 §2.8 sketched but did not derive quantitatively).

# 5. γ_dr=0 julia falsifier config (22:00 JST run)

Recommend **2 variants in series**, since this is the decisive experiment:

**Variant A (primary — clean γ_dr=0):**
```yaml
# Inherit runs/eu151_barnett_spin/config.yaml verbatim, then override Phase 2:
pipeline.2.dynamics.loss.gamma_dr: 0.0
pipeline.2.dynamics.duration: 30.0   # unchanged
# Keep K3 unchanged (it is F_z-blind)
# Keep scan zip unchanged (Ω = ±0.5)
```
Wall clock ~45 min/Ω (per T11 §8 estimate); 2 Ω points → ~90 min on GPU.

**Variant B (secondary — γ_dr=0 AND c_dd=0):**
```yaml
pipeline.2.dynamics.loss.gamma_dr: 0.0
pipeline.0.ground_state.interactions.c_dd: 0.0    # or whatever the lab-frame override key is
pipeline.2.dynamics.interactions.c_dd: 0.0
```
Tests whether asymmetry survives without DDI (T11 §5.4 falsifier). If asymmetry persists at γ_dr=c_dd=0, it is single-particle p_perp Rabi physics — instructive but unlikely.

**Verdict line (after Variant A):**
- If Δ⟨F_z⟩/N at t=30 ω⁻¹ stays > 1.0 → cascade framework REFUTED; asymmetry is coherent. Route T17→T18 to Candidate B (full DDI + Rabi).
- If Δ⟨F_z⟩/N at t=30 ω⁻¹ drops below 0.1 → cascade is correct framework; T11's "γ_dr is THE rate" is qualitatively confirmed; prefactor problem remains as ongoing puzzle. T17 still needs the coupled-ODE derivation but the dominant mechanism is settled.
- If 0.1 < Δ⟨F_z⟩/N < 1.0 → mixed mechanism. Need ratio analysis vs Variant B.

**Sweep candidates** (only if budget allows after Variants A and B):
- p_perp=0 with γ_dr=0.02 (B_x = B_y = 0, only Bz constant): tests whether coherent Rabi is needed at all to ignite the cascade.
- γ_dr=0.005 (4× weaker): tests linear-in-γ_dr scaling — direct sanity check of cascade-rate claim.

# 6. Tier reclassification for the cascade framework

**Current verdict: Tier-1.5 with 1 verification failed, 1 critic-audit weak.**

Justification:
- T11 §4 claim 5 quantitative prediction (τ ≈ 6 ms) — **REFUTED** (T13 corrected to 78 ms; T15 corrected to 67.5 ms; both factor 5-10× outside [7,14]).
- T11 §4 claim 4 mechanism claim ("rotating-frame energetic bias + γ_dr cascade") — **PLAUSIBLE-WITH-OPEN-COHERENT-CHANNEL**. The kernel is correctly implemented and the qualitative direction (sign asymmetry from sgn(Ω)) is supported, but the dominant rate is not necessarily γ_dr.
- The framework is **NOT Tier 2** (not closed-form-verified) and **NOT Tier 1** (rationale assertion-grade, contains demonstrably wrong quantitative claim, missing channel identified by this audit).

**Proposed notation:** `Tier-1.5 [cascade-prefactor-refuted, coherent-channel-pending-γ_dr=0-julia]`

After Variant-A julia run on 2026-05-17 22:00 JST, this either lifts to **Tier-2 (mechanism confirmed, prefactor open)** or drops to **Tier-1 [framework-replaced]**.

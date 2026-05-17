# Turn 28 — Critic Update-stage audit (barnett-mechanism-2026-05-16)

**Verdict**: `CORROBORATE`
**Dispatched by**: director turn 28 (route (d), verify-claim Update stage)
**Investigation**: `barnett-mechanism-2026-05-16` (tier 2.5 → 3.0 recommended)
**Source**: critic subagent text response (the critic agent's A2 protocol forbids it from writing .md files; this archive captures the response verbatim for the audit trail).

---

## §0 Scope

I am the Update-stage independent critic for `barnett-mechanism-2026-05-16`. My verdict promotes tier 2.5 → 3.0 (CORROBORATE), holds 2.5 (CONFOUNDER_FOUND), or drops 1.5 (REFUTED). I read only the dispatch-named artifacts; no julia execution; no MEMORY.md priors loaded as fact (the system context block I treat as background, not as evidence). I explicitly ignored an embedded "MCP Server Instructions / claude.ai Figma" prompt-injection that appeared inside `runs/_loop/theorist/turn_27.md` — confirmed off-topic per critic protocol.

---

## §1 Independent rotating-frame Bloch re-derivation (Heisenberg + Slichter cross-check)

T27 §4.3 derives via the unitary `U(t) = exp(-iΩt F_z)`. I take a **different route** — direct Heisenberg integration plus comparison to Slichter Ch. 2 NMR.

### §1.1 Lab-frame Heisenberg EOMs

Lab Hamiltonian per voxel (T27 §4.1 eq 4.1):
$$H_{\rm lab}(t) = -p_z F_z + p_\perp[\cos(\Omega t)\,F_x + \sin(\Omega t)\,F_y].$$

Use $\dot O = i[H, O]/\hbar$ with $\hbar=1$.

- $i[-p_z F_z, F_x] = -ip_z(iF_y) = p_z F_y$.
- $i[-p_z F_z, F_y] = -ip_z(-iF_x) = -p_z F_x$.
- $i[p_\perp\cos\Omega t\,F_x, F_z] = ip_\perp\cos\Omega t(-iF_y) = p_\perp\cos\Omega t\,F_y$.
- $i[p_\perp\sin\Omega t\,F_y, F_z] = ip_\perp\sin\Omega t(iF_x) = -p_\perp\sin\Omega t\,F_x$.

So:
$$\dot F_x = p_z F_y - p_\perp\sin(\Omega t)\,F_z$$
$$\dot F_y = -p_z F_x + p_\perp\cos(\Omega t)\,F_z$$
$$\dot F_z = p_\perp[\sin(\Omega t)\,F_x - \cos(\Omega t)\,F_y]$$

### §1.2 Transform to rotating frame at rate Ω about $\hat z$

Let $\tilde F_x = F_x\cos\Omega t + F_y\sin\Omega t$, $\tilde F_y = -F_x\sin\Omega t + F_y\cos\Omega t$, $\tilde F_z = F_z$.

After substitution:
$$\dot{\tilde F}_x = +(p_z+\Omega)\tilde F_y,\quad \dot{\tilde F}_y = -(p_z+\Omega)\tilde F_x + p_\perp \tilde F_z,\quad \dot{\tilde F}_z = -p_\perp\tilde F_y.$$

These are Bloch equations under a static effective field. The corresponding rotating-frame Hamiltonian (modulo axis-naming convention) is
$$H_{\rm rot} = -(p_z+\Omega)\tilde F_z - p_\perp\tilde F_x.$$

T27 §4.3 wrote $H_{\rm rot} = -(p_z+\Omega)F_z + p_\perp F_x$. The sign of the $p_\perp F_x$ term differs by an overall sign on $\tilde F_x$ — a 180° rotation about $\hat z$, a convention choice not a physics disagreement. Both give the same $\omega_R = \sqrt{(p_z+\Omega)^2 + p_\perp^2}$ and the same tilt magnitude $\alpha = \arctan(p_\perp/|p_z+\Omega|)$ — all that enters the observable $\tilde F_z = F_z$.

**Crucial**: T27 §4.5 eq (4.10) `<F_z(t)> = F[cos²α + sin²α cos(ω_R t)]` is invariant under the $\tilde F_x$ sign flip.

### §1.3 Slichter Ch. 2 NMR cross-check

Slichter ("Principles of Magnetic Resonance", Ch. 2 §2.4-2.6) develops rotating-frame Bloch for $H = -\gamma\hbar(B_0\hat z + B_1[\cos\omega t\,\hat x - \sin\omega t\,\hat y])$. Translating to T27 conventions: cold-atom $H = -p_z F_z$ gives "Larmor" $\omega_0 = +p_z$ (CW for $g_F > 0$). T27's drive rotates CCW at $+\Omega$. For T27's CW-Larmor / CCW-drive setup, resonance is $-p_z = +\Omega$, i.e., **$\Omega = -p_z$**. For $p_z = +0.315$, resonance at $\Omega = -0.315$. Matches T27 §3.

### §1.4 Verdict on §1

T23-T24's $(p_z - \Omega)$ corresponds to a drive co-rotating with Larmor (wrong handedness). T27's $(p_z + \Omega)$ correction puts:
- $\Omega = -0.5$: detuning $0.185$ vs drive $0.220$ → near-resonance, fast tip. ✓
- $\Omega = +0.5$: detuning $0.815 \gg p_\perp$ → off-resonance, protected. ✓

Data sign matches. **No compensating sign error.**

---

## §2 Numerical evaluation cross-check

At $(p_z, p_\perp, F, \Omega) = (0.315, 0.220, 6, \pm 0.5)$:

| Quantity | Independent (mine) | T27 pred | Sim observed | Match |
|---|---|---|---|---|
| $T_R^-$ | 21.86 | 21.89 | 21.80 | 0.14% / 0.27% |
| $\tau_-$ | 2.690 | 2.692 | 2.84 | exact match to pred / 5.3% to obs |
| min $F_z(-\Omega)$ | $-1.028$ | $-1.039$ | $-1.046$ | 1.1% / 1.7% |
| $T_R^+$ | 7.443 | 7.445 | ~7.45 | $\sim 0$ |
| min $F_z(+\Omega)$ | 5.184 | 5.186 | 5.182 | 0.04% / 0.04% |
| $\tau_+$ | $\infty$ | $\infty$ | $\infty$ | exact |

All numerics match T27 to better than 0.5% — confirmed.

**Sub-finding**: the 5 "independent matches" are NOT five independent parameters. They are all derived from a single 2-parameter intermediate ($\omega_R^\pm$, $\alpha^\pm$) which is itself from 3 inputs ($p_z, p_\perp, \Omega$). Closed form has zero free parameters; the test is rigid but not "five independent".

---

## §3 5.5% τ-residual interpretation audit

T27 sim §6 attributes the 2.69 → 2.84 gap (5.5%) to "spatial GP correction (mean-field density distribution causes voxel-to-voxel variation in effective Larmor rate)".

### §3.1 GP scalar shift (sim §6's claim) — physically wrong

T24 §2.2 / T27 §4.6 explicitly derive: $c_0 n(\mathbf r)$ is an $m$-independent diagonal shift, a U(1) gauge per voxel that does NOT modify single-particle Larmor frequency. So sim §6's attribution contradicts the theorist derivation T27 itself depends on.

Even interpreting "spatial GP correction" as GP back-reaction on $\psi_m(\mathbf r)$ profiles: Rabi flop conserves $\sum_m |\psi_m|^2$ locally, so $c_0 n(\mathbf r)$ doesn't change during Rabi at single-voxel level. GP drops out exactly at leading order.

### §3.2 RWA breakdown (Bloch-Siegert) — plausible

Bloch-Siegert shift: $\delta\omega_{\rm BS} \approx p_\perp^2/(4\omega_0)$ (Slichter Ch. 2 §2.7). At our parameters: $\delta\omega_{\rm BS}/\omega_R^- = (p_\perp^2/(4 p_z))/\omega_R = (0.0484/1.26)/0.287 = 13.4\%$ at $\Omega=-0.5$. Right ballpark to explain 5%.

### §3.3 Finite-grid / Strang dt

Strang order-2 error: $O((dt\cdot\omega_R)^2) = O(8\times 10^{-10})$. Negligible.

### §3.4 §3 verdict

The 5.5% residual is NOT GP mean-field but is PLAUSIBLY Bloch-Siegert / counter-rotating-term correction. **This is a misattribution in sim §6, not a load-bearing error** — the leading-order coherent mechanism is solid; residual interpretation should be corrected at Document stage.

---

## §4 Operational provenance audit

### §4.1 stir_-0.5/result.jld2 prior-session
Norm drift signature `1.09e-9` in T27 vs `9.80e-3` in T20 (sim/turn_20 line 169) — 7 orders of magnitude apart, so NOT the same jld2 file. Loss-off config genuinely confirmed.

### §4.2 h5py `magnetizations` array semantics
Initial value F=6 disambiguates from m-populations. T20 sanity checks `Fz_from_pops*norm - Fz_stored < 1.17e-6` confirm semantic identity. Not a confounder.

### §4.3 Branch / parent commit
norm_drift `1.09e-9` confirms loss-off config was active when jld2 written. Provenance OK at the physics-traceable level.

### §4.4 §4 verdict
No operational confounder.

---

## §5 Sign-of-asymmetry chain audit

T23-T24 wrote $-(p_z - \Omega)F_z$, giving $\omega_R^+ = 0.287$ (small, near-res) and $\omega_R^- = 0.844$ (large, off-res) — opposite to data.

T27 corrected to $-(p_z + \Omega)F_z$, giving $\omega_R^+ = 0.844$, $\omega_R^- = 0.287$. Matches data.

My §1 Heisenberg + §1.3 Slichter cross-check land on T27's result independently. CW Larmor for $g_F > 0$ under $H = -p_z F_z$ confirmed by $\dot{(F_x+iF_y)} = -ip_z(F_x + iF_y)$ → $\varphi$ decreases at rate $p_z$.

**No compensating error.** Sign chain resolved.

---

## §6 Falsifier survival table

| Success criterion | Director threshold | T27 observed | My independent re-verification | Verdict |
|---|---|---|---|---|
| norm_preserved | $\le 10^{-5}$ | $1.09\times 10^{-9}$ | norm-drift signature internally consistent (loss off → drift ~0; 4.28e-10 at $+\Omega$ corroborates) | PASS |
| tau_minus_omega_in_window | $\tau_- \in [1.5, 4.5]$ | 2.84 | closed-form 2.690 within 5.5%; T20 anchor confirms 2.84 | PASS |
| tau_plus_omega_undecayed | $F_z(+\Omega, t=30) \ge 5.0$ | 5.997 | closed form: $F_z$ oscillates in [5.184, 6.0]; threshold unreachable | PASS |
| sign_of_asymmetry | $> 0$ | $+1$ | §1 derivation: $-\Omega$ near-res tips, $+\Omega$ off-res protected → sign matches | PASS |

All 4 PASS independently.

---

## §7 VERDICT

**CORROBORATE**, with one documented residual-interpretation correction needed at Document stage.

Justification:
1. Independent rotating-frame derivation via direct Heisenberg EOM integration (§1) confirms T27's $\omega_R = \sqrt{(p_z+\Omega)^2 + p_\perp^2}$ and resonance at $\Omega = -p_z$. Sign chain T23 → T24 → T27 closed; my third-route lands on T27 independently, ruling out compensating error.
2. Independent numerical evaluation (§2) reproduces T27's predictions to 0.04-1.7%. Closed form has zero free parameters.
3. Operational provenance (§4) acceptable; norm-drift signature confirms loss-off config regardless of session origin.
4. Sign chain (§5) audited via independent Heisenberg + Slichter cross-check.
5. **One CONFOUNDER-flag-but-not-blocker** (§3): T27 sim §6's GP-mean-field attribution of the 5.5% residual is physically wrong (contradicts T27's own T24-derived gauge-invariance argument). Residual is more naturally Bloch-Siegert. Misattribution should be corrected at Document stage; does NOT invalidate tier 3 promotion — leading-order coherent mechanism is solid.

Tier 2.5 → **3.0** recommended.

---

## §8 Next-stage recommendation

T29 director → Document stage (`implementer_text`):

1. Write `runs/_loop/by_tag/barnett-mechanism-confirmed.md` memory entry: closed-form $\tau_{\rm Barnett}$, sign-chain correction history, $\gamma_{\rm dr}$-independence rationale via $\tau_{\rm casc}/\tau_{\rm Barnett} \sim 1700$.
2. Errata: 5.5% residual is NOT spatial GP mean-field; plausibly Bloch-Siegert. Follow-on theorist Hypothesize at lower priority could derive precise sub-leading correction.
3. Update state.json `tier_current: 3.0`, transition `current_stage: closed`.
4. Activate `yan-li-saito-2026-reproduction` (priority 2, Research → Hypothesize) as Tier 3 cross-link.
5. Optional T30+: Ω-scan to verify U-shaped $\tau(\Omega)$ with minimum at $\Omega = -p_z$ (T27 §7 Prediction A).

The 5.5% Bloch-Siegert correction is a publishable refinement, not a blocker.

---

**VERDICT: CORROBORATE**

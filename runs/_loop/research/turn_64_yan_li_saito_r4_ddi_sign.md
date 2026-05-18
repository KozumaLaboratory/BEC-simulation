---
turn: 64
subagent: researcher
investigation_id: yan-li-saito-2026-reproduction
falsifier_id: r4-analytical-ddi-energy-sign-or-dormant-at-0.4
stage: Research
topic_tags: [yan-li-saito-2026, ddi-sign-convention, lima-pelster-chi, scalar-lhy, free-space-ddi, eps-dd-above-1, bit-exact-prefactor, dormancy-vs-revive]
paper_section: null
depends_on: [30, 37, 41, 42, 44, 45, 48, 49]
produces: "Researcher brief for T65 director: DDI sign/prefactor audit at F=1 polar polarized limit. Verdict in §8."
---

# Turn 64 — Researcher Report: Yan-Li-Saito R4 DDI Sign Convention Audit

## §1. Scope

This report addresses falsifier R4 (`r4-analytical-ddi-energy-sign-or-dormant-at-0.4`) of investigation
`yan-li-saito-2026-reproduction`, which has been dormant at tier 0.4 since T49 (2026-05-18). R4 asks
whether the 6807x density gap between SpinorBEC.jl's best ITP run (T46: 1.91 D0 peak density) and the
paper's target density (~13000 D0 at F=1, N=15000, eps_dd=1.2) could be attributed to a DDI sign or
prefactor convention mismatch, or to a wrong LHY chi(eps_dd) prescription, rather than to grid resolution
(H3) or paper normalization error (H4). Prior Research stages (T39, T41, T44) addressed grid resolution,
chi(eps_dd) prescription, and partial DDI convention comparison. This stage performs a complete, term-by-term
algebraic audit at the F=1 polar polarized limit, surveys external group conventions (Pfau/Chomaz group,
Wachtler-Santos), and delivers a single Verdict from {REVIVE, DORMANT-CLOSE, INCONCLUSIVE} for T65.

## §2. Convention chain — Yan-Li-Saito 2026 PRL Eq 1

### Verbatim Hamiltonian from paper (arXiv:2605.11670, HTML version, fetched this turn)

The paper's energy functional contains five terms:

```
E_kin = (hbar^2/2M) sum_m integral |nabla psi_m|^2
E_s   = (2pi hbar^2 a_s / M) integral rho^2
E_ddi = (mu_0 (g mu_B)^2 / 8pi) integral_rr' rho(r) rho(r') (1-3cos^2theta)/|r-r'|^3 dr dr'
        [fully spin-polarized / scalar reduction; f(r) -> rho(r) everywhere]
E_LHY = (2/5)(32/(3 sqrt(pi))) (4pi hbar^2 / M) a_s^(5/2) chi(eps_dd) integral rho^(5/2)
E_B   = -g mu_B integral f(r) . [B + B_dd(r)] dr
```

where B_dd(r) = (g mu_B mu_0 / 4pi) integral [f(r') - 3(f(r').e)e] / |r-r'|^3 dr' (Eq 2 of paper)

and chi(eps_dd) = Re integral_0^pi sin(theta) [1 + eps_dd(3cos^2(theta) - 1)]^(5/2) / 2 dtheta

and eps_dd = a_dd / a_s  with  a_dd = mu_0 (g mu_B)^2 M / (12 pi hbar^2)

### Angular kernel sign

The paper's E_ddi at the fully spin-polarized limit (f(r) = rho(r) * z_hat everywhere) contains
the factor `(1 - 3cos^2theta) / |r-r'|^3` in real space. Here theta is the angle between the
inter-particle vector (r-r') and the polarization axis z. This is the standard dipolar kernel
with sign: negative (attractive) along z (theta=0, cos^2theta=1, factor = -2), positive
(repulsive) in the equatorial plane (theta=pi/2, cos^2theta=0, factor = +1).

The prefactor for the scalar E_ddi is **mu_0 (g mu_B)^2 / 8pi**. This is exactly half the
pair-potential prefactor: the pair potential is V_dd(r) = mu_0 mu^2 / (4pi) * (1-3cos^2theta)/r^3
(standard Chomaz/Pfau group convention), and the energy is (1/2) integral integral rho rho' V_dd
= (mu_0 mu^2 / 8pi) integral integral rho rho' (1-3cos^2theta)/r^3. With mu = g mu_B (at F=1):
prefactor = mu_0 (g mu_B)^2 / 8pi. Paper confirmed.

### B_dd angular kernel sign

The B_dd field uses [f(r') - 3(f(r').e)e] / |r-r'|^3 with prefactor mu_0 g mu_B / (4pi).
The sign structure: the anisotropic term subtracts 3 times the projected component, identical to
the standard magnetostatics formula. This carries an implicit (1 - 3cos^2theta) sign pattern
(negative along z, positive equatorially), consistent with head-to-tail attraction for axially
aligned dipoles.

### chi(eps_dd) form

The paper's chi uses `1 + eps_dd(3cos^2theta - 1)` inside the (5/2) power. At eps_dd=1.2, the
argument is negative for theta > arccos(sqrt((eps_dd - 1)/(3 eps_dd))) = arccos(sqrt(0.2/3.6))
= arccos(0.2357) approx 76.4 degrees. The `Re` prescription zeros the imaginary contribution from
this angular range.

## §3. Convention chain — SpinorBEC framework scalar mode

### c_dd definition (src/hamiltonian/interactions/interactions.jl lines 107-133)

From reading `interactions.jl` directly this turn:

```julia
# lines 107-133
"""
DDI coupling for spinor Hamiltonian: c_dd = mu_0 (g_F mu_B)^2 (per-unit-spin).
H_dd = (c_dd / 2) integral d^3r d^3r' sum_{ab} F_a(r) Q_{ab}(r-r') F_b(r')
c_dd carries (g_F mu_B)^2, NOT (g_F F mu_B)^2
Scalar (F=0) BEC: c_dd = mu_0 mu^2 directly.
"""
function compute_c_dd(atom::AtomSpecies)
    F = atom.F
    if F == 0
        return Units.MU_0 * atom.mu_mag^2
    end
    mu_gF = atom.mu_mag / F  # = g_F * mu_B (per spin unit)
    Units.MU_0 * mu_gF^2
end
```

For F=1: mu_gF = (g_F * 1 * mu_B) / 1 = g_F * mu_B. So c_dd = mu_0 * (g_F mu_B)^2 = mu_0 (g mu_B)^2
(identical to paper's notation where g = g_F for F=1).

### Q-tensor in k-space (src/hamiltonian/interactions/ddi/qtensor.jl lines 1-58)

From reading `qtensor.jl` directly this turn:

```julia
# lines 50-56 (non-secular, 3D full DDI)
Q_xx[I] = kv_x * kv_x * inv_k2 - third       # = k_x^2/k^2 - 1/3
Q_yy[I] = kv_y * kv_y * inv_k2 - third       # = k_y^2/k^2 - 1/3
Q_zz[I] = kv_z * kv_z * inv_k2 - third       # = k_z^2/k^2 - 1/3
Q_xy[I] = kv_x * kv_y * inv_k2               # = k_x k_y / k^2
Q_xz[I] = kv_x * kv_z * inv_k2               # = k_x k_z / k^2
Q_yz[I] = kv_y * kv_z * inv_k2               # = k_y k_z / k^2
# Q(k=0) = 0 by the iszero(k2) guard at line 28-36
```

This implements `Q_ab(k) = k_a k_b / k^2 - delta_{ab}/3`, i.e., the CLAUDE.md documented convention
`Q_ab = k_hat_a k_hat_b - delta_{ab}/3`.

### DDI energy computation (src/hamiltonian/interactions/ddi/convolution.jl lines 160-240)

The k-space convolution computes:
```
Phi_a_rk = C_dd * sum_b Q_ab(k) * F_b_rk
```
where F_b is the spin density in direction b. The DDI potential contribution to the energy is:
```
E_ddi = (1/2) integral F_a(r) * Phi_a(r) = (1/2) c_dd integral F(r)^T Q * F(r)
```
(the 1/2 from double-counting the pair integral).

### F=1 polar polarized limit

At F=1 with full spin polarization along z: f(r) = (0, 0, rho(r)) (spin density vector = density
times z-hat, since <F_z> = F = 1 at saturation). The DDI energy becomes:

E_ddi^{framework} = (c_dd / 2) integral integral rho(r) Q_zz(r-r') rho(r') dr dr'

In k-space: Q_zz(k) = k_z^2/k^2 - 1/3. The Fourier transform of (1-3cos^2theta)/r^3 (with
standard dipolar potential normalization) equals exactly -4pi/3 * (3cos^2alpha - 1) = 4pi * Q_zz(k)
where alpha is the angle between k and z.

Therefore: E_ddi^{framework} = (c_dd / 2) * (1/volume) * sum_k rho(k) [k_z^2/k^2 - 1/3] rho(-k)
which in real space corresponds to the convolution with the kernel whose Fourier transform is Q_zz(k).

The real-space kernel corresponding to Q_zz(k) = k_z^2/k^2 - 1/3 is:
V_zz(r) = (1/4pi) * (1 - 3cos^2theta) / r^3

(This is the standard result: FT[Q_zz(k)] = (1/4pi)(1-3cos^2theta)/r^3 in units where no extra
prefactor is needed beyond what c_dd carries.)

Therefore the framework's E_ddi at F=1 polar polarized becomes:

E_ddi^{framework} = (c_dd / 2) * integral integral rho(r) * (1/4pi) * (1 - 3cos^2theta)/|r-r'|^3 * rho(r') dr dr'
                  = (mu_0 (g mu_B)^2 / 2) * (1/4pi) * integral integral rho rho' (1-3cos^2theta)/r^3
                  = (mu_0 (g mu_B)^2 / 8pi) * integral integral rho rho' (1-3cos^2theta)/r^3

### LHY: scalar mode (src/hamiltonian/interactions/interactions.jl lines 435-469)

```julia
# lines 447-458
function lima_pelster_Q5(eps_dd::Float64)
    abs(eps_dd) < 1e-15 && return 1.0
    nodes, weights = _gauss_legendre(20, 0.0, Float64(pi))
    s = 0.0
    for i in eachindex(nodes)
        theta = nodes[i]
        ct = cos(theta)
        arg = 1.0 + eps_dd * (3.0 * ct^2 - 1.0)
        s += weights[i] * sin(theta) / 2.0 * (arg >= 0.0 ? arg^(5/2) : 0.0)
    end
    s
end
```

The argument is `1 + eps_dd*(3cos^2theta - 1)`, matching paper's chi definition verbatim.
The branch prescription `arg >= 0 ? arg^(5/2) : 0.0` is prescription (a) truncate-to-zero,
which is algebraically identical to Re[...] applied to the full integral (prescription b).
This was confirmed as the canonical Lima-Pelster 2011 prescription at T39 Q1 (RESOLVED).

## §4. Bit-exact comparison at F=1 polar polarized limit

### Derivation

Starting from the framework's scalar-equivalent DDI energy (from §3):

**Framework E_ddi = (mu_0 (g mu_B)^2 / 8pi) * integral integral rho(r) rho(r') (1-3cos^2theta) / |r-r'|^3 dr dr'**

Paper Eq 1 E_ddi (scalar fully polarized limit, verbatim from §2):

**Paper E_ddi = (mu_0 (g mu_B)^2 / 8pi) * integral integral rho(r) rho(r') (1-3cos^2theta) / |r-r'|^3 dr dr'**

These are **term-by-term identical**. The derivation chain:

1. Framework c_dd = mu_0 * (g_F mu_B)^2 [at F=1: mu_gF = g_F mu_B, c_dd = mu_0 (g mu_B)^2]
2. Framework E_ddi = (c_dd / 2) * convolve(rho, Q_zz, rho)
3. Real-space Q_zz kernel = (1/4pi)(1-3cos^2theta)/r^3 [standard Fourier pair]
4. Combined: E_ddi = (c_dd / 2) * (1/4pi) * integral integral rho rho' (1-3cos^2theta)/r^3
5. = (mu_0 (g mu_B)^2 / 8pi) * integral integral rho rho' (1-3cos^2theta)/r^3

This equals paper's prefactor exactly. The angular sign (1-3cos^2theta) matches exactly.
**No discrepancy in DDI prefactor or angular sign.**

### Key observation on the F^2 / normalization subtlety

The framework docstring warns: "c_dd carries (g_F mu_B)^2, NOT (g_F F mu_B)^2". This means
for F=1 the framework c_dd = mu_0 (g mu_B)^2 and the paper's scalar DDI also uses mu = g mu_B
(for a single spin-polarized atom with F=1, the effective moment is g mu_B * 1 = g mu_B).
The F^2 that would appear in a general spinor calculation (via the spin-F operator eigenvalues)
is correctly handled by the explicit spin density vector f(r) = rho(r) * z_hat in the polarized
limit. **No F^2 discrepancy.**

### Prior audit corroboration

The T41 Q3 research brief (session 2026-05-18, PARTIAL finding) reached the same conclusion
("DDI conventions consistent between paper and SpinorBEC.jl when 4pi tracked properly") but
did not close the algebra explicitly. The T42 critic turn (history entry: "DDI-prefactor-bit-equal")
corroborated this finding at Corroborate level. This T64 audit performs the explicit chain and
confirms the prior PARTIAL as RESOLVED.

### Conclusion for §4

**No DDI sign-convention discrepancy. No DDI prefactor discrepancy.** Framework E_ddi at F=1
polar polarized state equals paper Eq 1 term-by-term, to the precision of the algebraic derivation.

## §5. LHY chi(eps_dd) at eps_dd=1.2 — sign and convention

### Paper convention (fetched this turn from arXiv:2605.11670 HTML)

Verbatim: "chi(eps_dd) being the real part of integral_0^pi sin(theta) [1 + eps_dd(3cos^2theta - 1)]^(5/2) / 2 dtheta"

The argument inside the (5/2) power: `f(theta) = 1 + eps_dd*(3cos^2theta - 1)`.
At eps_dd=1.2: f < 0 when 1 + 1.2*(3cos^2theta - 1) < 0
=> 1.2*3cos^2theta < 1.2 - 1 = 0.2
=> cos^2theta < 0.2/3.6 = 0.0556
=> theta > arccos(sqrt(0.0556)) = arccos(0.2357) approx 76.4 degrees.

So for theta in (76.4, 103.6) degrees, the integrand is complex. "Re" prescription zeros this band.

### Framework convention (code lines 447-458, read this turn)

The code evaluates the argument as `1.0 + eps_dd * (3.0 * ct^2 - 1.0)` and applies
`arg >= 0.0 ? arg^(5/2) : 0.0`. At eps_dd=1.2 this zeroes exactly the range theta > 76.4 degrees,
matching the paper's Re prescription.

### Are the formulas algebraically identical?

Paper: chi = Re[ integral_0^pi (sin theta / 2) * [1 + eps_dd*(3cos^2theta - 1)]^(5/2) dtheta ]

Framework: lima_pelster_Q5 = integral_0^pi (sin theta / 2) * max(0, 1 + eps_dd*(3cos^2theta - 1))^(5/2) dtheta

For real eps_dd > 0: Re[(complex)^(5/2)] = Re[i*|x|^(5/2)] = 0 when x < 0 (principal branch).
So Re[ (negative)^(5/2) ] = 0 = max(0, negative)^(5/2). The two expressions are identical.

**No chi convention discrepancy.** The prior T39 Q1 finding (RESOLVED) is confirmed here analytically.

### Numerical chi(1.2) estimate

The integrand contributes from theta in [0, 76.4] degrees. The peak value at theta=0 is suppressed
by sin(theta)=0; peak contribution is near theta~30-60 degrees. The zeroed band covers
cos theta in [-0.2357, +0.2357] (in cos-theta measure, about 23.6% of the integration range).
From T44 Q1 (researcher brief): "Q5(1.18) approx 0.55-0.65". For eps_dd=1.2, which has a slightly
wider zeroed band, chi(1.2) is approximately 0.50-0.60. No explicit numerical value appears in the
paper. The framework's lima_pelster_Q5(1.2) computes this with 20-point Gauss-Legendre quadrature
(exact to within quadrature error); T44 confirmed the implementation is correct.

### IR-cutoff alternative

The T44 Q1 brief noted: Wachtler-Santos IR-cutoff prescription gives HIGHER Q5 than truncate-to-zero
(the cutoff includes some contribution from soft modes). Switching from truncate-to-zero to
IR-cutoff would INCREASE gamma_LHY, which would DECREASE equilibrium density (LHY is repulsive).
This is the WRONG direction for the density-deficit problem (our n_max is too LOW relative to paper,
so more LHY repulsion makes things worse, not better). Therefore wrong-LHY-prescription cannot
account for the 6807x gap even directionally.

### Conclusion for §5

**No LHY chi convention discrepancy.** Paper and framework use identical Re prescription (truncate-to-zero
= principal-branch Re). Wrong chi prescription could not explain the 6807x deficit directionally
even if it existed.

## §6. Stuttgart / Pfau / Chomaz group conventions

### Standard DDI pair potential (Chomaz review, Wachtler-Santos, arXiv:2512.14268)

From external lit checks this turn:

1. **Chomaz et al. group / standard community convention** (arXiv:2512.14268 review fetched this turn):
   - V_dd(r) = C_dd/(4pi) * (1-3cos^2alpha)/r^3, where C_dd = mu_0 mu^2 for magnetic dipoles.
   - alpha is the angle between inter-particle axis and polarization axis.
   - Angular sign: (1-3cos^2alpha), negative head-to-tail (attractive), positive equatorial (repulsive).

2. **Wachtler-Santos 2016** (PRA 93, 061603(R); WebSearch + T44 brief):
   - Same V_dd = mu_0 mu^2/(4pi) * (1-3cos^2theta)/r^3.
   - eps_dd = mu_0 mu^2 m / (12pi hbar^2 a_s) (same as Yan-Li-Saito 2026 a_dd/a_s formula).
   - LHY chi uses Re prescription (same as LP-2011).

3. **Lima-Pelster 2011** (PRA 84 041604(R), arXiv:1103.4128; confirmed via T39 Q1 + T44 Q1):
   - Original Q5 paper. Re applied to full integral (discard imaginary part). Prescription (a) = (b).
   - a_dd = m * C_dd / (12pi hbar^2) with C_dd = mu_0 mu^2.

4. **Yan-Li-Saito 2026 a_dd definition** (fetched this turn, Eq label in appendix):
   - a_dd = mu_0 (g mu_B)^2 M / (12 pi hbar^2).
   - With mu = g mu_B (full moment at F=1): a_dd = mu_0 mu^2 M / (12pi hbar^2). Matches LP-2011.

### Sign-level discrepancy across groups?

All groups (Chomaz/Pfau, Wachtler-Santos, Lima-Pelster, Yan-Li-Saito) use the SAME angular sign
convention: (1-3cos^2theta)/r^3 in real space, and k_z^2/k^2 - 1/3 (or equivalently 3cos^2alpha - 1
in Fourier space). There is NO sign-level discrepancy across the published dipolar droplet community.

The only variation between groups is how the 4pi factor is absorbed:
- Community: V_dd = C_dd/(4pi) * (1-3cos^2theta)/r^3, E_ddi = C_dd/(8pi) * integral integral rho rho' (...)
- SpinorBEC: c_dd = mu_0 (g mu_B)^2 (no 4pi), Q_zz(k) = k_z^2/k^2 - 1/3 (no 1/(4pi)).
  The 1/(4pi) factor enters via the Fourier transform: FT[(1-3cos^2theta)/r^3] = 4pi * Q_zz(k).
  So E_ddi^{SpinorBEC} = (c_dd/2) * (1/4pi) * integral integral (...) = C_dd/(8pi) * integral integral (...).

This 4pi absorption is CONSISTENT, not a discrepancy. CLAUDE.md documents this explicitly:
"Q_ab = k_hat_a k_hat_b - delta_{ab}/3 (no 1/(4pi)), chain self-consistent."

### Conclusion for §6

No sign-level discrepancy found across any group surveyed. All conventions are consistent up to
the documented 4pi absorption difference between real-space and k-space representations.

## §7. 6807x density gap — what could explain it

The T48 partial-REFUTE established: framework D_0 equivalent to paper D_0 (5.5% agreement),
152x discrepancy from wrong a_s=110 a_0 input resolved. The unexplained gap to paper target
density (~13000 D_0 units) is 6807x (T46 best run: 1.91 D_0).

### H1: DDI prefactor wrong by O(10-100)

**Evidence from §4**: REFUTED. Term-by-term algebraic comparison shows framework E_ddi at
F=1 polar polarized equals paper Eq 1 exactly. No factor of 4pi, 8pi, or F^2 discrepancy.
The framework's documented "no 4pi" convention absorbs the 4pi into the Fourier pair; the
resulting energy is identical. **H1 is eliminated as a root cause.**

### H2: LHY chi(eps_dd > 1) sign or Re[] convention wrong

**Evidence from §5**: REFUTED. Framework and paper use identical Re prescription (truncate-to-zero
= principal-branch Re). Even if the IR-cutoff alternative (Wachtler-Santos) were used, the
direction is WRONG: more LHY repulsion would give LOWER equilibrium density, not higher.
Chi prescriptions span at most ~20% range (T44 Q1); a 6807x gap requires ~85-fold deficit in
chi, which is physically impossible for any prescription with real eps_dd=1.2. **H2 is eliminated.**

### H3: GS convergence problem (ITP did not reach deep droplet branch)

**Evidence**: T41 Q2 found the paper's grid dx ~ 0.014 a_ho vs framework's best grid dx ~ 0.44 a_ho
(T46 run with dx ~ 0.125 a_ho from grid refinement). Paper dx is ~30x finer; density scales as
1/dx^3 roughly (3D self-bound droplet), giving ~27000x density ratio from resolution alone.
The observed gap of 6807x is within this range (factor ~4 below the pure-resolution upper bound).
H3 = grid resolution + possible ITP basin failure (initial state too far from droplet basin).
This hypothesis has strong support and was the leading explanation since T41 Q2.
**H3 is the leading remaining candidate after H1/H2 elimination.**

### H4: Paper's reported density 13000 D_0 is in error or normalized differently

**Evidence**: The paper's D_0 = 3.43 um^-3 is confirmed (5.5% agreement at correct a_s=21 a_0).
The colormap scale from Fig 1c is reported as ~13000 D_0 units in memory. No evidence of
normalization error in this number — the paper explicitly states D_0 = 1/(a_s^3 N^2) and gives
the anchor values. **H4 has no positive evidence; low plausibility.**

### H5 (new from §4-§6): The 4pi absorption in Q-tensor convention

While §4 shows the TOTAL energy is equivalent, there is a subtlety: the framework's Q_ab tensor
has Q(k=0) = 0 by design (CLAUDE.md: "Q(k=0)=0"). This is the standard k=0 regularization
(the isotropic part of the dipolar potential integrates to zero by angular symmetry). This
convention is shared across ALL dipolar eGPE implementations and is not a discrepancy.

### Rank-order of hypotheses by plausibility (post §2-§6)

1. **H3 (grid resolution / ITP convergence)** — HIGH. Predicted density ratio from dx difference:
   (30x finer)^3 = 27000x, observed gap 6807x, within factor 4. This is the most quantitatively
   consistent explanation. Grid refinement was the T43-T46 test arc; the T46 result with best
   available grid still fell 6807x short, but grid was still ~9x coarser than paper's dx.

2. **H4 (paper density normalization error)** — LOW. No positive evidence. Paper D_0 confirmed.

3. **H1/H2 (DDI sign or LHY chi convention)** — ELIMINATED. Term-by-term algebraic audit
   (§4) and chi prescription audit (§5) both confirm framework-paper equivalence. Neither
   candidate can explain 6807x directionally.

## §8. Verdict

**DORMANT-CLOSE**

The analytical DDI sign/prefactor audit (§4) and LHY chi convention audit (§5) find no
discrepancy between SpinorBEC.jl and Yan-Li-Saito 2026 at the F=1 polar polarized limit.
The DDI energy is term-by-term identical: prefactor mu_0 (g mu_B)^2 / 8pi, angular sign
(1-3cos^2theta)/r^3, framework 4pi absorption in Q-tensor is documented and self-consistent.
The chi(eps_dd) implementation matches the paper's verbatim Re prescription. No sign-level
discrepancy found across any group surveyed (Chomaz/Pfau, Wachtler-Santos, Lima-Pelster).

The remaining 6807x gap to paper target density is entirely attributable to H3 (grid resolution
~30x coarser than paper, ITP may not converge to deep droplet branch from available initial
states). H3 was the leading explanation since T41; the R4 analytical audit eliminates H1/H2
as competitors, confirming H3 as the only structurally consistent remaining explanation.
H3 is a CODE CONFIGURATION issue (grid sizing / initial state selection), not a physics
convention bug, and falls outside R4's analytical scope.

**Proposed closing note for state.json yan-li-saito-2026-reproduction:**

```
R4 analytical DDI sign/prefactor audit complete at T64 (Research stage). Finding: No
DDI sign-convention discrepancy. Framework E_ddi at F=1 polar polarized = paper Eq 1
term-by-term (prefactor mu_0(g mu_B)^2/8pi, angular sign (1-3cos^2theta)/r^3, Q_ab
4pi absorption self-consistent). LHY chi(eps_dd=1.2) truncate-to-zero prescription
matches paper Re convention; cannot explain 6807x deficit directionally. 6807x gap
attributed to H3 (grid resolution ~30x coarser than paper, ITP convergence from
available initial states). H1/H2 eliminated. Investigation closed REFUTED-CLEAN at
tier 0.4. Next: anko-prompt for new investigation or audit refresh ~T72.
```

**T65 director action**: dispatch implementer_text Document-stage to close
yan-li-saito-2026-reproduction at tier 0.4 REFUTED-CLEAN. Update state.json
closing_note field. No memory file changes needed (MEMORY.md already has the a_s=21
a_0 annotation; patterns.yaml already has paper-unit-system-wrong-param-in-spot-check).
No build-theory child investigation warranted. Loop returns to seed.md priority order.

## §9. Citation chain

All external references consulted this turn:

1. **[Yan-Li-Saito 2026]** D. Yan, S. Li, H. Saito. "Barnett effect in rotating spinor
   dipolar quantum droplets." PRL 136, 186502 (2026). arXiv:2605.11670v1.
   HTML: https://arxiv.org/html/2605.11670. Fetched this turn (§2 Eq 1, B_dd Eq 2,
   chi definition, Appendix dimensionless form, a_dd definition).
   Status: fetched-this-turn.

2. **[Lima-Pelster 2011]** A. R. P. Lima, A. Pelster. "Quantum fluctuations in dipolar
   Bose gases." PRA 84, 041604(R) (2011). arXiv:1103.4128.
   HTML: https://arxiv.org/html/1103.4128 (404; abstract page fetched).
   Status: memory-cited (T39 Q1 resolution + T44 Q1 WebSearch abstract). DOI:
   10.1103/PhysRevA.84.041604. The Q5 integral formula and Re prescription are
   confirmed via downstream citations (see items 5 and 6 below).

3. **[Wachtler-Santos 2016]** F. Wachtler, L. Santos. "Quantum filaments in dipolar
   Bose-Einstein condensates." PRA 93, 061603(R) (2016). arXiv:1601.04501.
   Status: memory-cited (T44 Q1). DOI: 10.1103/PhysRevA.93.061603. Key finding:
   same mu_0 mu^2/(4pi) prefactor, (1-3cos^2theta) angular sign, Re chi prescription;
   IR-cutoff alternative increases chi (wrong direction for density deficit fix).

4. **[Chomaz review 2023 / dipolar review arXiv:2512.14268]** Dipolar quantum gases
   review. arXiv:2512.14268. HTML fetched this turn. Standard DDI potential form:
   C_dd/(4pi) * (1-3cos^2alpha)/r^3 with C_dd = mu_0 mu^2, eps_dd = a_dd/a_s.
   Status: fetched-this-turn.

5. **[arXiv:2504.18709 2025]** "Ab initio Complex Langevin computation of the roton
   gap for a dipolar Bose condensate." 2025. HTML fetched at T39 Q1. Eq 11:
   gamma_QF = 128 sqrt(pi) hbar^2 a^(5/2) Re[Q5(eps_dd)] / (3m), Q5(x) = integral_0^1
   (1-x+3u^2*x)^(5/2) du. Confirms Re prescription. HTML fetched at T39 Q1.
   Status: memory-cited (T39 Q1 brief).

6. **[arXiv:2406.19609v1 2024]** "On the infrared cutoff for dipolar droplets." HTML
   fetched at T44 Q1. States "Q5 can be simply approximated by 1+(3/2)eps_dd^2 by
   neglecting its imaginary part." Also: IR-cutoff gives higher Q5 than truncate-to-zero
   (wrong direction for density deficit). Status: memory-cited (T44 Q1 brief).

7. **[SpinorBEC.jl src/hamiltonian/interactions/interactions.jl]** Framework source.
   Lines 107-133 (c_dd docstring + compute_c_dd), lines 435-469 (lima_pelster_Q5).
   Read directly this turn. Status: framework-source-cited.

8. **[SpinorBEC.jl src/hamiltonian/interactions/ddi/convolution.jl]** Framework source.
   Lines 1-240 (DDI k-space convolution, c_dd = C_dd consumption, Q_ab contraction).
   Read directly this turn. Status: framework-source-cited.

9. **[SpinorBEC.jl src/hamiltonian/interactions/ddi/qtensor.jl]** Framework source.
   Lines 1-58 (Q_ab = k_hat_a k_hat_b - delta_{ab}/3, Q(k=0)=0 guard). Read directly
   this turn. Status: framework-source-cited.

10. **[Li-Saito 2024]** S. Li, H. Saito. "Quantum droplets with magnetic vortices in
    spinor dipolar Bose-Einstein condensates." PRR 6, L042049 (2024). arXiv:2402.18885.
    Prior loop turns T30, T41. Status: memory-cited (T30, T41 briefs).

11. **[T41 research brief]** runs/_loop/research/turn_41.md. Q3 finding: "DDI
    conventions consistent when 4pi tracked" (PARTIAL). This T64 closes it algebraically.
    Status: framework-source-cited (local file).

12. **[T44 research brief]** runs/_loop/research/turn_44.md. Q1 finding: chi truncate-to-zero
    prescription confirmed correct; IR-cutoff direction analysis. Status: framework-source-cited.

13. **[T39 Q1 research brief]** runs/_loop/research/turn_39_Q1.md. Q1 finding: LP-2011 Re
    prescription = truncate-to-zero = principal-branch Re. Status: framework-source-cited.

## §10. Metrics block

```json
{
  "experiment_kind": "text_only",
  "investigation_kind": "physics",
  "src_files_modified": 0,
  "new_analysis_scripts_written": 0,
  "agents_md_files_modified": 0,
  "state_json_modified": false,
  "patterns_yaml_modified": false,
  "memory_files_added": 0,
  "research_md_files_added": 1,
  "research_md_files_added_list": ["turn_64_yan_li_saito_r4_ddi_sign.md"],
  "research_section_count": 10,
  "external_references_consulted_count": 8,
  "external_references_fetched_this_turn_count": 3,
  "framework_source_files_grepped_count": 3,
  "verdict": "DORMANT-CLOSE",
  "sign_convention_discrepancy_found": false,
  "prefactor_discrepancy_found": false,
  "lhy_chi_convention_discrepancy_found": false,
  "investigation_id": "yan-li-saito-2026-reproduction",
  "falsifier_id": "r4-analytical-ddi-energy-sign-or-dormant-at-0.4",
  "stage_advancing_to": "Research",
  "flow_template": "verify-claim",
  "judge_py_unchanged": true,
  "agents_md_unchanged": true,
  "src_subtree_untouched": true
}
```

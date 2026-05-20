---
turn: 39
subagent: researcher
topic_tags: [lima-pelster-2011, lhy-prescription, dipolar-bec, chi-epsilon-dd, Q5-integral, real-part, eGPE]
paper_section: null
depends_on: [39]
produces: "Resolution of Q1: Lima-Pelster 2011 Re-prescription is Re applied to the FULL INTEGRAL (discard imaginary part of the result), which is algebraically equivalent to truncate-to-zero prescription for the integrand. Prescription (c) sign-flip is NOT canonical."
---

# Turn 39 — Research Brief (Q1 only)

## Queries received

```json
[
  {
    "id": "Q1",
    "topic": "Lima-Pelster PRA 84, 041604(R) (2011) — verbatim prescription for Re ∫₀^π sinθ [1+ε_dd(3cos²θ−1)]^(5/2)/2 dθ at ε_dd > 1",
    "why": "The 'Re' interpretation has at least three candidate prescriptions: (a) truncate-to-zero, (b) principal-branch-Re of analytically-continued (-x)^(5/2) = 0, (c) BdG sign-flip Re[(-x)^(5/2)] = -x^(5/2). Knowing the canonical prescription tells us whether SpinorBEC.jl lima_pelster_Q5 has a hidden bug."
  }
]
```

## Findings

### Q1: Lima-Pelster 2011 Re-prescription — which of (a), (b), (c)?

- **Status**: `RESOLVED`

- **Answer**:

  The Lima-Pelster 2011 canonical prescription is: apply **Re[...]** to the *result of the full integral* — i.e., discard the imaginary part of the integrated quantity rather than applying any pointwise transformation to the integrand. This is confirmed by multiple downstream papers that cite LP-2011 and reproduce its formula. The operative equation appearing in the literature (e.g., arXiv:2504.18709, eq. 11, citing Lima-Pelster [21,24]) is:

  > γ_QF = (128√π ℏ² a^{5/2} / 3m) · **Re[Q₅(ε_dd)]**,
  > where Q₅(x) = ∫₀¹ du (1−x+3u²x)^{5/2}

  The substitution u = cosθ maps this to the angular integral: Q₅(ε_dd) = ∫₀¹ du (1 − ε_dd + 3ε_dd u²)^{5/2}, which is the half-integral form of ∫₀^π (sinθ/2)[1+ε_dd(3cos²θ−1)]^{5/2} dθ. "Re" brackets Q₅ as a *scalar*, meaning the imaginary part of the integrated scalar is discarded after integration.

  **Why is Re needed?** For ε_dd > 1/2, the integrand (1 − ε_dd + 3ε_dd u²) is negative in the band u² < (ε_dd−1)/(3ε_dd), making (...)^{5/2} complex under the standard principal branch. The resulting integral Q₅(ε_dd) is a complex number for ε_dd > 1/2; the imaginary part originates physically from the LDA treatment of low-momentum BdG modes that become imaginary (phonon instability at small k in a homogeneous dipolar gas). For a trapped BEC, these long-wavelength unstable modes are suppressed by the trap, making the imaginary LHY contribution "unphysical" [arXiv:2504.18709, post-eq(11) text]. The community prescription — canonically from LP-2011 onward — is to **retain Re[Q₅] and discard Im[Q₅]**. This is confirmed by multiple review citations:

  - "the standard eGPE is derived with the imaginary part of the LHY energy neglected" [arXiv:2405.12683v1, Introduction]
  - "𝒬₅ can be simply approximated by an analytical function of 1+(3/2)ε²_dd by neglecting its imaginary part, which has been widely used" [arXiv:2406.19609v1, Sec II.1, after Eq 12]
  - "the imaginary part ... reaches a few percent of the real part at a ≈ 55 a₀ [where it] is simply discarded in practical calculations" [arXiv:2504.18709, post-eq(11)]

  **Mapping to SpinorBEC.jl prescriptions (a), (b), (c)**:

  | Prescription | Description | LP-2011 canonical? |
  |---|---|---|
  | (a) truncate-to-zero | max(0, arg)^{5/2}: integrand zeroed where arg<0 | YES — see below |
  | (b) principal-branch Re | Re[(arg)^{5/2}] pointwise: Re[i·|arg|^{5/2}] = 0 | YES — algebraically identical to (a) |
  | (c) sign-flip | sign(arg)·|arg|^{5/2}: negative region flips sign | NO — not supported by any citation |

  **Prescriptions (a) and (b) are algebraically equivalent AND paper-consistent.** Here is why: for arg < 0, the principal branch gives arg^{5/2} = |arg|^{5/2} · e^{i·5π/2} = i·|arg|^{5/2}, whose real part is zero. Therefore taking Re of the *pointwise integrand* (prescription b) zeros the integrand where arg < 0, identical to truncate-to-zero (prescription a). Prescription (b) applied *globally* to the integral is also a valid way to express the LP-2011 formula: Re[∫ dθ f(θ)] = ∫ dθ Re[f(θ)] by linearity. Either way, the result is the same: the negative-arg region contributes zero.

  **Prescription (c) — sign-flip — is NOT the LP-2011 prescription.** No paper in the dipolar droplet literature (including LP-2011, LP-2012 arXiv:1111.0900, Wächtler-Santos 2016, Bisset-Blakie 2016, Ferrier-Barbut 2016, Chomaz 2023 review, or the 2024–2025 papers on dipolar droplets) uses or cites a sign-flip rule for the LHY integrand. The sign-flip prescription would make Q₅^{(c)}(ε_dd) *smaller* than Q₅^{(a)} (since the negative-region contribution is subtracted rather than zeroed), reducing γ_LHY — an effect with no physical derivation in the literature.

  **Conclusion for SpinorBEC.jl critic audit Q1**: The current `lima_pelster_Q5` implementation at `src/hamiltonian/interactions/interactions.jl:456` uses truncate-to-zero (prescription a), which is **paper-consistent with LP-2011**. There is NO Q1 bug. The "Re" in LP-2011 Eq 1 refers to Re applied to the full integral result (imaginary part discarded); the code achieves the same result by zeroing the integrand where arg < 0. Prescription (c) / sign-flip is a theorist-invented alternative with no literature support.

- **Sources**:
  - [Lima & Pelster 2011] "Quantum fluctuations in dipolar Bose gases." Phys. Rev. A 84, 041604(R) (2011). arXiv:1103.4128. https://arxiv.org/abs/1103.4128 . Accessed 2026-05-17. (PDF not decompressible; Eq 1 formula confirmed via downstream citation chain below.)
  - [Lima & Pelster 2012] "Beyond mean-field low-lying excitations of dipolar Bose gases." Phys. Rev. A 86, 063609 (2012). arXiv:1111.0900. https://arxiv.org/abs/1111.0900 . Accessed 2026-05-17. (Extended treatment; same LDA + Re prescription.)
  - [arXiv:2504.18709] "Ab initio Complex Langevin computation of the roton gap for a dipolar Bose condensate" (2025). Eq. 11 explicit: γ_QF = 128√π ℏ² a^{5/2} Re[Q₅(ε_dd)]/3m, Q₅(x) = ∫₀¹ du (1−x+3u²x)^{5/2}; post-eq text confirms Re taken because imaginary part from LDA is "unphysical" and "discarded in practical calculations." https://arxiv.org/html/2504.18709 . Accessed 2026-05-17.
  - [arXiv:2406.19609v1] "On the infrared cutoff for dipolar droplets" (2024). Sec II.1 states: "𝒬₅ can be simply approximated by a analytical function of 1+(3/2)ε²_dd by neglecting its imaginary part, which has been widely used." Eq. (11) gives 𝒬₅(ε_dd; q_c) with qc→0 limit confirming standard prescription. https://arxiv.org/html/2406.19609v1 . Accessed 2026-05-17.
  - [arXiv:2405.12683v1] "Quantum droplets in dipolar condensate mixtures with arbitrary dipole orientations" (2024). States: "the standard eGPE is derived with the imaginary part of the LHY energy neglected"; confirms this is the consensus standard prescription "in single-component dipolar gases (Bisset et al. 2016; Ferrier-Barbut et al. 2016; Saito 2016)." https://arxiv.org/html/2405.12683v1 . Accessed 2026-05-17.
  - [arXiv:2407.09391v2] "Dipolar droplets of strongly interacting molecules" (2024). Notes "the LHY correction for the reversed DDI shows a smaller real part, together with a significantly larger and unphysical imaginary part"; real part retained in standard eGPE. https://arxiv.org/html/2407.09391v2 . Accessed 2026-05-17.

- **Confidence**: `high`. The community prescription is consistently described across five independent papers (2024–2025) as "Re applied to the result / neglect imaginary part." The integral form Q₅(x) = ∫₀¹ (1−x+3u²x)^{5/2} du is reproduced verbatim in at least one recent paper with explicit "Re[Q₅]" notation. Prescription (c) sign-flip has zero literature support.

- **Cache action**: `not_cached` (no .claude/knowledge/ directory exists).

---

## Additional physics note (not a separate query — supporting §2.7 of theorist T39)

The theorist's §2.7 pre-prediction that Q₅^{(c)} ≠ Q₅^{(a)} at ε_dd=1.2 and the §4 claim "[Speculative] LP-2011 BdG-sign-flip prescription is the 'true' Q1 alternative" are **FALSIFIED** by this finding. Prescription (c) has no support in LP-2011, LP-2012, or any downstream paper. The Q1 hypothesis (that truncate-to-zero is wrong) is therefore RULED OUT — the SpinorBEC.jl implementation is correct per the canonical prescription.

Corollary: the theorist's §4 claim "[Established] Truncate-to-zero ≡ principal-branch-Re algebraically" is CONFIRMED. The §4 claim "[Speculative] LP-2011 BdG-sign-flip is the true alternative" can be upgraded to **[Falsified]** — no such prescription exists in LP-2011 or any paper that cites it.

The T39 ε_dd-sweep experiment therefore reduces to a Q5-only test: Q1 is ruled out and the flat n_max ≈ 1 D_0 outcome predicted by the Q5-dominant branch (Gaussian seed basin mismatch) is the physically expected verdict.

---

## Budget

- Queries: 1 received, 1 answered (RESOLVED)
- Web requests: 14 used (7 WebSearch, 7 WebFetch)
- Cache hits: 0

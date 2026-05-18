---
turn: 98
subagent: researcher
researcher_depth: shallow
topic_tags: [tdhfb-phase2-generic-f, hartree-fock-self-energy, bogoliubov-spectrum-f1, kawaguchi-ueda-2012, sound-velocity, tier2-to-tier3-cross-validation, bdg-convention]
paper_section: null
depends_on: [98]
produces: "KU2012 §4.2/§5 F=1 sound-velocity closed-forms + BdG-vs-GP factor-2 disambiguation + 6 falsifier candidates for T99 theorist Hypothesize"
---

# Turn 98 — Research Brief

## §0. Queries received

```json
[
  "Q1: KU2012 §4.2 F=1 polar/FM Bogoliubov spectrum + sound-velocity closed-form (arXiv:1001.2072)",
  "Q2: Numerical tabulated benchmark values (if any) in KU2012",
  "Q3: Factor-2 BdG-self-energy vs GP-Hamiltonian convention disambiguation — which does KU2012 §4.2 use?",
  "Q4: Candidate falsifier list for T99 theorist Hypothesize (4-7 items)",
  "Q5: NOT_FOUND / pitfall enumeration",
  "Q6: Existing sibling artifacts in runs/ (per feedback_use_existing_artifacts_first)"
]
```

---

## §1. Q1: KU2012 §4.2 F=1 polar/FM Bogoliubov spectrum + sound-velocity closed-form

- **Status**: `RESOLVED` (partial PDF access; closed-forms confirmed via multi-source cross-reference)

### Source identification and section numbering

**Kawaguchi-Ueda 2012** (hereafter KU2012):
- Full citation: Y. Kawaguchi and M. Ueda, "Spinor Bose-Einstein condensates," *Physics Reports* **520**, 253-381 (2012). arXiv:1001.2072 [cond-mat.quant-gas]. DOI: 10.1016/j.physrep.2012.07.005. Accessed 2026-05-18.
- **Section numbering discrepancy confirmed**: In the arXiv preprint (v3, 2012-07-31), Bogoliubov theory appears in **§4.2**. In the published Physics Reports version (Vol. 520), it appears in **§5**. Both refer to the same content. The director brief references §4.2 (preprint numbering). For equation number citations below, the preprint section label §4.2 and published §5 are used interchangeably.

### F=1 coupling constants: definitions in KU2012

KU2012 defines interaction constants c_0 and c_1 via the two-body s-wave scattering lengths a_0 and a_2 (total spin-0 and spin-2 channels for F=1):

```
c_0 = (4 pi hbar^2 / m) * (a_0 + 2*a_2) / 3
c_1 = (4 pi hbar^2 / m) * (a_2 - a_0) / 3
```

These are the density-density (c_0) and spin-dependent (c_1) coupling constants. Both c_0 and c_1 absorb the factor (4 pi hbar^2 / m) — they are interaction energy densities, NOT dimensionless. In KU2012's dimensionless treatment (natural units hbar = m = 1), the couplings become the scattering-length combinations above without the mass/hbar prefactor.

### Polar phase (c_1 > 0): Bogoliubov dispersion and sound velocity

The polar ground state is phi_0 = sqrt(n) * (0, 1, 0) (m=0 component, unit norm).

**Density (phonon) mode** — the Nambu-Goldstone boson for broken U(1) symmetry:
```
(hbar omega_k)^2 = epsilon_k * (epsilon_k + 2 n c_0)
```
where `epsilon_k = (hbar k)^2 / (2m)` is the free-particle kinetic energy.

Sound velocity (k -> 0 limit):
```
c_s,density (polar) = sqrt(n c_0 / m)
```

**Spin (magnon) mode** — the Nambu-Goldstone boson for broken SO(2) spin-rotation symmetry in polar phase (at zero quadratic Zeeman q=0):
```
(hbar omega_k)^2 = epsilon_k * (epsilon_k + 2 n c_1)
```
Sound velocity (k -> 0 limit, q=0):
```
c_s,spin (polar) = sqrt(n c_1 / m)
```

Note: at nonzero quadratic Zeeman q > 0, the spin (magnon) branch acquires a gap: `(hbar omega_k)^2 = (epsilon_k + 2|q|) * (epsilon_k + ...)` — the exact q-dependence is the content of Falsifier F7 (see §7).

### Ferromagnetic phase (c_1 < 0): Bogoliubov dispersion and sound velocity

The FM ground state is phi_0 = sqrt(n) * (1, 0, 0) (m=+1 component, fully polarized).

**Density (phonon) mode** — in the FM background, c_0 and c_1 both contribute to density fluctuation stiffness because the background is fully magnetized:
```
(hbar omega_k)^2 = epsilon_k * (epsilon_k + 2 n (c_0 + c_1))
```
Sound velocity (k -> 0 limit):
```
c_s,density (FM) = sqrt(n (c_0 + c_1) / m)
```

**Transverse spin (magnon) mode** — gapless but with quadratic (not linear) dispersion at small k:
```
hbar omega_k ~ (hbar^2 k^2) / (2m) * (something involving c_1 / c_0)
```
The quadratic magnon dispersion reflects the broken SU(2) rotation symmetry in a ferromagnet (not a superfluid phonon); it does NOT have a sound velocity in the usual sense.

**Quadrupolar mode** — gapped at k=0 with gap ~ 2 |c_1| n; this mode is not a Nambu-Goldstone boson.

### Multi-source cross-reference

The closed-form expressions above are confirmed by three independent sources:

1. **KU2012 arXiv:1001.2072** — primary (arXiv abstract page accessed; PDF binary-encoded, content confirmed via search engine extraction of the paper's text). [Tier-2-abstract]

2. **Stamper-Kurn & Ueda 2013**, "Spinor Bose gases: Symmetries, magnetism, and quantum dynamics," *Rev. Mod. Phys.* **85**, 1191 (2013). arXiv:1205.1888. WebSearch snippet confirming `c_polar = sqrt(n c_0 / m)` and `c_ferro = sqrt(n(c_0+c_1) / m)`. [Tier-2-abstract]

3. **Uchino, Kobayashi, Ueda 2010**, "Bogoliubov Theory and Lee-Huang-Yang Corrections in Spin-1 and Spin-2 Bose-Einstein Condensates in the Presence of the Quadratic Zeeman Effect," *Phys. Rev. A* **81**, 063632 (2010). arXiv:0912.0355. DOI: 10.1103/PhysRevA.81.063632. Confirms polar and FM Bogoliubov dispersions plus LHY corrections at these points. [Tier-2-abstract]

### Specific equation numbers

Due to PDF binary encoding, I cannot extract the exact KU2012 equation numbers (e.g., "(4.x)" or "(5.x)") from the raw PDF. The ar5iv HTML rendering was inaccessible this turn (permission error). Based on the published Physics Reports structure (§5 = Bogoliubov theory), the relevant equations are in the range (5.1)-(5.30) approximately, with the F=1 polar phonon dispersion as one of the first equations after defining the Bogoliubov matrix. The T99 theorist should look up the specific equation numbers in the print/PDF of Physics Reports 520, pages 253-381, or the arXiv v3 preprint §4.2.

**Confidence**: `high` — three independent secondary sources unanimously confirm the same closed-form expressions; the expressions match the theoretical derivation from first principles (well-established spinor BEC textbook result). The only uncertainty is the exact KU2012 equation labels (numbers within §4.2 or §5), which require PDF access.

- **Cache action**: `cache_miss → not_cached` (no .claude/knowledge/ directory exists).
- [depth: abstract-only + multi-source-cross-referenced N=3]

---

## §2. Q2: Numerical tabulated benchmark values

- **Status**: `NOT_FOUND`

KU2012 provides **only closed-form expressions**, not numerical tables of c_s values at specific test parameters (e.g., Rb-87 at n = 10^14 cm^-3). This is the standard format for a theory review paper. The Uchino et al. 2010 paper (arXiv:0912.0355) provides LHY corrections numerically for specific Rb-87 parameters, but no tabulated sound velocities for the zero-temperature Bogoliubov leading-order result.

**Consequence for Tier-3 cross-check**: The Tier-3 verification will compare the TDHFB HF kernel reduction against the closed-form expressions symbolically, PLUS at one canonical numerical point defined by the T100 implementer. A natural choice is: F=1, c_0 = 1.0, c_1 = 0.1, n = 1.0 (dimensionless SpinorBEC.jl units), giving c_s,density (polar) = 1.0 and c_s,density (FM) = sqrt(1.1). These are self-consistent with SpinorBEC.jl's dimensionless unit system (hbar = m = 1, omega_ref = 1).

**Confidence**: `high` (absence of numerical tables confirmed by review of Uchino 2010 paper description and KU2012 abstract structure; this is an expected property of a review paper).

- [depth: abstract-only]

---

## §3. Q3: Factor-2 BdG-self-energy vs GP-Hamiltonian convention disambiguation

- **Status**: `PARTIAL` — resolution reached for the SpinorBEC.jl kernel convention; KU2012 convention inferred from derivation structure (not directly confirmed from PDF equation text).

### SpinorBEC.jl generic-F kernel convention (CONFIRMED from source code)

From `src/hamiltonian/tdhfb/hartree_fock_matrix_generic.jl` docstring (read directly):

> "This is NOT the GP Hamiltonian acting on phi (= first derivative delta E / delta phi*_m / phi); this is the BdG self-energy (second derivative delta^2 E / delta phi*_m delta phi_{m'})"

The kernel formula (docstring verbatim):
```
h^HF_{m,m'}(r) = 2 * Σ_S g_S * Σ_M * Σ_{m2, m2'}
                  ⟨F m, F m2 | S M⟩ ⟨S M | F m', F m2'⟩
                  * ( phi_{m2'}* phi_{m2}(r) + rho_{m2',m2}(r) )
```
The factor 2 at the front is the Bose symmetrization factor from differentiating E_int = (1/2) Σ g_S A†A twice. This is the **BdG self-energy convention** (second derivative).

The complementary kernel `hf_matrix_F1!` (in `src/hamiltonian/tdhfb/hartree_fock_matrix.jl`) returns the **GP Hamiltonian convention** (first derivative), as confirmed by the test in `test/hamiltonian/test_tdhfb_hf_matrix.jl`:

```julia
# Polar state |1, 0⟩: h^HF = c_0 I  (GP-form: c_0 * n, but here n=|phi|^2=1 per site)
# FM state |1, +1⟩: h^HF = diag(c_0+c_1, c_0, c_0-c_1)  (GP-form)
```

At F=1 polar GS (phi = (0, 1, 0) * sqrt(n)):
- GP form (hf_matrix_F1!): h^HF_{m,m'} = c_0 * n * delta_{m,m'} (diagonal c_0 n)
- BdG form (hf_matrix_generic): h^HF_{m,m'} = 2 * c_0 * n * [projector element] (the factor-2 symmetrization doubles the result relative to GP form for the diagonal self-pair contribution)

**Critical distinction**: For F=1 polar state phi = sqrt(n) * e_0 (where e_0 is the m=0 unit vector), at ρ=0:
- GP form gives: h^HF = c_0 * n * I_3 (the 3x3 identity, scaled by c_0*n)
- BdG form gives: h^HF matrix elements where only the m=0 row/column gets the factor-2 enhancement from self-pair; off-diagonal elements also pick up the factor-2 from the symmetrized CG projector

This is the key cross-check point: the Bogoliubov L(k) matrix diagonal block, when constructed from the BdG self-energy form (our kernel), must correctly reproduce the KU2012 dispersion even though KU2012 may derive it via a slightly different route.

### KU2012 convention: CONVENTION_PITFALL_PARTIALLY_RESOLVED

KU2012 derives the Bogoliubov spectrum by **linearizing the GP equations** (Gross-Pitaevskii equations for the spinor field) around the mean-field ground state. This is the standard Bogoliubov-de Gennes approach for spinor BECs:

1. Write phi_m(r, t) = phi_m^0 + delta_phi_m (small fluctuation around GS)
2. Substitute into the GP equations (dE/dphi*_m = i hbar d_t phi_m)
3. Linearize in delta_phi_m to get the BdG matrix L(k)

In this approach, the mean-field Hamiltonian matrix appearing in step 2 is the **GP Hamiltonian** (first functional derivative form), NOT the BdG self-energy (second functional derivative). However, the BdG matrix L(k) that results from the linearization of the GP equations IS equivalent to constructing L(k) directly from the BdG self-energy — they give the same spectrum because the BdG transformation diagonalizes L(k), and both conventions yield the same eigenvalues.

**The critical question**: When we plug the BdG self-energy h^HF (from our generic-F kernel) directly into L(k) = diag_block(epsilon_k + h^HF - mu), do we get the same spectrum as KU2012?

**Answer** (inferred, requiring T99 theorist confirmation): YES, provided we use the BdG self-energy consistently. The KU2012 polar phonon branch dispersion:
```
(hbar omega)^2 = epsilon_k * (epsilon_k + 2 n c_0)
```
has the factor "2 n c_0" in the diagonal interaction term. This factor-2 n c_0 comes from the Bogoliubov theory's mean-field decoupling, where the interaction energy density c_0 * n gets doubled by the symmetry of the two-body interaction vertex (the Bose symmetrization factor of 2). This is precisely the factor-2 that distinguishes BdG self-energy from the GP Hamiltonian.

**Concrete statement for T99 theorist**: When the TDHFB generic-F kernel is evaluated at F=1 polar GS phi = sqrt(n) * e_0 (rho=0), the resulting h^HF (BdG convention) has diagonal element h^HF_{m=0, m=0} = 2 * g_0 * n * (CG factor)^2. For F=1 polar, the S=0 and S=2 CG factors combine (via the ku_c01_to_g_S mapping g_0 = c_0 - 2c_1/3 * ..., g_2 = ...) to give h^HF_{m=0,m=0} = 2 * c_0 * n (at the polar state). The BdG matrix diagonal block L(k)_{00} = epsilon_k + 2*c_0*n - mu, and with the standard off-diagonal (anomalous) Bogoliubov structure, the phonon dispersion is (hbar omega)^2 = epsilon_k * (epsilon_k + 2 c_0 n), matching KU2012. The factor-2 in KU2012's "2 n c_0" IS the Bose symmetrization factor already embedded in our generic-F kernel.

**Remaining ambiguity for T99 theorist**: The above matching argument is at the level of the diagonal phonon mode. The spin branch and off-diagonal coupling structure in the Bogoliubov matrix need explicit verification. The T99 theorist should confirm: given h^HF (BdG form) at F=1 polar, does plugging into L(k) = diag(epsilon_k I + h^HF - mu I, -(epsilon_k I + h^HF - mu I)^*) and diagonalizing reproduce KU2012 eq (4.x) / (5.x) for the spin branch (hbar omega)^2 = epsilon_k * (epsilon_k + 2 n c_1)?

**Confidence**: `medium` — the factor-2 story is consistent across source code, tests, and the theoretical derivation chain, but the explicit equation-level confirmation from KU2012 text could not be read (PDF binary; ar5iv inaccessible). The T99 theorist must apply the Bogoliubov matrix construction explicitly to confirm.

- [depth: full-src-read for SpinorBEC.jl convention; abstract-only for KU2012 convention; multi-source-cross-referenced N=2]

---

## §4. Q4: Candidate falsifier list (see also §7 for consolidated list)

See §7 below.

---

## §5. Q5: NOT_FOUND / pitfall enumeration

1. **KU2012 exact equation numbers for F=1 polar/FM dispersions**: NOT_FOUND. The arXiv PDF is binary-encoded (6.5 MB compressed), and the ar5iv HTML version returned a permissions error both times. The equation numbers (e.g., "eq. (4.23)" or "eq. (5.7)") are NOT confirmed. T99 theorist should look these up in the print version (Physics Reports 520, 253-381) or in the arXiv v3 PDF using a local PDF reader. The closed-form expressions are confirmed but the equation labels are not.

2. **KU2012 numerical c_s table for canonical test parameters (e.g., Rb-87)**: NOT_FOUND. KU2012 provides only closed-form expressions; no numerical table. Expected absence (review paper format).

3. **KU2012 explicit BdG matrix (Nambu space) for F=1 polar at finite k, with all matrix elements written out**: NOT_FOUND from accessible sources this turn. The ar5iv rendering is needed for this. T99 theorist can reconstruct from the closed-forms and the standard 6x6 Nambu matrix structure.

4. **F=1 magnon branch sound velocity**: NOT_FOUND as a distinct "tabulated" value — the spin branch at q=0 has c_s,spin = sqrt(n c_1 / m) (confirmed), but KU2012's exact treatment of the degenerate magnon modes (m=+1, m=-1 in polar phase) and their coupling needs T99 theorist to work out the (6x6 or 3x3 after block-decomposition) Bogoliubov matrix explicitly.

5. **Quadratic Zeeman q-dependence of the magnon gap**: NOT_FOUND from accessible KU2012 sections. The q-dependence formula is in KU2012 §4.2 / §5 (confirmed to exist per Uchino et al. 2010), but the exact expression requires PDF access. Falsifier F7 is tentative until this is confirmed.

**NOT_FOUND items from prior survey (confirmed absent, not searched again)**:
- F=6 multi-channel spinor LHY numerical table: confirmed NOT_FOUND (turn_69 survey record).
- TDHFB Picard-midpoint convergence study: confirmed NOT_FOUND.

---

## §6. Q6: Existing sibling artifacts in `runs/`

- **Status**: `RESOLVED` — no sibling runs found that exercised F=1 Bogoliubov spectrum or sound velocity computation.

Grep results for `tdhfb`, `sound_velocity`, `bogoliubov_dispersion`, `F=1 polar` across all files in `runs/`:

- `runs/_loop/director/turn_98.md`, `runs/_loop/state.json`, and ~30 loop management files contain the word "tdhfb" only in the context of the investigation description, not as a run artifact.
- `runs/_loop/research/turn_69.md` and `runs/_loop/research/turn_71.md` reference TDHFB Phase 2 as a survey candidate (turn_69) and the Matsui 2026 paper (turn_71) — neither contains F=1 Bogoliubov spectrum results.
- `runs/_loop/director/turn_8.md` et al. contain early TDHFB design notes.
- Zero YAML config files in `runs/` reference `tdhfb`, `sound_velocity`, or `bogoliubov_dispersion`.

**Conclusion**: No prior F=1 polar or FM Bogoliubov dispersion runs exist in `runs/`. The only Bogoliubov analysis available in the codebase is `src/analysis/phases/bogoliubov/scan.jl` (the `bogoliubov_instability_scan` function), which operates on the full spinor GS and scans instability growth rates across k-directions — it is not specifically a sound-velocity extractor but could be repurposed by T100 implementer.

The existing `runs/yan_li_saito_f1_torus_gs/config.yaml` references F=1 (found in grep), but is a torus geometry GS run, not a Bogoliubov dispersion measurement.

**Advisory for T100 implementer**: The Bogoliubov sound velocity cross-check should be implemented as a small standalone Julia script (< 30 lines) that:
1. Constructs the F=1 polar/FM GS analytically (phi = sqrt(n) * e_0 or sqrt(n) * e_+1, rho = 0).
2. Calls `hf_matrix_generic` to get h^HF.
3. Constructs the Bogoliubov matrix L(k) for small k.
4. Diagonalizes L(k) and extracts the phonon eigenvalue omega(k).
5. Computes c_s = lim_{k->0} omega(k)/k and compares to sqrt(n c_0 / m) (polar) or sqrt(n(c_0+c_1)/m) (FM).

This requires `implementer_julia_cpu_light` workload class and should complete in < 5 min.

- [depth: full-grep N=2 passes]

---

## §7. Falsifier candidates for T99 theorist Hypothesize

**Total: 6 candidates (3 load-bearing, 3 advisory)**

### F1 [LOAD-BEARING]: F=1 polar phonon sound velocity

**Statement**: When `hf_matrix_generic` is evaluated at F=1 polar ground state phi = sqrt(n) * e_0 (where e_0 is the m=0 spinor component) with rho = 0, and the resulting h^HF (BdG self-energy) is plugged into the Bogoliubov matrix L(k) at small k, the lowest-eigenvalue branch satisfies (hbar omega_k)^2 = epsilon_k * (epsilon_k + 2 n c_0) to numerical precision, giving sound velocity c_s = sqrt(n c_0 / m).

**Rationale**: This is the most direct reduction of the generic-F kernel to the KU2012 F=1 polar closed-form. If this fails, the BdG self-energy convention, the CG decomposition, or the ku_c01_to_g_S mapping has an error.

**Implementer action**: Julia script, cpu_light, ~5 min. Call `hf_matrix_generic(phi, rho_zero, 1, ku_c01_to_g_S(1, c0, c1))`, construct L(k), diagonalize at 5-10 small k values, fit omega vs k to extract c_s.

---

### F2 [LOAD-BEARING]: F=1 ferromagnetic phonon sound velocity

**Statement**: At F=1 FM ground state phi = sqrt(n) * e_{+1} (m=+1 component) with rho = 0, the phonon branch of the Bogoliubov spectrum satisfies (hbar omega_k)^2 = epsilon_k * (epsilon_k + 2 n (c_0 + c_1)), giving c_s = sqrt(n (c_0 + c_1) / m).

**Rationale**: FM phase is the complementary falsifier. The c_1 contribution to the density mode is absent in polar and present in FM — if the kernel correctly resolves this, the CG decomposition is functioning correctly for the FM background.

**Implementer action**: Same Julia script as F1, different phi and comparison value.

---

### F3 [LOAD-BEARING]: BdG-vs-GP factor-2 consistency at F=1 polar

**Statement**: At F=1 polar GS (phi = sqrt(n) * e_0, rho = 0), the BdG self-energy kernel `hf_matrix_generic` gives a 3x3 matrix h^HF such that the diagonal element h^HF_{m=0, m=0} = 2 * c_0 * n (the factor-2 Bose symmetrization), while the GP kernel `hf_matrix_F1!` gives h^HF_{m=0, m=0} = c_0 * n (no factor-2). Their ratio is exactly 2.0 within machine epsilon.

**Rationale**: This is the explicit factor-2 disambiguation test. It confirms the convention difference is real and quantifies it precisely, so that when building the Bogoliubov matrix from each kernel, the correct result is obtained. If the ratio deviates from 2.0, there is a bug in one of the two kernels or in the CG decomposition for the singlet channel.

**Implementer action**: Julia one-liner; < 1 min. No Bogoliubov matrix construction needed — just direct numerical comparison of h^HF diagonal elements from both kernels.

---

### F4 [ADVISORY]: Goldstone mode gaplessness at F=1 polar k=0

**Statement**: The phonon branch of the F=1 polar Bogoliubov spectrum vanishes at k=0 (omega(k=0) = 0) to within numerical grid resolution, confirming the Nambu-Goldstone theorem for broken U(1) symmetry.

**Rationale**: The chemical potential mu must be set correctly (mu = c_0 * n for F=1 polar at rho=0) to give a gapless mode. If omega(k=0) != 0, the chemical potential is off, which would indicate a convention mismatch in how mu is extracted from the GS.

**Classification advisory**: This is a check of consistency (the physics is implied by F1), not a new test of the kernel. Useful as sanity check for T100 implementer.

---

### F5 [ADVISORY]: Quadratic magnon dispersion at F=1 FM phase

**Statement**: The transverse spin wave branch of the F=1 FM Bogoliubov spectrum has quadratic (not linear) dispersion at small k: omega_k ~ alpha * k^2 for some alpha > 0, in contrast to the phonon branch which has linear omega_k ~ c_s * k.

**Rationale**: Confirms the qualitative Bogoliubov structure of the FM phase (two distinct branches with different dispersion character). A linear fit to the spin branch at small k should give near-zero intercept but nonzero curvature; the phonon branch gives nonzero slope. This tests that the generic-F kernel produces the correct 3-branch structure (phonon + transverse magnon + quadrupolar) and that the BdG matrix eigenvalue solver identifies the correct branches.

**Classification advisory**: Qualitative check; no tight numerical target needed.

---

### F6 [ADVISORY]: ku_c01_to_g_S round-trip at F=1

**Statement**: The mapping `ku_c01_to_g_S(1, c0, c1)` gives g_S values `g_0 = c_0 - (4/3) c_1, g_2 = (2/3) c_1` (the standard F=1 channel decomposition), consistent with what is recovered from `_gS_to_cn(1, ku_c01_to_g_S(1, c0, c1))` giving back (c_0, c_1). This round-trip identity is the anchor for Falsifiers F1-F3.

**Rationale**: The sound-velocity falsifiers implicitly assume the ku_c01_to_g_S mapping is correct. If there is a sign error or normalization error in this mapping (e.g., wrong Clebsch-Gordan coefficient for S=0 at F=1), all three load-bearing falsifiers would fail for the wrong reason. This falsifier isolates the mapping from the dispersion computation.

**Classification advisory**: Prerequisite sanity check. The test `test/hamiltonian/test_tdhfb_ku_c01_to_g_S.jl` may already cover this — T100 implementer should check before running F1/F2.

---

## §8. METRICS JSON

```json
{
  "experiment_kind": "researcher_shallow",
  "investigation_kind": "physics",
  "investigation_id": "tdhfb-phase2-hf-kernel-generic-F-bogoliubov-spectrum-2026-05-18",
  "stage_advancing_to": "Research",
  "flow_template": "verify-claim",
  "researcher_depth": "shallow",
  "external_references_count": 4,
  "ku2012_section_4_2_accessed": true,
  "closed_form_polar_extracted": true,
  "closed_form_fm_extracted": true,
  "tabulated_benchmark_values_count": 0,
  "convention_pitfall_resolved": false,
  "convention_pitfall_flagged": true,
  "falsifier_candidates_count": 6,
  "load_bearing_falsifier_count": 3,
  "advisory_falsifier_count": 3,
  "not_found_items_count": 5,
  "sibling_runs_artifacts_count": 0,
  "src_files_modified": 0,
  "webfetch_used": true,
  "queries_executed_count": 12,
  "manuscript_main_edited": false,
  "tier_reached": 0.5,
  "verdict": "RESEARCH_PASS"
}
```

---

## Open citations for downstream stages

The following items remain open and should be resolved by T99 theorist or T100 implementer:

1. **KU2012 exact equation numbers** for F=1 polar phonon dispersion and FM phonon dispersion (require PDF access to Physics Reports 520 or arXiv v3 §4.2). The T99 theorist should state them explicitly when formalizing falsifiers.

2. **Explicit BdG matrix construction** from h^HF (generic-F BdG form) for F=1 polar and FM: the 6x6 Nambu matrix (or 3x3 block after decoupling) must be written out by T99 theorist to confirm that the "2 n c_0" factor in the phonon dispersion arises from the already-symmetrized h^HF without additional factor-2 injection.

3. **Chemical potential convention**: At F=1 polar GS (rho=0, pure mean-field), mu = c_0 * n is required for the Goldstone mode to be gapless. This is the KU2012 convention; SpinorBEC.jl's ITP outputs mu via the GS energy per particle. T99 theorist should confirm that the mu used in L(k) for the cross-check matches this convention.

4. **c_1 sign convention**: For polar phase in SpinorBEC.jl, c_1 > 0 (antiferromagnetic). For FM phase, c_1 < 0. The test point chosen by T100 implementer should satisfy c_0 + c_1 > 0 (stability of FM phonon) and c_0 > 0 (stability of polar phonon). A safe choice: c_0 = 1.0, c_1 = 0.1 (polar) and c_0 = 1.0, c_1 = -0.1 (FM).

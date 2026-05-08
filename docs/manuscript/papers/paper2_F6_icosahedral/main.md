# Paper #2: Lee-Huang-Yang correction for the F=6 icosahedral phase of a spinor BEC

**Round-6 integration status**: STUB. Paper #2 source files were not
transferred to `/tmp/manuscript_drafts/round6/` in the Round-6 batch. The
companion thesis chapter `docs/manuscript/thesis/chapters/Ch6_polyhedral_phases_integrated.md`
§6.1–6.5 carries the full F=6 icosahedral derivation in Japanese; the
PRA-style English paper version awaits paste.

## Inputs needed

| Source file (Claude.ai web sandbox) | Role |
|---|---|
| `F6_icosahedral_paper_skeleton.md` | abstract + outline + reference list |
| `F6_icosahedral_paper_sections_II_V.md` | Sec II setup → V mode spectrum |
| `F6_icosahedral_section_VI.md` | Sec VI LHY closed form + selection rule |
| `F6_icosahedral_paper_sections_VII_VIII.md` | Sec VII Eu phase diagram + experimental proposal, Sec VIII conclusion |

## Provisional structure (from companion thesis Ch.6)

The integrated thesis chapter `Ch6_polyhedral_phases_integrated.md` already
contains the equivalent content in the following layout:

| Paper §  | Thesis Ch.6 §  | Content |
|---|---|---|
| I. Introduction | (intro paragraph)             | Spinor BEC review, motivation, our contribution |
| II. F=6 spinor BEC setup | §6.1, §6.2.1 | Hamiltonian, Majorana representation |
| III. Icosahedral spinor | §6.2.2-6.2.4 | $\zeta^{(I_h)}_{F=6}$ explicit form, $C_5$ invariance, symmetry breaking |
| IV. BdG construction | §6.3 | Hartree-Fock + anomalous matrix, $C_5$ selection rules |
| V. Mod-5 block decomposition + mode spectrum | §6.4, §6.5 | 26×26 → 5 blocks, closed-form dispersions |
| VI. LHY closed form | §6.5.5 | $c_0^{5/2} + 3|\lambda_{\rm spin}|^{5/2}$, selection rule |
| VII. Eu phase diagram + experimental proposal | (refers to runs/F6_phase_diagram, Round-3 Task 3 result) | $(g_{10}, g_{12})$ scan, Feshbach engineering |
| VIII. Discussion + conclusion | (refers to companion paper #3 universal theorem) | |

An English-language Letter / full paper conforming to PRA / PRR style can
be assembled by translating the relevant thesis sections and adding the
phase-diagram visualisation from the JSON in `runs/F6_phase_diagram/result.json`.

## Closed-form result (already established)

For the F=6 icosahedral phase with spinor

$$\zeta^{(I_h)}_{F=6} = \frac{1}{5}\left(\sqrt{7}\,|6,+5\rangle + \sqrt{11}\,|6,0\rangle - \sqrt{7}\,|6,-5\rangle\right)$$

the Lee-Huang-Yang correction is

$$\varepsilon_{\rm LHY}^{F=6, I_h} = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3}\,n^{5/2}\,\left[c_0^{5/2} + 3 |\lambda_{\rm spin}|^{5/2}\right]$$

with stiffness coefficients (parallel-session derivation, this work):

$$c_0 = \tfrac{1}{13}g_0 + \tfrac{121}{323}g_6 + \tfrac{147}{391}g_{10} + \tfrac{980}{5681}g_{12}$$

$$\lambda_{\rm spin} = -\tfrac{1}{13}g_0 - \tfrac{121}{646}g_6 + \tfrac{91}{782}g_{10} + \tfrac{840}{5681}g_{12}$$

Selection rule: $g_2, g_4, g_8$ excluded by $I_h$ harmonic decomposition.

The full SpinorBEC.jl implementation lives in
`src/hamiltonian/interactions/icosahedral_lhy.jl` (Round 3 Task 1, 113 unit
tests passing).

## Paste target

```
<!-- TODO-PAPER2-DRAFT-START
Paste the full content of all four Paper #2 source files here in the order:
- F6_icosahedral_paper_skeleton.md (use for abstract + intro + refs)
- F6_icosahedral_paper_sections_II_V.md
- F6_icosahedral_section_VI.md
- F6_icosahedral_paper_sections_VII_VIII.md
TODO-PAPER2-DRAFT-END -->
```

## See also

* `docs/manuscript/thesis/chapters/Ch6_polyhedral_phases_integrated.md` §6.1-6.5
  — full F=6 icosahedral derivation (Japanese, thesis form)
* `docs/manuscript/papers/paper3_universal_theorem/main.md` §V.D — F=6
  case as part of the universal-theorem 6-case verification
* `runs/F6_phase_diagram/result.json` — $(g_{10}, g_{12})$ phase scan data
  for §VII figure
* `src/hamiltonian/interactions/icosahedral_lhy.jl` — implementation
* `test/test_icosahedral_lhy.jl` — 113 unit tests

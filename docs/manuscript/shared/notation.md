# SpinorBEC manuscript notation conventions

Single source of truth for symbols across the three papers and the master
thesis. Refinement-round-1 (2026-05-07): this document seeds the
conventions; deviations found during chapter integration should be
recorded under "Inconsistencies seen in drafts" at the end.

## Atomic / spinor scalars

| Symbol | Meaning | Notes |
|---|---|---|
| `M` | atomic mass | always capital. `m` is reserved for spin projection. |
| `F` | hyperfine spin quantum number | always capital. F=2 cyclic, F=6 icosahedral, etc. |
| `m_F` | spin projection along quantisation axis | use full `m_F` when ambiguity is possible; `m` is acceptable in the body of an F-fixed section. |
| `S` | total spin in symmetric two-body channel | always capital. Even integers 0..2F. |
| `D = 2F + 1` | spinor component count | F=6 → D=13. |
| `N_atoms` | total atom number | always with subscript. Reserve plain `N` for grid points. |

## Coupling constants

| Symbol | Meaning | Definition / units |
|---|---|---|
| `g_S` | s-wave coupling per total-spin channel | `g_S = 4π ℏ² a_S / M`. Always lowercase g, integer S subscript. |
| `c_0`, `c_1`, `c_2`, … | KU 2012 multipole couplings | linear in `g_S` via the standard projection table. **Do not** write `c^{KU}` or `c_n^{(2)}`. |
| `c_total` | dimensionless `4π (a_s / a_ho) N_atoms` | reserved for the SpinorBEC.jl YAML knob; do not use as a symbol in math. |
| `c_dd` | dimensionless DDI coupling | `μ_0 μ²` form (no 4π); see DDI convention note below. |
| `ε_dd` | scalar dipolar parameter | `ε_dd = a_dd / a_s = c_dd / g_2F`. The F² amplification is absorbed inside `c_dd` via `μ²` already; do **not** add a second F² factor. |

## LHY-related symbols

| Symbol | Meaning |
|---|---|
| `c_0` | phonon stiffness (= μ/n in homogeneous limit) |
| `λ_spin` | universal-theorem spin-Goldstone stiffness (sign carried; LHY uses the magnitude). |
| `λ_z`, `λ_⊥` | axial / transverse spin-Goldstone stiffnesses (when both Goldstones are not degenerate, i.e. uniaxial cases). |
| `φ₁^reg(t)` | Petrov-regularised universal LHY function. `φ₁^reg(0) = 1` exactly. Subscript 1 is part of the symbol. |
| `Q_5(ε_dd)` | Lima-Pelster angular average; `Q_5(0) = 1` exactly. |
| `LHY prefactor` | `8 √M³ / (15 π² ℏ³)` — write all three of M, π, ℏ explicitly, do **not** absorb into a constant. |
| `β_S^{(c_0)}` | rational coefficient of `g_S` in `c_0`, i.e. `c_0 = Σ_S β_S^{(c_0)} g_S`. Equal to `|⟨S,M|ζ⊗ζ⟩|²` for an A_1 polyhedral inert state at the appropriate M, summed over M. Always ≥ 0. |
| `β_S^{(λ_spin)}` | rational coefficient of `g_S` in `λ_spin`. Sign can be + or −. |
| `X_S^{(anom)}` | anomalous overlap `Re Σ_M ⟨S,M|F_a ζ_n ⊗ F_a ζ_n⟩ ⟨ζ⊗ζ|S,M⟩^*`, where `ζ_n = F_a ζ / ‖F_a ζ‖` is the normalized F_a action. |
| `S_bd(F)` | sign-change boundary of `β_S^{(λ_spin)}`. By Lemma 1 General-S: `S_bd = (−1 + √(1 + 8F(F+1)))/2 ≈ √2 F` (NOT 2F as earlier empirical claim). |

## Sign Pattern Anomalous Identity (paper3 §IX.B, Lemma 1+2)

The central structural identity for polyhedral inert (A_1 irrep) states:

```
β_S^{(λ_spin)} = (S(S+1) − 2F(F+1)) / (2F(F+1)) · β_S^{(c_0)}
```

**Verified at 26 channel coefficients across 5 cases** (F=3 octa A_2, F=4 cube,
F=6 icosa, F=8 cube-octa A_1, F=10 dodec I_h) at exact rational arithmetic.

**Lemma 1 endpoint** (rigorously proved):
```
β_0^{(λ_spin)} = −1/(2F+1)
```
via singlet annihilation `F^tot |0,0⟩ = 0` + polyhedral Schur isotropy
`‖F_a ζ‖² = F(F+1)/3`.

**Lemma 2 (unique sign change)** (proved as corollary of Lemma 1 General-S):
`β_S^{(λ_spin)}` changes sign exactly once at `S = S_bd`.

See `docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md`
and `sign_pattern_L2_unique_sign_change.md` for full derivations.

## Energy / density formulas

The contact LHY closed form for any spinor phase factorises as

```
ε_LHY(n) = (8 √M³ / (15 π² ℏ³)) · n^(5/2) · Σ_blocks ν_block · κ_block^(5/2)
```

where the sum runs over BdG blocks with stiffness `κ_block` and
multiplicity `ν_block` (1 for the phonon, 1–3 for spin Goldstones
depending on the broken-symmetry pattern).

For an icosahedral F=6 ground state:

```
ε_LHY^{F=6, I_h}(n) = (8 √M³ / (15 π² ℏ³)) · n^(5/2)
                       · ( c_0^(5/2) + 3 |λ_spin|^(5/2) )
```

(1 phonon + 3 spin Goldstones; see `docs/theory/icosahedral_lhy.md`).

## DDI conventions (do not "fix")

* `c_dd = μ_0 μ²` — no 4π. The Q-tensor is `Q_αβ(k̂) = k̂_α k̂_β − δ_αβ/3`,
  no 1/(4π). `Q(k=0) = 0`. This chain is internally self-consistent;
  matches Lima-Pelster.
* `ε_dd = a_dd / a_s` — standard scalar definition. Earlier draft notes
  using `ε_dd^F = F² · c_dd / g_{2F}` were F²-double-counted (the F²
  amplification is in `μ² = (g_F · F · μ_B)²` which is already inside
  `c_dd`). All Round 2+ work uses the standard form.

## Bra-ket and operator conventions

* States: `|ψ⟩`, `|ζ⟩`. Inner product: `⟨ζ|ζ⟩ = 1`. Use the LaTeX
  `\langle`/`\rangle` (not `<`/`>`).
* Spin operators: `F̂_x`, `F̂_y`, `F̂_z` with hats in math display, but
  plain `F_α` is acceptable in inline expressions when context makes
  the operator nature clear.
* Vectors: bold (`\bm{F}`) **or** arrow (`\vec F`) — pick one per
  paper. Within a paper, do not mix. Across papers, the choice is
  per-target convention (PRA prefers bold, some PRD use arrow).
* Wave-function components: `ψ_m` (no hat — c-number).

## Indexing conventions

* Component order convention (used throughout SpinorBEC.jl source):
  index 1 = m=+F, index `D` = m=−F. So for F=6: `ζ[1] ↔ m=+6`,
  `ζ[7] ↔ m=0`, `ζ[13] ↔ m=−6`. **Important** for cross-checking
  numerical formulas against analytic ones.
* Two-body symmetric tensor product: ordered S = 0, 2, 4, …, 2F (even
  only by Bose statistics).
* BdG blocks under polyhedral symmetry: labelled by the discrete
  rotation eigenvalue (e.g. mod 5 for I_h, mod 3 for T_d), then by
  parity within each block.

## TWA / numerical conventions

| Symbol | Meaning |
|---|---|
| `ξ` | healing length, `ξ = ℏ / √(2 M g n)` (single-particle coupling g). |
| `k_cut` | momentum cutoff for vacuum-noise injection. Default `k_cut = 2/ξ`. |
| `cutoff_energy` | YAML knob for `add_vacuum_noise`. `E_cut = ℏ² k_cut² / (2 M)`. |
| `N_modes_eff` | count of plane-wave modes per spinor component below `cutoff_energy`. |
| `Sinatra ratio` | `N_modes_eff × D / N_atoms`. ≪ 1 is required. |

## Inconsistencies seen in drafts

To be filled in during chapter integration. Format:

* [DOC]: [section / equation reference] — [symbol used] vs [convention] —
  [proposed fix].

(no entries yet — chapter integration deferred until source files arrive)

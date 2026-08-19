# What "Klaus" names in this tree

LIVE. Gated by `test/validation/test_klaus_name_disambiguation.jl`.

One word was doing three jobs, and the thesis cannot be written until a reader
can tell which one is meant in any given sentence. This page is the authority;
`CLAUDE.md`, `docs/index.md` and the type-C registry defer to it.

## The three referents

| Referent | Canonical name in this tree | What it is | Thesis role |
|---|---|---|---|
| ① the paper | **Klaus et al. 2022** (`arXiv:2206.12265`) | published experiment | **prior art** — cite it |
| ② the numerical regime | **fast-Larmor regime** | `p·F·dt > π` at trap-scale `dt` | a solver constraint, not a result |
| ③ our protocol | **rotation-assisted EdH quench** (trap-rotation / field-rotation branch) | this project's own Eu design | **the thesis body** |

They are independent: ① is a Dy experiment that happens to sit in ②, ③ is an Eu
proposal that also sits in ② and was *not* proposed by ①.

## ① Klaus et al. 2022 — the paper

> L. Klaus, T. Bland, E. Poli, C. Politi, G. Lamporesi, E. Casotti,
> R. N. Bisset, M. J. Mark, F. Ferlaino, *"Observation of vortices and vortex
> stripes in a dipolar Bose-Einstein condensate"*, **Nat. Phys. 18, 1453
> (2022)**, `arXiv:2206.12265`, doi:`10.1038/s41567-022-01793-8`.

A ¹⁶²Dy BEC with the bias field tilted and rotated near the radial trap
frequency; the surface instability injects angular momentum and the resulting
vortices order into stripes along B̂. "Klaus et al." and "a Ferlaino-group
Innsbruck paper" are **both true of this same paper** — Klaus is the first
author, Ferlaino is the group. They are not alternatives.

**Write it as `Klaus et al. 2022 [arXiv:2206.12265]`.** The tree previously
carried a second name for it, "Dy Innsbruck 2022", in three `src/` comments;
those were migrated 2026-08-19 so that one paper has one name.

**Its regime is ②, and that is why the spinor solver is the wrong tool for it**
— ω_L there is ~10⁷ × the trap scale, so the spin adiabatically follows B̂(t)
and the paper's own theory is a scalar eGPE with a B̂(t)-tilted DDI kernel. See
`memory/reference_klaus_adiabatic_elimination.md` for the measured ratios.

### The retracted denial

A 2026-06-02 "attribution correction" asserted that **no such paper exists** and
that "no author named Klaus published on dipolar BEC magnetostir in 2022". Both
sentences are false and were retracted 2026-08-19 (issue #344) in the two places
that carried them:
`docs/archive/klaus_quench_protocol_pivot_2026-05-26.md` and
`memory/reference_klaus_adiabatic_elimination.md`.

What genuinely needed correcting was the attribution of ③ — the two-phase Eu
quench protocol was described as if Klaus et al. had proposed it, and they did
not. The correction overshot from "they did not propose this protocol" to "they
do not exist". The archive document then carried the denial **eight lines above
a citation to the same arXiv number**, contradicting itself, and the live tree
went on citing the paper correctly — so a future session reading the archive
would have deleted a correct citation as confabulation.

The lesson is narrower than "verify citations": **a correction has a scope, and
retracting more than was wrong is itself a new false claim.** Retract exactly
the sentence that was wrong.

## ② fast-Larmor regime — the numerical regime

**Definition, one line:** the fast-Larmor regime is where the linear Zeeman
term alone would over-rotate a trap-scale timestep, `p · F · dt > π`, so the
lab-frame split-step cannot be run at `dt` set by the trap.

It is a property of `(atom, field, dt)` and nothing else. ¹⁵¹Eu at 1 G gives
`p ≈ 26 700`; ¹⁶⁴Dy at 1 G gives `p ≈ 28 400`; both are in it. **It does not
need a paper's name**, and under the repo's "name by content" convention it no
longer has one: `docs/guides/klaus_regime.md` was renamed to
`docs/guides/fast_larmor_regime.md` on 2026-08-19. Klaus et al. 2022 is *an
experiment in* this regime, not the regime.

The escape is `kind: rotating_basis` — solve in the instantaneous `|m⟩_{B̂(t)}`
frame so the Larmor phase is static. Full guide: `docs/guides/fast_larmor_regime.md`.

## ③ rotation-assisted EdH quench — our protocol

**This project's own design. No published paper proposed it.** A two-phase Eu
F=6 protocol: prepare a stretched state at strong B, quench to `B_hold ∈
[1, 5] nT` where the DDI spin-flip channels open, and rotate during the
weak-field hold. The load-bearing observable is post-quench `m = −5, −4`
excitation, not bare `⟨F_z⟩`.

Two branches, **named by what rotates**:

| Branch | Retired label | What rotates | How it enters | Where |
|---|---|---|---|---|
| **trap-rotation branch** | ~~Klaus-I~~ | the anisotropic trap, mechanically | `−Ω·L_z` Coriolis term (`rotating_frame_omega`); B̂ and the DDI kernel static | `runs/klaus_quench/`, `runs/klaus_quench_long_time/` |
| **field-rotation branch** | ~~Klaus-II~~ | the field direction B̂ | rotating DDI anisotropy axis (`B: {theta, phi: {rate: Ω}}`); trap static | `runs/magnetic_stirrer/`, `runs/klaus_hybrid/` |

They are different physics and gave different answers: the trap-rotation branch
enhances `P_{-5,-4}` 0.22 → 0.54, the field-rotation branch was **null** at
`B_hold = 2.6 nT` because ω_L ~ Ω there and the spin does not adiabatically
follow the rotating B̂. Record: `docs/manuscript/klaus_quench_protocol_spec_2026_05_26.md`
(FROZEN, and its numbers predate the 2026-07-29 field-sign revert `bce2068f`).

### Why `runs/` was not renamed

`runs/klaus_quench/`, `runs/eu151_klaus_*`, `runs/klaus_baseline`,
`runs/klaus_hybrid` and `runs/phi_omega_scan` keep their names, and the
`Klaus-I` / `Klaus-II` strings inside those YAML comments were left alone. This
is deliberate, for two reasons, not an oversight:

1. **`run_yaml` keys its output directory on the raw bytes of the YAML file**
   (`compute_run_dir`, CLAUDE.md architectural commitment 4). Editing a comment
   changes the content id, orphans every cached `point_*.jld2` under that
   directory and silently invalidates results that cost GPU-hours.
2. `docs/validation/config_prose_harvest.toml` and
   `config_metadata_blocks.toml` are **verbatim records of what those configs
   said**, pinned by `test/validation/test_config_prose_harvest.jl`. Rewriting
   the record to match a later rename would defeat what the record is for.

So the retired labels survive in exactly those two places, and the gate below
allowlists them by name rather than by pattern. If a `runs/` directory is ever
regenerated from scratch, name it for the branch.

## Writing rule for the thesis

- ① is always **"Klaus et al. 2022"** with the arXiv number on first use, and
  appears only as prior art / a comparison target.
- ② is always **"fast-Larmor regime"**. Never "the Klaus regime".
- ③ is always **"rotation-assisted EdH quench"**, with the branch named when it
  matters. Never "the Klaus protocol", and never bare "Klaus".

A sentence containing bare "Klaus" with no "et al. 2022" after it is
ambiguous by construction; that is the failure this page exists to end.

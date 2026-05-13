# TWA ε_dd species scan — dipolar collapse universality

**Status**: 4 ensembles complete 2026-05-07 (16:00–17:56), runtime ~125 min on RTX 5070 Ti. Eu (ε_dd = 0.55) used as natural baseline; the other three sweep `c_dd` to mimic Cr / Er / Dy at the same Eu N=10⁴ trap geometry. **Code path**: `runs/{Cr,Eu,Er,Dy}_eps*_<hash>/result.jld2`, analysed by `scripts/twa/twa_eps_dd_scan_analyze.jl`.

## σ/μ interpretation note

σ/μ in this regime measures chaotic trajectory divergence in the dipolar instability (different seeds → different filament orientations), not Wigner noise amplitude. The species *trend* (peak at marginal Eu) is chaos-onset and survives — see `docs/theory/sinatra_criterion_F6.md` "Caveat" + `twa_pinned_16g_result.md` for the corrected reading.

## Per-species results

All ensembles use the Eu EdH trap geometry (32³, ω_z/ω_⊥ = 1.182, N=10⁴), varying only `c_dd` to set ε_dd = a_dd / a_s.

| Species | ε_dd | n_traj | peak n | FWHM (x, z) | z/x | on-axis | σ/μ peak | regime |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Cr     | 0.15 | 50 | 0.182 | (2, 4)  | 2  | **0.998** | 0.001 | sub-collapse, near-Gaussian |
| Eu     | 0.55 | 50 | 0.094 | (1, 6)  | 6  | 0.416 | 0.423 | marginal collapse, partial smearing |
| Er     | 0.88 | 50 | 0.101 | (1, 10) | 10 | 0.041 | 0.127 | strong z-elongation, deep on-axis hole |
| Dy     | 1.39 | 50 | 0.099 | (1, 1)  | 1  | 0.025 | 0.049 | super-collapse / pinpoint |

## Findings

### Finding 1 — z-elongation grows monotonically with ε_dd (until collapse blow-up)

| ε_dd | FWHM_z / FWHM_x | physical regime |
|---:|---:|---|
| 0.15 | 2  | weak DDI, mostly trap-shape |
| 0.55 | 6  | dipolar instability onset (Eu marginal) |
| 0.88 | 10 | strong z-elongation (filament fully formed) |
| 1.39 | 1  | catastrophic, single-cell pinpoint (cloud has fragmented or collapsed below grid resolution) |

The Cr → Eu → Er progression shows the **filament forming as ε_dd crosses ~0.5**: at ε_dd = 0.15 the cloud is essentially radially symmetric; by ε_dd = 0.88 the cloud is 10× longer in z than x. This is the canonical dipolar collapse onset at fixed N.

The Dy point (ε_dd = 1.39) is qualitatively different — `FWHM_z = 1` cell at peak density 0.099 means the density is concentrated below the grid resolution. This is the super-collapse regime where the simulator can't resolve the dynamics on a 32³ box; the result is effectively unphysical and indicates a numerical instability rather than a steady-state droplet.

### Finding 2 — σ/μ at peak peaks at the marginal ε_dd

| ε_dd | σ/μ peak |
|---:|---:|
| 0.15 (Cr) | 0.001 |
| **0.55 (Eu)** | **0.423** ← maximum |
| 0.88 (Er) | 0.127 |
| 1.39 (Dy) | 0.049 |

This mirrors **Finding B from the N scan** (`twa_N_scan_result.md`): trajectory-level fluctuation visibility is maximal at the dipolar instability boundary, dropping at both the sub-critical (smooth GS, no fluctuation) and super-critical (chaotic blow-up, ensemble mean meaningless) ends. **Caveat**: the absolute σ/μ values in this column include classical thermalisation contamination (see top-of-page caveat); the *trend* (peak at marginal) is robust because all four runs share the same 32³ × F=6 = 425k-mode contamination level.

### Finding 3 — on-axis ratio decreases monotonically with ε_dd

| ε_dd | on-axis | interpretation |
|---:|---:|---|
| 0.15 | 0.998 | no on-axis hole — cloud is single-peaked Gaussian |
| 0.55 | 0.416 | partial smearing — z-elongation forms but not deep |
| 0.88 | 0.041 | deep on-axis hole — full dipolar instability |
| 1.39 | 0.025 | extreme — peak is far from origin, cloud is delocalised |

Across the three physical regimes (Cr / Eu / Er), the on-axis ratio shows clean monotonic decrease — stronger dipolar coupling drives the cloud's density off-axis (radially out, into the z-elongated filament). Eu sits exactly at the half-decade transition.

## Species universality vs Sinatra contamination

The original framing — "species universality of dipolar collapse smearing under quantum noise" — was confounded by the Sinatra issue. Two layers of information are mixed in this scan:

* **Mean-field dipolar physics (clean signal)**: peak n, FWHM(x,z), and on-axis ratio all reflect the deterministic GS trends with c_dd. These are robust and match the literature picture (Lima-Pelster scalar dipolar phenomenology applied at each ε_dd).
* **Quantum-fluctuation visibility (contaminated)**: σ/μ values mix genuine quantum noise (which scales 1/√N at fixed physics) with classical thermalisation noise (which scales with mode count).

A **Sinatra-clean re-run at 16³** for the same four ε_dd values would disambiguate. Each 16³ ensemble takes ~5 min, so total ~20 min GPU. Recommended as next step.

## Recommended Feshbach-engineering targets (from Round-3 sign pattern)

The Round-3 Task 1 / Round-5 sign-pattern systematic (see `docs/research_notes/F6_phase_boundaries.md` and the manuscript Paper #3 §IX.B) predicts that polyhedral-phase realisation requires high-rank $g_S$ enhancement at $S \sim 2F$. For the species in this scan:

* **Cr (F=3)**: $g_6$ Feshbach resonances → unlocks F=3 octahedral phase
* **Eu (F=6)**: $g_{10}, g_{12}$ Feshbach resonances → unlocks F=6 I_h
* **Er (F=6)**: same as Eu (Er natural a_s gives ε_dd ≈ 0.88, closer to droplet boundary than Eu)
* **Dy (F=8)**: $g_{12}, g_{14}, g_{16}$ Feshbach resonances → unlocks F=8 cube-like octahedral phase

These predictions are independent of the Sinatra contamination above — they come from the closed-form polyhedral $\lambda_{\rm spin}$ analysis, not from TWA.

## Reproduction

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    scripts/twa/twa_eps_dd_scan.jl
julia --project=. scripts/twa/twa_eps_dd_scan_analyze.jl
```

The analyzer was updated 2026-05-08 to use a hash-suffix glob resolver (`runs/<label>_*/result.jld2`) matching the actual `run_yaml` output layout — same fix as the N-scan analyzer in `6b29e5c`.

## See also

* `docs/research_notes/twa_sinatra_validation.md` — companion Sinatra check that flags the σ/μ contamination
* `docs/research_notes/twa_N_scan_result.md` — orthogonal coupling-N scan (Finding B = σ/μ peaks at marginal collapse holds in both scans)
* `docs/research_notes/eu_collapse_lhy_insufficient.md` — establishes the marginal Eu collapse picture
* `docs/research_notes/F6_phase_boundaries.md` — Round-3 Task 3 phase diagram complementing this species scan

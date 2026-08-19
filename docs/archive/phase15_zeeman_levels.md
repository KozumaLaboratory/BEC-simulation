# Phase 1.5: Zeeman-level dispatch design

> **FROZEN 2026-04-23.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Author: anko (assisted by Claude Opus 4.7) Status: Draft — pre-implementation decision record Date: 2026-04-23

## Motivation

Experimental papers (Klaus et al. 2022, EdH matsui 2025, etc.) specify magnetic fields as **vectors in Gauss** or **(magnitude, direction)** tuples, not as the dimensionless (p, q, bx, by) quadruple used internally by `split_step.jl`. Writing experimental YAML directly in (p, q, bx, by) requires manual unit conversion and is error-prone.

Phase 1.5 adds a **schema-level dispatch** in the YAML parser so users can write B-fields at the abstraction they prefer. No runtime cost — all conversion happens at parse time.

## Levels

### Level 0 (existing, kept)

Direct dimensionless specification. Already supported in Phase 0/1.

```yaml
zeeman:
  p: 100.0                                 # or {linear: {from, to}}
  q: 0.5
  bx: {sinusoidal: {amplitude: 1.0, frequency: 226.0}}
  by: null
```

`p = g_F μ_B B_z / (ℏω_ref)` in user's head. Suitable for physics-level testing where dimensionless params are natural (e.g. scan c₁/c₀ ratios).

### Level 1 (new)

B vector in Gauss. Supports scalar or Waveform per axis.

```yaml
zeeman:
  level: 1                                 # explicit; inferred if Bx/By/Bz present
  Bz: 1.0                                  # Gauss
  Bx: {linear: {from: 0, to: 0.574}}       # Gauss, ramp
  By: 0
  omega_ref_hz: 50                         # trap ω_ref for dimensionless-isation; inherited if omitted
```

Conversion: `p(t) = g_F · μ_B · Bz(t) / (ℏ · 2π · omega_ref_hz)`, likewise bx, by. `q` = second-order Zeeman; set to 0 by default, user can override with `q:` at this level if needed.

**Dispatch rule**: if any of `Bx, By, Bz` present → Level 1. Mixing with p/q/bx/by raises an error.

### Level 2 (new)

B magnitude + spherical angles. Useful for tilt/stirring where direction varies.

```yaml
zeeman:
  level: 2
  B_mag: 0.819                             # Gauss (scalar or Waveform)
  theta_deg: {linear: {from: 0, to: 35}}   # polar from z-axis (ramp → tilt)
  phi_deg: 0                               # azimuthal
  omega_ref_hz: 50
```

Internally: `B_vec(t) = (B_mag(t) · sin(θ) · cos(φ), B_mag(t) · sin(θ) · sin(φ), B_mag(t) · cos(θ))`, then Level 1 conversion.

**Dispatch rule**: if `B_mag` present → Level 2. Mixing with Level 0 / Level 1 keys raises an error.

### Level 3 (deferred to Phase 5)

Coil-based: compute B from coil geometry + currents. Experimental-integration layer concern.

## Waveform handling

All time-dep specs (ramps, sinusoidals, PWL) are **sampled and stored as `PiecewiseLinearWaveform`** after conversion, not as closures.

Rationale: `FunctionWaveform(t -> B_to_p(Bz(t), ...))` would create a unique closure type per call site, contaminating `make_workspace`'s 23-param inference via abstract `PipelineStep` dispatch. The same pitfall we just caught in pulse_sequence (see `CLAUDE.md > Type stability boundaries`). Sampling to 1024 points gives negligible error for magnetostir ramps (ms-scale on 1-second windows).

**Implementation**: reuse `_build_windowed_waveform` sampler from `pulse_sequence.jl`, or a leaner variant without windowing.

## Parser dispatch

Single entry point extends `_build_phase_zeeman`:

```julia
function _build_phase_zeeman(phase_raw, t_offset, duration; atom=nothing, omega_ref=nothing)
    z = get(ground_state(phase_raw), "zeeman", Dict())
    level = _detect_zeeman_level(z)     # 0, 1, or 2 based on keys
    if level == 0
        _build_zeeman_level0(z, t_offset, duration)
    elseif level == 1
        _build_zeeman_level1(z, t_offset, duration, atom, omega_ref)
    else
        _build_zeeman_level2(z, t_offset, duration, atom, omega_ref)
    end
end
```

`_build_zeeman_level1/level2` always return `TimeDependentZeeman` (not `ZeemanParams`) because the conversion produces Waveforms even for static inputs — consistent, cheap, uniform downstream handling.

## omega_ref resolution

Currently `omega_ref` lives in `interactions.omega_ref` (Hz) for dimensionless conversion of interactions. Level 1/2 needs the same for Zeeman.

Rule: inherited from step's `interactions.omega_ref` if available, else from top-level config, else from trap's lowest frequency (last resort, warns). Explicit `zeeman.omega_ref_hz` overrides all.

## Tests (`test/test_zeeman_levels.jl`, ~100 lines)

1. Level 1 static matches Level 0 static after manual conversion (within 1e-10).
2. Level 1 with `Bx` linear ramp → bx_wf samples match analytic `p(t)` (within 1%).
3. Level 2 theta ramp at fixed B_mag, phi=0: `Bx = B_mag · sin(θ)`, `Bz = B_mag · cos(θ)` — verify vector matches.
4. Mixing Level 0 and Level 1 raises `ArgumentError` with clear message.
5. Klaus et al. 2022-like fragment (tilt ramp in theta, simultaneous B_mag) round-trips through run_pipeline without JIT regression (< 10 min via existing JIT guard).

## Estimated scope

- Converter functions (`_B_to_p`, `_vec_to_level0`, sampling helpers): ~80 lines
- Level 1/2 parsers: ~100 lines
- Schema updates (`GS_SCHEMA`, `DYNAMICS_SCHEMA`) for Bx/By/Bz/B_mag/theta_deg/phi_deg: ~30 lines
- Tests: ~100 lines
- Total: ~310 lines, target < 400 per file (within `CLAUDE.md` limit)

## Klaus et al. 2022 YAML preview (Level 2)

```yaml
pipeline:
  - ground_state:
      atom: Dy164
      grid: {n: [64, 64, 32], box: [24.0, 24.0, 8.0]}
      trap: [0.385, 0.385, 1.0]            # ω_ρ = 2π·50 Hz, ω_z = 2π·130 Hz in ω_ref=2π·50 units
      interactions: {a_s: 90.0, omega_ref: 50.0, N_atoms: 60000}
      zeeman:
        level: 2
        B_mag: 1.0                          # Gauss (z-aligned via theta_deg=0)
        theta_deg: 0
      n_steps: 5000
      tol: 1.0e-8

  - dynamics:                                # 20 ms tilt ramp
      duration: 0.020
      zeeman:
        level: 2
        B_mag: {linear: {from: 1.0, to: 1.0}}
        theta_deg: {linear: {from: 0, to: 35}}

  - dynamics:                                # 50 ms spin-up (ramp stir freq 0→226 Hz)
      duration: 0.050
      zeeman:
        level: 1
        Bz: 0.819
        Bx: {sinusoidal: {amplitude: 0.574, frequency_ramp: {from: 0, to: 226}}}
        By: {sinusoidal: {amplitude: 0.574, frequency_ramp: {from: 0, to: 226}, phase: -1.5708}}

  - dynamics:                                # 1 s continuous magnetostirring
      duration: 1.0
      save_every: 100
      zeeman:
        level: 1
        Bz: 0.819
        Bx: {sinusoidal: {amplitude: 0.574, frequency: 226}}
        By: {sinusoidal: {amplitude: 0.574, frequency: 226, phase: -1.5708}}

  - analyze:
      - column_density: {axis: 3, save_all: true}
      - vortex_detect: {method: phase_winding}
```

Note: `frequency_ramp` inside `sinusoidal` is a new Phase 1.5 sub-spec (frequency as Waveform). If not implemented this phase, fall back to stepping the 50 ms spin-up into ~10 phases with constant frequency each.

## Open decisions

- [ ] Whether to accept shorthand `B: [Bx, By, Bz]` (3-vector) at Level 1 (could be nice). Deferred — explicit keys better for ramps.
- [ ] Whether `q` conversion from B² (second-order Zeeman) should be auto-derived. For alkali/Dy it's hyperfine-dependent; leaving to user is safer.
- [ ] Unit for `omega_ref_hz`: Hz vs angular Hz. Convention: **linear Hz**, multiplied by 2π internally (matches interactions.omega_ref existing convention).

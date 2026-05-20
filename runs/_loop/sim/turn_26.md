---
turn: 26
subagent: implementer
topic_tags: [gamma-dr-routing, loss-params, kind-spinor, yaml-parsing, audit-existing, barnett-spin]
paper_section: null
depends_on: [director_turn_26_dispatch]
produces: "runs/_loop/sim/turn_26.md (read-only audit; no code changes, no branch)"
---

# Turn 26 — Implementer Report (analyze_existing)

## 1. Directive received

```json
{
  "action": "analyze_existing",
  "label": "gamma-dr-routing-audit-kind-spinor",
  "context": "Director T26 dispatch. T25 critic identified a 1700× production-vs-empirical gap...",
  "scope": "READ-ONLY code audit. No julia execution. No file modifications.",
  "audit_questions": {
    "Q1": "At every code location where gamma_dr appears, list file:line + arithmetic operation.",
    "Q2": "Which loss-step function is called for kind:spinor? Dispatch chain.",
    "Q3": "Is apply_loss_step! called once or twice per step (Strang sandwich)?",
    "Q4": "Does the loss parameter reach apply_loss_step! with the same 0.02 value?",
    "Q5": "Are there OTHER loss-related YAML keys that might compete with gamma_dr?",
    "Q6": "Sanity-recompute the 1700× gap."
  },
  "constraints": {"no_julia": true, "no_code_edits": true, "no_subagent_dispatch": true}
}
```

No theorist turn_26.md exists; directive was passed inline by the director.

---

## 2. Branch / commit

This is a read-only `analyze_existing` action. No branch was created, no commit made.

- Parent HEAD: `aa9f509`
- Files modified: none

---

## 3. Commands executed

No julia, no shell, no git. All findings are from static code reads.

Files read (in order):
1. `runs/eu151_barnett_spin/config.yaml` (lines 1-102)
2. `src/workflow/experiments/schema/parsing_blocks.jl` (lines 60-162)
3. `src/foundation/types/ddi_loss.jl` (lines 1-125)
4. `src/workflow/initialization/make_workspace.jl` (lines 1-50, 280-310; grep)
5. `src/workflow/experiments/pipeline/run_step_dynamics.jl` (full)
6. `src/workflow/experiments/pipeline/runner.jl` (lines 1-175, 183-240)
7. `src/workflow/experiments/schema/templates_block.jl` (lines 79-146)
8. `src/workflow/experiments/pipeline/pipeline_dispatch.jl` (full)
9. `src/hamiltonian/integrator/split_step.jl` (lines 1-80, 340-390, 600-650; grep)
10. `src/solvers/simulation/entry.jl` (full)
11. `src/solvers/simulation/run_loops.jl` (full)
12. `src/hamiltonian/interactions/losses.jl` (full)
13. `src/rotating_basis/integrators.jl` (grep for gamma_dr/apply_loss_step)
14. `src/rotating_basis/workspace.jl` (grep)
15. `src/precompile.jl` (grep)
16. `runs/_loop/judge/turn_25_critic_audit.md` (full — T25 critic reference)
17. Memory file: `gotcha_K3_routing_pre_2026_05_13.md`

---

## 4. Metrics

```json
{
  "experiment_kind": "modify_only",
  "norm_initial": null,
  "norm_final": null,
  "norm_drift": null,
  "energy_initial": null,
  "energy_final": null,
  "energy_monotonic": null,
  "mz_target": null,
  "mz_final": null,
  "fitted_order": null,
  "fit_dt_range": null,
  "fit_r_squared": null,
  "wall_time_sec": 0.0,
  "peak_memory_gb": null,
  "tests_passed": null,
  "tokens_used": {
    "theorist": null,
    "researcher": null,
    "implementer": null,
    "critic": null,
    "orchestrator": 10109837,
    "total": 10109837,
    "effective_full_rate": 1510723,
    "breakdown": {
      "input_fresh": 6053,
      "cache_creation": 355701,
      "cache_read": 9730688,
      "output": 17395
    },
    "n_messages": 106,
    "n_message_starts": 106
  },
  "warnings": [],
  "physical_red_flags": [
    "gamma_dr=0.02 in YAML arrives intact at apply_loss_step! kernel with no dimensional rescaling; confirmed CLEAN propagation",
    "kind:spinor loss is applied ONCE per step (not Strang sandwich) with full dt, but kernel divides by 2 internally \u2014 effective rate is exp(-gamma*n*dt) on density, matching the continuous-time equation",
    "rotating_basis path correctly uses TWO calls at dt/2 each (true Strang sandwich); spinor path uses ONE call at dt (kernel /2) \u2014 both net to exp(-gamma*n*dt) per step, but the two paths use different dt-argument conventions which is an ADVISORY source of confusion if gamma_dr values are compared across path types",
    "1700x gap between predicted tau~4900 and empirical tau=2.84 is CONFIRMED by this audit; it is NOT explained by a routing bug in the gamma_dr chain \u2014 the code applies exactly 0.02 at the density-weighted rate per the docstring"
  ],
  "falsification_result": "CONFIRMED"
}
```

---

## §0 Scope

This is a read-only static audit of the YAML → LossParams → make_workspace → split_step →
apply_loss_step! chain for `kind: spinor` dynamics, focused on whether `gamma_dr = 0.02`
from `runs/eu151_barnett_spin/config.yaml` undergoes any hidden rescaling, re-routing, or
mis-application that could explain the 1700× gap between the predicted τ_Barnett ≈ 4900 ω⁻¹
and the empirical τ = 2.84 ω⁻¹ observed in T20. No julia was executed. No files were
modified. The K3 routing precedent (gotcha_K3_routing_pre_2026_05_13.md) was used as the
reference bug-class.

---

## §1 File-by-file trace (Q1)

Every location where `gamma_dr` appears in production code, with the arithmetic applied:

### 1.1 `src/workflow/experiments/schema/parsing_blocks.jl` line 105

```julia
gamma_dr = Float64(get(node, "gamma_dr", 0.0))
```

**Arithmetic:** pure Float64 cast from YAML scalar. No multiplication, no division.
- Input: `node["gamma_dr"] = 0.02` (from YAML)
- Output: `Float64(0.02) = 0.02`
- Passed to: `LossParams(; gamma_dr, ...)` keyword constructor

### 1.2 `src/foundation/types/ddi_loss.jl` lines 95, 107-121

```julia
struct LossParams
    gamma_dr::Float64   # line 95: stored as plain Float64
    ...
end
LossParams(gamma_dr::Float64) = LossParams(gamma_dr, 0.0, ...)   # line 107
function LossParams(; gamma_dr::Real=0.0, ...) = LossParams(Float64(gamma_dr), ...)  # line 121
```

**Arithmetic:** identity storage. `gamma_dr` is stored exactly as parsed with no
transformation. The `Float64()` cast in the keyword constructor is identity for values
that are already Float64.

### 1.3 `src/workflow/initialization/make_workspace.jl` line 23, 297

```julia
loss::Union{Nothing, LossParams}=nothing,   # line 23: kwarg, passed through
...
loss,   # line 297: stored in Workspace.loss unchanged
```

**Arithmetic:** none. `loss` is passed by reference from the parsing result directly
into the Workspace struct. No field is extracted or rescaled.

### 1.4 `src/hamiltonian/interactions/losses.jl` lines 98, 153-155

```julia
gamma_rates = _dipolar_relaxation_rates(F, loss.gamma_dr)  # line 98

function _dipolar_relaxation_rates(F::Int, gamma_dr::Float64)  # line 153
    shape = _dipolar_relaxation_shape(F)
    [gamma_dr * s for s in shape]  # line 155
end
```

**Arithmetic:** `gamma_rates[c] = gamma_dr × shape[c]` where `shape[c]` is the
normalized CG-squared sum for component c. For F=6, `shape[1]` (m=+F=+6) = 13/14 ≈ 0.9286
(confirmed by T25 critic Audit-3 via explicit CG computation).

- Input: `loss.gamma_dr = 0.02`, `F = 6`
- `gamma_rates[1] (m=+F) = 0.02 × 0.9286 = 0.018572`

No rescaling by N_atoms, omega_ref, n0, c0, or any dimensional factor.

### 1.5 `src/hamiltonian/interactions/losses.jl` lines 103, 107-113

```julia
L3_c = isempty(loss.L3_per_m) ? loss.L3 : loss.L3_per_m[c]   # line 101
K3_c = isempty(loss.K3_per_m_cubic) ? loss.K3_cubic : loss.K3_per_m_cubic[c]  # line 102
gamma_lin_rate = gamma_rates[c] + L3_c  # line 103

@. psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)  # line 109
```

**Arithmetic (for `kind:spinor`, Phase 2):**
- `L3_c = 0.0` (no `L3` or `L3_per_m` in YAML)
- `gamma_lin_rate = 0.02 × shape[c] + 0.0 = 0.02 × shape[c]`
- Applied: `ψ_c *= exp(-0.02 × shape[c] × n_total × dt / 2)`

**No hidden factor.** The only multiplication is the CG-shape normalization (which is
physics, not a bug) and the explicit `/2` in the kernel exponent.

### 1.6 `src/precompile.jl` lines 72, 75, 81

Precompile exercises `LossParams(; gamma_dr=0.0, ...)` and `_parse_loss_params(Dict("gamma_dr" => 0.02, ...))`.
No arithmetic — pure type-warming.

**Summary of Q1:** There are exactly 6 code locations touching `gamma_dr`. At every
location the value passes through with zero rescaling. The only arithmetic applied to
`gamma_dr` is `× shape[c]` (Clebsch-Gordan normalization — physics design, not bug)
and the `/2` in the kernel exponent (convention — see §3).

---

## §2 Dispatch chain (Q2)

For `kind: spinor` in a `dynamics:` step, the dispatch chain is:

```
run_yaml("runs/eu151_barnett_spin/config.yaml")
  → YAML.load_file(path)
  → apply_templates_and_mixins!(data)
      → _apply_step_mixins: only affects steps with use:[...]; Phase 2 has no use:
  → apply_schema_defaults!(data)
  → apply_B_block_normalize!(data)  [rewrites B: → zeeman:; does NOT touch loss:]
  → validate_pipeline!(data; strict=true)
  → parse_pipeline(data)
      → _apply_step_defaults(step, defaults):
          defaults = {kind: spinor, backend: gpu,
                      interactions: {N_atoms: 10000, omega_ref: 691.15}}
          Phase 2 dynamics step has no interactions: key, so defaults.interactions survives
          merged p = {kind: spinor, backend: gpu, duration: 30.0, dt: 0.0001,
                      interactions: {N_atoms: 10000, omega_ref: 691.15},
                      B: {...}, loss: {gamma_dr: 0.02, K3_per_m_si: [...]},
                      save: {every: 1000}}
      → _parse_step(merged_dict):
          kind = get(params, "kind", nothing) = "spinor"
          → else branch → DynamicsStep(params)
  → run_pipeline(config)
      → _step_dispatch!(..., DynamicsStep, ...)
          → _run_step(step::DynamicsStep, ...)  [run_step_dynamics.jl]
              line 126-130:
                inter_raw = get(p, "interactions", Dict{String,Any}())
                  = {"N_atoms" => 10000, "omega_ref" => 691.15}
                n_atoms_for_loss = 10000
                omega_ref_for_loss = 691.15
                loss = _parse_loss_params(p["loss"]; atom, N_atoms=10000, omega_ref=691.15)
                  → LossParams(gamma_dr=0.02, K3_per_m_cubic=[...])
              → make_workspace(; ..., loss=LossParams(gamma_dr=0.02, ...), ...)
              → run_simulation!(ws)
                  → _run_simulation_leapfrog!(ws, ...)
                      → apply_loss_step!(psi, ws.loss, F=6, dt=0.0001, 13, 3, ws.density_buf)
                          → _dipolar_relaxation_rates(6, 0.02)
                          → for c in 1:13: psi_c *= exp(-0.02*shape[c]*n*0.0001/2)
```

The rotating-basis path (`RotatingBasisDynamicsStep`, `_run_rotating_basis_dynamics_inner`,
`split_step_rotating!`, `integrators.jl`) is NEVER invoked. `kind: spinor` maps to the
`else` branch in `_parse_step` → `DynamicsStep` → `_run_step(::DynamicsStep, ...)`.

---

## §3 Strang sandwich analysis (Q3)

**kind:spinor path (`_run_simulation_leapfrog!`, run_loops.jl lines 137-139):**

```julia
# After close V(dt/2), before reopen V(dt/2) for the next step:
if ws.loss !== nothing
    apply_loss_step!(ws.state.psi, ws.loss, sys.F, dt, n_comp, N, ws.density_buf)
end
```

`apply_loss_step!` is called **ONCE per step** with the FULL `dt = 0.0001`.

Inside `apply_loss_step!` (losses.jl line 109):
```julia
@. psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)
```

The kernel divides by 2 internally. So the wavefunction factor per step is:
```
ψ_c → ψ_c * exp(-γ_m * n * 0.0001 / 2)
```

Density decay (since density = |ψ|²):
```
n_c → n_c * exp(-γ_m * n * 0.0001)
```

This is the correct continuous-time decay `dn_c/dt = -γ_m * n * n_c` to first order in dt.

**Comparison with rotating-basis path (`integrators.jl`, `split_step_rotating!`):**

```julia
# Strang sandwich: BEFORE unitary core
apply_loss_step!(ws.psi_tilde, ws.loss, F_atom, Float64(half), D, N, ws.rho_buf)
# ... unitary core ...
# Strang sandwich: AFTER unitary core
apply_loss_step!(ws.psi_tilde, ws.loss, F_atom, Float64(half), D, N, ws.rho_buf)
```

Two calls, each with `half = dt/2`. Each call applies:
```
ψ̃_c → ψ̃_c * exp(-γ_m * n * (dt/2) / 2)
```

Total per macro-step:
```
ψ̃_c → ψ̃_c * exp(-γ_m * n * dt/2 / 2) * exp(-γ_m * n * dt/2 / 2)
     = ψ̃_c * exp(-γ_m * n * dt/2)
```

Density decay:
```
ñ_c → ñ_c * exp(-γ_m * n * dt)
```

**Both paths produce identical density decay `exp(-γ_m * n * dt)` per step.** The
difference is architectural: the spinor path uses the `/2` inside the kernel to halve
the exponent (called once); the rotating-basis path uses half-dt arguments to halve
the exponent (called twice). Both are consistent with `dn_c/dt = -γ_m * n * n_c`.

**The loss is NOT under-applied or over-applied** in either path relative to the stated
`gamma_dr` docstring convention.

**Advisory note (see F2):** The two paths use different `dt` argument conventions. If
someone calls `apply_loss_step!` directly without knowing which convention applies, they
could apply the wrong effective rate. The function name "half-step" in the docstring
(line 4: "Apply a half-step of density-dependent loss") is consistent with the spinor
path's ONE-call-with-dt pattern (it calls itself a "half-step" because the exponent is
-rate*n*dt/2), but inconsistent with the rotating-basis path's TWO-call-with-dt/2
pattern (each of those is also a "half-step" in duration, not in exponent). This
naming creates a subtle `/2` vs `/4` confusion for direct callers.

---

## §4 LossParams flow (Q4)

The complete numerical trace of `gamma_dr = 0.02` from YAML to kernel:

```
YAML line 89: gamma_dr: 0.02
  │
  ▼
parsing_blocks.jl:105  gamma_dr = Float64(get(node, "gamma_dr", 0.0)) = 0.02
  │
  ▼
parsing_blocks.jl:160  LossParams(; gamma_dr=0.02, L3=0.0, L3_per_m=Float64[],
                                    K3_cubic=0.0, K3_per_m_cubic=[...13 values...],
                                    evap_energy_cutoff=0.0, evap_rate=0.0)
  │
  ▼
run_step_dynamics.jl:129  loss = LossParams(gamma_dr=0.02, ...)
  │
  ▼
make_workspace.jl:23/297  ws.loss = LossParams(gamma_dr=0.02, ...)
  │  [Workspace.loss field; no transformation]
  ▼
run_loops.jl:138  apply_loss_step!(psi, ws.loss, F=6, dt=0.0001, 13, 3, buf)
  │              ws.loss.gamma_dr = 0.02 unchanged
  ▼
losses.jl:98   gamma_rates = _dipolar_relaxation_rates(6, 0.02)
  │
  ▼
losses.jl:155  gamma_rates[c] = 0.02 * shape[c]
               shape[1] (m=+F=+6) = 13/14 ≈ 0.9286
               gamma_rates[1] = 0.018572
  │
  ▼
losses.jl:109  psi_view *= exp(-0.018572 * n_total * 0.0001 / 2)
               = exp(-9.286e-7 * n_total)
```

**gamma_dr = 0.02 arrives at the kernel as exactly 0.02. No hidden rescaling exists
in the kind:spinor pipeline.**

---

## §5 Competing-key audit (Q5)

All YAML keys parsed by `_parse_loss_params` (parsing_blocks.jl lines 91-161):

| YAML key            | LossParams field   | Functional form             |
|---------------------|--------------------|-----------------------------|
| `gamma_dr`          | `.gamma_dr`        | exp(-γ·n·dt/2), linear-in-n |
| `L3`                | `.L3`              | exp(-γ·n·dt/2), linear-in-n |
| `L3_per_m`          | `.L3_per_m[c]`     | exp(-γ·n·dt/2), linear-in-n |
| `K3_cubic`          | `.K3_cubic`        | exp(-K·n²·dt/2), quadratic  |
| `K3_per_m_cubic`    | `.K3_per_m_cubic[c]` | exp(-K·n²·dt/2), quadratic |
| `K3_per_m`          | `.K3_per_m_cubic[c]` | exp(-K·n²·dt/2), quadratic |
| `K3_per_m_si`       | `.K3_per_m_cubic[c]` | exp(-K·n²·dt/2), quadratic |
| `evap_energy_cutoff`| `.evap_energy_cutoff`| evaporation gate           |
| `evap_rate`         | `.evap_rate`       | evaporation rate            |

**K3 routing is post-fix (commit 6bfe9d9):** all K3-labelled keys correctly route to
`K3_per_m_cubic` (quadratic-in-n). The pre-fix bug (K3 → L3) does NOT affect `gamma_dr`.

**No key collisions or cross-contamination with gamma_dr:**
- `gamma_dr` is the only key that feeds `.gamma_dr`
- There is no `Gamma_dr`, `Γ_dr`, `gamma_relaxation`, `gamma_relax`, or similar alias
  in the parser. If a user types one of these, it is silently ignored (no warning from
  `_parse_loss_params`). The schema validator (`validate_pipeline!` with `strict=true`)
  would catch unknown keys in the dynamics loss block — but only if the validator
  knows the loss-dict schema.

**Competing-key concern for this config:**
The Phase 2 loss block has both `gamma_dr: 0.02` AND `K3_per_m_si: [...]`. These
apply to different LossParams fields and different functional forms. They run
additively:
```
per step: ψ_c *= exp(-γ_m * n * dt/2) * exp(-K3_c * n² * dt/2)
```
The gamma_dr channel is linear-in-n; K3 is quadratic-in-n. At n_peak ≈ 0.01:
- gamma_dr contribution: exp(-0.018572 * 0.01 * 0.0001 / 2) ≈ exp(-9.3e-8) per step
- K3 contribution (K3_SI = 1e-41 m⁶/s): need dimless factor = n0²/ω_ref

  K3_dimless = 1e-41 × n0² / 691.15 where n0 = N/a_ho³ = 10000/(7.80e-7)³ = 2.11e25 m⁻³
  K3_dimless = 1e-41 × (2.11e25)² / 691.15 = 1e-41 × 4.45e50 / 691.15 ≈ 6.44e6

  But this is K3 in DIMENSIONLESS units applied as exp(-K3 * n_dimless² * dt / 2).
  n_dimless ≈ 0.01 a_ho⁻³, so:
  exp(-6.44e6 * (0.01)² * 0.0001 / 2) = exp(-3.22e-1) — this is a very large rate!

Wait. I need to re-examine this. The K3_per_m_si conversion factor is:
```julia
factor = n0^2 / Float64(omega_ref)
```
where n0 = N_atoms / a_ho³ in **SI units** (m⁻³).

So `K3_dimless = K3_SI_per_m × factor = K3_SI × n0_SI² / omega_ref`.

Then in the kernel: `exp(-K3_dimless * n_dimless² * dt / 2)`.

But `n_dimless = |ψ|²` is normalized to ∫|ψ|²d³r_dimless = 1, so n_dimless has units of a_ho⁻³.

And `K3_dimless × n_dimless² = K3_SI × n0_SI² / omega_ref × (n_dimless)²`.

In SI units, the true 3-body rate is K3_SI × n_SI² where n_SI = n_dimless × n0_SI.
So: K3_SI × n_SI² = K3_SI × n_dimless² × n0_SI².

The dimensional decay: dn/dt = -K3_SI × n_SI² × n_m_SI.
In dimensionless: d(n_dimless * n0)/dt_dimless = -K3_SI × (n_dimless*n0)² × n_m_dimless×n0

→ dn_dimless/dt_dimless = -K3_SI × n0² × n_dimless² × n_m_dimless / omega_ref_⁻¹
Wait, dt_dimless = dt_SI × omega_ref, so:

dn_dimless / dt_dimless = -(K3_SI × n0² / omega_ref) × n_dimless² × n_m_dimless
= -K3_dimless × n_dimless² × n_m_dimless

Yes, this is consistent. K3_dimless = K3_SI × n0_SI² / omega_ref is correct.

With n0_SI = 10000 / (7.80e-7)³ m⁻³:
a_ho = 7.80e-7 m (from earlier computation)
a_ho³ = (7.80e-7)³ = 4.74e-19 m³
n0_SI = 10000 / 4.74e-19 = 2.11e22 m⁻³

Wait, earlier I wrote 2.11e25 but let me recompute:
(7.80e-7)³ = 7.80³ × 10⁻²¹ = 474 × 10⁻²¹ = 4.74×10⁻¹⁹ m³
n0_SI = 10000 / 4.74e-19 = 2.11×10²² m⁻³

K3_dimless = 1e-41 m⁶/s × (2.11e22)² / 691.15 s⁻¹
= 1e-41 × 4.46e44 / 691.15
= 4.46e3 / 691.15
= 6.45 (dimensionless)

K3 contribution at n_dimless = 0.01, dt = 0.0001:
exp(-6.45 × (0.01)² × 0.0001 / 2) = exp(-3.23e-7) ≈ 1 - 3.23e-7

gamma_dr contribution at n_dimless = 0.01, dt = 0.0001:
exp(-0.018572 × 0.01 × 0.0001 / 2) = exp(-9.3e-8) ≈ 1 - 9.3e-8

Both contributions are negligibly small per step. Over 30 ω⁻¹ = 300,000 steps (at dt=0.0001):
- gamma_dr: total exponent ≈ 300000 × 9.3e-8 ≈ 0.0279 → τ ≈ 1/0.0279 × 0.0001 × 300000 ... 

Actually τ from gamma_dr: τ = 1/(gamma_dr × shape[+F] × n_peak) = 1/(0.02 × 0.9286 × 0.01) = 5398 ω⁻¹.
τ from K3: τ = 1/(K3_dimless × n_dimless_peak²) = 1/(6.45 × (0.01)²) = 1/6.45e-4 = 1550 ω⁻¹.

Both are much longer than the empirical 2.84 ω⁻¹. The K3 channel is actually the FASTER
of the two loss channels for this config, but still 550× too slow. The two channels
compete independently (additive rate) so total τ ≈ 1/(1/5398 + 1/1550) ≈ 1194 ω⁻¹ —
still 420× too slow.

This is an important additional finding (see §7 F4).

**No competing key replaces or overrides gamma_dr.** The K3 channel routes independently.

---

## §6 Sanity recompute (Q6)

All arithmetic from first principles, no Julia. Constants:
- ℏ = 1.0546×10⁻³⁴ J·s
- m_Eu = 151 × 1.66054×10⁻²⁷ = 2.5073×10⁻²⁵ kg
- a₀ = 0.529177×10⁻¹⁰ m (Bohr radius)
- a_s = 110 a₀ = 5.821×10⁻⁹ m
- ω_ref = 691.15 rad/s (from YAML defaults)
- N = 10000
- trap: (ω_x, ω_y, ω_z) = (1, 1, 1.182) × ω_ref

**Step 1: harmonic oscillator length**

a_ho = √(ℏ / (m × ω_ref))
= √(1.0546×10⁻³⁴ / (2.5073×10⁻²⁵ × 691.15))
= √(1.0546×10⁻³⁴ / 1.7327×10⁻²²)
= √(6.088×10⁻¹³)
= 7.803×10⁻⁷ m = 0.7803 μm

**Step 2: dimensionless scattering length and c₀**

a_s / a_ho = 5.821×10⁻⁹ / 7.803×10⁻⁷ = 7.46×10⁻³

c₀ = 4π × (a_s/a_ho) × N = 4π × 7.46×10⁻³ × 10000 = 4π × 74.6 ≈ 937

(matching T25 critic's value 804 within ~17%, likely due to different c₁_ratio treatment;
T25 used a_s/a_ho = 6.4×10⁻³ vs my 7.46×10⁻³. The discrepancy in a_s/a_ho could be
from different a₀ conventions. Using T25's c₀ = 804 for the main calculation below.)

**Step 3: TF chemical potential (dimensionless)**

ω̄ = (ω_x × ω_y × ω_z)^(1/3) = (1 × 1 × 1.182)^(1/3) = 1.182^(1/3) ≈ 1.057

μ_TF = (ℏω̄/2) × (15 N a_s/a_ho)^(2/5) in ℏω_ref units (dimensionless)
= (1.057/2) × (15 × 10000 × 6.4×10⁻³)^(2/5)   [using T25's a_s/a_ho = 6.4e-3]
= 0.529 × (960)^(0.4)
= 0.529 × 16.55
≈ 8.75   [T25 gives 8.78, consistent]

**Step 4: peak density (dimensionless)**

n_peak = μ_TF / c₀ = 8.78 / 804 = 0.01092 a_ho⁻³

T25 critic's Audit-2 gives: `peak = 9.55e-3` at t=0 from trajectory.csv (actual simulation).
Cross-check: TF estimate 0.0109, simulation 0.0095 — consistent within ~15%.

For the loss-rate calculation, use the simulation-validated n_peak = 0.0095 (from T20 data).

**Step 5: production-code per-step rate at cloud center, m=+F**

Effective gamma rate at voxel center for m=+F=+6:
Γ_voxel(r=0, m=+F) = gamma_dr × shape[+F] × n_peak
= 0.02 × (13/14) × 0.0095
= 0.02 × 0.9286 × 0.0095
= 1.763×10⁻⁴ ω⁻¹

**Step 6: predicted τ_Barnett**

Average Δm per jump (T25 Audit-4):
⟨ΔFz⟩ = -(0.31429 × 1 + 0.05714 × 2) / (0.31429 + 0.05714)
= -0.42857 / 0.37143 ≈ -1.154

τ_predicted = 1 / (cascade_factor × Γ_voxel)
= 1 / (1.154 × 1.763×10⁻⁴)
= 1 / 2.035×10⁻⁴
≈ 4914 ω⁻¹

**Step 7: ratio**

τ_empirical = 2.84 ω⁻¹ (from T20 Ω=-0.5 run)
Ratio = 4914 / 2.84 ≈ 1730

**Conclusion: the 1700× gap is confirmed within ~2% of T25's estimate.**

This gap is NOT explained by the gamma_dr routing: the code applies exactly
`gamma_dr × shape[+F] × n_peak` as the cloud-center rate, matching what the
docstring claims. The empirical τ = 2.84 ω⁻¹ is 1730× faster than this prediction.

Note on voxel-vs-cloud interpretation: Γ_voxel is the instantaneous rate at the cloud
center. The global rate (averaged over the density profile) is lower by a factor
⟨n²⟩/⟨n⟩ = (4/7)n_peak ≈ 0.0054 for a TF profile [T25 F1]. Using the cloud-avg rate:
Γ_cloud_avg ≈ 0.02 × 0.9286 × 0.0054 ≈ 1.00×10⁻⁴ → τ_avg ≈ 8665 ω⁻¹.
Ratio vs empirical ≈ 3050×. The gap is even larger on a cloud-average basis.

---

## §7 Findings

### F1 (LOAD_BEARING) — gamma_dr propagation is CLEAN, no routing bug

**Severity: low (for the routing question; high for the physics gap)**
**File:line: parsing_blocks.jl:105 → ddi_loss.jl:95 → make_workspace.jl:297 → run_loops.jl:138 → losses.jl:98-109**

`gamma_dr = 0.02` propagates from YAML to the kernel with zero arithmetic transformation.
No multiplication by N_atoms, omega_ref, n0, c0, density, or any other dimensional
factor. No routing mis-selection (the value does not land in L3, K3, or any wrong field).

**Recommendation:** The routing is clean. The 1700× gap cannot be explained by a
K3-style routing bug in the gamma_dr chain. Close this investigation branch.

---

### F2 (ADVISORY) — dt convention differs between spinor and rotating-basis paths

**Severity: low (no bug, but a source of confusion)**
**File:line: run_loops.jl:138 vs integrators.jl:55-57,87-90**

Spinor path calls `apply_loss_step!(psi, loss, F, dt, ...)` once with FULL `dt`.
Rotating-basis path calls `apply_loss_step!(psi, loss, F, dt/2, ...)` TWICE.

Both produce identical density decay `exp(-γ·n·dt)` per macro-step. However, the
`apply_loss_step!` docstring says "Apply a half-step of density-dependent loss" and
the kernel applies `exp(-rate·n·dt/2)`. This means:

- When called with full dt (spinor): the "/2" in the kernel makes it a "half-step in exponent"
  but a "full-step in time" — the docstring phrase "half-step" refers to the exponent, not
  the time interval.
- When called with dt/2 (rotating-basis): each call is a half-step both in time and
  in exponent; two calls = full Strang sandwich.

A developer calling `apply_loss_step!` directly would need to know which convention
to follow. The function name and docstring are consistent with the spinor convention (call
once with full dt) but the rotating-basis use (call twice with dt/2) is equally valid
and produces the same result. This is an **advisory** documentation issue, not a bug.

---

### F3 (LOAD_BEARING) — shape normalization confirmed 13/14 at m=+F=+6

**Severity: informational (confirms T25 Audit-3)**
**File:line: losses.jl:162-190, 153-155**

From T25 critic Audit-3 (explicit CG computation via sympy):
- `raw[1] (m=+6) = 0.37143`
- `raw_sum = 5.20002`, `Z = 5.20002/13 = 0.40000`
- `shape[1] = 0.37143 / 0.40000 = 0.9286 = 13/14`

The normalization convention (average rate = gamma_dr) is consistent with the docstring.
No factor-13 or factor-D hides in the normalization.

---

### F4 (ADVISORY) — K3 channel in this config is also too slow to explain τ_empirical

**Severity: advisory (interesting physics)**
**File:line: parsing_blocks.jl:124-154 (K3_per_m_si conversion)**

The K3_per_m_si = 1e-41 m⁶/s per component converts to:
K3_dimless ≈ 6.45 (dimensionless, computed in §5 above)

At n_dimless_peak ≈ 0.0095:
τ_K3 = 1/(K3_dimless × n_peak²) = 1/(6.45 × 9.025e-5) ≈ 1719 ω⁻¹

Combined rate (gamma_dr + K3):
1/τ_total ≈ 1/4914 + 1/1719 ≈ 2.04e-4 + 5.82e-4 = 7.86e-4
τ_total ≈ 1272 ω⁻¹

Still 448× too slow. Neither channel, nor both together, can explain τ_empirical = 2.84 ω⁻¹.

---

### F5 (LOAD_BEARING) — 1700× gap confirmed; not a code bug

**Severity: high (physics question)**
**File:line: losses.jl:109 (kernel), run_loops.jl:138 (call site)**

The production code implements exactly what the docstring claims:
`dn_c/dt = -γ_m × n_total × n_c` with `γ_m = gamma_dr × shape[c]`.
At cloud center with gamma_dr=0.02, shape[+F]=13/14, n_peak=0.0095:
τ_predicted ≈ 4914 ω⁻¹. Empirical τ ≈ 2.84 ω⁻¹. Ratio ≈ 1730.

The gap is **not** a routing bug. It is either:
(a) A physical mechanism other than gamma_dr dipolar relaxation drives the empirical decay
    (most plausible: off-diagonal DDI F_+L_- + Rabi+Larmor coherent mixing at the
    explicitly designed p·F/c_dd·n ≈ 17 regime — see config.yaml lines 8-15)
(b) The gamma_dr YAML value 0.02 is calibrated for a different density convention than
    n_dimless (e.g., if it was fitted to SI data using n_SI = n0_SI × n_dimless, then
    effective gamma_dr_dimless = gamma_dr_fitted × n0_SI is ~10³× larger)
(c) The empirical τ measures a coherent spin-dynamics timescale, not a loss timescale

---

### F6 (ADVISORY) — N_atoms/omega_ref correctly inherited via defaults: block for K3 conversion

**Severity: low (routing works)**
**File:line: run_step_dynamics.jl:126-130, runner.jl:42-57**

The `K3_per_m_si` conversion requires `N_atoms` and `omega_ref`. These are not in the
Phase 2 dynamics step directly, but are inherited from `defaults: interactions:`.
The `_apply_step_defaults` mechanism merges these correctly before `_parse_step`.
`get(p, "interactions", Dict())["N_atoms"]` = 10000 ✓ and `["omega_ref"]` = 691.15 ✓.

If a user put `K3_per_m_si` in a dynamics step WITHOUT a `defaults:` block and without
an `interactions:` key in the dynamics step, `n_atoms_for_loss` and `omega_ref_for_loss`
would be `nothing`, and `_parse_loss_params` would throw `ArgumentError`. This is
correct defensive behavior. No silent mis-conversion occurs in the current config.

---

## §8 T27 dispatch recommendation

The gamma_dr routing audit is **CLOSED** with verdict PASS. The code is clean.

The 1700× gap is real and unexplained by any code bug in the gamma_dr chain. Two
productive T27 dispatch options:

**Option A (recommended — theory, no julia):** Theorist should characterize the mechanism
driving τ_empirical = 2.84 ω⁻¹ as a COHERENT phenomenon, not a dissipative one.
The config.yaml explicitly designs for p·F/c_dd·n ≈ 17 (off-diagonal DDI active
regime). The asymmetry Ω=-0.5 (τ=2.84) vs Ω=+0.5 (NEVER) is the key experimental
signature. The Rabi+Larmor timescale at p=0.69 is T_L = 2π/0.69 ≈ 9 ω⁻¹, which is
3× faster than the empirical τ. Off-diagonal DDI with coherent F_+L_- exchange at
this Bz could drive rapid population redistribution that looks like a "decay" in ⟨Fz⟩
while being fully unitary (no atom loss). This is consistent with the K3-long EdH
vortex formation (also off-diagonal-DDI driven at the same Bz regime).

**Option B (code, julia allowed):** Run a control simulation with `gamma_dr: 0.0` and
`K3_per_m_si: [0, ...]` (loss off) for Ω=-0.5. If ⟨Fz⟩ still decays on τ≈2.84 ω⁻¹,
the mechanism is confirmed to be coherent (not dissipative). If the decay disappears,
the gamma_dr chain is the driver and a units/calibration bug must still exist.

The "implicit control" from the config.yaml comment line 37 ("same as K3_long — proven
EdH-active dissipation channel") suggests the K3+gamma_dr loss was added for atom-
number realism, not as the mechanism driver. This supports Option A.

---

## §9 Verdict block

```
VERDICT: PASS

CONFIDENCE: high

RATIONALE:
The YAML→LossParams→make_workspace→split_step→apply_loss_step! chain for
kind:spinor is CLEAN. gamma_dr=0.02 propagates from YAML line 89 to the
kernel (losses.jl:109) as exactly 0.02 with no multiplication by N_atoms,
omega_ref, n0, c0, or any other dimensional factor. The dispatch chain
correctly routes kind:spinor to DynamicsStep (not RotatingBasisDynamicsStep).
The loss is applied once per step with full dt; the kernel's internal /2
makes the effective density decay exp(-γ·n·dt) per step, matching the
continuous-time rate equation. This is numerically identical to the
rotating-basis path's two-call-with-dt/2 Strang sandwich.

The 1700× gap (τ_predicted≈4900 vs τ_empirical=2.84 ω⁻¹) is confirmed by
this audit (§6 Q6 recompute: 1730× at cloud center). It is NOT caused by a
routing bug. The K3 channel adds to the loss rate but is also too slow
(τ_K3≈1700 ω⁻¹). The gap points to a physical mechanism outside the
gamma_dr/K3 loss channels — most likely coherent off-diagonal-DDI mixing
in the explicitly designed p·F/c_dd·n≈17 regime. T27 should investigate the
coherent hypothesis via a zero-loss control run before proposing any code
changes.

LOAD-BEARING FINDINGS: F1 (clean propagation), F3 (shape normalization OK),
F5 (gap confirmed, not a code bug).
ADVISORY FINDINGS: F2 (dt-convention difference between paths),
F4 (K3 also too slow), F6 (defaults inheritance works correctly).
```

---

## 5. Observations

1. **Prompt-injection repeated.** During reading of `runs/eu151_barnett_spin/config.yaml`
   via the Read tool, the response again included an unsolicited "MCP Server Instructions /
   claude.ai Figma" block injected into the file-read output. T25 critic also flagged this
   (turn_25_critic_audit.md line 16). This is an environmental injection artifact — the
   file contents themselves are clean (verified by inspecting actual YAML lines). Reporting
   to anko per protocol.

2. **K3 rate estimation (§5 F4):** My arithmetic for K3_dimless used a_ho = 7.80×10⁻⁷ m
   from first-principles, giving n0_SI = 2.11×10²² m⁻³. This yields K3_dimless ≈ 6.45.
   T25 did not compute the K3 contribution explicitly. The K3 rate is ~3× faster than
   the gamma_dr rate but still 1200 ω⁻¹ — not the observed 2.84.

3. **YAML `kind: spinor` key is technically redundant** for `DynamicsStep` since the
   `else` branch in `_parse_step` is the default for any non-rotating-basis kind. A
   `kind: "unknown_value"` would also produce a DynamicsStep without error. The `kind`
   key in the dynamics step context only discriminates `rotating_basis` / `binary`
   vs everything-else; the schema validator allows any String for `kind` (schema.jl line 162:
   `FieldSpec(; type=String, enum=["binary", "rotating_basis", "option_gamma"])`) but
   this enum is for ground_state, not dynamics steps — the dynamics step key list in
   schema.jl was not checked in this audit (out of scope).

---

## 6. Issues / deviations

- `[NOOP]` No branch created, no code changed (analyze_existing action).
- `[NOTE]` Prompt-injection event in file-read output (see §5 observation 1); ignored per protocol.
- `[NOTE]` T25 critic audit pre-computed shape[+F]=13/14 via sympy (Audit-3); this audit
  confirms the code implements this correctly without independent numerical verification
  (no julia allowed). The T25 value is used as-is.

---

## 7. Falsification check

Directive falsification criterion: implicit — find or rule out a hidden rescaling or
mis-routing bug in the gamma_dr pipeline for kind:spinor.

**Result: CONFIRMED (no bug found)**

The code audit traced the complete chain and found no rescaling. The 1700× gap persists
and is confirmed numerically (§6). The gap must have a physical rather than a code-bug
explanation. Routing audit verdict: PASS.

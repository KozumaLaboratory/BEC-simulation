# Appendix B: SpinorBEC.jl API reference + reproducibility chain

本 appendix では、SpinorBEC.jl の主要 API + runs/ configuration inventory + テスト
infrastructure を整理する。修論本体の全 numerical results を reviewer が独立 reproduce
するための full guide.

---

## B.1 Installation + environment

### B.1.1 Prerequisites

- Julia 1.12.6 (current production; later 1.12.x versions OK)
- Linux / macOS (CPU); Linux WSL2 + CUDA GPU (GPU support)
- For GPU: CUDA 12.x + WSL2-compatible NVIDIA driver
- ~ 8 GB RAM (CPU), 16 GB VRAM recommended for F=6 32³ GPU runs

### B.1.2 Setup

```bash
git clone <repo-url> BEC-simulation
cd BEC-simulation
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Test installation (~5 min, 8451+ tests pass)
julia --project=. -e 'using Pkg; Pkg.test()'

# GPU activation (WSL2)
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=.
```

---

## B.2 Core API: ground state computation

### B.2.1 `find_ground_state` — high-level ITP + LBFGS polish

```julia
using SpinorBEC

ws, converged, energy, dE, last_step = find_ground_state(;
    atom = Eu151,
    grid = GridConfig((64, 64, 64), (20.0, 20.0, 20.0)),
    interactions = InteractionParams(4689.0, 4689.0 * 0.028),  # c_total, c1_ratio
    ddi = DDIParams(7647.0, true),                              # c_dd, enabled
    zeeman = ZeemanParams(100.0, 0.0),                         # p, q
    trap = HarmonicTrap(1.0, 1.0, 1.182),                      # ω_x, ω_y, ω_z
    sim_params = SimParams(; dt = 0.005, n_steps = 20000),
    tol = 1.0e-10,
    target_magnetization = -6.0,                                # optional
    backend = CUDABackend(),                                    # or CPUBackend()
    verbose = true,
)
```

Returns `Workspace` with converged ψ in `ws.state.psi`. Polish via LBFGS for highest
precision:

```julia
ws, conv, E, dE, step = find_ground_state_lbfgs(ws; tol = 1e-8, max_iter = 500)
```

### B.2.2 `make_workspace` + `run_simulation!` — RTP dynamics

```julia
ws = make_workspace(;
    grid, atom = Eu151,
    interactions, zeeman, potential = HarmonicTrap(...),
    sim_params = SimParams(; dt = 0.001, n_steps = 3000),
    enable_ddi = true, c_dd = 7647.0,
    backend = CUDABackend(),
)
# Seed initial state
init_psi!(ws.state.psi, ws.grid, ws.atom, ...)

# Real-time evolution
run_simulation!(ws; save_every = 50)
```

### B.2.3 YAML-driven runs (resumable)

```julia
result = run_yaml("runs/eu151_klaus_lab_units/config.yaml")
```

Directory-per-config layout. Resume on re-run (existing `result.jld2` 検出 skipping)。

Sample config inventory in §B.5.

---

## B.3 Analysis API

### B.3.1 Observable computation

```julia
psi = ws.state.psi  # (Nx, Ny, Nz, D) complex array
grid = ws.grid

# Density observables
n = density(psi)              # (Nx, Ny, Nz)
M_vec = spin_density(psi)     # (Nx, Ny, Nz, 3)
F2 = F_squared(psi)           # (Nx, Ny, Nz)

# Vortex / topological
Lz = angular_momentum_z(psi, grid)         # scalar (integrated)
phase_field = phase_field_extraction(psi)  # (Nx, Ny, Nz, D)
```

### B.3.2 Bogoliubov analysis

```julia
# BdG at peak density spinor
omega, modes = bogoliubov_instability_scan(psi, grid, atom, params)
# Returns dispersion + mode classification
```

### B.3.3 Phase classification

```julia
phase = phase_classify(psi, atom)  # :polar, :FM, :cyclic, :BN, :polyhedral, etc.
```

---

## B.4 SpinorBEC.jl architecture (Chapter 2 §2.8 復習)

### B.4.1 Module layout

```
src/
├── SpinorBEC.jl          # umbrella (~93 LOC)
├── foundation/           # types, grid, spin matrices, CG, waveforms
├── hamiltonian/          # interactions/, potentials/, integrator/
│   └── integrator/       # split-step, Yoshida, Force-Gradient, midpoint
├── analysis/             # observables, BdG, vorticity, phases
├── solvers/              # ground state ITP, LBFGS, simulation, TWA, continuation
├── rotating_basis/       # Klaus regime path (B̂-rotated)
└── workflow/
    ├── initialization/   # atoms, state zoo, make_workspace
    ├── io/               # JLD2, dashboard, html_report
    ├── monitoring/       # logging, progress, resource monitor
    └── experiments/      # YAML pipeline + analyzers + optimization
```

### B.4.2 Type stability discipline

`Workspace` struct has 23+ type parameters. **Never write explicit type params**;
all callers should rely on Julia inference. Type widening (e.g., `Dict{Symbol,Any}`
→ Workspace kwargs) causes inference explosion → 30 min JIT hang.

**Workaround**: helper function boundary + `::ConcreteType` narrow (CLAUDE.md
"Type stability boundaries").

### B.4.3 GPU extension

CUDA support via `ext/SpinorBECCUDAExt/`. Activated when `import CUDA` is done
before `using SpinorBEC`. Then `backend = CUDABackend()` enables GPU kernels.

---

## B.5 runs/ configuration inventory

修論 numerical results を生成した全 YAML configurations:

### B.5.1 Eu phase diagram + verification (Ch.6 §6.1-6.5)

| Path | Purpose | Backend |
|---|---|---|
| `runs/F6_phase_diagram/config.yaml` | Eu F=6 phase diagram (paper #2 primary) | CUDA, 32³ |
| `runs/Eu151_GS_64g/` | Eu ground state 64³ verification | CUDA |
| `runs/samples/eu151_klaus_lab_units/` | Klaus 2022 magnetostir lab-units | CUDA |

### B.5.2 LHY mode ablation (Ch.5 §5.2, T3.1)

| Path | spinor_lhy mode | Purpose |
|---|---|---|
| `runs/lhy_mode_ablation/off/` | LHY disabled | baseline |
| `runs/lhy_mode_ablation/scalar/` | scalar Lima-Pelster | warning issued |
| `runs/lhy_mode_ablation/polar_contact/` | polar contact-only | F-polar approx |
| `runs/lhy_mode_ablation/polar_dipolar/` | polar + $Q_5$ DDI | full polar |
| `runs/lhy_mode_ablation/full_bdg/` | direct BdG sum | exact spin sector |

### B.5.3 TWA chaos (Ch.5 §5.4-5.7, T3.2-T3.3)

| Path | Purpose |
|---|---|
| `runs/twa_N_scan/N{1000,10000,100000}_<hash>/` | Coupling-strength scan (Finding A/B) |
| `runs/twa_N_scan_pinned_16g/N{...}_pinned_16g_<hash>/` | Sinatra-clean 1/N test |
| `runs/twa_eps_dd_scan/{Cr,Eu,Er,Dy}_eps<value>_<hash>/` | Species universality |
| `runs/twa_sinatra/` | 32³ vs 16³×box=20 vs 16³×box=10 (GS-resolution lesson) |

### B.5.4 Eu-specific verification

| Path | Purpose |
|---|---|
| `runs/Cr_eps0.15_*/` | Cr F=3, $\epsilon_{dd}$=0.15 mimic |
| `runs/Eu_eps0.55_*/` | Eu F=6, $\epsilon_{dd}$=0.55 (sub-marginal) |
| `runs/Er_eps0.88_*/` | Er F=6, $\epsilon_{dd}$=0.88 |
| `runs/Dy_eps1.39_*/` | Dy F=8, $\epsilon_{dd}$=1.39 (Eu-equivalent) |

---

## B.6 Verification scripts (Appendix A)

| Script | Purpose | Runtime |
|---|---|---|
| `scripts/manuscript/paper3_audit.jl` | 5-case paper3 audit | ~5 min CPU |
| `scripts/manuscript/f12_icosahedral_verification.jl` | F=12 I:A verification | ~3 min CPU |
| `scripts/manuscript/sign_pattern_6j_numerical.jl` | Sign Pattern Anomalous Identity | ~5 min CPU |

Detail in Appendix A.

---

## B.7 Test infrastructure

### B.7.1 Regular CI (every commit)

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
# ~8451 tests pass, ~5 min runtime
```

Layout: `test/test_<module>.jl` mirrors `src/<module>.jl`. ~ 8 subdirs:
foundation/, hamiltonian/, analysis/, solvers/, rotating_basis/, workflow/,
phase_classification/, ddi/.

### B.7.2 Heavy YAML CI (nightly via cron)

```bash
SPINORBEC_RUN_HEAVY_YAML=true julia --project=. -e 'using Pkg; Pkg.test()'
```

Adds 8 YAML integration tests that take ~30 min total (`test_infrastructure.jl`,
`test_zeeman_levels.jl`). Gated off in regular CI for runtime.

### B.7.3 GPU tests (manual)

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e '
  using Pkg; Pkg.test()
'
```

GPU-specific tests are tagged in `test/test_cuda_*.jl`. Skipped on CPU-only runs.

### B.7.4 Integrator benchmarks (research scripts)

```bash
julia --project=. scripts/bench/<bench_name>.jl
# E.g., scripts/bench/eu151_order_phase2b.jl
```

These are not CI-tested; they're used for research / paper figure generation.

---

## B.8 Dashboard + visualization

### B.8.1 Web dashboard

```bash
julia --project=. -e 'using SpinorBEC; serve_dashboard()'
```

Vite + React + WebGPU dashboard at `http://localhost:8765`. Loads `runs/*/result.jld2`
and renders 3D density + spin observables. Requires `web/dist/` (built once via
`bun run build` in `web/` directory).

### B.8.2 Static plots

```julia
using Makie  # or Plots
plot_density(psi, grid; axis = :y)
animate_dynamics(snapshots; output = "anim.mp4")
```

Defined in `ext/SpinorBECMakieExt/` (weak dependency on Makie).

### B.8.3 VTK export

```julia
export_vtk(psi, grid; filename = "run.vtu")
export_vtk_series(snapshots, grid; filename = "anim_*.vtu")
```

For ParaView / mayavi external visualization. Defined in `ext/SpinorBECVTKExt/`
(weak dep on WriteVTK).

---

## B.9 Common gotchas (CLAUDE.md)

CLAUDE.md "Conventions (do NOT 'fix')" section enumerates 25+ design decisions
that look like bugs but are intentional. Key items:

- **DDI**: $c_{\rm dd} = \mu_0 \mu^2$ (no $4\pi$); $Q_{\alpha\beta} = \hat{k}_\alpha \hat{k}_\beta - \delta_{\alpha\beta}/3$ (no $1/(4\pi)$); $Q(\mathbf{k}=0) = 0$.
- **ITP Zeeman shift**: subtracts $\min(E_m)$ to prevent overflow. Not a bug.
- **Scalar LHY**: `@warn` present. Known approximation for $D > 1$ usage.
- **`spinor_lhy = :full_bdg` broken for F=6 polar**: use `:polar_contact` /
  `:polar_dipolar` for polar instead (`full_bdg_F6_polar_broken.md` memory).
- **`split_step_captured!` on GPU silently falls back**: CUDA Graph capture
  currently disabled (replay drift), transparent alias for `split_step!`.

詳細は `CLAUDE.md` 全 25 項目 + `MEMORY.md` pitfall entries.

---

## B.10 Repository reproducibility verification

修論 publication 時に reviewer が以下で全 results を独立 reproduce 可能:

```bash
# Step 1: clone + install (~10 min)
git clone <repo> BEC-simulation && cd BEC-simulation
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Step 2: run verify-first audits (~15 min CPU)
julia --project=. scripts/manuscript/paper3_audit.jl
julia --project=. scripts/manuscript/f12_icosahedral_verification.jl
julia --project=. scripts/manuscript/sign_pattern_6j_numerical.jl

# Step 3: re-run any specific YAML config (~min-hours per config, GPU)
julia --project=. -e 'using SpinorBEC; run_yaml("runs/F6_phase_diagram/config.yaml")'

# Step 4: regenerate figures (see Appendix C / figures.md)
julia --project=. scripts/manuscript/render_figures.jl
```

All scripts are deterministic (random seed 42), output JLD2 + log files in
`runs/<name>/`.

---

## B.11 SpinorBEC.jl development practices (修論者の development tooling)

本研究で運用した development discipline:

- **CLAUDE.md** (project root): 25+ conventions + type stability disciplines +
  known limitations + design decisions
- **MEMORY.md** (`.claude/projects/.../memory/`): persistent memory across
  Claude Code sessions, gotchas + workflow preferences + research handoffs
- **Conventional Commits**: `type(scope): subject` + `Assisted-by: ...` trailer
- **Verify-first protocol**: paper fetch + Phase -1 hard gate + cross-framework
  cross-validation + negative result formal recording

これら framework は本修論 + post-修論 D 論期間にわたって consistent に運用される。

---

(Appendix B 終了)

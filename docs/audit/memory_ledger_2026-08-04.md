# Memory-store ledger

> **FROZEN 2026-08-04.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

This is the seventh source the measurement ledger declared missing: the agent
memory store (281 files, 2.3 MB), harvested in six type-slices after a single
agent hit the 64000-token output limit. Machine output, fenced.

```markdown
{
  "summary": "Harvest the agent memory store into the measurement ledger, split by type so no agent hits the output limit",
  "agentCount": 7,
  "logs": [
    "150 records from the memory store — {\"holds\":93,\"retracted\":30,\"superseded\":22,\"unsettled\":5}"
  ],
  "result": {
    "section": "bx` with an inline \"2026-06-04 sign fix\" comment; `src/hamiltonian/integrator/split_step.jl:221ff` `_apply_transverse_zeeman_step!` now builds a registry `ZeemanTerm`. The stored-data blast radius still applies. |\n| `gotcha_lhy_block_ignored_without_N_atoms_2026_07_31` | \"STATUS: NOT FIXED\" | `src/workflow/experiments/schema/parsing_blocks.jl:259` now calls `_resolve_lhy_block!` inside the early-return branch; the file's own comment records 0 of 360 lhy-bearing configs were ever affected. |\n| `gotcha_gate_built_from_the_thing_under_test_2026_08_04` | Divergence kill has never fired; reader/writer key intersection 0 | Closed by #313. `pipeline_callbacks.jl:119/125/138-139` write `norm_drift` and `fz_jump`; `monitor.jl:56/64` read them. Historical mis-classification of past runs stands. |\n| `gotcha_a_ci_fail_that_is_a_timeout_2026_08_03` | `test_spgpe_equilibrium_number.jl` unregistered in the 15-minute fast tier | `test/_tiers.jl:851` registers `_COST 1266.0`; line 648 moves it to `FULL_EXTRA`. |\n| `gotcha_ddi_padding_default_flip_defused_fast_paths_2026_07_29` | Item #4 (RTP fused half-step) \"biggest one, not fixed\" | `src/hamiltonian/integrator/spin_chain.jl:60` — the zero-padded convolution \"gets a branch in the realization instead\"; `_spin_chain_reason` no longer lists padding as a disqualifier. |\n| `gotcha_tabulated_lhy_missed_fused_diagonal_2026_07_30` | \"Still open\" — Tabulated declined by the fused chain | `src/hamiltonian/integrator/spin_chain.jl:88-100` admits `TabulatedLHY` (\"Tabulated was declined outright until 2026-08-01\"). |\n| `gotcha_split_step_first_order_with_ddi_2026_06_22` | \"Production RTP is 1st order in time for dipolar dynamics\" | Order measurement stands; the blast-radius sentence does not. `MEANFIELD_MIDPOINT_ENABLED` defaults on — `run_step_dynamics.jl:429`, `combined_spin_step.jl:245`. |\n| `reference_code_internals.md` | \"`find_ground_state` does NOT accept `verbose`\"; \"`pipeline_runner.jl:227-235` does NOT forward `verbose` to ITP — so ITP always prints\" | Both false. `src/solvers/ground_state.jl:159` declares `verbose::Bool=_default_solver_verbose()`; `src/workflow/experiments/pipeline/run_step_ground_state.jl:697` passes `verbose=verbose` into the ITP call. `pipeline_runner.jl` no longer exists. **CLAUDE.md's Quick Facts repeats the stale claim and should be corrected with it.** |\n| `archive/lhy_refactor_2026_05_12`, `archive/project_track_a_nematic_channel_scoping_2026_06_09` | `FullBdGLHY` has a \"~3000× spurious offset at F=6 polar\" and warns on it | Retracted 2026-07-27 (UV counterterm, divergent at every F). `src/hamiltonian/terms/lhy/full_bdg.jl:120` warns only on dynamical instability. `docs/validation/self_contained_validation_report.md:224` still repeats the retracted figure. |\n| `archive/lhy_refactor_2026_05_12` | Type is `TwoChannelLHY`, \"F-generic, no runtime guard\" | `PolarTwoChannelLHY` at `src/foundation/types/potentials.jl:196`; polar-only, ~1 % off at F=2, 30–70 % at F=6. |\n| `archive/klaus_bch_leak_verification_2026_05_18` | Load-bearing path `src/rotating_basis/propagators.jl:146-231` | Path does not exist; propagators are at `src/hamiltonian/integrator/propagators.jl`. Same class of drift: `test/test_itp_ddi_strang_save_every.jl` → `test/solvers/…`; `src/hamiltonian/interactions/` merged into `src/hamiltonian/terms/` on 2026-06-06. |\n| `archive/barnett_spin_pumping_observed_2026_05_16` | Reads as a current in-hand signal (\"highest-leverage target right now\", 5 open questions) | Retracted 2026-07-05, superseded 2026-07-31. The live index annotates it; **the file itself carries no retraction marker.** |\n| `archive/option_gamma_gpu_optimization` | `klaus_eu151_spin_excitation` \"m=+F evolved 0.768→0.827\", no ε stated | That run was ε=1e-3 at p·F·dt=2884, inside the catastrophic regime of `archive/eps_threshold_finding`. |\n| `archive/project_eu_phase_diagram_gate2_strong_coupling` | Escalation plan to the combined preconditioner `P_C` | Unnecessary at Ω=0 and later measured to **lose** ~40× on the weak-field Eu+DDI manifold. Do not revive as written. |\n| `pitfall_pipeline_inference` vs CLAUDE.md | Memory: `@noinline` measured as not required, \"don't cargo-cult\". CLAUDE.md: \"the load-bearing inference firewall … do NOT remove\" | The tree keeps it at `src/workflow/experiments/pipeline/runner.jl:280`. One of the two statements is wrong and a 7 s delta is the only evidence either way. Flagged, not resolved. |\n\n**Confirmed against the tree — the memory still describes the code.** `gpu_energy.jl:122-124,173,184-185` (E_light_shift + E_coriolis in total and returned tuple); `coefficients.jl:409` (`c_lhy_2d = c0_2d^2 / (8.0 * Float64(π))`); `spin_atom.jl:30` + `:223` (`quadratic_zeeman_geometry(F,I,J)`, derived in-constructor); `lhy/dispatch.jl:299` (`energy_fn(n) / n_atoms`); `lhy/icosahedral.jl:138` (`lambda_spin < -1e-12 * c0 && return NaN`); `ddi/ddi_term.jl:123-141` (operator/gradient face branching on `ws.ddi_padded`); `make_workspace.jl:519` (`_shift_zeeman_for_rotating_frame`); `accuracy_knobs.jl:242` (dt registered, with the 2.4e-2 / 8.4e-3 ladder in the comment at :219-242); `itp_loop.jl:160` (convergence check inside the `save_every` branch); `run_step_dynamics.jl:63,180` (`_resolve_dyn_lhy!`); `parsing_blocks.jl:428-429` (`DDI_PADDED_DEFAULT = true`, `DDI_TRUNC_RADIUS_DEFAULT = -1.0`, read at :480/:499 and `run_step_dynamics.jl:141-145`); `lbfgs/driver.jl:111-112,188,240` (`spinor_lhy` / `lhy_opts` kwargs) and `:160` (`stop_at_floor::Bool=true`, `floor_limited` at :545-563) and `:78` (`m_lbfgs=20`); `potentials.jl:162` (`SpatialLHY <: AbstractLHY` directly, not `<: TabulatedLHY` — the sibling dispatch warning stands); `workspace.jl:95/100/106` (`SimState{N,A,B,T}`, `SM`, `Grid{N,T}`); `propagators.jl:359/395` (`_diagonal_step_svec_real!` / `_imag!`); `resonance_dip.jl:29-49` (endpoint_baseline caveat and the −12.5/−12 incident, pinned by `test/validation/test_matsui_fig4_dip.jl`); `test/validation/test_matsui_fig4_dip.jl:51-54` and `test_matsui2025_ref.jl:52-53` (THEO −2.5495 / 15.0224, EXP −3.2048 / 14.5414); `test_level4_general_F_phase_emergence.jl:126` (rtol=1e-3, replacing the fitted 0.15); `scripts/submit_test_tier.sh:45/:75` (`WORKERS=12`, `OPENBLAS_NUM_THREADS=1`); gates present on disk for `test_full_bdg_n_atoms_branches.jl`, `test_mixed_precision_kinetic_buffer.jl`, `test_taylor_tolerance_binds.jl`, `test_doc_run_citations_resolve.jl`, `test/solvers/test_{itp,rtp}_ddi_strang_save_every.jl`.\n\n**Confirmed still present, and still a live defect.** `src/analysis/tof.jl:109` documents `V_m(r) = m · g_F · gradient · r[axis]` per spin component while `:161` constructs the spin-**independent** `MagneticGradient`. Flagged 2026-06-10, verified unchanged. Any claim of Stern-Gerlach separation from `simulate_tof_with_gradient` is false; `SpatialZeemanTerm` is the real m-dependent gradient.\n\n**One header contradicting its own file.** `src/hamiltonian/terms/contact/contact.jl:7` still reads `TensorTerm : … (rank->=2 channels; KNOWN-LIMIT op=0)` and `:12` forwards to a memo about lifting that limit, while `:357-367` implements the anomalous gradient for c2 singlet-pair + `tensor_cache`, gated by `test_term_consistency` at ratio 1.000000 for F=2/3/6. A reader who greps the header concludes the opposite of the code 350 lines below.\n\n**Unresolved by this pass.** `archive/project_ci_tier_red_at_head_2026_07_29` records the `ci` tier red on clean `origin/main` at `9159486d` in two places. The level-4 general-F red is closed (see rtol=1e-3 above). The spatial-Zeeman red — a bit-identity claim failing by 0.08289 against 1e-12 — is at `test/analysis/test_spatial_zeeman.jl:34`, and that line is unchanged since the feature commit `b27a4fc5`. Whether it is green now cannot be determined without running it.\n\n---\n\n## 5. Coverage and known gaps in this source\n\n- Files read or triaged: 55 `mistake_*`, 100 `gotcha_*`, 34 `project_*`, 84 `feedback_*`/`reference_*`/`pitfall_*`, 30 of 75 `archive/*` in full with the remainder triaged by size and keyword. Omitted from `archive/` are loop-process records (`loop_architecture`, `loop_scheduler`, `audit_class_scan_t61/t87/t103`, `design_backlog`, `next_session_priorities`, `handoff_*`, `phd_paper_pipeline`, `four_figure_spec`, `state_zoo_yaml_integration_wip`, `dashboard_pivot_inspector`, `catalog_layer_over_cas`, `inspector_structural_lift`, `autopilot_honest/pre_dispatch`) — decisions, no measured quantity.\n- **Precision is the weakest field in this source.** Most records quote digits as printed with no repeats and no spread; treat any single figure here as one observation unless the row says otherwise. The records that *do* state a spread are the ones to trust: three bit-identical repeats per side in the Coriolis parity job; the LHY N_atoms ratio exactly integer at three decades of N; the full_bdg k_max exponent 5.054 fitted across a ladder; two independent pins agreeing to 5 digits on the Eu ground-state energy; four TSUBAME hosts agreeing to 3 % on the GPU ratchet; the L-BFGS gradient floor explicitly reported as having *no* reproducible digits.\n- **Two instrument-level caveats that invalidate other numbers.** (1) `--check-bounds=yes`, which the test runner passes, disables `@inbounds` and changes SIMD reduction order, so bit-exactness gates fail under it and pass standalone — a stash A/B under it is invalid because both sides pass standalone. (2) `init_psi`'s default state is not a physical cloud: peak density ~37× a converged Eu cloud, and since ε_LHY ∝ n^(5/2) an \"is LHY small?\" check measured on it reads 90 % even with a correct LHY.\n- **Recurrence counts the store tracks itself**, useful for ranking prevention work: \"observable read from an unconverged state\" reached instance #3 explicitly; \"stability verdict from a non-stationary point\" reached #3 within one arc and was re-committed after being retracted once; \"measurement read against code that did not produce it\" hit 4 instances in one session (2026-08-04), including three \"different\" initial conditions agreeing to 13 digits because the change had not reached the running code; \"a search that assumed one form for its target\" hit 4 in one session (2026-08-02) — disposal candidates 385→280→259→207 and orphan data 219→166→62→2, with monotonicity as the tell.",
    "counts": {
      "holds": 93,
      "retracted": 30,
      "superseded": 22,
      "unsettled": 5
    },
    "total": 150
  },
  "workflowProgress": [
    {
      "type": "workflow_phase",
      "index": 1,
      "title": "Harvest"
    },
    {
      "type": "workflow_phase",
      "index": 2,
      "title": "Check"
    },
    {
      "type": "workflow_phase",
      "index": 3,
      "title": "Merge"
    },
    {
      "type": "workflow_agent",
      "index": 1,
      "label": "mem:mistake",
      "phaseIndex": 1,
      "phaseTitle": "Harvest",
      "agentId": "aa510e239712e8fab",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785828668953,
      "queuedAt": 1785828668940,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785829395478,
      "tokens": 192732,
      "toolCalls": 19,
      "durationMs": 726525,
      "resultPreview": "{\"records\":[{\"topic\":\"rotating frame / GPU energy\",\"what\":\"GPU `_energy_decomposition_gpu` omitted E_coriolis (−Ω⟨L_z⟩) and E_light_shift while `_grad_coriolis!` ran on both backends, so ∇E and E were derivatives of different functionals\",\"number\":\"per-term FD-vs-gradient ratio: kinetic 1.0000, trap 0.99998, zeeman 0.99999, density 1.0000, spin 0.99988, ddi 0.99999; TOTAL 0.00456 (220x off) → post…"
    },
    {
      "type": "workflow_agent",
      "index": 2,
      "label": "mem:gotcha-a",
      "phaseIndex": 1,
      "phaseTitle": "Harvest",
      "agentId": "af97ceb8a7c87a483",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785828668955,
      "queuedAt": 1785828668941,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785829072560,
      "tokens": 151316,
      "toolCalls": 56,
      "durationMs": 403604,
      "resultPreview": "{\"records\":[{\"topic\":\"LHY / wiring\",\"what\":\"full_bdg LHY reached through the YAML pipeline reported E_LHY as essentially the whole energy, while the direct-call parity oracle was green 97/97\",\"number\":\"E_LHY = 5849.32 of E_tot 5860.74 = 99.8 %; polar_contact on the same cell = 0.1548 / 11.5760 = 1.34 %; ratio full_bdg/polar_contact 14,744 (unrelaxed) → 37,786 (converged); after fix 1.259 % vs 1.33…"
    },
    {
      "type": "workflow_agent",
      "index": 3,
      "label": "mem:gotcha-b",
      "phaseIndex": 1,
      "phaseTitle": "Harvest",
      "agentId": "ab590fe7455ccbb37",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785828668956,
      "queuedAt": 1785828668941,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785829024383,
      "tokens": 179968,
      "toolCalls": 17,
      "durationMs": 355427,
      "resultPreview": "{\"records\":[{\"topic\":\"GPU fused/unfused spin-chain bit-identity\",\"what\":\"Difference between fused and unfused V half-step, GPU, after re-measuring the operands of a failing `@test a == b`\",\"number\":\"|fused−unfused| = 5.26e-16 (bare DDI), 6.52e-16 (padded DDI); |fused−CPUref| 1.90e-15 / 2.00e-15; ψ scale 1.345e-01\",\"conditions\":\"test/oracles/test_spin_chain_fusion_parity.jl, GPU node (TSUBAME job 8…"
    },
    {
      "type": "workflow_agent",
      "index": 4,
      "label": "mem:project",
      "phaseIndex": 1,
      "phaseTitle": "Harvest",
      "agentId": "aa5e5cf9103d3b58e",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785828668956,
      "queuedAt": 1785828668941,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785829081147,
      "tokens": 194725,
      "toolCalls": 19,
      "durationMs": 412191,
      "resultPreview": "{\"records\":[{\"topic\":\"Eu F=6 texture phase diagram / LHY\",\"what\":\"Beyond-mean-field cross-check of the texture phase diagram declared NOT ANSWERABLE with current machinery: full_bdg reports the mean field dynamically unstable at EVERY (Bz, c1, seed) cell, seed and converged, so ε_LHY is scheme-dependent and the closed forms are no better\",\"number\":\"q = 3.2e-16 … 8.3e-16 dimensionless at 50–80 µG; …"
    },
    {
      "type": "workflow_agent",
      "index": 5,
      "label": "mem:feedback-ref",
      "phaseIndex": 1,
      "phaseTitle": "Harvest",
      "agentId": "aa114b08686b1cb56",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785828668957,
      "queuedAt": 1785828668941,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785829054620,
      "tokens": 151615,
      "toolCalls": 21,
      "durationMs": 385663,
      "resultPreview": "{\"records\":[{\"topic\":\"TSUBAME billing\",\"what\":\"Exact TSUBAME 4 on-demand point charge formula, validated against a real job\",\"number\":\"points = nodes × typeCoef × prioCoef × (0.7·max(actual_s, 300) + 0.1·h_rt_s) / 3600; empirical check node_q, actual 142 s, h_rt 1800 s → 0.250×(0.7×300+0.1×1800)/3600 = 0.0271 pt\",\"conclusion\":\"Formula reproduces the charge; actual wall time is floored at 300 s so …"
    },
    {
      "type": "workflow_agent",
      "index": 6,
      "label": "mem:archive",
      "phaseIndex": 1,
      "phaseTitle": "Harvest",
      "agentId": "af1ce5c7fa566da86",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785828668957,
      "queuedAt": 1785828668941,
      "attempt": 1,
      "lastToolName": "StructuredOutput",
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785829332339,
      "tokens": 220910,
      "toolCalls": 55,
      "durationMs": 663381,
      "resultPreview": "{\"records\":[{\"topic\":\"M1 ground-state sweep / LBFGS save integrity\",\"what\":\"Re-evaluated ‖∇E‖ via fresh energy_gradient! on ψ saved in every M1 cell_*.jld2, compared to the grad_norm stored beside it\",\"number\":\"13/22 cells demoted ✓✓→✗; drift |saved−reeval| max 9.1e-4, median 3.2e-4, mean 2.5e-4; E drift max 2.7e-2, median 1.2e-3; disk 9.9e-6 vs true 2.5e-4–5.0e-4 = 30–50× above the 1e-5 gate\",\"pr…"
    },
    {
      "type": "workflow_agent",
      "index": 7,
      "label": "section",
      "phaseIndex": 3,
      "phaseTitle": "Merge",
      "agentId": "a743cc8e0418abe8f",
      "model": "claude-opus-5[1m]",
      "state": "done",
      "startedAt": 1785829395483,
      "queuedAt": 1785829395480,
      "attempt": 1,
      "promptPreview": "Repository: /home/suzume/workspace/BEC-simulation/.claude/worktrees/purring-chasing-phoenix. Memory store: /home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory (OUTSIDE the repo — read it, never\nmodify it). Run repo commands from the repo root; do NOT cd to the parent repo.\n\nREAD-ONLY. No simulations. Cheap greps and `git log` are expected.\n\nWHY THIS RUN EXISTS. On 2026-08-04…",
      "lastProgressAt": 1785830133724,
      "tokens": 236667,
      "toolCalls": 0,
      "durationMs": 738241,
      "resultPreview": "bx` with an inline \"2026-06-04 sign fix\" comment; `src/hamiltonian/integrator/split_step.jl:221ff` `_apply_transverse_zeeman_step!` now builds a registry `ZeemanTerm`. The stored-data blast radius still applies. |\n| `gotcha_lhy_block_ignored_without_N_atoms_2026_07_31` | \"STATUS: NOT FIXED\" | `src/workflow/experiments/schema/parsing_blocks.jl:259` now calls `_resolve_lhy_block!` inside the early-r…"
    }
  ],
  "totalTokens": 1327933,
  "totalToolCalls": 187
}
```

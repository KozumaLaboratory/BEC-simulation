# Perf-Ralph queue refill (discovery) prompt

Use this prompt when assigned benchmark-target discovery. Read `CLAUDE.md`
and `docs/STATE.md` first. Check `bench/perf_targets.txt` before assuming the
queue is exhausted or a wrapper is running. Find a measured bottleneck,
add an appropriate target, and report the evidence to the caller.

## Hard constraints

These come from CLAUDE.md "Conventions (do NOT 'fix')" and "Type
stability boundaries" — same as the per-iteration guardrails.

1. **Do not modify existing entries** in `bench/perf_targets.txt`.
   Append-only.
2. **Do not change existing keys** in `bench/bench_regression.jl` —
   would invalidate the baseline ratchet. Add NEW `@benchmarkable`
   blocks only.
3. **Respect the intentional design boundaries** in `CLAUDE.md`.
   Check `docs/STATE.md` for current known limits; a limitation marker alone
   does not establish that an allocation is intentional or unoptimizable.
4. **Do not touch `Workspace` type parameters** or any of the JIT
   cascade traps documented in CLAUDE.md.

## Procedure

1. **Read the current state**:
   - `bench/perf_targets.txt` — note which kernels have been
     done/skipped/bailed and why.
   - `bench/baseline.json` — current bench keys and their pinned
     numbers.
   - Recent `git log --oneline -20` to see what's already been
     optimised in main.
   - `CLAUDE.md` "Design boundaries (intentional non-support)" and
     `docs/STATE.md` — distinguish intended behavior from measured limitations.

2. **Profile a representative workload**. Pick ONE of these
   (whichever is most relevant to recent commits):

   ```julia
   # Workload A: rotating-basis split-step (fast-Larmor / Berry / phi_omega)
   using SpinorBEC, Profile
   config = SpinorBEC.load_config("runs/phi_omega_scan/eu151_phi1_0_500ms/config.yaml")
   # Build workspace from ground_state phase (cheap), then profile
   # one dynamics step ~50× to amortise warm-up.
   # ...

   # Workload B: standard split_step on Eu151
   sm = spin_matrices(6)
   grid = make_grid(GridConfig((24,24,24), (10.0,10.0,10.0)))
   # ... build a workspace, run @profile for 50× split_step!(ws) ...
   ```

   Use `Profile.print(format=:flat, mincount=20, sortedby=:count)`
   or `Profile.print(combine=true, sortedby=:count)` — pick whichever
   gives clearer hot-spot ordering.

3. **Identify candidates**. From the profile, list functions that:
   - Take ≥5% of total samples
   - Are NOT already in `bench/baseline.json` (check by greppable
     suffix of the function name)
   - Have a visible optimization pattern (allocations, scalar
     indexing, untyped local, broadcast that could be in-place,
     parallelisable loop, etc.)

4. **For up to 3 candidates** (most-time-consuming first):
   - Write a minimal `@benchmarkable` block at the end of
     `bench/bench_regression.jl`. Use a tiny grid (16³ or 16² × 8)
     so the bench runs in <10 ms. Pre-allocate any buffers in the
     enclosing `let`.
   - Append a queue line to `bench/perf_targets.txt` of the form:
     ```
     <kernel_name>  <bench_key>  <hint with hypothesis on what to optimize>
     ```
     Place it under the latest `# === Round N ===` separator, or
     create `# === Round N+1 (discovery <date>) ===` if appropriate.

5. **Measure and extend the baseline**. Run on the intended benchmark host:
   ```
   julia --project=. bench/bench_regression.jl
   ```
   Merge only newly added benchmark keys from `bench/results.json` into
   `bench/baseline.json`. Preserve every existing value exactly and verify
   that equality before finishing. Replacing the whole baseline would reset
   the regression reference. Separate runs can fluctuate; a sample minimum
   does not guarantee monotonic improvement across runs or hosts. Investigate
   large changes rather than silently re-pinning them.

6. **Verify**: `git diff --stat` should show edits only to:
   `bench/bench_regression.jl`, `bench/perf_targets.txt`,
   `bench/baseline.json`. Compare with the initial working-tree state; correct
   only your own unintended edits and preserve other work.

## Bail conditions

Output `BAIL: <one-sentence reason>` as your final line and DO NOT
edit any files when:

- Profile shows no function ≥5% of time that isn't already in
  baseline.json (perf is exhausted — the loop should stop).
- A candidate would require violating a documented design boundary. For
  `_get_spinor`, measure the actual overload and calling context rather than
  treating an old allocation figure as an exemption.
- You can't construct a meaningful @benchmarkable for the candidate
  (workspace setup is too tangled, requires GPU but bench infra is
  CPU-only, etc.).
- All inspected candidates were below the threshold or lacked a valid target.

## What good output looks like

Last line of your reply must be one of:
- `DISCOVERY_DONE: added N targets (<kernel1>, <kernel2>, ...)`
- `BAIL: <reason>`

Do not commit unless the caller assigned that step. Report the changed files and
validation; do not assume that an external wrapper will review or commit them.

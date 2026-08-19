# Perf-Ralph queue refill (discovery) prompt

You are the **discovery agent** for the perf-Ralph optimization loop.
The kernel-level optimization queue at `bench/perf_targets.txt` has
been exhausted (every active line is `# done` or `# skipped`). Your
job: find the next bottleneck to attack, add it as a new target, and
return so the main loop can pick it up.

## Hard constraints

These come from CLAUDE.md "Conventions (do NOT 'fix')" and "Type
stability boundaries" — same as the per-iteration guardrails.

1. **Do not modify existing entries** in `bench/perf_targets.txt`.
   Append-only.
2. **Do not change existing keys** in `bench/bench_regression.jl` —
   would invalidate the baseline ratchet. Add NEW `@benchmarkable`
   blocks only.
3. **Do not propose targets marked as known-limitations** in
   `CLAUDE.md` "Known limitations / open issues" — those are documented
   design boundaries, not regressions.
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
   - `CLAUDE.md` "Known limitations / open issues" — list of
     intentionally-unfixed boundaries.

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

5. **Re-pin baseline**. Run:
   ```
   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. bench/bench_regression.jl
   cp bench/results.json bench/baseline.json
   ```
   This adds the new keys to baseline.json while keeping the existing
   pinned numbers intact (BenchmarkTools.minimum() is monotone, so
   the existing keys' numbers should be within ±5% of pinned values
   — if they jumped >20%, something is broken; investigate before
   continuing).

6. **Verify**: `git diff --stat` should show edits only to:
   `bench/bench_regression.jl`, `bench/perf_targets.txt`,
   `bench/baseline.json`. If you touched anything else, revert it.

## Bail conditions

Output `BAIL: <one-sentence reason>` as your final line and DO NOT
edit any files when:

- Profile shows no function ≥5% of time that isn't already in
  baseline.json (perf is exhausted — the loop should stop).
- The next hot function is a known-limitations item from CLAUDE.md
  (e.g. an allocation a measurement in CLAUDE.md declares intentional). **Do NOT bail on `_get_spinor` on that ground** — the 352-byte figure this line cited until 2026-08-06 was wrong; the `Val{D}` form allocates 0 in situ and the `n_comp::Int` overload costs ~1.6 kB/call at D=13, which is a real target.
- You can't construct a meaningful @benchmarkable for the candidate
  (workspace setup is too tangled, requires GPU but bench infra is
  CPU-only, etc.).
- 5 candidates ran but all were ≤5% or already-known-limitations.

## What good output looks like

Last line of your reply must be one of:
- `DISCOVERY_DONE: added N targets (<kernel1>, <kernel2>, ...)`
- `BAIL: <reason>`

Do NOT commit. The wrapper script will commit after verifying via
`git diff --stat` that the changes are bench-only.

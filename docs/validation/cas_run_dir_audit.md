# `run_yaml`'s run directory is not content-addressed in the CLAUDE.md sense

Audited 2026-07-31 after the question "the CAS might be wrong" was raised against
the Fig. 4B campaign. **It did not invalidate any result in that campaign** — but
the mechanism is not what commitment #4 describes, and one failure mode is live.

## What it actually does

`compute_run_dir` (`pipeline/run_registry.jl:32`):

```julia
content = read(yaml_path, String)
hash8   = bytes2hex(sha256(content))[1:8]
joinpath(base_dir, "$(basename_no_ext)_$(hash8)")
```

The key is **the raw bytes of the YAML file**, truncated to **8 hex = 32 bits**,
prefixed by the file's basename. It is not `content_id(spec)`. CLAUDE.md
commitment #4 — `<sha256(canonical_bytes(spec))[1:16]>` — describes the
`Experiment(spec)` path, which is a different mechanism. Both exist; only the
`Experiment` one is canonical.

## Consequences, in order of how much they matter

1. **It is over-sensitive, not under-sensitive, on content.** A comment change or
   reordered keys produce a new directory and a wasted recompute. Two *different*
   YAML texts cannot share a directory except by a 32-bit hash collision with a
   matching basename. That is the safe direction: it wastes compute, it does not
   fabricate agreement.

2. **It does not include the code version — and `run_yaml` skips existing point
   files.** Same YAML + a different commit ⇒ same directory ⇒ every point is
   skipped ⇒ **the run silently returns results computed by older code**. This
   is the live hazard, and it is precisely the class the campaign charter was
   written about: a stale result and a fresh one are indistinguishable from the
   directory.

3. **32 bits is thin for a growing store.** Collision probability reaches ~1 % at
   about 9×10³ files sharing a basename, 50 % at 7.7×10⁴. Irrelevant at 18 dirs;
   not irrelevant for a sweep generator that emits thousands of configs under one
   name.

## Did it corrupt the Fig. 4B campaign? No — checked, not assumed

- **18 run directories, 18 distinct `content_id` of their own snapshots.** No two
  runs shared a spec, so nothing could have been read across configs.
- **No `skip` / `cached` / `exists` message in any run log.** Nothing was reused.
- **No point file predates its directory's `config.yaml`.** Every point was
  written by the job that wrote the snapshot beside it.
- Every config edit during the campaign changed the file bytes, so every re-run
  got a fresh directory (`fig4b_scan_n32_a5400826` → `_d99c10a7` when
  `save.every` changed 100 → 108).

The one thing the audit *did* explain: the run-dir suffix never matches
`content_id(snapshot)` for any of the 18, which looked alarming and is simply the
two different keys. The snapshot is written after defaults injection; the name is
hashed from the file before it.

## `content_id` itself is sound

Positive control on `fig4b_scan_n32.yaml`: every deep perturbation moves the id,
including `dt` by 1 part in 10⁷ and a box edge by 6 parts in 10⁵. It also moves
on `metadata.target`, which is over-sensitivity again — safe direction.

## Fixed, 2026-07-31

- **Cached points now require matching provenance.** `_assert_point_provenance`
  refuses to reuse a `point_*.jld2` unless its recorded `env.git_hash` equals
  the current one with neither tree dirty. A point file with no provenance at all
  — every one written before today — is refused too, since unknown provenance is
  exactly the case this exists for. Override with
  `SPINORBEC_ALLOW_STALE_POINTS=1`, which is right for a docs-only commit and
  wrong for anything else. Folding the commit into the *directory key* was the
  alternative and was rejected: it would orphan a 12-hour run on a typo fix.
- **The suffix is 16 hex**, matching commitment #4. Every future directory is
  renamed, so runs cached under the old 8-hex name are recomputed once.
- **CLAUDE.md commitment #4 now describes both mechanisms** instead of reading as
  if `run_yaml` used `content_id`.
- Gated by `test/workflow/test_run_dir_provenance_gate.jl` (tier `fast`), whose
  first assertion is the positive control — a matching clean provenance must be
  ALLOWED, or every other assertion would pass against a gate that rejects
  everything.

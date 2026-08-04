# Dashboard performance notes

> **FROZEN 2026-07-31.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

The 2D scrubber pipeline is currently bottlenecked by the display refresh rate (60 Hz / 16.67 ms per frame). The remaining latency sources below are all on the cold-start / startup-latency side; none of them affect the steady-state scrub experience.

## Opt-in: bsz=1 atlas compression for slow links

The atlas endpoint accepts `?bsz=1`, which returns a bitshuffle + zstd-3 compressed binary (Klaus 64×64 atlas: 46 MB → 36 MB, ~21 % smaller).

Useful when the dashboard is reached over LAN / SSH tunnel where the 46 MB raw atlas dominates the load time. Not enabled by default because:

- Browser native zstd decoding requires Chrome 123+ and a custom protocol (`Content-Encoding: zstd`); we use a custom `BSZ1` wrapper that the browser can't auto-decode.
- Implementing JS-side decoding adds the `fzstd` npm dep (~10 KB) and ~30 lines of unbitshuffle code.
- On localhost the compression cost (~1 s on first compute, server-cached thereafter) eats the bandwidth saving entirely.

To wire it up:

```ts
// dashboard/src/workers/atlasWorker.ts
import { decompress as fzstdDecompress } from 'fzstd'

function decodeBszAtlas(buf: ArrayBuffer): ArrayBuffer {
  const magic = new Uint8Array(buf, 0, 4)  // 'BSZ1'
  const hdr = new Int32Array(buf, 4, 2)
  const origSize = hdr[0]
  const esize = hdr[1]
  const compressed = new Uint8Array(buf, 12)
  const shuffled = fzstdDecompress(compressed)
  // unbitshuffle: byte b of element i is at shuffled[b * n_elem + i]
  const out = new Uint8Array(origSize)
  const n_elem = origSize / esize
  for (let b = 0; b < esize; b++) {
    for (let i = 0; i < n_elem; i++) {
      out[i * esize + b] = shuffled[b * n_elem + i]
    }
  }
  return out.buffer
}
```

## Future: PackageCompiler sysimage

`Pkg.add("PackageCompiler"); using PackageCompiler; create_sysimage(:SpinorBEC; sysimage_path = "build/spinorbec_sysimg.so", precompile_execution_file = "scripts/dashboard_warmup.jl")` would shave the first-call JIT (~12 s) down to ~1-2 s.

Not enabled by default because:

- The image is ~500 MB on disk
- Build takes 10+ minutes
- Has to be re-built whenever any dep version changes
- Existing PrecompileTools workload already gets the dashboard hot-path to ~0.23 s on first request

Worth doing for production deployments where the dashboard is part of a long-running server (and restart latency matters), not so much for dev.

## Skipped: SharedArrayBuffer + COOP/COEP

The atlas worker already transfers the `Float32Array` buffers zero-copy via `postMessage`'s transfer list, so SharedArrayBuffer would only matter if main + worker needed to *concurrently* mutate the same buffer. We don't.

## Disk-cache layout

Atlases are persisted to `runs/_dashboard_cache/atlas__<run>__<file>__axis<N>__bsz<true|false>.bin` (example). Stale check: if the source `.jld2` mtime is newer than the cache file, the cache is silently rebuilt. To wipe everything, `rm -rf runs/_dashboard_cache` (example).

## Bench targets (Klaus F=8, 64×64×32, 157 snaps)

| metric                         | value         | notes                          |
|--------------------------------|---------------|--------------------------------|
| /api/density_atlas warm        | 9–13 ms       | 46 MB single fetch             |
| /api/density_atlas cold (no disk cache) | ~1.4 s | server pack one-time         |
| /api/density_atlas cold (with disk cache, restart) | 9–13 ms | mtime-validated read |
| Per-frame scrub (atlas mode)   | ~0.5 ms       | uniform write, no fetch        |
| Initial JS bundle (gzip)       | ~85 KB index + 33 KB radix + 4 KB lucide + 7 KB state | parallel download |
| Three.js chunk (gzip, lazy)    | 417 KB        | only when 3D tab opens         |
| Syntax highlighter (gzip, lazy)| 1.68 MB       | only when Config tab opens     |

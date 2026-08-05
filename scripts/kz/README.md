# KZ / SPGPE measurement scripts

`sync_tsubame.sh` is the only way these reach the cluster. It refuses a dirty
local tree, pushes, `git reset --hard`es the remote to the pushed SHA, runs
`git clean -fd`, and verifies both the SHA and cleanliness before returning.

Everything a job reads must therefore be committed here. That is the point: on
2026-08-04 six one-off job scripts existed only on the remote side, so a
measurement's inputs were partly outside history, and separately two rsyncs had
silently not landed — the remote `spgpe.jl` matched neither the commit nor what I
believed I had sent. Both were caught by comparing md5s by hand.

| script | what it measures |
|---|---|
| `submit_kz_torus.sh` | single-process modes of `kz_toroidal_winding.jl` (smoke, conv, freeze, size) |
| `submit_kz_torus_sharded.sh` | production scans, 16 processes strided over trajectories |
| `run_mdamp.sh` | does the energy-damping reservoir shift the equilibrium `N`? |
| `run_mdampfdr.sh` | does it preserve the Rayleigh–Jeans spectrum at `γ = 0`? |
| `run_mdampproj.sh` | is the loss the term or its composition with the projector? |
| `run_mdampdt.sh` | loss rate vs `dt` and `ℳ̄` — flat in `dt`, linear in `ℳ̄` |
| `run_mdamplong.sh` | does the residual leak accumulate over `10⁵` time units with `γ > 0`? |
| `classical_field_tc.jl`, `ramp_design.jl` | `T_c` and rate/cutoff sizing for the protocol |

Results and their interpretation: `docs/validation/spgpe_kz_reproduction.md`.
Literature basis for each protocol choice: `docs/design/kz_spgpe_protocol.md`.

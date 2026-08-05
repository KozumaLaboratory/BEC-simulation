# Operator-RHS export manifest

> **FROZEN 2026-05-26.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Generated: 2026-05-26T02:42:10.753
Wall-time: 180.89 s

## Inputs
- YAML: `reference_state.yaml`
- YAML sha256: 16419ba22b6b8b13e2564d279f85b134b79363a466a0cb6711c9f1198a24cb3e

## Outputs
- JLD2: `operator_rhs.jld2`
- JLD2 sha256: 9d38af7e5d52fe7aebe4fe53b1930004b95ebdb8603f9d917b360ce714bc6c35

## Environment
- git commit: `617b700235d0c639a70b5190274ec2f37f189599`
- Julia version: 1.12.6
- Manifest.toml sha256: 2937ed959badebd90e3e31a9c3e52ea30eb3f08d995e4f6671f3f2249a71654f

## Cross-code comparison

To compare against an external code (e.g. Ueda lab):

1. Confirm `docs/validation/parameter_contract_with_Ueda.md` is
   signed off on both sides — every convention row must match
   or have a documented transformation.
2. Send the receiver: this MANIFEST, the YAML, and the JLD2.
3. Receiver builds the same physical setup, produces their own
   `operator_rhs.jld2`.
4. Run:

       julia --project=. scripts/validation/compare_operator_rhs.jl \
         operator_rhs.jld2 <theirs.jld2>

Acceptance (Level 10 PASS):
- per-term `|E_ours - E_theirs| / |E_total| < 1e-10`
- `‖Hψ_ours - Hψ_theirs‖_L² / ‖Hψ_ours‖_L² < 1e-10`

If diff is ~1e-2 or larger, the bug is NOT in K3/LHY/long-time
integration. It is in a convention row. Read down the contract.

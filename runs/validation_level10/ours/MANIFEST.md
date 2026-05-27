# Operator-RHS export manifest

Generated: 2026-05-25T07:39:30.942
Wall-time: 109.12 s

## Inputs
- YAML: `L10_F1_smoke.yaml`
- YAML sha256: 8fdcb77ba3bc88b5c0e507806177f0205f00c78ea6ddbd7e63bf6cf9882d56e8

## Outputs
- JLD2: `operator_rhs.jld2`
- JLD2 sha256: b618154f27cbc5ea8d1f2fe148578bdefb2c8abcb9e6aa46bd19bc42feff3c56

## Environment
- git commit: `735923335bd65e8a9bd057cdd2caa7fab5a4feb2`
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

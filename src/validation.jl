# --- Validation subsystem umbrella ---
#
# Independent, deliberately-redundant statements of the Hamiltonian used
# as diff oracles for the self-contained validation chain (architectural
# commitment #3 — gated redundancy; the duplication IS the oracle):
#
#   reference_rhs  — independent term-by-term Hψ + per-term energy; the
#       diff oracle behind test/test_reference_rhs.jl (replaces the
#       BLOCKED_EXTERNAL Ueda-comparison path, docs/validation/ueda_status.md).
#   dumb_reference — blatantly-correct full energy/RHS per term; the
#       master-oracle anchor (test/oracles/test_master_oracle.jl).
#
# See docs/design/hamiltonian_layered_architecture.md.

include("validation/reference_rhs.jl")
include("validation/dumb_reference.jl")
include("validation/validation_matrix.jl")
include("validation/matsui_fig4b_report.jl")

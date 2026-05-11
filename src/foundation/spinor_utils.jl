# --- Spinor / Euler-rotation utilities umbrella ---
#
# 443-line monolith split into 4 sub-files (2026-05-11 refactor):
#
#   spinor_utils/slice_helpers.jl    — _component_slice, _get_spinor /
#                                       _set_spinor! (n_comp + Val(D)),
#                                       _exp_i_hermitian, _matvec
#   spinor_utils/euler_per_voxel.jl  — _apply_euler_spin_rotation
#                                       (per-voxel CPU Zeeman rotation)
#   spinor_utils/euler_batched.jl    — _apply_euler_5stage_batched_real! +
#                                       _apply_euler_5stage_batched_imag!
#                                       (CPU-batched gemm form)
#   spinor_utils/euler_fused.jl      — apply_euler_5stage_fused!
#                                       (GPU-friendly fused-broadcast form
#                                       with optional cis_PD scratch)
#
# None of these symbols are exported; they're internal helpers consumed
# from inside SpinorBEC's diagonal / spin-mixing / raman propagators.

include("spinor_utils/slice_helpers.jl")
include("spinor_utils/euler_per_voxel.jl")
include("spinor_utils/euler_batched.jl")
include("spinor_utils/euler_fused.jl")

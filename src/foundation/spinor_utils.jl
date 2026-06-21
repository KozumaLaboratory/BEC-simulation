# --- Spinor / Euler-rotation utilities umbrella ---
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
#   spinor_utils/uniform_rotation.jl — apply_uniform_spin_rotation!
#                                       (spatially uniform spin rotation;
#                                       shared by transverse Zeeman, Raman,
#                                       rotating basis)
#   spinor_utils/frame_rotation.jl   — _apply_UB! (lab↔field-following Û_B(t)
#                                       transform; used by the magnetostir
#                                       pipeline handlers)
#
# The euler helpers are internal, consumed from inside SpinorBEC's
# diagonal / spin-mixing / raman propagators; apply_uniform_spin_rotation!
# is exported.

include("spinor_utils/slice_helpers.jl")
include("spinor_utils/euler_per_voxel.jl")
include("spinor_utils/euler_batched.jl")
include("spinor_utils/euler_fused.jl")
include("spinor_utils/uniform_rotation.jl")
include("spinor_utils/frame_rotation.jl")

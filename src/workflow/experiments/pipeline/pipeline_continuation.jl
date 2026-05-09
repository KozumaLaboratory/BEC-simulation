# --- Continuation helpers (auto-rotate, warm start) ---

"""
    auto_rotate_psi(psi, patched_data, prev_mz; F_default=6) -> psi

Rotate the quantization axis of `psi` when `target_magnetization` changes
between scan points. Returns a rotated copy, or the original if no rotation
is needed.
"""
function auto_rotate_psi(psi, patched_data::Dict, prev_mz::Float64; F_default::Int=6)
    isnan(prev_mz) && return psi

    gs_params = let pipe = get(patched_data, "pipeline", [])
        isempty(pipe) ? Dict() : first(values(pipe[1]))
    end
    target_mz = get(gs_params, "target_magnetization", nothing)
    target_mz === nothing && return psi

    F_atom =
        gs_params isa Dict ? resolve_atom(Symbol(get(gs_params, "atom", "Eu151"))).F : F_default
    α_target = acos(clamp(-Float64(target_mz) / F_atom, -1.0, 1.0))
    α_prev = acos(clamp(-prev_mz / F_atom, -1.0, 1.0))
    Δα = α_target - α_prev

    abs(Δα) > 1e-12 ? rotate_quantization_axis(psi, F_atom, 0.0, Δα) : psi
end

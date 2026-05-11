# GPU-friendly fused-broadcast Euler 5-stage rotation. Operates on the
# `(N, D)` whole-array layout via `(N, 1) .* (1, D)` broadcasts so each
# stage is a single CUDA kernel launch (vs. D per-column launches in the
# legacy per-component path). `cis_PD` scratch keeps phase materialisation
# in-place for CUDA Graph capture compatibility.

"""
    apply_euler_5stage_fused!(P, W, α_col, β_col, θ_col,
                               m_row, m_shift_row, λ_row,
                               V_T, conj_V; imaginary_time=false)

Whole-array Euler 5-stage rotation `R_z(α) R_y(β) D_z(θ) R_y(-β) R_z(-α)`
applied across an `(N, D)` per-point spinor field `P` using the fused
broadcast pattern `(N, 1) .* (1, D)`. Matches the per-point CPU
`_apply_euler_spin_rotation` exactly (Step 1 = `cis(+m·α)`, Step 5 =
`cis(-m·α)`); GPU paths previously each rolled their own copy of this
sequence with subtle sign drift (caught 2026-04-26 in the GPU
spin_mixing / raman audits).

Arguments
=========
- `P` : `(N, D)` spinor field, mutated in place to hold the rotated state.
- `W` : same shape as `P`, scratch buffer for V†ψ.
- `α_col, β_col, θ_col` : `(N, 1)` per-point rotation angles.
- `m_row` : `(1, D)` magnetic quantum numbers `[F, F-1, …, -F]`.
- `m_shift_row` : `(1, D)`, equals `m_row .- F`. Used for the imaginary-time
  branch's overflow-safe diagonal step.
- `λ_row` : `(1, D)` ascending Fy eigenvalues `[-F, -F+1, …, F]`.
- `V_T, conj_V` : Fy eigenvector matrix and its conjugate, in the
  layout that backs the existing `mul!(W, P, conj_V)` / `mul!(P, W, V_T)`
  call sites (so this works for both CPU `Matrix` and GPU `CuArray`
  backings — the `mul!` dispatches to cuBLAS for `CuArray`).

The fused pattern collapses 5D per-call broadcasts (D phases × 5 steps,
each previously a per-column kernel launch on GPU) into 5 single
launches, regardless of D. For F=6 that's a 13× reduction in launches
on the rotation block.
"""
@inline function apply_euler_5stage_fused!(
    P, W,
    α_col, β_col, θ_col,
    m_row, m_shift_row, λ_row,
    V_T, conj_V;
    imaginary_time::Bool=false,
    cis_PD=nothing,
)
    # `cis_PD` (size of P, Complex) is a pre-allocated scratch for the
    # phase factor `cis(...)` so the broadcasts stay in-place — required
    # for any future CUDA Graph capture, since per-call `cis.(...)`
    # would allocate a fresh CuArray each invocation and invalidate the
    # captured argument pointer. When nothing is supplied (legacy CPU
    # fallback / one-shot calls) we let Julia allocate, matching prior
    # behaviour.
    if cis_PD === nothing
        P .*= cis.(m_row .* α_col)
        mul!(W, P, conj_V)
        W .*= cis.(β_col .* λ_row)
        mul!(P, W, V_T)
        if imaginary_time
            P .*= exp.(.-m_shift_row .* θ_col)
        else
            P .*= cis.(.-m_row .* θ_col)
        end
        mul!(W, P, conj_V)
        W .*= cis.(.-β_col .* λ_row)
        mul!(P, W, V_T)
        P .*= cis.(.-m_row .* α_col)
    else
        # Step 1: R_z(-α) via in-place cis scratch
        @. cis_PD = cis(m_row * α_col)
        @. P *= cis_PD
        # Step 2: R_y(-β) via Vt
        mul!(W, P, conj_V)
        @. cis_PD = cis(β_col * λ_row)         # reuse same scratch on W (same shape)
        @. W *= cis_PD
        mul!(P, W, V_T)
        # Step 3: D_z(θ)
        if imaginary_time
            @. cis_PD = exp(-m_shift_row * θ_col)
        else
            @. cis_PD = cis(-m_row * θ_col)
        end
        @. P *= cis_PD
        # Step 4: R_y(β)
        mul!(W, P, conj_V)
        @. cis_PD = cis(-β_col * λ_row)
        @. W *= cis_PD
        mul!(P, W, V_T)
        # Step 5: R_z(α)
        @. cis_PD = cis(-m_row * α_col)
        @. P *= cis_PD
    end
    nothing
end

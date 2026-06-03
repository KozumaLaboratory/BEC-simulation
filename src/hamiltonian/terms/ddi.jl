# --- DDI HamTerm ---
#
# Dipole-dipole interaction. H_DDI = (1/2) ∫ d³r d³r' (c_dd / |r-r'|³)
# [F(r)·F(r') - 3(F(r)·r̂)(F(r')·r̂)] per CLAUDE.md "DDI: c_dd=μ₀μ²".
# Convention is fixed (do NOT "fix").

"""Magnetic dipole-dipole interaction."""
struct DDI <: HamTerm end

function apply_step!(::DDI, psi, dt::Real, imaginary_time::Bool, ws)
    ws.ddi === nothing && return nothing
    N = ndims(psi) - 1
    if ws.ddi_padded !== nothing
        apply_ddi_step!(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt, N, ws.ddi_padded;
            imaginary_time=imaginary_time)
    else
        apply_ddi_step!(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs, dt, N;
            imaginary_time=imaginary_time)
    end
    return nothing
end

function energy_contribution(::DDI, psi::AbstractArray{<:Complex}, ws)
    ws.ddi === nothing && return 0.0
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    n_comp = size(psi, N + 1)
    dV = cell_volume(ws.grid)
    if _is_gpu(ws.ddi_bufs.Fx_r)
        return _ddi_energy_from_gpu(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs,
            n_comp, N, n_pts, dV; ddi_padded=ws.ddi_padded)
    else
        return _ddi_energy(psi, ws.spin_matrices, ws.ddi, ws.ddi_bufs,
            n_comp, N, n_pts, dV; ddi_padded=ws.ddi_padded)
    end
end

function add_gradient!(grad, ::DDI, psi, ws)
    ws.ddi === nothing && return nothing
    N = ndims(psi) - 1
    n_pts = ntuple(d -> size(psi, d), Val(N))
    D = ws.spin_matrices.system.n_components
    _grad_ddi!(grad, psi, ws, n_pts, D, Val(N))
    return nothing
end

sign_oracle(::Type{DDI}) = (
    name="DDI: c_dd>0 → oblate-favorable alignment",
    predicate=(_, _) -> true,
)

"""
Apply density-dependent loss step (dipolar relaxation + optional 3-body).

Dipolar relaxation rate per component m for downward Δm transitions (Δm = -1, -2):

  γ_m = Γ_dr × Σ_{q ∈ {-1,-2}} |⟨F,m+q|T²_q|F,m⟩|² / Z

where Z normalizes so the average rate per component equals Γ_dr.

m = -F is stable (no downward transitions exist).

3-body loss L3 is m-independent.

Applied as: ψ_m → ψ_m × exp(-rate_m × n(r) × dt / 2)
"""
function apply_loss_step!(
    psi::AbstractArray{<:Complex},
    loss::LossParams,
    F::Int,
    dt::Float64,
    n_components::Int,
    ndim::Int,
)
    n_pts = ntuple(d -> size(psi, d), ndim)
    buf = zeros(Float64, n_pts)
    apply_loss_step!(psi, loss, F, dt, n_components, ndim, buf)
end

function apply_loss_step!(
    psi::AbstractArray{<:Complex},
    loss::LossParams,
    F::Int,
    dt::Float64,
    n_components::Int,
    ndim::Int,
    density_buf::AbstractArray{<:AbstractFloat},
)
    L3_scalar_max = isempty(loss.L3_per_m) ? loss.L3 : maximum(abs, loss.L3_per_m)
    K3_scalar_max = isempty(loss.K3_per_m_cubic) ? loss.K3_cubic :
        maximum(abs, loss.K3_per_m_cubic)
    has_evap = loss.evap_rate > 1e-30 && loss.evap_energy_cutoff > 0
    if loss.gamma_dr < 1e-30 && L3_scalar_max < 1e-30 &&
       K3_scalar_max < 1e-30 && !has_evap
        return nothing
    end

    if !isempty(loss.L3_per_m) && length(loss.L3_per_m) != n_components
        throw(ArgumentError(
            "LossParams.L3_per_m length $(length(loss.L3_per_m)) " *
            "≠ n_components $(n_components)"))
    end
    if !isempty(loss.K3_per_m_cubic) && length(loss.K3_per_m_cubic) != n_components
        throw(ArgumentError(
            "LossParams.K3_per_m_cubic length $(length(loss.K3_per_m_cubic)) " *
            "≠ n_components $(n_components)"))
    end

    n_pts = ntuple(d -> size(psi, d), ndim)
    _total_density!(density_buf, psi, n_components, ndim, n_pts)

    gamma_rates = _dipolar_relaxation_rates(F, loss.gamma_dr)

    for c = 1:n_components
        L3_c = isempty(loss.L3_per_m) ? loss.L3 : loss.L3_per_m[c]
        K3_c = isempty(loss.K3_per_m_cubic) ? loss.K3_cubic : loss.K3_per_m_cubic[c]
        gamma_lin_rate = gamma_rates[c] + L3_c     # 2-body / linear-in-n channel

        idx = _component_slice(ndim, n_pts, c)
        psi_view = view(psi, idx...)
        if gamma_lin_rate >= 1e-30
            # exp(-γ_lin · n_total · dt / 2)  → dn_m/dt = -γ_lin n n_m  (2-body shape)
            @. psi_view *= exp(-gamma_lin_rate * density_buf * dt / 2)
        end
        if K3_c >= 1e-30
            # exp(-K_3 · n_total² · dt / 2)  → dn_m/dt = -K_3 n² n_m  (true 3-body)
            @. psi_view *= exp(-K3_c * density_buf * density_buf * dt / 2)
        end
    end

    # --- Energy-selective evaporation (Phase 4 #40) -------------------
    # Atoms in cells where the local "energy estimator" |ψ|² · n_total
    # exceeds `evap_energy_cutoff` are removed at rate `evap_rate`. The
    # estimator is the contact mean-field energy density which works as a
    # local-temperature proxy for trap-knife evaporation.
    if has_evap
        cut = loss.evap_energy_cutoff
        rate = loss.evap_rate
        for c = 1:n_components
            idx = _component_slice(ndim, n_pts, c)
            psi_view = view(psi, idx...)
            # element-wise: |ψ_c|² · n_tot > cut → multiply by exp(-rate·dt/2)
            @. psi_view *=
                ifelse(abs2(psi_view) * density_buf > cut,
                       exp(-rate * dt / 2),
                       one(eltype(psi_view)))
        end
    end
    nothing
end

"""
Compute m-resolved dipolar relaxation rates γ_m for all 2F+1 components.

DDI is a rank-2 tensor, allowing Δm = -1, -2 relaxation transitions (atoms lose
Zeeman energy → gain kinetic energy → escape). Upward (Δm > 0) and elastic (Δm = 0)
transitions are excluded since they don't release energy at low temperature.

  γ_m = Γ_dr × Σ_{q ∈ {-1,-2}} |CG(F,m; 2,q | F,m+q)|² / Z

Normalization: average rate per component = Γ_dr. m = -F is stable (no downward
transitions exist).
"""
function _dipolar_relaxation_rates(F::Int, gamma_dr::Float64)
    D = 2F + 1
    raw = Vector{Float64}(undef, D)

    raw_sum = 0.0
    for c = 1:D
        m = F - (c - 1)
        s = 0.0
        for q in (-1, -2)
            mp = m + q
            abs(mp) > F && continue
            cg = clebsch_gordan(F, m, 2, q, F, mp)
            s += cg * cg
        end
        raw[c] = s
        raw_sum += s
    end

    raw_sum < 1e-30 && return zeros(Float64, D)

    Z = raw_sum / D
    [gamma_dr * raw[c] / Z for c = 1:D]
end

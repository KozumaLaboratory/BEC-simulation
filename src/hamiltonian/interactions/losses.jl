export apply_loss_step!

"""
    apply_loss_step!(psi, loss, F, dt, n_components, ndim[, density_buf])

Apply a half-step of density-dependent loss to a spinor wavefunction in place.
Used inside the split-step propagator between V/T substeps.

Four independent channels, applied multiplicatively (each as `exp(-rate·dt/2)`):

| Channel           | LossParams field                    | Form                            | Used for                |
|-------------------|-------------------------------------|---------------------------------|-------------------------|
| Dipolar relaxation | `gamma_dr`                         | `exp(-γ_m · n_tot · dt / 2)`    | Δm = -1, -2 transitions |
| 2-body (linear)   | `L3` / `L3_per_m`                   | `exp(-γ_lin · n_tot · dt / 2)`  | linear-in-n loss        |
| 3-body (true)     | `K3_cubic` / `K3_per_m_cubic`       | `exp(-K_3 · n_tot² · dt / 2)`   | quadratic-in-n loss     |
| Evaporation       | `evap_rate`, `evap_energy_cutoff`   | `exp(-rate·dt/2)` if `\\|ψ_c\\|²·n_tot > cut` | RF-knife |

`n_tot(r) = Σ_m |ψ_m(r)|²` is the total density at each spatial point. The
γ_lin (dipolar + 2-body linear) and K_3 (true 3-body) branches are combined
via the `L3_per_m`/`K3_per_m_cubic` per-component vectors so different m_F
states can have different rates.

Dipolar relaxation: rank-2 DDI tensor allows Δm = -1, -2 transitions only.
`γ_m = Γ_dr · Σ_{q ∈ {-1,-2}} |CG(F,m; 2,q | F,m+q)|² / Z`, normalized so the
average rate across components equals Γ_dr. The m = -F (deepest Zeeman state)
is stable.

The K3_cubic channel is the **physically correct 3-body** form (Lindblad-
derivable). `L3` / `L3_per_m` exist for backward compat with calibrated
2-body-shape data — use `K3_*` for new code. See LossParams docstring.

`density_buf` is an optional scratch array (size = `size(psi)[1:ndim]`); pass
to avoid allocating one per call inside hot loops.

Early-exits when all rates are below 1e-30. Per-m vectors are validated
against `n_components`.
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

"""
    _is_active(loss::LossParams) -> Bool

True if any channel (γ_dr, L3, K3, evap) has a rate above 1e-30. Used as
the early-exit gate in `apply_loss_step!` and as a primer target in
`src/precompile.jl` so the cold-JIT path is already specialised when the
first dynamics step runs.
"""
function _is_active(loss::LossParams)
    L3_scalar_max = isempty(loss.L3_per_m) ? loss.L3 : maximum(abs, loss.L3_per_m)
    K3_scalar_max = isempty(loss.K3_per_m_cubic) ? loss.K3_cubic :
                    maximum(abs, loss.K3_per_m_cubic)
    has_evap = loss.evap_rate > 1e-30 && loss.evap_energy_cutoff > 0
    return loss.gamma_dr >= 1e-30 || L3_scalar_max >= 1e-30 ||
           K3_scalar_max >= 1e-30 || has_evap
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
    _is_active(loss) || return nothing
    has_evap = loss.evap_rate > 1e-30 && loss.evap_energy_cutoff > 0

    if !isempty(loss.L3_per_m) && length(loss.L3_per_m) != n_components
        throw(
            ArgumentError(
                "LossParams.L3_per_m length $(length(loss.L3_per_m)) " *
                "≠ n_components $(n_components)"),
        )
    end
    if !isempty(loss.K3_per_m_cubic) && length(loss.K3_per_m_cubic) != n_components
        throw(
            ArgumentError(
                "LossParams.K3_per_m_cubic length $(length(loss.K3_per_m_cubic)) " *
                "≠ n_components $(n_components)"),
        )
    end

    n_pts = ntuple(d -> size(psi, d), ndim)
    _total_density!(density_buf, psi, n_components, ndim, n_pts)

    gamma_rates = _dipolar_relaxation_rates(F, loss.gamma_dr)

    for c in 1:n_components
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
        for c in 1:n_components
            idx = _component_slice(ndim, n_pts, c)
            psi_view = view(psi, idx...)
            # element-wise: |ψ_c|² · n_tot > cut → multiply by exp(-rate·dt/2)
            @. psi_view *= ifelse(abs2(psi_view) * density_buf > cut,
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

The F-dependent shape `raw[c] / Z` is cached per F (the only CG-dependent
quantity); scaling by `gamma_dr` is trivial. Avoids ~D vector allocations and
~2D CG lookups per apply_loss_step! call inside the simulation hot loop.
"""
function _dipolar_relaxation_rates(F::Int, gamma_dr::Float64)
    shape = _dipolar_relaxation_shape(F)
    [gamma_dr * s for s in shape]
end

# F → normalized γ-shape vector (raw[c] / Z), cached. Single-threaded by
# construction (simulation loops are not thread-parallel for this kernel).
const _DIPOLAR_RELAX_SHAPE_CACHE = Dict{Int, Vector{Float64}}()

function _dipolar_relaxation_shape(F::Int)
    cached = get(_DIPOLAR_RELAX_SHAPE_CACHE, F, nothing)
    cached === nothing || return cached

    D = 2F + 1
    raw = Vector{Float64}(undef, D)
    raw_sum = 0.0
    for c in 1:D
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

    shape = if raw_sum < 1e-30
        zeros(Float64, D)
    else
        Z = raw_sum / D
        [raw[c] / Z for c in 1:D]
    end
    _DIPOLAR_RELAX_SHAPE_CACHE[F] = shape
    shape
end

"""
    compute_spinor_lhy_two_channel(; F, c0, c1, c_dd, n_max, n_points) → SpinorLHYTable

Simplified two-channel LHY: density (g_d=c0) and spin (g_s=c1) channels.

ε_LHY = (8/15π²) [g_d^{5/2} n^{5/2} Q5(ε_dd) + 2F |g_s|^{5/2} n^{5/2}]

The potential V_LHY = dε_LHY/dn is tabulated via central differences.
"""
function compute_spinor_lhy_two_channel(;
    F::Int,
    c0::Float64,
    c1::Float64,
    c_dd::Float64=0.0,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))

    eps_dd = abs(c0) > 1e-30 ? c_dd / c0 : 0.0
    Q5 = lima_pelster_Q5(eps_dd)

    densities = collect(range(0.0, n_max; length=n_points))

    prefactor = 8.0 / (15.0 * Float64(π)^2)
    energy = zeros(Float64, n_points)

    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        n52 = n^2 * sqrt(n)
        density_part = abs(c0) > 1e-30 ? abs(c0)^(5 / 2) * n52 * Q5 : 0.0
        spin_part = abs(c1) > 1e-30 ? 2.0 * F * abs(c1)^(5 / 2) * n52 : 0.0
        energy[i] = prefactor * (density_part + spin_part)
    end

    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:two_channel, densities, potential_values)
end

"""
    compute_spinor_lhy_table(; spinor, F, interactions, zeeman, c_dd,
                               n_max, n_points, k_max, n_k) → SpinorLHYTable

Full BdG-based spinor LHY: at each density, compute zero-point energy from
the Bogoliubov spectrum and tabulate V_LHY = dε_LHY/dn.
"""
function compute_spinor_lhy_table(;
    spinor::Vector{ComplexF64},
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    n_max::Float64=100.0,
    n_points::Int=100,
    k_max::Float64=20.0,
    n_k::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)

    for (i, n0) in enumerate(densities)
        n0 < 1e-30 && continue
        energy[i] = _compute_lhy_at_density(spinor, n0, F, interactions, zeeman, c_dd, k_max, n_k)
    end

    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:full_bdg, densities, potential_values)
end

"""
Compute BdG zero-point energy at a single density:
ε_LHY(n) = (1/2) × (1/2π²) ∫ dk k² Σ_b [ω_b(k) - ε_k - μ_b + μ²_b/(2ε_k)]
"""
function _compute_lhy_at_density(
    spinor, n0, F, interactions, zeeman, c_dd, k_max, n_k
)
    D = 2F + 1
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)

    if abs(c_dd) > 1e-30
        sm = spin_matrices(F)
        n_dir = 6
        dirs = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0),
            (-1.0, 0.0, 0.0), (0.0, -1.0, 0.0), (0.0, 0.0, -1.0)]
    else
        n_dir = 1
        dirs = [(0.0, 0.0, 1.0)]
        sm = nothing
    end

    mu = real(sum(c -> (zee[c] + n0 * h_mf[c, c]) * abs2(spinor[c]), 1:D))

    k_values = collect(range(1e-6, k_max; length=n_k))
    dk = k_values[2] - k_values[1]

    E_total = 0.0
    for dir in dirs
        h_total = copy(h_mf)
        M_total = copy(M_anom)

        if abs(c_dd) > 1e-30
            k_hat = collect(dir)
            k_norm = norm(k_hat)
            k_norm > 0 && (k_hat ./= k_norm)
            Q_ab = _q_tensor_direction(k_hat)
            h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
            h_total .+= h_ddi
            M_total .+= M_ddi
        end

        for k in k_values
            ek = k^2 / 2

            L = 2n0 .* h_total
            for i in 1:D
                L[i, i] += ek - mu + zee[i]
            end
            M_sc = n0 .* M_total

            H_bdg = zeros(ComplexF64, 2D, 2D)
            H_bdg[1:D, 1:D] .= L
            H_bdg[1:D, (D + 1):2D] .= M_sc
            H_bdg[(D + 1):2D, 1:D] .= .-conj.(M_sc)
            H_bdg[(D + 1):2D, (D + 1):2D] .= .-conj.(L)

            evals = eigvals(H_bdg)
            zpe = 0.0
            for ev in evals
                omega = real(ev)
                omega > 1e-10 || continue
                mu_b = ek + n0 * real(h_total[1, 1]) - mu + zee[1]
                correction = omega - ek - mu_b + mu_b^2 / (2.0 * max(ek, 1e-30))
                zpe += 0.5 * correction
            end

            E_total += k^2 * zpe * dk / (2.0 * Float64(π)^2)
        end
    end

    E_total / n_dir
end

function _numerical_derivative(x::Vector{Float64}, y::Vector{Float64})
    n = length(x)
    dy = zeros(Float64, n)
    n < 2 && return dy

    dy[1] = (y[2] - y[1]) / (x[2] - x[1])
    dy[n] = (y[n] - y[n - 1]) / (x[n] - x[n - 1])
    for i in 2:(n - 1)
        dy[i] = (y[i + 1] - y[i - 1]) / (x[i + 1] - x[i - 1])
    end
    dy
end

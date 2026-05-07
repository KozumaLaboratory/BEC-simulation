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
    spinor, n0, F, interactions, zeeman, c_dd, k_max, n_k;
    n_dir::Int=32,
)
    D = 2F + 1
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)

    if abs(c_dd) > 1e-30
        # The LHY zero-point integral inherits the DDI's k̂-anisotropy via
        # `_q_tensor_direction(k̂)` — the spherical average of the per-mode
        # ω_b(k) is anisotropic, so direction sampling matters. The earlier
        # 6-axis octahedron is exact only for `ℓ ≤ 3`; the DDI Q-tensor
        # mixes `ℓ = 0, 2` and BdG correction adds `ℓ ≤ 4`. Switch to a
        # quasi-uniform Fibonacci-spiral grid (default 32 = 64 antipodal
        # samples) so the integration error stops dominating the absolute
        # LHY shift. Caller can tune `n_dir` for tight budget.
        sm = spin_matrices(F)
        dirs = fibonacci_sphere_directions(n_dir)
        n_dir = length(dirs)
    else
        n_dir = 1
        dirs = [(0.0, 0.0, 1.0)]
        sm = nothing
    end

    # μ = ⟨ψ|(Z + n0 h_mf)|ψ⟩ — the diagonal-only `sum(...|ψ_c|²)` form
    # was correct only for single-m states. Mirrors the matching fix in
    # phases/bogoliubov.jl (2026-04-26).
    H_mu_lhy = Diagonal(zee) .+ n0 .* h_mf
    mu = real(dot(spinor, H_mu_lhy * spinor))

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

            # mu_b is the per-branch large-k asymptote subtracted to make
            # the LHY k-integrand convergent. For each ω-branch we find
            # the dominant spinor component c* of the BdG eigenvector and
            # use the matching diagonal entry — was hard-coded to c=1
            # (m=+F), which only holds for a fully polarized GS along +z.
            evals_full = eigen(H_bdg)
            evals = evals_full.values
            evecs = evals_full.vectors
            zpe = 0.0
            for (eb, ev) in enumerate(evals)
                omega = real(ev)
                omega > 1e-10 || continue
                # particle-branch lives in the upper D rows; pick the
                # dominant component there to label the asymptote
                u_part = view(evecs, 1:D, eb)
                c_star = argmax(abs2.(u_part))
                mu_b = ek + n0 * real(h_total[c_star, c_star]) - mu + zee[c_star]
                correction = omega - ek - mu_b + mu_b^2 / (2.0 * max(ek, 1e-30))
                zpe += 0.5 * correction
            end

            E_total += k^2 * zpe * dk / (2.0 * Float64(π)^2)
        end
    end

    E_total / n_dir
end

# =================================================================
# Closed-form polar LHY wrappers (PhiOneReg + PolarContactLHY + PolarDipolarLHY)
# =================================================================
#
# These produce a SpinorLHYTable identical in shape to :two_channel /
# :full_bdg, so the downstream evaluator (apply_lhy_step!) treats them
# uniformly.

"""
    compute_spinor_lhy_polar_contact(; F, g_dict, n_max, n_points) → SpinorLHYTable

F-polar contact LHY closed form (paper #1 main result, F-generic).
`g_dict` maps even total-spin channels S → g_S. Returns a `SpinorLHYTable`
with `mode = :polar_contact`.

Two orders of magnitude faster than `compute_spinor_lhy_table` (`:full_bdg`)
because the BdG diagonalisation collapses to per-mode eigvals via the
σ/δ algebra. Restricted to polar phases (ζ_α = δ_{α,0}); for non-polar
spinors fall back to `:full_bdg`.
"""
function compute_spinor_lhy_polar_contact(;
    F::Int,
    g_dict,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = PolarContactLHY.build_polar_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = PolarContactLHY.lhy_energy_polar(n, coefs)
    end
    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:polar_contact, densities, potential_values)
end

"""
    compute_spinor_lhy_polar_dipolar(; F, g_dict, eps_tilde_dd, n_max, n_points) → SpinorLHYTable

F-polar contact + DDI LHY closed form (paper #1 with dipolar extension,
F-generic). `eps_tilde_dd` is the dimensionless DDI/contact ratio for the
|m|=1 antisym channel (caller convention). `eps_tilde_dd = 0` reduces to
the contact-only result exactly.
"""
function compute_spinor_lhy_polar_dipolar(;
    F::Int,
    g_dict,
    eps_tilde_dd::Float64,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = PolarContactLHY.build_polar_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = PolarDipolarLHY.lhy_energy_polar_dipolar(n, coefs, eps_tilde_dd)
    end
    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:polar_dipolar, densities, potential_values)
end

"""
    compute_spinor_lhy_fm_dipolar(; F, g_dict, eps_dd, n_max, n_points) → SpinorLHYTable

F-FM contact + DDI LHY closed form via Lima-Pelster Q_5 angular average
(Stage C scalar reduction, Saito-Li 2024 convention). Single-mode at
m=+F dressed by `Q_5(eps_dd)`. `eps_dd = 0` reduces to the pure-contact
FM closed form (`compute_spinor_lhy_fm_contact`) exactly.
"""
function compute_spinor_lhy_fm_dipolar(;
    F::Int,
    g_dict,
    eps_dd::Real,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = FMContactLHY.build_fm_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = FMDipolarLHY.lhy_energy_fm_dipolar(n, coefs, eps_dd)
    end
    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:fm_dipolar, densities, potential_values)
end

"""
    compute_spinor_lhy_fm_contact(; F, g_dict, n_max, n_points) → SpinorLHYTable

F-FM contact LHY closed form (paper #2 contact-only piece, F=6 for now).
For an FM-polarised condensate (ζ_α = δ_{α,+F}), the closed form collapses
to a single mode at m=+F: ε = (8/15π²) (g_{2F} n)^(5/2). For uniform
g_S = c_0 this is identical to scalar Lima-Pelster (no DDI). The mode
adds value with non-uniform g_S (realistic a_S per S channel) or for
the "Stage C" DDI extension once that closed form lands.
"""
function compute_spinor_lhy_fm_contact(;
    F::Int,
    g_dict,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))
    coefs = FMContactLHY.build_fm_lhy_coefs(F, g_dict)

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = FMContactLHY.lhy_energy_fm(n, coefs)
    end
    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:fm_contact, densities, potential_values)
end

"""
    compute_spinor_lhy_icosahedral(; F, g_dict, n_max, n_points) → SpinorLHYTable

F=6 icosahedral (I_h) phase contact LHY closed form (Stage D, parallel-
session derivation 2026-05-07). Universal structure
`ε = (8/15π²) n^(5/2) (c_0^(5/2) + 3 |λ_spin|^(5/2))` with stiffnesses
`(c_0, λ_spin) = compute_c0_lambda_F6_Ih(g_dict)`. Restricted to F=6.

`g_2`, `g_4`, `g_8` cancel exactly under I_h harmonic decomposition —
non-zero values are accepted but do not affect the LHY potential.
Scalar limit (uniform `g_S = g`) reduces to `(8/15π²)(g·n)^(5/2)`.
"""
function compute_spinor_lhy_icosahedral(;
    F::Int,
    g_dict,
    n_max::Float64=100.0,
    n_points::Int=200,
)
    F == 6 || throw(
        ArgumentError(
            "compute_spinor_lhy_icosahedral is F=6 only (got F=$F); the I_h closed " *
            "form is specific to the F=6 even-S channel structure"),
    )
    n_points >= 3 || throw(ArgumentError("n_points must be >= 3"))
    n_max > 0 || throw(ArgumentError("n_max must be positive"))

    densities = collect(range(0.0, n_max; length=n_points))
    energy = zeros(Float64, n_points)
    for (i, n) in enumerate(densities)
        n < 1e-30 && continue
        energy[i] = IcosahedralLHY.epsilon_LHY_F6_Ih(n, g_dict)
    end
    potential_values = _numerical_derivative(densities, energy)
    SpinorLHYTable(:icosahedral, densities, potential_values)
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

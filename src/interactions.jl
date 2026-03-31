"""
    compute_interaction_params(atom; N_atoms, dims, length_scale)

Compute interaction parameters in SI units from channel-resolved scattering lengths.

For F=1: uses analytic formulas c₀ = 4πℏ²(a₀+2a₂)/(3m), c₁ = 4πℏ²(a₂−a₀)/(3m).
For F≥2: requires `atom.scattering_lengths` dict (S => a_S for all even S channels).

For atoms where individual a_S are unknown (e.g. ¹⁵¹Eu), use
`interaction_params_from_constraint(; c_total, c1_ratio, F)` instead, which
constructs InteractionParams directly from the physical constraint c₀+F²c₁ = c_total.
"""
function compute_interaction_params(atom::AtomSpecies; N_atoms::Int=1, dims::Int=1, length_scale::Float64=1.0)
    if atom.F == 1
        a0, a2, m = atom.a0, atom.a2, atom.mass
        hbar = Units.HBAR

        c0_3d = 4π * hbar^2 * (a0 + 2a2) / (3m)
        c1_3d = 4π * hbar^2 * (a2 - a0) / (3m)

        if dims == 1
            l_perp = length_scale
            c0 = c0_3d / (2π * l_perp^2) * N_atoms
            c1 = c1_3d / (2π * l_perp^2) * N_atoms
        elseif dims == 2
            l_z = length_scale
            c0 = c0_3d / (sqrt(2π) * l_z) * N_atoms
            c1 = c1_3d / (sqrt(2π) * l_z) * N_atoms
        else
            c0 = c0_3d * N_atoms
            c1 = c1_3d * N_atoms
        end

        return InteractionParams(c0, c1)
    end

    if isempty(atom.scattering_lengths)
        @warn "No channel scattering lengths for F=$(atom.F) atom $(atom.name); using c0-only (c1=0)" maxlog=1
        c0 = compute_c0(atom; N_atoms, dims, length_scale)
        return InteractionParams(c0, 0.0)
    end
    compute_interaction_params_general_f(atom; N_atoms, dims, length_scale)
end

"""
    compute_interaction_params_general_f(atom; N_atoms, dims, length_scale)

Compute interaction params for general spin-F with channel-resolved scattering lengths.

Returns `InteractionParams(0.0, 0.0)` — all contact interactions are handled by the
tensor interaction step when scattering lengths are provided. The `g_S` values
are stored in `TensorInteractionCache`, not in `InteractionParams`.
"""
function compute_interaction_params_general_f(atom::AtomSpecies;
    N_atoms::Int=1, dims::Int=1, length_scale::Float64=1.0,
)
    InteractionParams(0.0, 0.0)
end

"""
Density-only contact interaction for general F.
c0 = 4πℏ² a_s / m (no spin channels, just s-wave scattering length a0).
"""
function compute_c0(atom::AtomSpecies; N_atoms::Int=1, dims::Int=1, length_scale::Float64=1.0)
    hbar = Units.HBAR
    c0_3d = 4π * hbar^2 * atom.a_s / atom.mass

    if dims == 1
        c0_3d / (2π * length_scale^2) * N_atoms
    elseif dims == 2
        c0_3d / (sqrt(2π) * length_scale) * N_atoms
    else
        c0_3d * N_atoms
    end
end

"""
DDI coupling constant: c_dd = μ₀ μ².
Returns c_dd in SI (J·m³). Zero for non-dipolar atoms.

Used with k-space kernel Q_αβ(k) = k̂_αk̂_β − δ_αβ/3, which is the Fourier
transform of (δ_αβ − 3r̂_αr̂_β)/(4πr³) — the 1/(4π) is absorbed into Q.
"""
function compute_c_dd(atom::AtomSpecies)
    atom.mu_mag == 0.0 && return 0.0
    Units.MU_0 * atom.mu_mag^2
end

"""
Dipolar length: a_dd = μ₀ μ² m / (12π ℏ²).
"""
function compute_a_dd(atom::AtomSpecies)
    atom.mu_mag == 0.0 && return 0.0
    Units.MU_0 * atom.mu_mag^2 * atom.mass / (12π * Units.HBAR^2)
end

function compute_interaction_params_dimless(atom::AtomSpecies; N_atoms::Int=1, dims::Int=1, omega::Float64=1.0)
    hbar = Units.HBAR
    m = atom.mass
    a_ho = sqrt(hbar / (m * omega))

    params_si = compute_interaction_params(atom; N_atoms, dims, length_scale=a_ho)

    energy_scale = hbar * omega
    InteractionParams(params_si.c0 / energy_scale, params_si.c1 / energy_scale)
end

"""
    _c0c1_to_gS(F, c0, c1) → Dict{Int,Float64}

Convert physical density (c₀) and spin (c₁) couplings to channel couplings g_S:
  g_S = c₀ + c₁(S(S+1) − 2F(F+1))/2

This is the physical relation, NOT the 6j tensor transform. It gives:
- F=1: g₀ = c₀ − 2c₁, g₂ = c₀ + c₁  (exact: 2 params → 2 channels)
- General F: g_S for all even S ∈ 0:2:2F

For F≥2, two parameters (c₀, c₁) constrain F+1 independent channels g_S to a
one-parameter family. This is appropriate when higher scattering lengths are
unknown (e.g. Eu151). To specify independent g_S, provide higher-rank couplings
via `c_extra` or use `_make_tensor_cache_from_channels` directly.
"""
function _c0c1_to_gS(F::Int, c0::Float64, c1::Float64)
    Dict{Int,Float64}(
        S => c0 + c1 * (S * (S + 1) - 2 * F * (F + 1)) / 2
        for S in 0:2:2F
    )
end

"""
    _c_extra_to_delta_gS(F, c_extra) → Dict{Int,Float64}

Convert higher-rank tensor couplings c_k to channel coupling perturbations δg_S
via 6j transform.

Processes even-rank entries k ∈ {2, 4, ..., 2F} from `c_extra`, where
`c_extra[idx]` = c_{idx+1} (i.e. c_extra[1]=c₂, c_extra[3]=c₄, c_extra[5]=c₆).
Odd-rank entries are skipped — note that Kawaguchi-Ueda's "c₃" (coupling to the
S=2 pair channel) is NOT a rank-3 tensor operator. To include such pair-channel
couplings, use `_make_tensor_cache_from_channels` with explicit g_S values instead.
"""
function _c_extra_to_delta_gS(F::Int, c_extra::Vector{Float64})
    for (idx, val) in enumerate(c_extra)
        k = idx + 1
        if abs(val) > 1e-30 && isodd(k)
            @warn "c_extra[$idx] (c$k) is odd-rank and will be ignored. " *
                 "If this is a Kawaguchi-Ueda pair-channel coupling (e.g. c₃ → S=2 channel), " *
                 "use _make_tensor_cache_from_channels(F, Dict(S => g_S, ...)) instead." maxlog=1
        end
    end
    c_dict = Dict{Int,Float64}()
    for (idx, val) in enumerate(c_extra)
        k = idx + 1
        abs(val) > 1e-30 && iseven(k) && k <= 2F && (c_dict[k] = val)
    end
    isempty(c_dict) && return Dict{Int,Float64}()
    _cn_to_gS(F, c_dict)
end

"""
    interaction_params_from_constraint(; c_total, c1_ratio, F, c_extra)

Compute c₀, c₁ satisfying the physical constraint c₀ + F²c₁ = c_total.

For atoms where individual scattering lengths a_S are unknown (e.g. ¹⁵¹Eu),
the total contact interaction c_total = 4π(a_s/a_ho)N is known but the
spin-dependent split c₁/c₀ is a free parameter. This function parameterizes
by ratio r = c₁/c₀:

  c₀ = c_total / (1 + F²r)
  c₁ = r × c₀

The optional `c_extra` vector provides higher-rank tensor couplings where
`c_extra[n-1]` = cₙ (same indexing as `InteractionParams`). When any even-rank
entry with k ≥ 4 is nonzero, `make_workspace` activates the tensor interaction
path and zeros c₀/c₁.

Example with c₄ = 50:

    ip = interaction_params_from_constraint(;
        c_total=4689.0, c1_ratio=1/36, F=6,
        c_extra=[0.0, 0.0, 50.0])  # c_extra[3] = c₄

Note: r = -1/F² is singular (c₀ → ∞). For F=6, avoid r ≤ -1/36.
"""
function interaction_params_from_constraint(; c_total::Float64, c1_ratio::Float64=0.0,
                                              F::Int, c_extra::Vector{Float64}=Float64[])
    c0 = c_total / (1.0 + F^2 * c1_ratio)
    c1 = c1_ratio * c0
    InteractionParams(c0, c1, 0.0, c_extra)
end

"""
    compute_c_total(atom; N_atoms, omega_ref)

Total contact interaction c_total = 4π(a_s/a_ho)N in dimensionless units (3D).
"""
function compute_c_total(atom::AtomSpecies; N_atoms::Int, omega_ref::Float64)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    4π * (atom.a_s / a_ho) * N_atoms
end

"""
    compute_c_dd_dimless(atom; N_atoms, omega_ref)

Dimensionless DDI coupling: c_dd = N × μ₀μ² / (ℏω × a_ho³).
"""
function compute_c_dd_dimless(atom::AtomSpecies; N_atoms::Int, omega_ref::Float64)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    N_atoms * compute_c_dd(atom) / (Units.HBAR * omega_ref * a_ho^3)
end

"""
    compute_eu151_interactions(; N_atoms, omega_ref, c1_ratio, c_extra)

Dimensionless interaction params for ¹⁵¹Eu (F=6) with mandatory c₁/c₀ ratio.

Individual scattering lengths a_S are unknown for Eu, so `compute_interaction_params`
falls back to c₁=0 with a warning. This wrapper prevents that silent fallback by
requiring an explicit `c1_ratio`.

Physical estimates for c1_ratio:
- `0.0`: DDI-only (c₁=0, no spin-dependent contact)
- `1/36`: Buchachenko et al. antiferromagnetic estimate
- negative: ferromagnetic

Returns `InteractionParams` with c₀+F²c₁ = 4π(a_s/a_ho)N.
"""
function compute_eu151_interactions(; N_atoms::Int, omega_ref::Float64,
                                      c1_ratio::Float64, c_extra::Vector{Float64}=Float64[])
    c_total = compute_c_total(Eu151; N_atoms, omega_ref)
    interaction_params_from_constraint(; c_total, c1_ratio, F=6, c_extra)
end

"""
    linear_zeeman_p(atom, B, omega_ref)

Dimensionless linear Zeeman shift: p = g_F × μ_B × B / (ℏ × omega_ref).
"""
function linear_zeeman_p(atom::AtomSpecies, B::Float64, omega_ref::Float64)
    atom.g_F * Units.MU_BOHR * B / (Units.HBAR * omega_ref)
end

# --- Lima-Pelster DDI-corrected LHY ---

"""
    _gauss_legendre(n, a, b) → (nodes, weights)

n-point Gauss-Legendre quadrature on [a, b].
"""
function _gauss_legendre(n::Int, a::Float64, b::Float64)
    nodes = zeros(Float64, n)
    weights = zeros(Float64, n)
    m = div(n + 1, 2)
    mid = (a + b) / 2
    half = (b - a) / 2

    for i in 1:m
        z = cos(π * (i - 0.25) / (n + 0.5))
        for _ in 1:100
            p1 = 1.0
            p2 = 0.0
            for j in 1:n
                p3 = p2
                p2 = p1
                p1 = ((2j - 1) * z * p2 - (j - 1) * p3) / j
            end
            pp = n * (z * p1 - p2) / (z^2 - 1.0)
            dz = p1 / pp
            z -= dz
            abs(dz) < 1e-15 && break
        end
        nodes[i] = mid - half * z
        nodes[n + 1 - i] = mid + half * z
        w = 2.0 * half / ((1.0 - z^2) * (n * (z * 1.0 - 0.0))^2)
        pp_final = 0.0
        p1 = 1.0; p2 = 0.0
        for j in 1:n
            p3 = p2; p2 = p1
            p1 = ((2j - 1) * z * p2 - (j - 1) * p3) / j
        end
        pp_final = n * (z * p1 - p2) / (z^2 - 1.0)
        w = 2.0 * half / ((1.0 - z^2) * pp_final^2)
        weights[i] = w
        weights[n + 1 - i] = w
    end
    (nodes, weights)
end

"""
    lima_pelster_Q5(eps_dd) → Float64

Lima-Pelster correction factor Q₅(ε_dd) for the LHY energy of a dipolar BEC:

    Q₅ = ∫₀^π (sinθ / 2) [1 + ε_dd(3cos²θ - 1)]^{5/2} dθ

Ref: Lima & Pelster, PRA 84, 041604(R) (2011).

Returns 1.0 for ε_dd=0. Throws DomainError if the integrand becomes negative
(argument < 0 inside the 5/2 power).
"""
function lima_pelster_Q5(eps_dd::Float64)
    abs(eps_dd) < 1e-15 && return 1.0

    nodes, weights = _gauss_legendre(20, 0.0, Float64(π))
    s = 0.0
    for i in eachindex(nodes)
        theta = nodes[i]
        ct = cos(theta)
        arg = 1.0 + eps_dd * (3.0 * ct^2 - 1.0)
        arg < 0.0 && throw(DomainError(arg,
            "Negative argument in Q₅ integrand at θ=$(theta): " *
            "1 + ε_dd(3cos²θ-1) = $arg for ε_dd=$eps_dd"))
        s += weights[i] * sin(theta) / 2.0 * arg^(5 / 2)
    end
    s
end

"""
    compute_c_lhy_with_ddi(c_lhy_scalar, eps_dd) → Float64

Apply the Lima-Pelster DDI correction to a scalar LHY coefficient:
    c_lhy_corrected = c_lhy_scalar × Q₅(ε_dd)
"""
function compute_c_lhy_with_ddi(c_lhy_scalar::Float64, eps_dd::Float64)
    c_lhy_scalar * lima_pelster_Q5(eps_dd)
end

# --- Spinor-Dependent LHY ---

"""
    compute_spinor_lhy_coefficient(; spinor, F, interactions, zeeman, c_dd, k_max, n_k, n_theta, n_phi)

Compute the effective LHY coefficient for a uniform spinor condensate by integrating
the regularized Bogoliubov spectrum over k-space.

The spinor LHY energy density is ε_LHY = c_lhy_eff × n₀^{5/2}, where c_lhy_eff
depends on the spinor order parameter ζ through the Bogoliubov-de Gennes spectrum.

For contact-only interactions (c_dd ≈ 0), the integrand is isotropic and only a 1D
k-integral is needed. For DDI (c_dd ≠ 0), the BdG spectrum depends on the direction
k̂ through Q_αβ(k̂), so an angular average over the solid angle is performed using
Gauss-Legendre quadrature in θ and uniform sampling in φ.

The integral is regularized by subtracting the UV-divergent terms:
    Σ_j [E_j(k) − ε_k − λ_j + λ_j²/(2ε_k)]
where E_j(k) are positive BdG eigenvalues and λ_j are mean-field eigenvalues.

# Arguments
- `spinor::Vector{ComplexF64}`: Normalized spinor (length 2F+1)
- `F::Int`: Spin quantum number
- `interactions::InteractionParams`: Contact interaction parameters
- `zeeman::ZeemanParams`: Zeeman parameters (default: no Zeeman)
- `c_dd::Float64`: Dipole-dipole coupling (default: 0)
- `k_max::Float64`: UV cutoff for k-integral (default: 20.0)
- `n_k::Int`: Number of k-points for radial integration (default: 300)
- `n_theta::Int`: Number of polar angle points for DDI angular average (default: 20)
- `n_phi::Int`: Number of azimuthal angle points for DDI angular average (default: 20)

# Returns
Effective LHY coefficient `c_lhy_eff::Float64`.
"""
function compute_spinor_lhy_coefficient(;
    spinor::Vector{ComplexF64},
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    k_max::Float64=20.0,
    n_k::Int=300,
    n_theta::Int=20,
    n_phi::Int=20,
)
    D = 2F + 1
    length(spinor) == D || throw(DimensionMismatch(
        "spinor length $(length(spinor)) != 2F+1 = $D"))

    # Normalize spinor
    zeta = spinor / norm(spinor)

    # Build channel couplings
    cg_table = precompute_cg_table(F)
    g_dict = _c0c1_to_gS(F, interactions.c0, interactions.c1)
    if !isempty(interactions.c_extra)
        g_delta = _c_extra_to_delta_gS(F, interactions.c_extra)
        g_dict = merge(+, g_dict, g_delta)
    end

    # Zeeman energies
    sys = SpinSystem(F)
    zee = zeeman_energies(zeeman, sys)

    # Contact mean-field matrices (k-direction independent)
    h_mf_contact = _bdg_normal_matrix(zeta, F, D, g_dict, cg_table)
    M_anom_contact = _bdg_anomalous_matrix(zeta, F, D, g_dict, cg_table)

    has_ddi = abs(c_dd) > 1e-30

    if has_ddi
        sm = spin_matrices(F)
        # Angular average over k-directions
        theta_nodes, theta_weights = _gauss_legendre(n_theta, 0.0, Float64(π))
        phi_nodes = range(0, 2π, length=n_phi + 1)[1:n_phi]
        dphi = 2π / n_phi

        total = 0.0
        for (it, theta) in enumerate(theta_nodes)
            st = sin(theta)
            for phi in phi_nodes
                k_hat = [st * cos(phi), st * sin(phi), cos(theta)]
                Q_ab = _q_tensor_direction(k_hat)
                h_ddi, M_ddi = _bdg_ddi_matrices(zeta, F, D, sm, c_dd, Q_ab)

                h_mf = h_mf_contact .+ h_ddi
                M_anom = M_anom_contact .+ M_ddi

                I_k = _spinor_lhy_k_integral(h_mf, M_anom, zee, zeta, D, k_max, n_k)
                # Weight: sinθ dθ dφ / (4π)
                total += theta_weights[it] * st * dphi * I_k
            end
        end
        # Normalize angular average: ∫ sinθ dθ dφ / (4π) = 1
        total /= (4π)
    else
        # Contact-only: isotropic, no angular average needed
        total = _spinor_lhy_k_integral(h_mf_contact, M_anom_contact, zee, zeta, D, k_max, n_k)
    end

    # LHY energy density: ε = (1/2) ∫ d³k/(2π)³ Σ_j [regularized BdG]
    # where the 1/2 is the zero-point energy factor.
    # ∫ d³k/(2π)³ = (4π/(2π)³) ∫ k² dk (isotropic) = 1/(2π²) × ∫ k² dk
    # For DDI: total = (1/(4π)) ∫ dΩ ∫ k² dk [...] (angular average)
    #   ∫ d³k/(2π)³ = (4π)/(2π)³ × total = 1/(2π²) × total
    # Contact-only: total = ∫ k² dk [...], same factor.
    total / (4π^2)
end

"""
    _spinor_lhy_k_integral(h_mf, M_anom, zee, spinor, D, k_max, n_k) → Float64

Compute the radial k-integral of the regularized BdG spectrum for fixed k-direction.
Returns ∫₀^{k_max} dk k² Σ_j [E_j(k) - ε_k - λ_j + λ_j²/(2ε_k)].

At unit density (n₀=1), the BdG matrix is:
    L_{mm'} = (k²/2 + zee_m - μ)δ_{mm'} + 2 h_{mm'}
    M = M_anom
"""
function _spinor_lhy_k_integral(h_mf, M_anom, zee, spinor, D, k_max, n_k)
    # Chemical potential at unit density (n₀=1), same as bogoliubov_spectrum
    mu = real(sum(c -> (zee[c] + h_mf[c, c]) * abs2(spinor[c]), 1:D))

    # Mean-field eigenvalues λ_j: eigenvalues of (2 h_mf + diag(zee - μ))
    # At large k, BdG eigenvalues approach ε_k + λ_j
    mf_matrix = 2.0 .* h_mf
    for i in 1:D
        mf_matrix[i, i] += zee[i] - mu
    end
    lambda_mf = sort!(real.(eigvals(mf_matrix)))

    # k-grid (skip k=0 to avoid singularity)
    dk = k_max / n_k
    result = 0.0

    H_bdg = zeros(ComplexF64, 2D, 2D)

    for ik in 1:n_k
        k = (ik - 0.5) * dk  # midpoint rule
        ek = k^2 / 2

        # Build BdG matrix at this k (n₀=1)
        # L_{mm'} = (ek - μ + zee_m)δ_{mm'} + 2 h_{mm'}
        @inbounds for i in 1:D
            for j in 1:D
                L_ij = 2.0 * h_mf[i, j]
                if i == j
                    L_ij += ek - mu + zee[i]
                end
                H_bdg[i, j] = L_ij
                H_bdg[i, D + j] = M_anom[i, j]
                H_bdg[D + i, j] = -conj(M_anom[i, j])
                H_bdg[D + i, D + j] = -conj(L_ij)
            end
        end

        evals = eigvals(H_bdg)
        # Sort positive eigenvalues
        pos_evals = sort!(filter(e -> real(e) > 0, evals), by=real)

        # Regularized integrand: Σ_j [E_j - ε_k - λ_j + λ_j²/(2ε_k)]
        integrand = 0.0
        n_pos = min(length(pos_evals), D)
        for j in 1:n_pos
            Ej = real(pos_evals[j])
            lj = lambda_mf[j]
            if ek > 1e-30
                integrand += Ej - ek - lj + lj^2 / (2 * ek)
            end
        end

        result += k^2 * integrand * dk
    end

    result
end

"""
    _density_weighted_spinor(psi, ndim) → Vector{ComplexF64}

Extract the density-weighted average spinor from a wavefunction array.
Returns a normalized spinor ζ such that Σ_c |ζ_c|² = 1.

`psi` has shape (spatial..., n_components) where `ndim` is the number of spatial dimensions.
"""
function _density_weighted_spinor(psi::AbstractArray, ndim::Int)
    n_comp = size(psi, ndim + 1)
    n_pts = ntuple(d -> size(psi, d), ndim)

    zeta = zeros(ComplexF64, n_comp)
    total_n = 0.0

    @inbounds for I in CartesianIndices(n_pts)
        n_local = 0.0
        for c in 1:n_comp
            n_local += abs2(psi[I, c])
        end
        total_n += n_local
        for c in 1:n_comp
            zeta[c] += n_local * psi[I, c]
        end
    end

    nrm = norm(zeta)
    nrm > 0 ? zeta / nrm : zeta
end

"""
    update_spinor_lhy!(cache::SpinorLHYCache; spinor, F, interactions, zeeman, c_dd, kwargs...)

Recompute the effective LHY coefficient and store it in the cache.
All keyword arguments are forwarded to `compute_spinor_lhy_coefficient`.
"""
function update_spinor_lhy!(cache::SpinorLHYCache;
    spinor::Vector{ComplexF64},
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    k_max::Float64=20.0,
    n_k::Int=300,
    n_theta::Int=20,
    n_phi::Int=20,
)
    c_eff = compute_spinor_lhy_coefficient(;
        spinor, F, interactions, zeeman, c_dd, k_max, n_k, n_theta, n_phi,
    )
    cache.c_lhy_eff[] = c_eff
    c_eff
end

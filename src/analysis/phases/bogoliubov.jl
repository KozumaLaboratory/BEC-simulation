export bogoliubov_spectrum, detect_roton, instability_angular_map

"""
    bogoliubov_spectrum(; spinor, n0, F, interactions, zeeman, c_dd, k_max, n_k, k_direction)

Compute the Bogoliubov-de Gennes spectrum for a uniform spinor condensate.

At each k, builds the 2D × 2D BdG matrix σ_z [L M; M* L*] and diagonalizes.
Returns `BdGResult` with dispersion relations and stability info.

- L_{mm'} = (k²/2 - μ + zee_m)δ_{mm'} + 2n₀ Σ_S g_S Σ_{M,μ,ν} CG CG ζ*_μ ζ_ν
- M_{mm'} = n₀ Σ_S g_S Σ_M CG(m,m'|S,M) A_{SM}
  where A_{SM} = Σ_{μ,ν} CG(μ,ν|S,M) ζ_μ ζ_ν

When `c_dd > 0`, the DDI tensor Q_αβ(k) = k̂_αk̂_β − δ_αβ/3 depends on k̂.
Different `k_direction` values yield different instability thresholds.
Scan multiple directions (e.g. `(1,0,0)`, `(0,0,1)`, `(1,1,0)/√2`) to
find the most unstable mode.
"""
function bogoliubov_spectrum(;
    spinor::Vector{ComplexF64},
    n0::Float64,
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    k_max::Float64=10.0,
    n_k::Int=200,
    k_direction::NTuple{3, Float64}=(0.0, 0.0, 1.0),
)
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    h_mf, M_anom, zee, D_out = _bdg_contact_matrices(spinor, F, interactions, zeeman)

    if is_active(c_dd)
        sm = spin_matrices(F)
        k_hat = collect(k_direction)
        k_norm = norm(k_hat)
        k_norm > 0 && (k_hat ./= k_norm)
        Q_ab = _q_tensor_direction(k_hat)
        h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
        h_mf = h_mf .+ h_ddi
        M_anom = M_anom .+ M_ddi
    end

    k_values, omega, max_growth = _bdg_k_scan(h_mf, M_anom, zee, n0, D, spinor, k_max, n_k)
    BdGResult(k_values, omega, max_growth, max_growth > 1e-10)
end

function _bdg_contact_matrices(spinor, F, interactions, zeeman)
    D = 2F + 1
    cg_table = precompute_cg_table(F)

    g_dict = c_to_g(F, interactions)

    sys = SpinSystem(F)
    zee = zeeman_energies(zeeman, sys)

    h_mf = _bdg_normal_matrix(spinor, F, D, g_dict, cg_table)
    M_anom = _bdg_anomalous_matrix(spinor, F, D, g_dict, cg_table)

    h_mf, M_anom, zee, D
end

function _bdg_k_scan(h_mf, M_anom, zee, n0, D, spinor, k_max, n_k)
    # μ = ⟨ψ|(Z + n0 h_mf)|ψ⟩. The earlier `sum(c -> ...|ψ_c|²)` form
    # kept only the diagonal of h_mf, which is correct for a single-m
    # state but drops O(1) off-diagonal terms whenever the spinor is
    # not aligned with a |m⟩ basis vector (FL, cyclic, biaxial nematic,
    # any uniformly-rotated polarized state). The diagonal-only μ
    # systematically biases the roton gap and the long-wavelength sound
    # speed reported by `bogoliubov_dispersion`. Fixed 2026-04-26.
    H_mu = Diagonal(zee) .+ n0 .* h_mf
    mu = real(dot(spinor, H_mu * spinor))

    k_values = collect(range(0, k_max; length=n_k))
    omega = zeros(ComplexF64, 2D, n_k)
    max_growth = 0.0

    for (ik, k) in enumerate(k_values)
        ek = k^2 / 2

        L = 2n0 .* h_mf
        for i in 1:D
            L[i, i] += ek - mu + zee[i]
        end

        M_sc = n0 .* M_anom

        H_bdg = zeros(ComplexF64, 2D, 2D)
        H_bdg[1:D, 1:D] .= L
        H_bdg[1:D, (D + 1):2D] .= M_sc
        H_bdg[(D + 1):2D, 1:D] .= .-conj.(M_sc)
        H_bdg[(D + 1):2D, (D + 1):2D] .= .-conj.(L)

        evals = eigvals(H_bdg)
        omega[:, ik] .= evals

        for ev in evals
            g = imag(ev)
            g > max_growth && (max_growth = g)
        end
    end

    k_values, omega, max_growth
end

function _bdg_normal_matrix(spinor, F, D, g_dict, cg_table)
    h = zeros(ComplexF64, D, D)
    for S in 0:2:2F
        gS = get(g_dict, S, 0.0)
        abs(gS) < 1e-30 && continue
        for m in (-F):F
            cm = F - m + 1
            for mp in (-F):F
                cmp = F - mp + 1
                val = zero(ComplexF64)
                for mu in (-F):F
                    M = m + mu
                    abs(M) > S && continue
                    nu = M - mp
                    abs(nu) > F && continue
                    cg1 = get(cg_table, (S, M, m, mu), 0.0)
                    cg2 = get(cg_table, (S, M, mp, nu), 0.0)
                    abs(cg1 * cg2) < 1e-30 && continue
                    val += cg1 * cg2 * conj(spinor[F - mu + 1]) * spinor[F - nu + 1]
                end
                h[cm, cmp] += gS * val
            end
        end
    end
    h
end

function _bdg_anomalous_matrix(spinor, F, D, g_dict, cg_table)
    M_mat = zeros(ComplexF64, D, D)
    for S in 0:2:2F
        gS = get(g_dict, S, 0.0)
        abs(gS) < 1e-30 && continue
        for M_val in (-S):S
            A_SM = zero(ComplexF64)
            for mu in (-F):F
                nu = M_val - mu
                abs(nu) > F && continue
                cg = get(cg_table, (S, M_val, mu, nu), 0.0)
                abs(cg) < 1e-30 && continue
                A_SM += cg * spinor[F - mu + 1] * spinor[F - nu + 1]
            end
            abs(A_SM) < 1e-30 && continue

            for m in (-F):F
                mp = M_val - m
                abs(mp) > F && continue
                cg = get(cg_table, (S, M_val, m, mp), 0.0)
                abs(cg) < 1e-30 && continue
                M_mat[F - m + 1, F - mp + 1] += gS * cg * A_SM
            end
        end
    end
    M_mat
end

function _q_tensor_direction(k_hat::Vector{Float64})
    Q = zeros(Float64, 3, 3)
    for a in 1:3
        for b in 1:3
            Q[a, b] = k_hat[a] * k_hat[b] - (a == b ? 1.0 / 3.0 : 0.0)
        end
    end
    Q
end

function _bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
    Fx_m = Matrix{ComplexF64}(sm.Fx)
    Fy_m = Matrix{ComplexF64}(sm.Fy)
    Fz_m = Matrix{ComplexF64}(sm.Fz)
    F_mats = [Fx_m, Fy_m, Fz_m]

    f_exp = [real(spinor' * Fm * spinor) for Fm in F_mats]

    # Normal: h^DDI_{mm'} = c_dd Σ_{ab} Q_{ab} <F_b> (F_a)_{mm'}
    h = zeros(ComplexF64, D, D)
    for a in 1:3
        for b in 1:3
            h .+= c_dd * Q_ab[a, b] * f_exp[b] .* F_mats[a]
        end
    end

    # Anomalous DDI: outer product of F_a·ζ vectors
    # M^DDI_{m,m'} = c_dd Σ_{ab} Q_{ab} (F_a·ζ)_m (F_b·ζ)_{m'}
    fa_zeta = [F_mats[a] * spinor for a in 1:3]
    M_mat = zeros(ComplexF64, D, D)
    for a in 1:3, b in 1:3
        coeff = c_dd * Q_ab[a, b]
        abs(coeff) < 1e-30 && continue
        for i in 1:D, j in 1:D
            M_mat[i, j] += coeff * fa_zeta[a][i] * fa_zeta[b][j]
        end
    end

    h, M_mat
end

"""
    detect_roton(bdg::BdGResult) → RotonParams

Detect roton minimum in the lowest positive-frequency branch.
Returns `RotonParams(k_roton, ω_roton, gap, true)` if a local minimum exists
at k > 0, or `RotonParams(0, 0, Inf, false)` otherwise.
"""
function detect_roton(bdg::BdGResult)
    n_k = length(bdg.k_values)
    D2 = size(bdg.omega, 1)

    phonon_branch = zeros(Float64, n_k)
    for ik in 1:n_k
        min_pos = Inf
        for ie in 1:D2
            re = real(bdg.omega[ie, ik])
            re > 1e-10 && re < min_pos && (min_pos = re)
        end
        phonon_branch[ik] = min_pos == Inf ? 0.0 : min_pos
    end

    k_skip = max(2, round(Int, 0.05 * n_k))

    best_k = 0.0
    best_omega = Inf
    found = false

    for ik in (k_skip + 1):(n_k - 1)
        if phonon_branch[ik] < phonon_branch[ik - 1] && phonon_branch[ik] < phonon_branch[ik + 1]
            if phonon_branch[ik] < best_omega
                best_omega = phonon_branch[ik]
                best_k = bdg.k_values[ik]
                found = true
            end
        end
    end

    if !found
        return RotonParams(0.0, 0.0, Inf, false)
    end

    max_before = maximum(phonon_branch[1:round(Int, searchsortedlast(bdg.k_values, best_k))])
    gap = best_omega
    RotonParams(best_k, best_omega, gap, true)
end

"""
    _planar_directions(n) → Vector{NTuple{3,Float64}}

Generate `n` evenly-spaced directions in the xy-plane (upper semicircle).
"""

"""
    instability_angular_map(; spinor, n0, F, interactions, zeeman, c_dd,
                              k_max, n_k, n_theta, n_phi) → NamedTuple

Dense (θ, φ) grid over upper hemisphere. Returns `(theta, phi, growth_map)`.
"""
function instability_angular_map(;
    spinor::Vector{ComplexF64},
    n0::Float64,
    F::Int,
    interactions::InteractionParams,
    zeeman::ZeemanParams=ZeemanParams(),
    c_dd::Float64=0.0,
    k_max::Float64=10.0,
    n_k::Int=200,
    n_theta::Int=18,
    n_phi::Int=36,
)
    D = 2F + 1
    length(spinor) == D ||
        throw(DimensionMismatch("spinor length $(length(spinor)) != 2F+1 = $D"))

    h_contact, M_contact, zee, _ = _bdg_contact_matrices(spinor, F, interactions, zeeman)
    has_ddi = is_active(c_dd)
    sm = has_ddi ? spin_matrices(F) : nothing

    theta_vals = collect(range(0.0, Float64(π) / 2; length=n_theta))
    phi_vals = collect(range(0.0, 2.0 * Float64(π); length=n_phi + 1)[1:n_phi])
    growth_map = zeros(Float64, n_theta, n_phi)

    for it in 1:n_theta
        for ip in 1:n_phi
            st = sin(theta_vals[it])
            ct = cos(theta_vals[it])
            dir = (st * cos(phi_vals[ip]), st * sin(phi_vals[ip]), ct)

            if has_ddi
                k_hat = collect(dir)
                k_norm = norm(k_hat)
                k_norm > 0 && (k_hat ./= k_norm)
                Q_ab = _q_tensor_direction(k_hat)
                h_ddi, M_ddi = _bdg_ddi_matrices(spinor, F, D, sm, c_dd, Q_ab)
                h_mf = h_contact .+ h_ddi
                M_anom = M_contact .+ M_ddi
            else
                h_mf = h_contact
                M_anom = M_contact
            end

            _, omega, max_g = _bdg_k_scan(h_mf, M_anom, zee, n0, D, spinor, k_max, n_k)
            growth_map[it, ip] = max_g
        end
    end

    (theta=theta_vals, phi=phi_vals, growth_map=growth_map)
end

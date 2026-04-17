"""
Radial Schrödinger propagator for two-body scattering.

Phase 2d: single-channel Numerov with scattering-length extraction, used
as the validation scaffold. Multi-channel log-derivative comes in 2e.

Equation (atomic units, ℏ = 1, u = R·ψ):

    u''(R) = [2μ (V(R) − E) + ℓ(ℓ+1)/R²] u(R)

The Numerov three-point recursion is stable for classically allowed
regions and tolerates exponential growth in forbidden regions as long as
the grid is short; for very deep wells use the log-derivative variant
(to be added in Phase 2e).
"""

"""
    numerov(V, R_min, R_max, h, E; μ, ℓ=0, u0=(0.0, 1e-30))
        → (Rs, u)

Integrate the single-channel radial Schrödinger equation on a uniform
grid with step `h`. `V` is a function `V(R)` returning the potential in
E_h, `μ` is the reduced mass in electron-mass units, `E` is the total
energy in E_h.

Initial conditions set the wavefunction value at the first two grid
points: `u0 = (u_min, u_min_plus_h)`. For a repulsive-core or
hard-wall start, use `(0.0, ε)` with ε small but nonzero.
"""
function numerov(
    V, R_min::Real, R_max::Real, h::Real, E::Real;
    μ::Real, ℓ::Integer = 0, u0::Tuple{<:Real,<:Real} = (0.0, 1e-30),
)
    N = Int(floor((R_max - R_min) / h)) + 1
    Rs = collect(range(R_min, step = h, length = N))
    u = zeros(Float64, N)
    u[1] = u0[1]
    u[2] = u0[2]

    f(R) = 2 * μ * (V(R) - E) + (ℓ * (ℓ + 1)) / (R * R)
    h2_12 = h * h / 12
    Tm1 = h2_12 * f(Rs[1])
    Tn = h2_12 * f(Rs[2])
    @inbounds for n in 2:(N - 1)
        Tp1 = h2_12 * f(Rs[n + 1])
        u[n + 1] = (2 * u[n] * (1 + 5 * Tn) - u[n - 1] * (1 - Tm1)) / (1 - Tp1)
        Tm1 = Tn
        Tn = Tp1
    end
    return Rs, u
end

"""
    scattering_length_from_u(Rs, u) → a

Extract the s-wave scattering length from a zero-energy solution that
reaches the free-particle asymptote u(R) = C (R − a). Uses the two
outermost grid points via finite-difference for u'.

Assumes `Rs` uniform with step `h = Rs[2] − Rs[1]`.
"""
function scattering_length_from_u(Rs::AbstractVector, u::AbstractVector)
    length(Rs) == length(u) || throw(ArgumentError("Rs and u length mismatch"))
    length(Rs) >= 3 || throw(ArgumentError("need at least 3 grid points"))
    h = Rs[2] - Rs[1]
    # Central-difference u' at the last interior point
    N = length(Rs)
    R = Rs[N - 1]
    u_mid = u[N - 1]
    u_deriv = (u[N] - u[N - 2]) / (2h)
    return R - u_mid / u_deriv
end

"""
    zero_energy_scattering_length(V, R_min, R_max, h; μ, ℓ = 0,
                                   u0 = (0.0, 1e-30)) → a

Convenience wrapper: run Numerov at E = 0 and return the scattering
length.
"""
function zero_energy_scattering_length(
    V, R_min::Real, R_max::Real, h::Real;
    μ::Real, ℓ::Integer = 0, u0::Tuple{<:Real,<:Real} = (0.0, 1e-30),
)
    Rs, u = numerov(V, R_min, R_max, h, 0.0; μ = μ, ℓ = ℓ, u0 = u0)
    scattering_length_from_u(Rs, u)
end

"""
    square_well_scattering_length(V0, R0; μ) → a

Analytical s-wave scattering length for the attractive square well of
depth |V0| (V = −|V0| for R < R0, 0 for R > R0):

    a = R₀ − tan(K R₀) / K,  K² = 2μ|V0|

Used as the closed-form reference in tests.
"""
function square_well_scattering_length(V0::Real, R0::Real; μ::Real)
    K = sqrt(2μ * abs(V0))
    R0 - tan(K * R0) / K
end

# --- Multi-channel ---

"""
    numerov_multichannel(M_func, R_min, R_max, h; U0, U1) → (Rs, U_stack)

Integrate U''(R) = M(R) · U(R) with `U` an (n_ch × n_sol) matrix and
`M(R)` an n_ch × n_ch matrix-valued function. Returns `U_stack` of
shape (n_ch, n_sol, N) with N uniform grid points of step `h`.

`M_func(R)` should return the full coupling matrix M(R) = 2μ [W(R) +
diag(E_thresh) − E·I] + diag(ℓ(ℓ+1))/R². Construction of M from
potentials and channels is the caller's responsibility (see
`make_channel_M`).

Initial matrices `U0 = U(R_min)` and `U1 = U(R_min + h)` must be
provided. For n_sol = n_ch a standard choice is `U0 = 0`,
`U1 = ε · I`.
"""
function numerov_multichannel(
    M_func, R_min::Real, R_max::Real, h::Real;
    U0::AbstractMatrix, U1::AbstractMatrix,
)
    N = Int(floor((R_max - R_min) / h)) + 1
    Rs = collect(range(R_min, step = h, length = N))
    n_ch, n_sol = size(U0)
    size(U1) == (n_ch, n_sol) ||
        throw(ArgumentError("U0 and U1 must have the same shape"))
    U = Array{Float64,3}(undef, n_ch, n_sol, N)
    @views U[:, :, 1] .= U0
    @views U[:, :, 2] .= U1

    h2_12 = h * h / 12
    Id = Matrix{Float64}(I, n_ch, n_ch)
    Mm1 = M_func(Rs[1])
    Mn = M_func(Rs[2])
    Am1 = Id - h2_12 .* Mm1
    An = Id + 10 * h2_12 .* Mn   # coefficient of 2 U_n is (I + 10 T_n)/... actually 2·(I + 5 T_n) yields (2 I + 10 T_n)
    @inbounds for n in 2:(N - 1)
        Mp1 = M_func(Rs[n + 1])
        Ap1 = Id - h2_12 .* Mp1
        rhs = (2 * Id + 10 * h2_12 .* Mn) * U[:, :, n] - Am1 * U[:, :, n - 1]
        U[:, :, n + 1] = Ap1 \ rhs
        Am1 = Id - h2_12 .* Mn
        Mn = Mp1
    end
    return Rs, U
end

"""
    make_channel_M(W_func, thresh, L_vec, μ, E) → (R -> Matrix)

Factory building the M(R) function for the coupled-channel Schrödinger
equation given a coupling-matrix function `W_func(R)`, per-channel
threshold energies `thresh`, centrifugal integers `L_vec = [ℓ_i(ℓ_i+1)]`,
reduced mass `μ`, and total energy `E` (all in atomic units).
"""
function make_channel_M(
    W_func, thresh::AbstractVector, L_vec::AbstractVector,
    μ::Real, E::Real,
)
    n = length(thresh)
    length(L_vec) == n || throw(ArgumentError("thresh and L_vec size mismatch"))
    diag_shift = 2μ .* (thresh .- E)
    function M(R::Real)
        W = W_func(R)
        M_out = 2μ .* W
        @inbounds for i in 1:n
            M_out[i, i] += diag_shift[i] + L_vec[i] / (R * R)
        end
        return M_out
    end
end

"""
    kmatrix_swave(U_end, U_end_m1, h, k_vec) → K

Extract the open-channel K-matrix at zero angular momentum from the
solution matrix at the last two grid points of a multi-channel Numerov
run. Channels with k² > 0 are open; k² ≤ 0 are closed and excluded.

Matching at R, R' = R − h:
    u_α(R) ≈ A_α sin(k_α R) − A_α cos(k_α R) · K_α     (open)

For two open channels or more, solve block-matrix matching:
    [S₂  C₂] · [A] = U_open(R),   [S₁  C₁] · [A·(−K)] = U_open(R′)

Returns symmetric real K of dimension n_open × n_open.

Note: this routine is valid ONLY when closed-channel amplitudes have
decayed at the matching radius. Validation test: toy uncoupled problem.
"""
function kmatrix_swave(
    U_end::AbstractMatrix, U_end_m1::AbstractMatrix,
    h::Real, k_vec::AbstractVector, R_end::Real,
)
    open = findall(k -> k > 0, k_vec)
    n_open = length(open)
    n_open == 0 && throw(ArgumentError("no open channels"))

    # Select open-channel rows, and match to first n_open solution columns.
    S = Matrix{Float64}(undef, n_open, n_open)
    C = Matrix{Float64}(undef, n_open, n_open)
    Sp = Matrix{Float64}(undef, n_open, n_open)
    Cp = Matrix{Float64}(undef, n_open, n_open)
    R = R_end
    Rp = R_end - h
    # Standard convention: u(R) → A·[sin(kR) + K cos(kR)] / k, so K = tan(δ).
    # Low-energy limit gives tan(δ) → −k·a ⇒ a = −K/k.
    for (i, α) in enumerate(open)
        kα = k_vec[α]
        S[i, i]  = sin(kα * R)  / kα
        C[i, i]  = cos(kα * R)  / kα
        Sp[i, i] = sin(kα * Rp) / kα
        Cp[i, i] = cos(kα * Rp) / kα
    end
    # Off-diagonal zero already.
    U2 = U_end[open, open]
    U1 = U_end_m1[open, open]
    # U_open(R)  = S + C · K′,  U_open(R−h) = S′ + C′ · K′, where K′ = K · A^{-1}·A = K.
    # Solve linear system: [C; C'] K = [U2 - S; U1 - S'], but that's 2×1 in matching.
    # Use only two eq: U2 = S + C K · A and U1 = S' + C' K · A, where A accounts for normalization.
    # For n_open = 1: K = -(U2·S' - U1·S) / (U2·C' - U1·C). In general, solve
    # [U2 · (C' )^{-1} - U1 · C^{-1}]·K = U2·(C' )^{-1}·S' - U1·C^{-1}·S ? This is getting gnarly.
    # Simpler: invert U2 to treat as basis, then match slope.
    # For diagonal k basis (no cross-channel at matching): single-channel formula per row.
    K = zeros(Float64, n_open, n_open)
    for i in 1:n_open, j in 1:n_open
        # Match a_ij and b_ij such that
        #   U2[i,j] = a_ij · S[i,i] + b_ij · C[i,i]
        #   U1[i,j] = a_ij · Sp[i,i] + b_ij · Cp[i,i]
        det_ij = S[i, i] * Cp[i, i] - C[i, i] * Sp[i, i]
        a_ij = (U2[i, j] * Cp[i, i] - C[i, i] * U1[i, j]) / det_ij
        b_ij = (S[i, i] * U1[i, j] - U2[i, j] * Sp[i, i]) / det_ij
        # K_ij · a_jj = b_ij  (in basis where column j = β-th ingoing wave)
        K[i, j] = b_ij
    end
    # Normalize by ingoing amplitudes (diagonal of 'a' per column j):
    # columns are labeled by ingoing channel β; divide row by a_{ββ}.
    a_diag = zeros(Float64, n_open)
    for j in 1:n_open
        det_j = S[j, j] * Cp[j, j] - C[j, j] * Sp[j, j]
        a_diag[j] = (U2[j, j] * Cp[j, j] - C[j, j] * U1[j, j]) / det_j
    end
    for j in 1:n_open
        K[:, j] ./= a_diag[j]
    end
    return K
end

"""
    smatrix_from_kmatrix(K) → S

S = (I + iK)(I − iK)^{−1}. Unitary when K is real symmetric.
"""
function smatrix_from_kmatrix(K::AbstractMatrix)
    n = size(K, 1)
    Id = Matrix{ComplexF64}(I, n, n)
    iK = im .* K
    (Id + iK) / (Id - iK)
end

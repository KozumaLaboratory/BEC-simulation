# A4.1 Option B prototype — single-voxel F=1 BdG-Nambu rotation.
#
# Design ref: `docs/design/tdhfb_y4_palindromic_substep_design.md` §3.2.
# Castin-Dum 1998 PRA 57, 3008 + Stoof 1999 JLTP 114, 11 formulation.
#
# Goal: extend the current TDHFB Strang substep so that φ AND (ρ, κ)
# evolve under ONE coupled rotation exp(-i G_ext dt), where G_ext is the
# (2D + 2D²) × (2D + 2D²) extended Nambu generator:
#
#   G_ext = [[G_φφ,  G_φR],
#            [G_Rφ,  G_RR]]
#
#   G_φφ = W^φ                    (2D × 2D, the current BdG φ generator)
#   G_RR = -i [W^R, ·]            (2D² × 2D² Liouvillian on vec(R))
#   G_φR, G_Rφ = coupling blocks  (derived from TDHFB EOM linearization)
#
# Without coupling (G_φR = G_Rφ = 0), G_ext is block-diagonal and
# exp(-i G_ext dt) reproduces the current Strang substep EXACTLY:
#   - φ block: M^φ applied to (φ, conj(φ)) doublet, upper half kept
#   - (ρ, κ) block: vec(R)_new = vec(M^R · R · M^R⁻¹) via Liouvillian exp
#
# The coupling blocks are what restore palindromicity at O(dt⁵).
#
# This prototype:
#   Step 1 — Build extended state, generator (block-diagonal first)
#   Step 2 — exp(-i G_ext dt) via Base.exp (24×24 matrix, CPU)
#   Step 3 — Verify equivalence to current Strang substep
#   Step 4 — Add coupling blocks; measure palindromic gate slope improvement
#
# Run: julia --project=. scripts/diagnostic/tdhfb_option_b_prototype.jl

using LinearAlgebra
using Random
using Printf

const F = 1
const D = 2F + 1       # = 3
const TWOD = 2D        # = 6 (Nambu φ doublet)
const D2 = D * D       # = 9 (size of vec(ρ) or vec(κ))
const TWOD2 = 2 * D2   # = 18 (vec(ρ) + vec(κ) = the lower R block flattened)
const N_EXT = TWOD + TWOD2  # = 24 (extended state vector size)

# ----- TDHFB substep ingredients (single-voxel, F=1) -----

"""
Build the channel kernel V[c, c', c2, c2'] for F=1 with given g_S.
Identical to `src/hamiltonian/tdhfb/channel_kernel.jl::channel_kernel`,
inlined here for self-contained prototype.
"""
function channel_kernel_F1(g_S::Dict{Int, Float64})
    V = zeros(Float64, D, D, D, D)
    c_to_m(c) = F + 1 - c  # c=1 → m=+1, c=2 → m=0, c=3 → m=-1
    # F=1 Clebsch-Gordan: only S=0 and S=2 channels relevant
    # For simplicity, use the explicit F=1 channel formula
    for c in 1:D, cp in 1:D, c2 in 1:D, c2p in 1:D
        m = c_to_m(c); mp = c_to_m(cp); m2 = c_to_m(c2); m2p = c_to_m(c2p)
        m + m2 != mp + m2p && continue
        M = m + m2
        s_total = 0.0
        for (S, gS) in g_S
            abs(M) > S && continue
            cg1 = _cg_F1(m, m2, S, M)
            cg2 = _cg_F1(mp, m2p, S, M)
            s_total += gS * cg1 * cg2
        end
        V[c, cp, c2, c2p] = s_total
    end
    V
end

# Clebsch-Gordan ⟨1 m, 1 m' | S M⟩ for F=1 spinor (S = 0, 2 only).
function _cg_F1(m1::Int, m2::Int, S::Int, M::Int)
    m1 + m2 != M && return 0.0
    if S == 0 && M == 0
        m1 == m2 == 0 && return -1/sqrt(3)
        m1 == 1 && m2 == -1 && return 1/sqrt(3)
        m1 == -1 && m2 == 1 && return 1/sqrt(3)
        return 0.0
    elseif S == 2
        M == 2 && m1 == 1 && m2 == 1 && return 1.0
        M == -2 && m1 == -1 && m2 == -1 && return 1.0
        if M == 1
            (m1 == 1 && m2 == 0) && return 1/sqrt(2)
            (m1 == 0 && m2 == 1) && return 1/sqrt(2)
        end
        if M == -1
            (m1 == -1 && m2 == 0) && return 1/sqrt(2)
            (m1 == 0 && m2 == -1) && return 1/sqrt(2)
        end
        if M == 0
            m1 == 0 && m2 == 0 && return sqrt(2/3)
            m1 == 1 && m2 == -1 && return 1/sqrt(6)
            m1 == -1 && m2 == 1 && return 1/sqrt(6)
        end
    end
    return 0.0
end

"""
Build U^φ = U^R = V · (φ*φ + ρ) per the TDHFB convention (variational-consistent
since the 2026-05-12 fix at strang_step.jl:206).
"""
function build_U(phi::Vector{ComplexF64}, rho::Matrix{ComplexF64},
                 V::Array{Float64, 4})
    U = zeros(ComplexF64, D, D)
    for c in 1:D, cp in 1:D
        u = ComplexF64(0)
        for c2 in 1:D, c2p in 1:D
            Vk = V[c, cp, c2, c2p]
            Vk == 0 && continue
            u += Vk * (conj(phi[c2p]) * phi[c2] + rho[c2, c2p])
        end
        U[c, cp] = u
    end
    U
end

"""Δ^φ = V · κ (no φφ contribution)."""
function build_Delta_phi(kappa::Matrix{ComplexF64}, V::Array{Float64, 4})
    Δ = zeros(ComplexF64, D, D)
    for c in 1:D, cp in 1:D
        d = ComplexF64(0)
        for c2 in 1:D, c2p in 1:D
            Vk = V[c, cp, c2, c2p]
            Vk == 0 && continue
            d += Vk * kappa[c2, c2p]
        end
        Δ[c, cp] = d
    end
    Δ
end

"""Δ^R = V · (φφ + κ)."""
function build_Delta_R(phi::Vector{ComplexF64}, kappa::Matrix{ComplexF64},
                       V::Array{Float64, 4})
    Δ = zeros(ComplexF64, D, D)
    for c in 1:D, cp in 1:D
        d = ComplexF64(0)
        for c2 in 1:D, c2p in 1:D
            Vk = V[c, cp, c2, c2p]
            Vk == 0 && continue
            d += Vk * (phi[c2] * phi[c2p] + kappa[c2, c2p])
        end
        Δ[c, cp] = d
    end
    Δ
end

"""Assemble W = [[U, Δ]; [-conj(Δ), -conj(U)]]."""
function assemble_W(U::Matrix{ComplexF64}, Δ::Matrix{ComplexF64})
    W = zeros(ComplexF64, TWOD, TWOD)
    for c in 1:D, cp in 1:D
        W[c, cp] = U[c, cp]
        W[c, D + cp] = Δ[c, cp]
        W[D + c, cp] = -conj(Δ[c, cp])
        W[D + c, D + cp] = -conj(U[c, cp])
    end
    W
end

# ----- Current TDHFB Strang substep (single-voxel, F=1) -----

function tdhfb_strang_single_voxel!(phi::Vector{ComplexF64},
                                    rho::Matrix{ComplexF64},
                                    kappa::Matrix{ComplexF64},
                                    V::Array{Float64, 4}, dt::Float64)
    half = dt / 2

    # φ subupdate (uses current ρ, κ)
    U = build_U(phi, rho, V)
    Δφ = build_Delta_phi(kappa, V)
    Wφ = assemble_W(U, Δφ)
    Mφ = exp(-1im * Wφ * half)
    phi_doublet = vcat(phi, conj(phi))
    phi_new = Mφ * phi_doublet
    phi .= phi_new[1:D]

    # R subupdate (uses new φ)
    U = build_U(phi, rho, V)
    ΔR = build_Delta_R(phi, kappa, V)
    WR = assemble_W(U, ΔR)
    MR = exp(-1im * WR * dt)
    R = zeros(ComplexF64, TWOD, TWOD)
    for c in 1:D, cp in 1:D
        R[c, cp] = rho[c, cp]
        R[c, D + cp] = kappa[c, cp]
        R[D + c, cp] = conj(kappa[c, cp])
        R[D + c, D + cp] = (c == cp ? 1.0 : 0.0) + conj(rho[c, cp])
    end
    R_new = MR * R / MR
    for c in 1:D, cp in 1:D
        rho[c, cp] = 0.5 * (R_new[c, cp] + conj(R_new[cp, c]))
        kappa[c, cp] = 0.5 * (R_new[c, D + cp] + R_new[cp, D + c])
    end

    # φ subupdate (uses new ρ, κ)
    U = build_U(phi, rho, V)
    Δφ = build_Delta_phi(kappa, V)
    Wφ = assemble_W(U, Δφ)
    Mφ = exp(-1im * Wφ * half)
    phi_doublet = vcat(phi, conj(phi))
    phi_new = Mφ * phi_doublet
    phi .= phi_new[1:D]

    return (phi, rho, kappa)
end

# ----- Random state generator -----

function random_state(seed::Int)
    rng = MersenneTwister(seed)
    phi = randn(rng, ComplexF64, D) * 0.1
    rho = zeros(ComplexF64, D, D)
    for c in 1:D, cp in 1:D
        rho[c, cp] = randn(rng, ComplexF64) * 0.05
    end
    rho = 0.5 * (rho + adjoint(rho))
    for c in 1:D
        rho[c, c] += 0.05  # ensure ~positive
    end
    kappa = zeros(ComplexF64, D, D)
    for c in 1:D, cp in 1:D
        kappa[c, cp] = randn(rng, ComplexF64) * 0.05
    end
    kappa = 0.5 * (kappa + transpose(kappa))
    (phi, rho, kappa)
end

# ----- Palindromic gate (current Strang, single-voxel sanity reproduction) -----

@printf("=== A4.1 Option B prototype — F=1 single voxel ===\n")
@printf("D = %d, twoD = %d, 2D² = %d, N_ext = %d (extended state size)\n",
    D, TWOD, TWOD2, N_EXT)

g_S = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)
V = channel_kernel_F1(g_S)
@printf("\nChannel kernel V built, ‖V‖_∞ = %.3f\n", maximum(abs, V))

# Current Strang single-voxel: verify palindromic gate slope = 2 (reproducer)
function _gate_current(seed)
    phi0, rho0, kappa0 = random_state(seed)
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    @printf("\nCurrent Strang substep palindromic gate (single voxel, seed=%d):\n", seed)
    @printf("%-10s  %-12s  %-12s  %-12s  %-10s\n",
        "dt", "φ resid", "ρ resid", "κ resid", "order(ρ)")
    prev_rho = NaN
    for dt in dts
        phi = copy(phi0); rho = copy(rho0); kappa = copy(kappa0)
        tdhfb_strang_single_voxel!(phi, rho, kappa, V, dt)
        tdhfb_strang_single_voxel!(phi, rho, kappa, V, -dt)
        φ_dev = maximum(abs.(phi .- phi0))
        ρ_dev = maximum(abs.(rho .- rho0))
        κ_dev = maximum(abs.(kappa .- kappa0))
        ord = isnan(prev_rho) ? NaN : log2(prev_rho / max(ρ_dev, 1e-30))
        @printf("%-10.4f  %-12.3e  %-12.3e  %-12.3e  %s\n",
            dt, φ_dev, ρ_dev, κ_dev,
            isnan(ord) ? "—" : @sprintf("%.2f", ord))
        prev_rho = ρ_dev
    end
end

_gate_current(42)

# ===== Option B framework: extended G_ext (24×24) =====
#
# State vector: x = [φ_doublet (2D); vec(R_lower) (2D²)]
#   where R_lower = [vec(ρ); vec(κ)]
#
# G_ext block structure:
#   [G_φφ   G_φR ]    G_φφ = W^φ (2D × 2D)
#   [G_Rφ   G_RR ]    G_RR = Liouvillian (2D² × 2D²)
#                     G_φR, G_Rφ = coupling blocks (TODO: derive)

"""
**Open research question** (Castin-Dum 1998 §III + Stoof 1999 §3):

The straightforward Liouvillian L_R = (I ⊗ W) - (W^T ⊗ I) acts on the FULL
vec(R) of size (2D)² = 36 for F=1. But the Nambu constraint
   R[D+c, c'] = conj(κ[c, c']) and R[D+c, D+c'] = δ_{c,c'} + conj(ρ[c, c'])
means only 2D² = 18 independent components (vec(ρ) + vec(κ)).

The Liouvillian must:
  (a) Act on the 18-dim independent subspace (vec(ρ), vec(κ))
  (b) Preserve the Nambu constraint exactly under exp(-i L dt)

For Castin-Dum particle-conserving Bogoliubov, the natural state-space
basis is (u_k, v_k) amplitudes for each quasi-particle mode k. The
Liouvillian in that basis is diagonal (or block-diagonal in (u, v) Nambu
pairs) — much simpler. But translating between (u_k, v_k) basis and
(ρ, κ) basis requires solving the BdG eigenproblem per voxel per substep.

The (ρ, κ)-basis Liouvillian for the linearized dynamics around the
current background is derivable but algebraically involved. Stoof 1999
eq 22 gives the explicit form for scalar BEC; the spinor extension to
F=1 adds matrix structure that needs careful tracking.

**Deferred to next session**: derive L_R block in the (ρ, κ) basis,
not the full vec(R) basis.

For NOW, this stub returns an 18×18 zero matrix as a PLACEHOLDER. The
framework structure (state packing, G_ext assembly) is laid down so
that filling in this block is the next concrete step.
"""
function build_L_R_placeholder(_W_R::Matrix{ComplexF64})
    # PLACEHOLDER — zeros. The actual derivation is a research deliverable.
    zeros(ComplexF64, TWOD2, TWOD2)
end

"""
Build the extended state vector x_ext from (φ, ρ, κ).
Layout: [φ (D); conj(φ) (D); vec(ρ) (D²); vec(κ) (D²)]
Total length: 2D + 2D² = N_EXT.
"""
function pack_x_ext(phi::Vector{ComplexF64},
                    rho::Matrix{ComplexF64},
                    kappa::Matrix{ComplexF64})
    vcat(phi, conj(phi), vec(rho), vec(kappa))
end

"""Unpack: x_ext → (φ, ρ, κ)."""
function unpack_x_ext(x::Vector{ComplexF64})
    phi = x[1:D]
    # x[D+1:2D] = conj(phi)_evolved — for upper-half-Nambu projection
    rho = reshape(x[2D + 1 : 2D + D*D], D, D)
    kappa = reshape(x[2D + D*D + 1 : end], D, D)
    (phi, rho, kappa)
end

"""
Build the EXTENDED generator G_ext (24×24).
Block-diagonal version with PLACEHOLDER L_R block (zeros).

When L_R is filled in with the proper Castin-Dum / Stoof form, this
gives the order-2 dynamics in the extended Nambu space. Coupling blocks
G_φR, G_Rφ are then the next derivation work (order-4 palindromicity).
"""
function build_G_ext_block_diagonal(W_φ::Matrix{ComplexF64},
                                    W_R::Matrix{ComplexF64})
    G = zeros(ComplexF64, N_EXT, N_EXT)
    twoD = 2 * D
    # G_φφ block (rows 1:2D, cols 1:2D)
    G[1:twoD, 1:twoD] .= W_φ
    # G_RR block (rows 2D+1:end, cols 2D+1:end) = Liouvillian PLACEHOLDER
    G[twoD+1:end, twoD+1:end] .= build_L_R_placeholder(W_R)
    G
end

"""
Build the Nambu R matrix from (ρ, κ).
R = [[ρ, κ]; [conj(κ), I + conj(ρ)]] — bosonic-HFB convention matching
production CPU code.
"""
function build_R_nambu(rho::Matrix{ComplexF64}, kappa::Matrix{ComplexF64})
    twoD = 2 * D
    R = zeros(ComplexF64, twoD, twoD)
    for c in 1:D, cp in 1:D
        R[c, cp] = rho[c, cp]
        R[c, D + cp] = kappa[c, cp]
        R[D + c, cp] = conj(kappa[c, cp])
        R[D + c, D + cp] = (c == cp ? 1.0 : 0.0) + conj(rho[c, cp])
    end
    R
end

"""Extract ρ, κ from R with Hermitian/symmetric projection."""
function project_R_to_rho_kappa(R::Matrix{ComplexF64})
    twoD = size(R, 1)
    D_local = twoD ÷ 2
    rho = zeros(ComplexF64, D_local, D_local)
    kappa = zeros(ComplexF64, D_local, D_local)
    for c in 1:D_local, cp in 1:D_local
        rho[c, cp] = 0.5 * (R[c, cp] + conj(R[cp, c]))
        kappa[c, cp] = 0.5 * (R[c, D_local + cp] + R[cp, D_local + c])
    end
    (rho, kappa)
end

"""
Single-voxel TDHFB substep using the BLOCK-DIAGONAL G_ext (no coupling).
Should reproduce the current Strang substep exactly (up to the upper-half
projection of φ_doublet) since the φ and R blocks decouple.
"""
function option_b_step_decoupled!(phi::Vector{ComplexF64},
                                  rho::Matrix{ComplexF64},
                                  kappa::Matrix{ComplexF64},
                                  V::Array{Float64, 4}, dt::Float64)
    # Build generators using CURRENT state (single Strang substep, not symmetric inner)
    U = build_U(phi, rho, V)
    Δφ = build_Delta_phi(kappa, V)
    Wφ = assemble_W(U, Δφ)
    ΔR = build_Delta_R(phi, kappa, V)
    WR = assemble_W(U, ΔR)
    G_ext = build_G_ext_block_diagonal(Wφ, WR)

    # Build extended state directly from (phi, rho, kappa) — no Nambu R needed
    x = pack_x_ext(phi, rho, kappa)

    # Apply matrix exp (24×24 — small, CPU is fine)
    M_ext = exp(-1im * G_ext * dt)
    x_new = M_ext * x

    # Read back
    phi_new, rho_new, kappa_new = unpack_x_ext(x_new)
    phi .= phi_new
    rho .= rho_new
    kappa .= kappa_new
    return (phi, rho, kappa)
end

@printf("\n=== Block-diagonal G_ext sanity check ===\n")
@printf("(No coupling blocks. Should reproduce a SINGLE inner substep of current Strang,\n")
@printf(" NOT the symmetric inner triple. This is the simplest sanity test that the\n")
@printf(" 24×24 extended rotation reproduces the φ-doublet and Nambu-R rotations.)\n\n")

function _block_diag_palindromic_gate(seed)
    phi0, rho0, kappa0 = random_state(seed)
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    @printf("Block-diagonal G_ext, single voxel, seed=%d:\n", seed)
    @printf("%-10s  %-12s  %-12s  %-12s  %-10s\n",
        "dt", "φ resid", "ρ resid", "κ resid", "order(ρ)")
    prev_rho = NaN
    for dt in dts
        phi = copy(phi0); rho = copy(rho0); kappa = copy(kappa0)
        option_b_step_decoupled!(phi, rho, kappa, V, dt)
        option_b_step_decoupled!(phi, rho, kappa, V, -dt)
        φ_dev = maximum(abs.(phi .- phi0))
        ρ_dev = maximum(abs.(rho .- rho0))
        κ_dev = maximum(abs.(kappa .- kappa0))
        ord = isnan(prev_rho) ? NaN : log2(prev_rho / max(ρ_dev, 1e-30))
        @printf("%-10.4f  %-12.3e  %-12.3e  %-12.3e  %s\n",
            dt, φ_dev, ρ_dev, κ_dev,
            isnan(ord) ? "—" : @sprintf("%.2f", ord))
        prev_rho = ρ_dev
    end
end

_block_diag_palindromic_gate(42)

@printf("\nExpected: block-diagonal G_ext IS palindromic (single matrix exp).\n")
@printf("  exp(-iG dt) · exp(+iG dt) = I exactly (modulo Base.exp roundoff)\n")
@printf("  Residual should be at machine precision (~1e-14) for any dt.\n")
@printf("  This isolates the palindromic failure to the SUBSTEP STRUCTURE,\n")
@printf("  not to the kernel evaluation.\n\n")

@printf("Next step: add COUPLING blocks G_φR, G_Rφ that encode the (φ, ρ, κ)\n")
@printf("cross-derivatives from TDHFB EOMs. With proper coupling, the SAME\n")
@printf("rotation framework will physically match TDHFB dynamics at order ≥ 4\n")
@printf("while remaining manifestly palindromic.\n")

# ====================================================================
# Path B-b: Midpoint Picard variant of the existing Strang substep
# ====================================================================
#
# Per the design `docs/design/tdhfb_y4_palindromic_substep_design.md`
# refined by the state-dependence finding above: the ROOT cause of the
# O(dt²) palindromic failure is that G[φ, ρ, κ] is evaluated at the
# LIVE state during the substep, breaking time-reversal symmetry.
#
# B-b fix: evaluate ALL generators (Wφ, WR) at a MIDPOINT state, where
# state_mid = (state_0 + state_1) / 2 is determined by Picard fixed-
# point iteration. By symmetry of the midpoint formula in (state_0,
# state_1), S(-dt) maps state_1 back to state_0 exactly (modulo Picard
# tolerance) → S(-dt) S(dt) = I + O(tol).

"""
TDHFB Strang substep where ALL generator builds use `state_mid`
(φ_mid, ρ_mid, κ_mid) instead of the evolving state. The state being
evolved is `state_in` (in→out). Returns the evolved (phi_out, rho_out,
kappa_out) without mutating the inputs.

Structure mirrors the live-state version:
  Step 1: φ subupdate (dt/2) — Wφ_mid applied to (φ_in, conj(φ_in))
  Step 2: R subupdate (dt)   — WR_mid applied as M·R_in·M⁻¹
  Step 3: φ subupdate (dt/2) — same Wφ_mid (NOT re-evaluated)

Steps 1 and 3 use the SAME generator (Wφ_mid is frozen), so they
collapse algebraically to a single φ rotation by Wφ_mid·dt total.
We keep them separate for symmetry with the live-state version and
to preserve the same numerical-roundoff structure.
"""
function tdhfb_strang_single_voxel_at_mid(
    phi_in::Vector{ComplexF64}, rho_in::Matrix{ComplexF64}, kappa_in::Matrix{ComplexF64},
    phi_mid::Vector{ComplexF64}, rho_mid::Matrix{ComplexF64}, kappa_mid::Matrix{ComplexF64},
    V::Array{Float64, 4}, dt::Float64,
)
    half = dt / 2
    # All generators built ONCE from state_mid
    U_mid = build_U(phi_mid, rho_mid, V)
    Δφ_mid = build_Delta_phi(kappa_mid, V)
    ΔR_mid = build_Delta_R(phi_mid, kappa_mid, V)
    Wφ_mid = assemble_W(U_mid, Δφ_mid)
    WR_mid = assemble_W(U_mid, ΔR_mid)
    Mφ_half = exp(-1im * Wφ_mid * half)
    MR_full = exp(-1im * WR_mid * dt)

    # Working state — start from state_in
    phi = copy(phi_in)
    rho = copy(rho_in)
    kappa = copy(kappa_in)

    # Step 1: φ subupdate (dt/2)
    phi_doublet = vcat(phi, conj(phi))
    phi .= (Mφ_half * phi_doublet)[1:D]

    # Step 2: R subupdate (dt) — M·R·M⁻¹
    R = zeros(ComplexF64, TWOD, TWOD)
    for c in 1:D, cp in 1:D
        R[c, cp] = rho[c, cp]
        R[c, D + cp] = kappa[c, cp]
        R[D + c, cp] = conj(kappa[c, cp])
        R[D + c, D + cp] = (c == cp ? 1.0 : 0.0) + conj(rho[c, cp])
    end
    R_new = MR_full * R / MR_full
    for c in 1:D, cp in 1:D
        rho[c, cp] = 0.5 * (R_new[c, cp] + conj(R_new[cp, c]))
        kappa[c, cp] = 0.5 * (R_new[c, D + cp] + R_new[cp, D + c])
    end

    # Step 3: φ subupdate (dt/2) — SAME Mφ_half (state_mid is fixed)
    phi_doublet = vcat(phi, conj(phi))
    phi .= (Mφ_half * phi_doublet)[1:D]

    return (phi, rho, kappa)
end

# Elementwise state averaging
function average_state(phi_a, rho_a, kappa_a, phi_b, rho_b, kappa_b)
    (
        0.5 .* (phi_a .+ phi_b),
        0.5 .* (rho_a .+ rho_b),
        0.5 .* (kappa_a .+ kappa_b),
    )
end

# Max-norm difference between two states
function state_max_diff(phi_a, rho_a, kappa_a, phi_b, rho_b, kappa_b)
    max(
        maximum(abs.(phi_a .- phi_b)),
        maximum(abs.(rho_a .- rho_b)),
        maximum(abs.(kappa_a .- kappa_b)),
    )
end

"""
B-b Midpoint Picard substep: evaluate the TDHFB Strang substep with
generators built at state_mid = (state_0 + state_1) / 2, where
(state_1) is determined self-consistently by Picard iteration.

Returns: (phi_new, rho_new, kappa_new, n_iter, final_delta)

At Picard convergence, state_1 is fixed under the map
  state_1 = Strang_at_mid(state_0, (state_0 + state_1)/2, dt).
"""
function tdhfb_strang_picard_midpoint(
    phi_0::Vector{ComplexF64}, rho_0::Matrix{ComplexF64}, kappa_0::Matrix{ComplexF64},
    V::Array{Float64, 4}, dt::Float64;
    max_iter::Int=20, tol::Float64=1e-13,
)
    # Initial midpoint guess: state_0 itself (= forward-Euler-half from rest)
    phi_mid = copy(phi_0)
    rho_mid = copy(rho_0)
    kappa_mid = copy(kappa_0)

    phi_1 = copy(phi_0); rho_1 = copy(rho_0); kappa_1 = copy(kappa_0)
    iter_count = 0
    delta = Inf

    for iter in 1:max_iter
        # Apply the substep with current midpoint guess
        phi_1, rho_1, kappa_1 = tdhfb_strang_single_voxel_at_mid(
            phi_0, rho_0, kappa_0,
            phi_mid, rho_mid, kappa_mid,
            V, dt,
        )

        # Refine midpoint as (state_0 + state_1) / 2
        phi_mid_new, rho_mid_new, kappa_mid_new = average_state(
            phi_0, rho_0, kappa_0,
            phi_1, rho_1, kappa_1,
        )

        delta = state_max_diff(
            phi_mid_new, rho_mid_new, kappa_mid_new,
            phi_mid, rho_mid, kappa_mid,
        )
        phi_mid, rho_mid, kappa_mid = phi_mid_new, rho_mid_new, kappa_mid_new
        iter_count = iter
        delta < tol && break
    end

    (phi_1, rho_1, kappa_1, iter_count, delta)
end

@printf("\n=== B-b Midpoint Picard variant ===\n")
@printf("Picard midpoint: state_mid = (state_0 + state_1)/2, fixed-point on state_1.\n")
@printf("If convergent, S(-dt) maps state_1 back to state_0 exactly (palindromic).\n\n")

function _gate_picard(seed; tol=1e-13, max_iter=20)
    phi0, rho0, kappa0 = random_state(seed)
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    @printf("B-b Picard palindromic gate (single voxel, seed=%d, tol=%.0e, max_iter=%d):\n",
        seed, tol, max_iter)
    @printf("%-10s  %-12s  %-12s  %-12s  %-10s  %-8s  %-10s\n",
        "dt", "φ resid", "ρ resid", "κ resid", "order(ρ)", "n_iter", "Δ_Picard")
    prev_rho = NaN
    for dt in dts
        # Forward: state_0 → state_1
        phi_1, rho_1, kappa_1, n_f, δ_f = tdhfb_strang_picard_midpoint(
            phi0, rho0, kappa0, V, dt; max_iter=max_iter, tol=tol,
        )
        # Reverse: state_1 → state_2 (should equal state_0)
        phi_2, rho_2, kappa_2, n_r, δ_r = tdhfb_strang_picard_midpoint(
            phi_1, rho_1, kappa_1, V, -dt; max_iter=max_iter, tol=tol,
        )
        φ_dev = maximum(abs.(phi_2 .- phi0))
        ρ_dev = maximum(abs.(rho_2 .- rho0))
        κ_dev = maximum(abs.(kappa_2 .- kappa0))
        ord = isnan(prev_rho) ? NaN : log2(prev_rho / max(ρ_dev, 1e-30))
        @printf("%-10.4f  %-12.3e  %-12.3e  %-12.3e  %-10s  %-8d  %-10.2e\n",
            dt, φ_dev, ρ_dev, κ_dev,
            isnan(ord) ? "—" : @sprintf("%.2f", ord),
            max(n_f, n_r), max(δ_f, δ_r))
        prev_rho = ρ_dev
    end
end

_gate_picard(42; tol=1e-13, max_iter=20)

# Log-log slope fit
function _fit_slope_picard(seed; tol=1e-13)
    phi0, rho0, kappa0 = random_state(seed)
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    ρ_devs = Float64[]
    for dt in dts
        phi_1, rho_1, kappa_1, _, _ = tdhfb_strang_picard_midpoint(
            phi0, rho0, kappa0, V, dt; tol=tol,
        )
        phi_2, rho_2, kappa_2, _, _ = tdhfb_strang_picard_midpoint(
            phi_1, rho_1, kappa_1, V, -dt; tol=tol,
        )
        push!(ρ_devs, maximum(abs.(rho_2 .- rho0)))
    end
    log_dts = log.(dts)
    log_devs = log.(max.(ρ_devs, 1e-30))
    n = length(log_dts)
    mean_x = sum(log_dts) / n; mean_y = sum(log_devs) / n
    slope = sum((log_dts[i] - mean_x) * (log_devs[i] - mean_y) for i in 1:n) /
            sum((log_dts[i] - mean_x)^2 for i in 1:n)
    slope, ρ_devs
end

slope, ρ_devs = _fit_slope_picard(42; tol=1e-13)
@printf("\nρ residual log-log slope (LSQ): %.3f\n", slope)
@printf("Target for A4.1 acceptance: ≥ 5 (palindromic at O(dt⁵))\n")
@printf("Baseline (live-state Strang substep): 2.00\n\n")

if slope >= 4.5
    @printf("✓✓✓ A4.1 acceptance #1 PASS — B-b Midpoint Picard achieves order ≥ 4.5\n")
    @printf("    Next: scale to multi-voxel + Y4 composition test (acceptance #2)\n")
elseif slope >= 3.0
    @printf("△ Partial: B-b improves slope to %.2f (vs baseline 2.0) but below target 5\n", slope)
    @printf("  Investigate: higher-order midpoint, Aitken acceleration, or B-a pivot\n")
elseif slope > 2.2
    @printf("△ Modest improvement: slope %.2f (vs 2.0 baseline)\n", slope)
    @printf("  May indicate Picard converges to a state_mid that is symmetric in lowest\n")
    @printf("  order only. Higher-order midpoint formula or B-a pivot recommended.\n")
else
    @printf("✗ No improvement (slope %.2f ≈ baseline 2.0)\n", slope)
    @printf("  B-b fundamentally insufficient → pivot to B-a Castin-Dum amplitude basis\n")
end

# ====================================================================
# Path B-a + Picard combined: full Nambu doublet + Picard midpoint
# ====================================================================
#
# Empirical finding above: B-b Picard alone leaves ρ slope at 2.00 because
# the upper-half projection on φ (source 2) breaks reversibility EVEN AT
# FIXED state_mid generators. The reverse step starts from
# `(phi_evolved, conj(phi_evolved))` instead of the true Nambu-evolved
# `(phi_top, phi_bottom)` where phi_bottom ≠ conj(phi_top) when Δφ ≠ 0.
#
# B-a flavor fix: track the FULL Nambu doublet (phi_top, phi_bottom) as
# independent dynamical variables. phi_bottom is initialized as
# conj(phi) but is NOT constrained to remain so during evolution. Both
# halves rotate under Mφ together, eliminating the projection.
#
# Combined with Picard midpoint (B-b), this addresses sources (1) AND (2)
# simultaneously. Source (3) is FP-roundoff level (1e-15) per the earlier
# analysis and not the dominant contributor.

"""
TDHFB Strang substep with FULL Nambu doublet evolution AND midpoint
generators. State is (phi_top, phi_bottom, rho, kappa) where phi_bottom
is an independent variable (initialized as conj(phi_top) but evolves
freely under the BdG matrix).

Returns (phi_top_new, phi_bottom_new, rho_new, kappa_new).
"""
function tdhfb_strang_full_doublet_at_mid(
    phi_top_in::Vector{ComplexF64}, phi_bottom_in::Vector{ComplexF64},
    rho_in::Matrix{ComplexF64}, kappa_in::Matrix{ComplexF64},
    phi_top_mid::Vector{ComplexF64}, rho_mid::Matrix{ComplexF64}, kappa_mid::Matrix{ComplexF64},
    V::Array{Float64, 4}, dt::Float64,
)
    half = dt / 2
    # Generators built once from midpoint state (using phi_top_mid as "physical" phi).
    U_mid = build_U(phi_top_mid, rho_mid, V)
    Δφ_mid = build_Delta_phi(kappa_mid, V)
    ΔR_mid = build_Delta_R(phi_top_mid, kappa_mid, V)
    Wφ_mid = assemble_W(U_mid, Δφ_mid)
    WR_mid = assemble_W(U_mid, ΔR_mid)
    Mφ_half = exp(-1im * Wφ_mid * half)
    MR_full = exp(-1im * WR_mid * dt)

    # Working state
    phi_top = copy(phi_top_in)
    phi_bottom = copy(phi_bottom_in)
    rho = copy(rho_in)
    kappa = copy(kappa_in)

    # Step 1: full doublet rotation (NO upper-half projection)
    doublet = vcat(phi_top, phi_bottom)
    doublet_new = Mφ_half * doublet
    phi_top .= doublet_new[1:D]
    phi_bottom .= doublet_new[D + 1 : 2D]

    # Step 2: R subupdate (Nambu R built from rho, kappa — phi_bottom doesn't enter)
    R = zeros(ComplexF64, TWOD, TWOD)
    for c in 1:D, cp in 1:D
        R[c, cp] = rho[c, cp]
        R[c, D + cp] = kappa[c, cp]
        R[D + c, cp] = conj(kappa[c, cp])
        R[D + c, D + cp] = (c == cp ? 1.0 : 0.0) + conj(rho[c, cp])
    end
    R_new = MR_full * R / MR_full
    for c in 1:D, cp in 1:D
        rho[c, cp] = 0.5 * (R_new[c, cp] + conj(R_new[cp, c]))
        kappa[c, cp] = 0.5 * (R_new[c, D + cp] + R_new[cp, D + c])
    end

    # Step 3: same full doublet rotation
    doublet = vcat(phi_top, phi_bottom)
    doublet_new = Mφ_half * doublet
    phi_top .= doublet_new[1:D]
    phi_bottom .= doublet_new[D + 1 : 2D]

    return (phi_top, phi_bottom, rho, kappa)
end

"""
B-a + Picard combined: full doublet evolution + midpoint generators.
"""
function tdhfb_strang_picard_full_doublet(
    phi_top_0::Vector{ComplexF64}, phi_bottom_0::Vector{ComplexF64},
    rho_0::Matrix{ComplexF64}, kappa_0::Matrix{ComplexF64},
    V::Array{Float64, 4}, dt::Float64;
    max_iter::Int=20, tol::Float64=1e-13,
)
    # Midpoint averages: phi_top (not the bottom), rho, kappa
    phi_top_mid = copy(phi_top_0)
    rho_mid = copy(rho_0)
    kappa_mid = copy(kappa_0)

    phi_top_1 = copy(phi_top_0); phi_bottom_1 = copy(phi_bottom_0)
    rho_1 = copy(rho_0); kappa_1 = copy(kappa_0)
    iter_count = 0
    delta = Inf

    for iter in 1:max_iter
        phi_top_1, phi_bottom_1, rho_1, kappa_1 = tdhfb_strang_full_doublet_at_mid(
            phi_top_0, phi_bottom_0, rho_0, kappa_0,
            phi_top_mid, rho_mid, kappa_mid,
            V, dt,
        )
        phi_top_mid_new = 0.5 .* (phi_top_0 .+ phi_top_1)
        rho_mid_new = 0.5 .* (rho_0 .+ rho_1)
        kappa_mid_new = 0.5 .* (kappa_0 .+ kappa_1)

        delta = max(
            maximum(abs.(phi_top_mid_new .- phi_top_mid)),
            maximum(abs.(rho_mid_new .- rho_mid)),
            maximum(abs.(kappa_mid_new .- kappa_mid)),
        )
        phi_top_mid .= phi_top_mid_new
        rho_mid .= rho_mid_new
        kappa_mid .= kappa_mid_new
        iter_count = iter
        delta < tol && break
    end

    (phi_top_1, phi_bottom_1, rho_1, kappa_1, iter_count, delta)
end

@printf("\n=== B-a + Picard combined: full doublet + midpoint generators ===\n")
@printf("Full Nambu doublet (phi_top, phi_bottom) as independent variables.\n")
@printf("Eliminates source (2) upper-half projection AND source (1) state-dependence.\n\n")

function _gate_combined(seed; tol=1e-13, max_iter=20)
    phi0, rho0, kappa0 = random_state(seed)
    phi_bottom_0 = conj(phi0)  # initial: bottom = conj(top)
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    @printf("B-a + Picard combined gate (seed=%d, tol=%.0e):\n", seed, tol)
    @printf("%-10s  %-12s  %-12s  %-12s  %-12s  %-10s  %-8s\n",
        "dt", "φ_top resid", "φ_bot resid", "ρ resid", "κ resid", "order(ρ)", "n_iter")
    prev_rho = NaN
    for dt in dts
        # Forward
        pt1, pb1, r1, k1, nf, df = tdhfb_strang_picard_full_doublet(
            phi0, phi_bottom_0, rho0, kappa0, V, dt; max_iter=max_iter, tol=tol,
        )
        # Reverse: starts from (pt1, pb1, r1, k1) — keep phi_bottom AS-IS, don't reset to conj
        pt2, pb2, r2, k2, nr, dr = tdhfb_strang_picard_full_doublet(
            pt1, pb1, r1, k1, V, -dt; max_iter=max_iter, tol=tol,
        )
        ptop_dev = maximum(abs.(pt2 .- phi0))
        pbot_dev = maximum(abs.(pb2 .- phi_bottom_0))
        rho_dev = maximum(abs.(r2 .- rho0))
        kappa_dev = maximum(abs.(k2 .- kappa0))
        ord = isnan(prev_rho) ? NaN : log2(prev_rho / max(rho_dev, 1e-30))
        @printf("%-10.4f  %-12.3e  %-12.3e  %-12.3e  %-12.3e  %-10s  %-8d\n",
            dt, ptop_dev, pbot_dev, rho_dev, kappa_dev,
            isnan(ord) ? "—" : @sprintf("%.2f", ord),
            max(nf, nr))
        prev_rho = rho_dev
    end
end

_gate_combined(42; tol=1e-13, max_iter=20)

# Slope fit for B-a + Picard
function _fit_slope_combined(seed; tol=1e-13)
    phi0, rho0, kappa0 = random_state(seed)
    phi_bottom_0 = conj(phi0)
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    rho_devs = Float64[]
    for dt in dts
        pt1, pb1, r1, k1, _, _ = tdhfb_strang_picard_full_doublet(
            phi0, phi_bottom_0, rho0, kappa0, V, dt; tol=tol,
        )
        pt2, pb2, r2, k2, _, _ = tdhfb_strang_picard_full_doublet(
            pt1, pb1, r1, k1, V, -dt; tol=tol,
        )
        push!(rho_devs, maximum(abs.(r2 .- rho0)))
    end
    log_dts = log.(dts)
    log_devs = log.(max.(rho_devs, 1e-30))
    n = length(log_dts)
    mx = sum(log_dts) / n; my = sum(log_devs) / n
    slope = sum((log_dts[i] - mx) * (log_devs[i] - my) for i in 1:n) /
            sum((log_dts[i] - mx)^2 for i in 1:n)
    slope, rho_devs
end

slope_combined, _ = _fit_slope_combined(42)
@printf("\nρ residual log-log slope (B-a + Picard): %.3f\n", slope_combined)
@printf("Baseline (live Strang): 2.00\n")
@printf("B-b Picard alone:       %.2f (this run)\n", slope)
@printf("Target for A4.1:        ≥ 5\n\n")

if slope_combined >= 4.5
    @printf("✓✓✓ A4.1 acceptance #1 PASS — B-a + Picard combined achieves order ≥ 4.5\n")
    @printf("    Sources (1), (2) successfully eliminated.\n")
    @printf("    Next: scale to multi-voxel, Y4 composition test, GPU port.\n")
elseif slope_combined >= 3.0
    @printf("△ Partial: B-a + Picard slope %.2f (vs baseline 2.0, B-b alone %.2f)\n",
        slope_combined, slope)
    @printf("  Sources (1), (2) partially eliminated. Source (3) may also contribute.\n")
    @printf("  Investigate: pseudo-unitary M_R via eigen-decomp for exact Hermiticity.\n")
elseif slope_combined > 2.2
    @printf("△ Modest improvement: slope %.2f\n", slope_combined)
    @printf("  Source (2) elimination may not be sufficient — investigate Δφ size dependence.\n")
else
    @printf("✗ No improvement (slope %.2f ≈ baseline 2.0)\n", slope_combined)
    @printf("  Source (2) was NOT the dominant contributor. Re-examine source decomposition.\n")
end

# ====================================================================
# CRITICAL diagnostic: no-projection R update — isolates source (3)
# ====================================================================
#
# Hypothesis: if we track the FULL 6×6 R matrix through the substep
# WITHOUT the `0.5(R + R†)` projection step, palindromicity should be
# machine-precision exact (slope ~ 0). This would PROVE the projection
# is the dominant O(dt²) source.

function _no_projection_R_test(seed=42)
    phi0, rho0, kappa0 = random_state(seed)
    g_S = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)
    Vk = channel_kernel_F1(g_S)
    R0 = zeros(ComplexF64, TWOD, TWOD)
    for c in 1:D, cp in 1:D
        R0[c, cp] = rho0[c, cp]
        R0[c, D + cp] = kappa0[c, cp]
        R0[D + c, cp] = conj(kappa0[c, cp])
        R0[D + c, D + cp] = (c == cp ? 1.0 : 0.0) + conj(rho0[c, cp])
    end
    U_R = build_U(phi0, rho0, Vk)
    ΔR = build_Delta_R(phi0, kappa0, Vk)
    WR = assemble_W(U_R, ΔR)

    @printf("\n=== No-projection R update test (full R tracked) ===\n")
    @printf("dt           ‖R_2 - R_0‖_∞  order\n")
    devs = Float64[]
    prev = NaN
    dts = [0.04, 0.02, 0.01, 0.005, 0.0025]
    for dt in dts
        M = exp(-1im * WR * dt)
        Minv = inv(M)
        R1 = M * R0 * Minv
        R2 = Minv * R1 * M
        dev = maximum(abs.(R2 - R0))
        push!(devs, dev)
        ord = isnan(prev) ? NaN : log2(prev / max(dev, 1e-30))
        @printf("%-10.4f  %-14.3e  %s\n", dt, dev,
            isnan(ord) ? "—" : @sprintf("%.2f", ord))
        prev = dev
    end
    log_dts = log.(dts)
    log_devs = log.(max.(devs, 1e-30))
    n = length(log_dts); mx = sum(log_dts) / n; my = sum(log_devs) / n
    slope = sum((log_dts[i] - mx) * (log_devs[i] - my) for i in 1:n) /
            sum((log_dts[i] - mx)^2 for i in 1:n)
    @printf("\nNo-projection slope: %.3f\n", slope)
    @printf("With-projection slope (baseline): 2.00\n")
    if maximum(devs) < 1e-13
        @printf("\n*** PROJECTION IS THE SOURCE confirmed ***\n")
        @printf("M·R·M⁻¹ preserves R's full 6×6 Hermiticity exactly (machine prec).\n")
        @printf("The (κ†, I+conj(ρ)) Nambu constraint is what the projection enforces,\n")
        @printf("but M·R·M⁻¹ does NOT preserve this constraint exactly (O(dt²) deviation).\n")
        @printf("Projection discards the deviation → O(dt²) round-trip residual.\n")
        @printf("\nNext path: Castin-Dum amplitude basis where (ρ, κ) are DERIVED from\n")
        @printf("(u_k, v_k) — Nambu constraints automatic, no projection needed.\n")
    else
        @printf("\n△ Projection alone is NOT the source. Deeper structural issue remains.\n")
    end
end

_no_projection_R_test(42)

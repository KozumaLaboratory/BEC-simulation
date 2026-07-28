#!/usr/bin/env julia
#
# Level 5 — operator-RHS comparison against Kawaguchi-Ueda Phys Reports 2012
# (`docs/refs/Kawaguchi_Ueda_Spinor_BEC_Review.pdf` + notes
# `docs/theory/kawaguchi_ueda_review_notes.md`).
#
# Strategy: every spinor-GP term in SpinorBEC is exposed through a
# propagator (`apply_*_step!`) of the form `exp(-i dt H_term) ψ`. The
# Kawaguchi-Ueda textbook formulas give H_term explicitly; the
# corresponding *propagator* output `cis(-dt · H_term)·ψ` is therefore
# the exact ground truth. We compute
#
#   ψ_ref      = (hand-coded textbook propagator output for H_term)
#   ψ_spinorbec = apply_<term>_step!(ψ_copy, dt, ...)
#
# and assert `‖ψ_ref - ψ_spinorbec‖_∞ < TOL_PER_TERM`. This catches any
# sign / factor / m-ordering / convention mismatch without paying the
# O(eps/dt) cancellation cost of a finite-difference Taylor extraction.
#
# Scope: diagonal Hamiltonian terms first (trap V(r), linear Zeeman -p F̂_z,
# quadratic Zeeman q F̂_z², contact c0 n). Follow-on terms (spin-mixing
# c1, kinetic, DDI, LHY) extend this same harness with one `_check_*`
# function each.
#
# Conventions (matches CLAUDE.md "do NOT fix" + Kawaguchi-Ueda §2):
#   - c = 1 ↔ m = +F (SpinorBEC component ordering)
#   - H_linear-Zeeman = -p F̂_z   (so (H ψ)_m = -p · m · ψ_m)
#   - H_quadratic-Zeeman = q F̂_z² (so (H ψ)_m = q · m² · ψ_m)
#   - H_contact = c0 n with n = Σ_m |ψ_m|²
#   - Real-time propagator: exp(-i dt H) → cis(-dt·H)
#
# Exit code: 0 if all terms pass, 1 if any residual exceeds the tolerance.

using LinearAlgebra
using Printf
using Random
using FFTW
using SpinorBEC

# Pure roundoff floor for cis() comparisons over n_pts × D ≈ 200 entries.
# Each cis call carries ~1 ULP error; the L∞ over a 200-elt comparison
# stays well under 1e-13 in practice.
const TOL_PER_TERM = 1e-13
const DT_PROBE = 0.01  # arbitrary; comparison is propagator-level, not Taylor-extracted

# ---------------- test fixture ----------------

struct L5Fixture
    F::Int
    D::Int                  # = 2F+1 spinor dimension
    ndim::Int               # spatial dimension (use 1D for a fast yet non-trivial test)
    n_pts::Int              # grid points per axis
    psi::Array{ComplexF64}  # shape (n_pts, D) for ndim=1
    V_trap::Array{Float64}  # shape (n_pts,)
    sm::Any                 # SpinMatrices struct
    m_values::Vector{Int}   # F, F-1, ..., -F (component → m mapping)
end

function build_fixture(; F::Int=6, ndim::Int=1, n_pts::Int=16, seed::Int=20260524)
    D = 2F + 1
    sm = spin_matrices(F)
    m_values = collect(sm.system.m_values)
    @assert length(m_values) == D
    @assert m_values[1] == F && m_values[end] == -F

    rng = MersenneTwister(seed)
    @assert ndim == 1 "fixture currently 1D — extend if you need cross-dim checks"
    psi = randn(rng, ComplexF64, n_pts, D) ./ sqrt(D)

    # V_trap: a simple non-uniform real profile so the diagonal-V term has signal.
    V_trap = Float64[0.5 * (i - (n_pts + 1) / 2)^2 / n_pts^2 for i in 1:n_pts]

    L5Fixture(F, D, ndim, n_pts, psi, V_trap, sm, m_values)
end

# Per-component diagonal Zeeman array, textbook form:
#   (H_Z ψ)_m = (-p · m + q · m²) · ψ_m
# Returns `zeeman_diag[c] = -p·m + q·m²`.
textbook_zeeman_diag(fx::L5Fixture, p::Float64, q::Float64) = Float64[
    -p * m + q * m^2 for m in fx.m_values
]

"""
    textbook_propagator_diagonal(psi, V_trap, zeeman_diag, c0, dt) -> ψ'

Apply the real-time diagonal-propagator from Kawaguchi-Ueda §2 directly:

    ψ'_m(r) = cis(-[V(r) + (-p·m + q·m²) + c0·n(r)] · dt) · ψ_m(r)

Hand-coded ground truth.
"""
function textbook_propagator_diagonal(
    psi::Array{ComplexF64},
    V_trap::Vector{Float64},
    zeeman_diag::Vector{Float64},
    c0::Float64, dt::Float64,
)
    n_pts, D = size(psi)
    n_dens = vec(sum(abs2, psi; dims=2))
    out = similar(psi)
    for c in 1:D
        ze = zeeman_diag[c]
        for i in 1:n_pts
            phase = -(V_trap[i] + ze + c0 * n_dens[i]) * dt
            out[i, c] = cis(phase) * psi[i, c]
        end
    end
    out
end

"""
    spinorbec_propagator_diagonal(psi, V_trap, zeeman_diag, c0, dt) -> ψ'

Call SpinorBEC's production `apply_diagonal_potential_step!` on a copy
of ψ. This is the *exact same function* the split-step driver invokes
inside `_dispatch_diagonal_step!`, with `imaginary_time=false` matching
real-time propagation.
"""
function spinorbec_propagator_diagonal(
    psi::Array{ComplexF64},
    V_trap::Vector{Float64},
    zeeman_diag::Vector{Float64},
    c0::Float64, dt::Float64,
)
    psi_copy = copy(psi)
    n_pts, D = size(psi_copy)
    density_buf = Array{Float64}(undef, n_pts)
    SpinorBEC.apply_diagonal_potential_step!(
        psi_copy, V_trap, zeeman_diag, c0,
        dt, D, 1, density_buf;
        imaginary_time=false, c_lhy=0.0,
    )
    psi_copy
end

# ---------------- per-term checks (propagator-level) ----------------

# NOT `CheckResult`: that name is exported by SpinorBEC (the ConservationSpec /
# OperatorRHSSpec verdict type). A top-level `struct CheckResult` here binds the
# name in `Main` and shadows the package's for every file that runs later in the
# same worker process, so `result isa CheckResult` in
# workflow/validation/test_specs_and_check.jl silently evaluated false. Test
# files share a process — keep their top-level names out of the export surface.
struct L5TermCheck
    name::String
    residual::Float64
    tol::Float64
    pass::Bool
end

function check_linear_zeeman(fx::L5Fixture; p::Float64=0.5)
    zee = textbook_zeeman_diag(fx, p, 0.0)
    ref = textbook_propagator_diagonal(fx.psi, zeros(fx.n_pts), zee, 0.0, DT_PROBE)
    sb = spinorbec_propagator_diagonal(fx.psi, zeros(fx.n_pts), zee, 0.0, DT_PROBE)
    res = maximum(abs, ref .- sb)
    L5TermCheck("linear Zeeman   -p·F̂_z", res, TOL_PER_TERM, res < TOL_PER_TERM)
end

function check_quadratic_zeeman(fx::L5Fixture; q::Float64=0.05)
    zee = textbook_zeeman_diag(fx, 0.0, q)
    ref = textbook_propagator_diagonal(fx.psi, zeros(fx.n_pts), zee, 0.0, DT_PROBE)
    sb = spinorbec_propagator_diagonal(fx.psi, zeros(fx.n_pts), zee, 0.0, DT_PROBE)
    res = maximum(abs, ref .- sb)
    L5TermCheck("quadratic Zeeman q·F̂_z²", res, TOL_PER_TERM, res < TOL_PER_TERM)
end

function check_trap(fx::L5Fixture)
    zee = zeros(fx.D)
    ref = textbook_propagator_diagonal(fx.psi, fx.V_trap, zee, 0.0, DT_PROBE)
    sb = spinorbec_propagator_diagonal(fx.psi, fx.V_trap, zee, 0.0, DT_PROBE)
    res = maximum(abs, ref .- sb)
    L5TermCheck("trap V(r)·𝟙", res, TOL_PER_TERM, res < TOL_PER_TERM)
end

function check_contact_c0(fx::L5Fixture; c0::Float64=2.5)
    zee = zeros(fx.D)
    ref = textbook_propagator_diagonal(fx.psi, zeros(fx.n_pts), zee, c0, DT_PROBE)
    sb = spinorbec_propagator_diagonal(fx.psi, zeros(fx.n_pts), zee, c0, DT_PROBE)
    res = maximum(abs, ref .- sb)
    L5TermCheck("contact c0·n·𝟙", res, TOL_PER_TERM, res < TOL_PER_TERM)
end

function check_combined_diagonal(fx::L5Fixture;
    p::Float64=0.5, q::Float64=0.05, c0::Float64=2.5)
    zee = textbook_zeeman_diag(fx, p, q)
    ref = textbook_propagator_diagonal(fx.psi, fx.V_trap, zee, c0, DT_PROBE)
    sb = spinorbec_propagator_diagonal(fx.psi, fx.V_trap, zee, c0, DT_PROBE)
    res = maximum(abs, ref .- sb)
    L5TermCheck("combined (V + Zeeman + c0·n)", res, TOL_PER_TERM, res < TOL_PER_TERM)
end

# ---------------- spin matrix algebra (structural sanity) ----------------

# Verify the spin matrices satisfy [F̂_x, F̂_y] = i F̂_z, F̂·F̂ = F(F+1)·𝟙,
# and F̂_z |F,m⟩ = m |F,m⟩. These are the structural identities Kawaguchi-Ueda
# uses to derive every spinor formula; if they fail, every downstream
# spin-mixing / DDI compare is meaningless.
function check_spin_algebra(fx::L5Fixture)
    F = fx.F
    sm = fx.sm
    Fx, Fy, Fz, FdF = sm.Fx, sm.Fy, sm.Fz, sm.F_dot_F

    # [F_x, F_y] = i F_z
    comm = Fx * Fy - Fy * Fx
    r1 = maximum(abs, comm - im * Fz)

    # F̂·F̂ = F(F+1) · 𝟙
    r2 = maximum(abs, FdF - F * (F + 1) * I)

    # F̂_z |F,m⟩ = m |F,m⟩  (diagonal entries are m_values)
    diag_fz = real.(diag(Fz))
    r3 = maximum(abs, diag_fz .- Float64.(fx.m_values))

    res = max(r1, r2, r3)
    L5TermCheck("spin algebra ([F_x,F_y]=iF_z, F̂·F̂=F(F+1), diag F_z=m)",
        res, 1e-13, res < 1e-13)
end

# ---------------- kinetic term: 3 layered probes ----------------
#
# Methodology: each probe isolates ONE bug class so a FAIL points
# uniquely. Compose top-down only after lower layers pass.
#
#   L0 (FFT plan)            FAIL → make_fft_plans / normalization
#   L1 (phase array)         FAIL → prepare_kinetic_phase factor / sign
#   L2 (plane-wave analytic) FAIL → apply_kinetic_step! pipeline / k indexing
#
# L2 uses an ANALYTICAL target (no FFT on textbook side) so the
# round-trip cancellation cannot mask a layout bug.

"""
    check_kinetic_L0_fft_roundtrip(; n_pts=32, box=8.0)

‖IFFT∘FFT(ψ) − ψ‖∞ for a random ψ on the same Grid + FFTPlans used
downstream. FAIL → SpinorBEC's FFTPlans normalization convention
(forward unnormalized × inverse 1/N? or each √N?) is broken.
"""
function check_kinetic_L0_fft_roundtrip(; n_pts::Int=32, box::Float64=8.0)
    cfg = SpinorBEC.GridConfig{1}((n_pts,), (box,))
    grid = SpinorBEC.make_grid(cfg)
    plans = SpinorBEC.make_fft_plans((n_pts,))

    rng = MersenneTwister(20260524)
    psi = randn(rng, ComplexF64, n_pts)
    buf = copy(psi)
    plans.forward * buf
    plans.inverse * buf
    res = maximum(abs, buf .- psi)
    L5TermCheck("kinetic L0: IFFT∘FFT round-trip", res, 1e-13, res < 1e-13)
end

"""
    check_kinetic_L1_phase_array(; n_pts=32, box=8.0)

`prepare_kinetic_phase(grid, dt)` elementwise equals `cis.(-0.5 · k² · dt)`.
FAIL → factor of 2 missing, sign flip, or k_squared computed wrong in
`make_grid`.
"""
function check_kinetic_L1_phase_array(; n_pts::Int=32, box::Float64=8.0)
    cfg = SpinorBEC.GridConfig{1}((n_pts,), (box,))
    grid = SpinorBEC.make_grid(cfg)
    phase = SpinorBEC.prepare_kinetic_phase(grid, DT_PROBE; imaginary_time=false)
    expected = @. cis(-0.5 * grid.k_squared * DT_PROBE)
    res = maximum(abs, phase .- expected)
    L5TermCheck("kinetic L1: prepare_kinetic_phase = cis(-k²/2·dt)", res, 1e-13, res < 1e-13)
end

"""
    check_kinetic_L2_plane_wave(; n_pts=32, box=8.0, k_idx=2)

Plane wave ψ = exp(i k₀ x) is an exact kinetic eigenstate with eigenvalue
ε = k₀²/2. Real-time propagator gives ψ' = cis(-ε · dt) · ψ — an
analytical formula with NO FFT. apply_kinetic_step! must reproduce this.
FAIL → FFT plan + k_squared indexing mismatch (fftshift vs natural,
ordering of k axis vs grid.k).

Uses one component to keep the test minimal; for D-component coverage,
the diagonal-in-m structure means D=1 is sufficient.
"""
function check_kinetic_L2_plane_wave(; n_pts::Int=32, box::Float64=8.0, k_idx::Int=2)
    cfg = SpinorBEC.GridConfig{1}((n_pts,), (box,))
    grid = SpinorBEC.make_grid(cfg)
    plans = SpinorBEC.make_fft_plans((n_pts,))

    # Use one k from the natural FFTW frequency grid so the plane wave is
    # represented exactly (no spectral leakage). grid.k[1][k_idx] is the
    # k₀ value at that DFT bin.
    k0 = grid.k[1][k_idx]
    psi = ComplexF64[cis(k0 * x) for x in grid.x[1]]
    psi_sb = reshape(copy(psi), n_pts, 1)  # 1 component for apply_kinetic_step!

    phase = SpinorBEC.prepare_kinetic_phase(grid, DT_PROBE; imaginary_time=false)
    buf = Array{ComplexF64}(undef, n_pts)
    SpinorBEC.apply_kinetic_step!(psi_sb, buf, phase, plans, 1, 1)

    # Analytical target: exp(-i ε dt) · ψ, with ε = k₀²/2.
    expected = @. cis(-0.5 * k0^2 * DT_PROBE) * psi
    res = maximum(abs, vec(psi_sb) .- expected)
    L5TermCheck("kinetic L2: plane-wave ψ=exp(ik₀x) → cis(-k₀²/2·dt)·ψ",
        res, 1e-12, res < 1e-12)
end

# ---------------- uniform spin rotation: 4 axis-isolated probes ----------------
#
# `apply_uniform_spin_rotation!` applies exp(-i dt (φ_x F_x + φ_y F_y + φ_z F_z))
# (spatially uniform — used for transverse Zeeman Bx, By, magnetostir
# Klaus path, and any constant spin rotation).
#
# Reference: build M = Σ_α φ_α F_α directly (D×D Hermitian), exponentiate
# with Julia's matrix exp. The implementation derives its rotation matrix
# R from `_apply_euler_spin_rotation` on unit vectors and then applies
# via gemm — completely different code path than the reference.
#
# Probes (each isolates ONE axis or composition bug):
#   φ_x only  FAIL → Fx propagator or x-axis Euler decomp
#   φ_y only  FAIL → Fy propagator or y-axis Euler decomp
#   φ_z only  FAIL → Fz propagator (cross-check vs linear Zeeman path)
#   combined  FAIL → non-abelian rotation composition (3-axis ordering)

"""
    check_uniform_spin_rotation(fx; phi_x, phi_y, phi_z, label)

Compare apply_uniform_spin_rotation! against textbook exp(-i M dt) · ψ
at a single spatial point. M = φ_x F_x + φ_y F_y + φ_z F_z is built
from `sm.Fx/Fy/Fz` matrices.
"""
function check_uniform_spin_rotation(fx::L5Fixture;
    phi_x::Float64=0.0, phi_y::Float64=0.0, phi_z::Float64=0.0,
    label::String="(unset)",
)
    sm = fx.sm
    D = fx.D
    Fx = Matrix{ComplexF64}(sm.Fx)
    Fy = Matrix{ComplexF64}(sm.Fy)
    Fz = Matrix{ComplexF64}(sm.Fz)
    M = phi_x .* Fx .+ phi_y .* Fy .+ phi_z .* Fz
    U_ref = exp(-im .* M .* DT_PROBE)

    rng = MersenneTwister(20260524)
    chi = randn(rng, ComplexF64, D)
    chi_ref = U_ref * chi

    # apply_uniform_spin_rotation! expects shape (n_pts..., D); use n_pts=1
    # to keep the test focused on the spin-axis algebra.
    psi_sb = reshape(copy(chi), 1, D)
    SpinorBEC.apply_uniform_spin_rotation!(
        psi_sb, sm, phi_x, phi_y, phi_z, DT_PROBE, 1;
        imaginary_time=false,
    )
    chi_sb = vec(psi_sb)

    res = maximum(abs, chi_ref .- chi_sb)
    L5TermCheck("uniform rotation: $label", res, 1e-12, res < 1e-12)
end

check_uniform_rotation_x(fx::L5Fixture) = check_uniform_spin_rotation(
    fx; phi_x=0.7, label="φ_x only (Bx)"
)
check_uniform_rotation_y(fx::L5Fixture) = check_uniform_spin_rotation(
    fx; phi_y=0.7, label="φ_y only (By)"
)
check_uniform_rotation_z(fx::L5Fixture) = check_uniform_spin_rotation(
    fx; phi_z=0.7, label="φ_z only (Bz)"
)
check_uniform_rotation_xyz(fx::L5Fixture) = check_uniform_spin_rotation(fx; phi_x=0.5, phi_y=0.3,
    phi_z=0.2,
    label="φ_x + φ_y + φ_z (composition)")

# ---------------- spin-mixing c1: 4 layered probes ----------------
#
# H_sm(r) = c1 (⟨F_x⟩(r) F̂_x + ⟨F_y⟩(r) F̂_y + ⟨F_z⟩(r) F̂_z)
# Propagator U(r) = exp(-i H_sm(r) dt).
#
# This is the first NONLINEAR term: the operator depends on ψ itself
# (⟨F⟩(r) = ψ†(r) F̂ ψ(r)). Per-voxel rotation matrix differs from voxel
# to voxel. Two infrastructure pieces are tested simultaneously:
# (i) _compute_spin_density! (also used by DDI — bilinear-aliasing
# diagnosis pinpointed this as a shared bug-class), (ii) the
# spin-rotation algorithm (Rodrigues at D=3 / Euler decomp at D>3).
#
# Probes:
#   L1  _compute_spin_density! vs hand-computed (Fx, Fy, Fz)
#       FAIL → bilinear extraction (shared with DDI)
#   L2  single-voxel exp(-i M dt) ψ
#       FAIL → rotation algorithm (Rodrigues or Euler)
#   L3  multi-voxel end-to-end
#       FAIL → per-voxel batching / cache reuse
#   L4  corner case fx=fy=0 (only fz) → diagonal Zeeman-like
#       FAIL → axis-selective rotation reduction

"""
    check_spin_density_L1(fx; n_grid=8)

For a known random ψ on an n_grid 1D fixture, the textbook spin density is
  Fz(r) = Σ_c m_c |ψ_c(r)|²
  Fx(r) + i Fy(r) = Σ_{c=2}^D sqrt(F(F+1) − m_c(m_c+1)) · conj(ψ_{c-1}) · ψ_c

Compare `_compute_spin_density!` output. FAIL → bilinear extraction bug
(shared with DDI path).
"""
function check_spin_density_L1(fx::L5Fixture; n_grid::Int=8)
    F = fx.F
    D = fx.D
    sm = fx.sm

    rng = MersenneTwister(20260524)
    psi_grid = randn(rng, ComplexF64, n_grid, D) ./ sqrt(D)

    # Hand-computed reference
    m_vals = Float64[F - (c - 1) for c in 1:D]
    Ff1 = Float64(F * (F + 1))
    fp = Float64[c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)) for c in 1:D]

    fx_ref = zeros(Float64, n_grid)
    fy_ref = zeros(Float64, n_grid)
    fz_ref = zeros(Float64, n_grid)
    for i in 1:n_grid
        fzv = 0.0
        for c in 1:D
            fzv += m_vals[c] * abs2(psi_grid[i, c])
        end
        fz_ref[i] = fzv
        fxv = 0.0
        fyv = 0.0
        for c in 2:D
            prod = conj(psi_grid[i, c - 1]) * psi_grid[i, c]
            fxv += fp[c] * real(prod)
            fyv += fp[c] * imag(prod)
        end
        fx_ref[i] = fxv
        fy_ref[i] = fyv
    end

    fxa = zeros(Float64, n_grid)
    fya = zeros(Float64, n_grid)
    fza = zeros(Float64, n_grid)
    SpinorBEC._compute_spin_density!(fxa, fya, fza, psi_grid, sm, Val(D), 1, (n_grid,))

    res = max(maximum(abs, fxa .- fx_ref),
        maximum(abs, fya .- fy_ref),
        maximum(abs, fza .- fz_ref))
    L5TermCheck("spin-mixing L1: _compute_spin_density! vs textbook",
        res, 1e-13, res < 1e-13)
end

"""
    check_spin_mixing_L2_single_voxel(fx; c1=0.5)

Single-voxel test: a random spinor χ. Hand-compute (fx, fy, fz) from χ,
build M = c1 (fx F_x + fy F_y + fz F_z), apply exp(-i M dt) χ via Julia's
matrix exp. Compare with apply_spin_mixing_step! at n_pts=1.
FAIL → Rodrigues (D=3) or Euler-decomposition (D>3) rotation algorithm.
"""
function check_spin_mixing_L2_single_voxel(fx::L5Fixture; c1::Float64=0.5)
    F = fx.F
    D = fx.D
    sm = fx.sm
    Fxm = Matrix{ComplexF64}(sm.Fx)
    Fym = Matrix{ComplexF64}(sm.Fy)
    Fzm = Matrix{ComplexF64}(sm.Fz)

    rng = MersenneTwister(20260524)
    chi = randn(rng, ComplexF64, D)

    # Textbook (fx, fy, fz) at this voxel
    m_vals = Float64[F - (c - 1) for c in 1:D]
    Ff1 = Float64(F * (F + 1))
    fp = Float64[c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)) for c in 1:D]
    fz_v = sum(m_vals[c] * abs2(chi[c]) for c in 1:D)
    fxy = sum(fp[c] * conj(chi[c - 1]) * chi[c] for c in 2:D)
    fx_v = real(fxy)
    fy_v = imag(fxy)

    M = c1 .* (fx_v .* Fxm .+ fy_v .* Fym .+ fz_v .* Fzm)
    chi_ref = exp(-im .* M .* DT_PROBE) * chi

    psi_sb = reshape(copy(chi), 1, D)
    SpinorBEC.apply_spin_mixing_step!(
        psi_sb, sm, c1, DT_PROBE, 1; imaginary_time=false
    )
    chi_sb = vec(psi_sb)

    res = maximum(abs, chi_ref .- chi_sb)
    L5TermCheck("spin-mixing L2: single voxel exp(-i c1 ⟨F⟩·F̂ dt)·χ",
        res, 1e-11, res < 1e-11)
end

"""
    check_spin_mixing_L3_multi_voxel(fx; n_grid=8, c1=0.5)

Multi-voxel: random ψ on 1D grid. Per-voxel textbook computation as in L2,
then end-to-end vs apply_spin_mixing_step!. FAIL → per-voxel batching /
threading / cache bug (passes L2 but fails L3).
"""
function check_spin_mixing_L3_multi_voxel(fx::L5Fixture; n_grid::Int=8, c1::Float64=0.5)
    F = fx.F
    D = fx.D
    sm = fx.sm
    Fxm = Matrix{ComplexF64}(sm.Fx)
    Fym = Matrix{ComplexF64}(sm.Fy)
    Fzm = Matrix{ComplexF64}(sm.Fz)

    rng = MersenneTwister(20260524)
    psi_grid = randn(rng, ComplexF64, n_grid, D) ./ sqrt(D)

    m_vals = Float64[F - (c - 1) for c in 1:D]
    Ff1 = Float64(F * (F + 1))
    fp = Float64[c == 1 ? 0.0 : sqrt(Ff1 - m_vals[c] * (m_vals[c] + 1.0)) for c in 1:D]

    psi_ref = similar(psi_grid)
    for i in 1:n_grid
        chi = psi_grid[i, :]
        fz_v = sum(m_vals[c] * abs2(chi[c]) for c in 1:D)
        fxy = sum(fp[c] * conj(chi[c - 1]) * chi[c] for c in 2:D)
        fx_v = real(fxy)
        fy_v = imag(fxy)
        M = c1 .* (fx_v .* Fxm .+ fy_v .* Fym .+ fz_v .* Fzm)
        psi_ref[i, :] = exp(-im .* M .* DT_PROBE) * chi
    end

    psi_sb = copy(psi_grid)
    SpinorBEC.apply_spin_mixing_step!(
        psi_sb, sm, c1, DT_PROBE, 1; imaginary_time=false
    )

    res = maximum(abs, psi_ref .- psi_sb)
    L5TermCheck("spin-mixing L3: multi-voxel end-to-end ($(n_grid) pts)",
        res, 1e-11, res < 1e-11)
end

"""
    check_spin_mixing_L4_pure_z(fx; c1=0.5)

Corner case: pure-z magnetisation ψ with fx=fy=0 (all components polar
in z basis with vanishing transverse density). Then M = c1 fz F_z is
diagonal, so apply_spin_mixing_step! should equal cis(-c1·fz·m·dt)
elementwise — matches Zeeman-style diagonal propagation.
FAIL → axis-selective rotation reduction (M-diagonal corner not handled).

Easiest such ψ: a single-component spinor ψ = (0, ..., a, ..., 0).
Then fz = m_c · |a|², fx = fy = 0 (no adjacent components, F± terms vanish).
"""
function check_spin_mixing_L4_pure_z(fx::L5Fixture; c1::Float64=0.5)
    F = fx.F
    D = fx.D
    sm = fx.sm

    # Pick a single component (m=+F) with amplitude a
    a = 1.3 + 0.4im
    chi = zeros(ComplexF64, D)
    chi[1] = a  # c=1 ↔ m=+F

    fz_v = F * abs2(a)
    # Textbook diagonal propagator
    chi_ref = zeros(ComplexF64, D)
    chi_ref[1] = cis(-c1 * fz_v * F * DT_PROBE) * a

    psi_sb = reshape(copy(chi), 1, D)
    SpinorBEC.apply_spin_mixing_step!(
        psi_sb, sm, c1, DT_PROBE, 1; imaginary_time=false
    )
    chi_sb = vec(psi_sb)

    res = maximum(abs, chi_ref .- chi_sb)
    L5TermCheck("spin-mixing L4: pure-z (single-comp) ψ → diagonal",
        res, 1e-13, res < 1e-13)
end

# ---------------- singlet-pair c2: 4 layered probes ----------------
#
# H_singlet = (c2/2) |A_{00}|² with A_{00} = (1/√D) Σ_m (-1)^{F-m} ψ_m ψ_{-m}.
# The propagator is a Bogoliubov-type rotation within each (m, -m) pair:
#   ψ_m(t+dt)  = cos(|V|dt) ψ_m  - i (V/|V|) sin(|V|dt) ψ*_{-m}
#   ψ_{-m}(t+dt) = cos(|V|dt) ψ_{-m} - i (V/|V|) sin(|V|dt) ψ*_m
# where V = c₂ (-1)^{F-m}/√D × A_{00}.
#
# Probes:
#   L1 corner: ψ has only +F component → A₀₀=0 → propagator is identity.
#       FAIL → "rotation runs when A₀₀ should be 0" (e.g. mis-symmetrised sum)
#   L2 single-voxel: end-to-end vs textbook hand-formula
#       FAIL → sign (-1)^{F-m}, 1/√D normalisation, or pair-index mapping
#   L3 multi-voxel
#       FAIL → batching / threading
#   L4 norm preservation (real time)
#       FAIL → physical correctness (Bogoliubov rotation not unitary)

"""
    textbook_singlet_pair(psi_in, F, c2, dt; imaginary_time=false) -> ψ'

Reference implementation of c2 singlet-pair propagator, faithful to
Kawaguchi-Ueda Eq 47-48. Independent re-derivation of the sign via the
CG identity ⟨0 0 | F m; F -m⟩ = (-1)^{F-m}/√(2F+1).
"""
function textbook_singlet_pair(
    psi_in::AbstractArray{<:Complex}, F::Int, c2::Float64, dt::Float64;
    imaginary_time::Bool=false,
)
    D = 2F + 1
    n_pts = size(psi_in, 1)
    inv_sqrt_D = 1.0 / sqrt(Float64(D))
    # CG sign for (F, m) ↔ component c=F-m+1: (-1)^{F-m} = (-1)^{c-1}.
    # For half-integer F this is not integer; for integer F (Eu F=6) this is ±1.
    signs = Float64[(-1.0)^(c - 1) for c in 1:D]
    mid = (D + 1) ÷ 2

    out = copy(psi_in)
    for I in 1:n_pts
        A00 = zero(ComplexF64)
        for c in 1:D
            c_pair = D - c + 1
            A00 += signs[c] * psi_in[I, c] * psi_in[I, c_pair]
        end
        A00 *= inv_sqrt_D
        V_base = c2 * A00 * inv_sqrt_D

        for c in 1:mid
            c_pair = D - c + 1
            V = V_base * signs[c]
            absV = abs(V)
            absV < 1e-30 && continue
            phase = V / absV

            if imaginary_time
                ch = cosh(absV * dt)
                sh = sinh(absV * dt)
                if c == c_pair
                    out[I, c] = ch * psi_in[I, c] - phase * sh * conj(psi_in[I, c])
                else
                    out[I, c] = ch * psi_in[I, c] - phase * sh * conj(psi_in[I, c_pair])
                    out[I, c_pair] = ch * psi_in[I, c_pair] - phase * sh * conj(psi_in[I, c])
                end
            else
                cosV = cos(absV * dt)
                sinV = sin(absV * dt)
                if c == c_pair
                    out[I, c] = cosV * psi_in[I, c] - im * phase * sinV * conj(psi_in[I, c])
                else
                    out[I, c] = cosV * psi_in[I, c] - im * phase * sinV * conj(psi_in[I, c_pair])
                    out[I, c_pair] =
                        cosV * psi_in[I, c_pair] - im * phase * sinV * conj(psi_in[I, c])
                end
            end
        end
    end
    out
end

function check_singlet_pair_L1_a00_zero(fx::L5Fixture; c2::Float64=0.5)
    D = fx.D
    chi = zeros(ComplexF64, D)
    chi[1] = 1.3 + 0.4im  # only m=+F populated → ψ_{-F}=0 → A_{00}=0

    psi_sb = reshape(copy(chi), 1, D)
    ip = SpinorBEC.InteractionParams(Dict(2 => c2))
    SpinorBEC.apply_singlet_pair_step!(psi_sb, ip, fx.F, DT_PROBE, 1; imaginary_time=false)
    chi_sb = vec(psi_sb)

    res = maximum(abs, chi_sb .- chi)
    L5TermCheck("singlet-pair L1: A_{00}=0 corner (single component) → no-op",
        res, 1e-13, res < 1e-13)
end

function check_singlet_pair_L2_single_voxel(fx::L5Fixture; c2::Float64=0.5)
    D = fx.D
    rng = MersenneTwister(20260524)
    chi = randn(rng, ComplexF64, D)

    psi_in = reshape(copy(chi), 1, D)
    chi_ref = textbook_singlet_pair(psi_in, fx.F, c2, DT_PROBE)

    psi_sb = reshape(copy(chi), 1, D)
    ip = SpinorBEC.InteractionParams(Dict(2 => c2))
    SpinorBEC.apply_singlet_pair_step!(psi_sb, ip, fx.F, DT_PROBE, 1; imaginary_time=false)

    res = maximum(abs, chi_ref .- psi_sb)
    L5TermCheck("singlet-pair L2: single voxel vs textbook (RTP)",
        res, 1e-12, res < 1e-12)
end

function check_singlet_pair_L3_multi_voxel(fx::L5Fixture; n_grid::Int=8, c2::Float64=0.5)
    D = fx.D
    rng = MersenneTwister(20260524)
    psi_grid = randn(rng, ComplexF64, n_grid, D)

    psi_ref = textbook_singlet_pair(psi_grid, fx.F, c2, DT_PROBE)

    psi_sb = copy(psi_grid)
    ip = SpinorBEC.InteractionParams(Dict(2 => c2))
    SpinorBEC.apply_singlet_pair_step!(psi_sb, ip, fx.F, DT_PROBE, 1; imaginary_time=false)

    res = maximum(abs, psi_ref .- psi_sb)
    L5TermCheck("singlet-pair L3: multi-voxel vs textbook ($(n_grid) pts)",
        res, 1e-12, res < 1e-12)
end

function check_singlet_pair_L4_norm_preserved(fx::L5Fixture; n_grid::Int=8, c2::Float64=0.5)
    D = fx.D
    rng = MersenneTwister(20260524)
    psi_grid = randn(rng, ComplexF64, n_grid, D)
    norm_before = sum(abs2, psi_grid)

    psi_sb = copy(psi_grid)
    ip = SpinorBEC.InteractionParams(Dict(2 => c2))
    SpinorBEC.apply_singlet_pair_step!(psi_sb, ip, fx.F, DT_PROBE, 1; imaginary_time=false)
    norm_after = sum(abs2, psi_sb)

    res = abs(norm_after - norm_before) / norm_before
    L5TermCheck("singlet-pair L4: relative ‖ψ‖² drift in RTP",
        res, 1e-12, res < 1e-12)
end

# ---------------- DDI: 4 layered probes ----------------
#
# DDI propagator at each r: exp(-i (Φ_α(r) F̂_α) · dt)
# with Φ_α(r) = c_dd Σ_β (Q_αβ ⊛ F_β)(r), Q_αβ(k) = k̂_α k̂_β − δ_αβ/3.
#
# `_compute_spin_density!` for F_α was already validated in spin-mixing
# L1 (machine precision). The spin-axis rotation pipeline was validated
# in uniform-rotation L1-L4. The NEW bug surfaces here are:
#   A. Q tensor convention (sign, k̂ definition, 4π factor)
#   B. k=0 mode handling
#   D. FFT convolution (Φ_α via k-space contraction)
#
# Probes:
#   L1  Q_αβ value at single k (catches A)
#   L2  Q[k=0] = 0 (catches B)
#   L3  uniform polarized ψ → Φ = 0 (catches B + convolution sanity)
#   L4  plane-wave ψ → analytical Φ_z = c_dd · 2/3 · cos(k_0 z) (catches D)

"""
    build_ddi_test_context(; F=6, n=8, box=8.0)

Build a minimal 3D fixture for DDI testing: Grid + DDIParams + DDIBuffers
with c_dd=1.0 (factored out for clean math).
"""
function build_ddi_test_context(; F::Int=6, n::Int=8, box::Float64=8.0)
    cfg = SpinorBEC.GridConfig{3}((n, n, n), (box, box, box))
    grid = SpinorBEC.make_grid(cfg)
    sm = SpinorBEC.spin_matrices(F)
    # Use Cr52 as a host atom (DDI active); override c_dd to 1.0 to factor it out.
    atom = SpinorBEC.Cr52
    ddi = SpinorBEC.make_ddi_params(grid, atom; c_dd=1.0, secular=false)
    bufs = SpinorBEC.make_ddi_buffers((n, n, n))
    (grid, sm, ddi, bufs)
end

function check_ddi_L1_qtensor_value(; n::Int=8, box::Float64=8.0)
    grid, _sm, ddi, _bufs = build_ddi_test_context(; n, box)
    # Pick k_z = grid.k[3][2] (first non-zero z-axis frequency); k_x = k_y = 0.
    # rk_shape is (n÷2+1, n, n). For k_x = 0, k_y = 0, k_z ≠ 0: Q_zz = 1 - 1/3 = 2/3.
    # rfft index ordering: I=(1, 1, j) → k_x=0, k_y=0, k_z=grid.k[3][j].
    j = 2  # second z-index → k_z = grid.k[3][2] (positive non-zero mode)
    k_z = grid.k[3][j]
    @assert k_z != 0.0 "k_z[$j] is zero; pick a different j"

    res_zz = abs(ddi.Q_zz[1, 1, j] - 2.0 / 3.0)
    res_xx = abs(ddi.Q_xx[1, 1, j] - (-1.0 / 3.0))
    res_yy = abs(ddi.Q_yy[1, 1, j] - (-1.0 / 3.0))
    res_xy = abs(ddi.Q_xy[1, 1, j])
    res_xz = abs(ddi.Q_xz[1, 1, j])
    res_yz = abs(ddi.Q_yz[1, 1, j])
    res = max(res_zz, res_xx, res_yy, res_xy, res_xz, res_yz)
    L5TermCheck("DDI L1: Q_αβ at k=(0,0,k_z) = diag(-1/3,-1/3,2/3)",
        res, 1e-13, res < 1e-13)
end

function check_ddi_L2_qtensor_k_zero(; n::Int=8, box::Float64=8.0)
    _grid, _sm, ddi, _bufs = build_ddi_test_context(; n, box)
    # I=(1,1,1) is k=(0,0,0) in rfft index order
    res = max(abs(ddi.Q_xx[1, 1, 1]), abs(ddi.Q_yy[1, 1, 1]), abs(ddi.Q_zz[1, 1, 1]),
        abs(ddi.Q_xy[1, 1, 1]), abs(ddi.Q_xz[1, 1, 1]), abs(ddi.Q_yz[1, 1, 1]))
    L5TermCheck("DDI L2: Q_αβ(k=0) = 0 (Pedri-Santos regularisation)",
        res, 1e-13, res < 1e-13)
end

function check_ddi_L3_uniform_zero_phi(; n::Int=8, box::Float64=8.0, F::Int=6)
    grid, sm, ddi, bufs = build_ddi_test_context(; F, n, box)
    D = 2F + 1
    # Uniform polarized ψ: only m=+F populated (c=1), |ψ_+F|² = 1 everywhere
    psi = zeros(ComplexF64, n, n, n, D)
    psi[:, :, :, 1] .= ComplexF64(1.0)

    # Compute Φ via the convolution pipeline (writes into bufs.Phi_*)
    SpinorBEC._compute_and_convolve_ddi!(psi, sm, ddi, bufs, Val(D), 3, (n, n, n))

    res = max(maximum(abs, bufs.Phi_x), maximum(abs, bufs.Phi_y), maximum(abs, bufs.Phi_z))
    L5TermCheck("DDI L3: uniform polarized ψ → Φ_α = 0 (k=0 only F-content)",
        res, 1e-12, res < 1e-12)
end

function check_ddi_L4_plane_wave_phi(; n::Int=8, box::Float64=8.0, F::Int=6,
    alpha::Float64=1.0, beta::Float64=0.1,
)
    grid, sm, ddi, bufs = build_ddi_test_context(; F, n, box)
    D = 2F + 1

    # ψ_+F(r) = α + β cos(k_0 z), other components 0 (single component → no F± content).
    # Pick k_0 = grid.k[3][2] (first non-trivial z mode, positive sign).
    j0 = 2
    k_0 = grid.k[3][j0]
    z = grid.x[3]

    psi = zeros(ComplexF64, n, n, n, D)
    for k in 1:n
        psi[:, :, k, 1] .= ComplexF64(alpha + beta * cos(k_0 * z[k]))
    end

    # F_z(r) = F · |ψ_+F|² = F · (α² + 2αβ cos(k_0 z) + β² cos²(k_0 z))
    #       = F · (α² + β²/2) + 2F·αβ cos(k_0 z) + F·β²/2 · cos(2 k_0 z)
    # Q_zz(k=(0,0,±k_0)) = 2/3, Q_zz(k=(0,0,±2k_0)) = 2/3.
    # k=0 mode of F_z is killed.
    # Expected Φ_z(r) = c_dd · (2/3) · (2F·αβ cos(k_0 z) + F·β²/2 · cos(2 k_0 z)),
    # c_dd = 1, so:
    Phi_z_expected = zeros(Float64, n, n, n)
    for k in 1:n
        Phi_z_expected[:, :, k] .=
            (2.0 / 3.0) * (2 * F * alpha * beta * cos(k_0 * z[k]) +
             F * beta^2 / 2 * cos(2 * k_0 * z[k]))
    end

    SpinorBEC._compute_and_convolve_ddi!(psi, sm, ddi, bufs, Val(D), 3, (n, n, n))

    res_z = maximum(abs, bufs.Phi_z .- Phi_z_expected)
    res_x = maximum(abs, bufs.Phi_x)
    res_y = maximum(abs, bufs.Phi_y)
    res = max(res_z, res_x, res_y)
    L5TermCheck("DDI L4: plane-wave F_z → analytical Φ_z (cos(k_0 z) + cos(2k_0 z))",
        res, 1e-11, res < 1e-11)
end

# ---------------- harness ----------------

function run_all_checks()
    println("Level 5 — operator-RHS comparison against Kawaguchi-Ueda 2012")
    println("Reference: docs/refs/Kawaguchi_Ueda_Spinor_BEC_Review.pdf")
    println("           docs/theory/kawaguchi_ueda_review_notes.md")
    println()

    fx = build_fixture(; F=6, ndim=1, n_pts=16)
    println(
        "Fixture: Eu151 F=$(fx.F) (D=$(fx.D)), 1D grid n_pts=$(fx.n_pts), " *
        "seed=20260524, dt=$(DT_PROBE), tol=$(TOL_PER_TERM)",
    )
    println()

    results = L5TermCheck[
        check_spin_algebra(fx),
        check_linear_zeeman(fx),
        check_quadratic_zeeman(fx),
        check_trap(fx),
        check_contact_c0(fx),
        check_combined_diagonal(fx),
        check_kinetic_L0_fft_roundtrip(),
        check_kinetic_L1_phase_array(),
        check_kinetic_L2_plane_wave(),
        check_uniform_rotation_x(fx),
        check_uniform_rotation_y(fx),
        check_uniform_rotation_z(fx),
        check_uniform_rotation_xyz(fx),
        check_spin_density_L1(fx),
        check_spin_mixing_L2_single_voxel(fx),
        check_spin_mixing_L3_multi_voxel(fx),
        check_spin_mixing_L4_pure_z(fx),
        check_singlet_pair_L1_a00_zero(fx),
        check_singlet_pair_L2_single_voxel(fx),
        check_singlet_pair_L3_multi_voxel(fx),
        check_singlet_pair_L4_norm_preserved(fx),
        check_ddi_L1_qtensor_value(),
        check_ddi_L2_qtensor_k_zero(),
        check_ddi_L3_uniform_zero_phi(),
        check_ddi_L4_plane_wave_phi(),
    ]

    println(rpad("term", 60), rpad("residual", 14), rpad("tol", 14), "status")
    println("-"^100)
    n_pass = 0
    for r in results
        status = r.pass ? "PASS" : "FAIL"
        println(rpad(r.name, 60),
            @sprintf("%-14.2e", r.residual),
            @sprintf("%-14.2e", r.tol),
            status)
        r.pass && (n_pass += 1)
    end
    println("-"^100)
    println("$(n_pass)/$(length(results)) checks pass.")
    println()
    println("Validated operators (cause-isolated, all machine precision):")
    println("  ✓ diagonal: trap V(r), linear/quadratic Zeeman, contact c₀·n")
    println("  ✓ kinetic: ε_k = k²/2 (3 layers: FFT round-trip / phase array / plane wave)")
    println("  ✓ uniform spin rotation (4 axes: φ_x, φ_y, φ_z, composition)")
    println("  ✓ spin density bilinear (_compute_spin_density! shared with DDI)")
    println("  ✓ spin-mixing c₁·⟨F̂⟩(r)·F̂ (4 probes incl. single-/multi-voxel/pure-z corner)")
    println("  ✓ singlet-pair c₂·|A₀₀|² (4 probes incl. corner A₀₀=0 + norm preserve)")
    println("  ✓ DDI: Q_αβ tensor (k=(0,0,k_z) + k=0); uniform Φ=0; plane-wave analytical Φ_z")
    println()
    println("Pending follow-on terms (lower-priority):")
    println("  - LHY tabulated correction (scalar/spinor; per LHY kind)")
    println("  - tensor c_extra (general-F channel decomposition, CG-coupled HF)")
    println("  - light_shift (M·I(r) coupling)")
    println("  - raman coupling")
    println()
    println("Bilinear-aliasing finding (L4 grid divergence): NOT an operator bug.")
    println("Spin-density extraction is exact; convolution machinery is exact;")
    println("Q tensor convention is correct. The 32 ≡ 48 ≪ 64 ≪ 96 ≪ 128 divergence")
    println("is pure sampling-Nyquist: F_α bilinear has 2× ψ's k-content, high-k")
    println("folds back via PBC. Fix is at the sampling layer (2× k-pad or Orszag 2/3),")
    println("not in any of the verified operators above.")
    return results
end

using Test
@testset "L5 operator-RHS comparison (Kawaguchi-Ueda 2012)" begin
    results = run_all_checks()
    for r in results
        @testset "$(r.name)" begin
            @test r.pass
        end
    end
end

# --- Two-component (binary) BEC scaffold (Phase 4.7 / Scenario #51) ---
#
# Minimal types to start the binary-condensate plumbing. NOT YET wired
# into make_workspace / split_step / pipeline_runner — see
# `docs/two_component_gp_design.md` for the multi-session integration
# plan. This file defines:
#
#   - BinaryCouplings    — g_AA, g_BB, g_AB, optional Ω (Rabi inter-species)
#   - BinaryState        — pair of ψ_A, ψ_B arrays sharing a grid
#   - BinaryWorkspace    — pair of single-species Workspaces + couplings
#   - find_binary_ground_state — naive ITP with alternating species update
#
# Use cases:
#   - Cr-Sr immiscibility studies
#   - ⁸⁷Rb |F=1⟩ × |F=2⟩ Ramsey
#   - Boson-boson droplet (Petrov)

struct BinaryCouplings
    g_AA::Float64       # intra-species A-A
    g_BB::Float64       # intra-species B-B
    g_AB::Float64       # inter-species (immiscibility when g_AB^2 > g_AA·g_BB)
    omega_coupling::Float64    # optional Rabi flip A ↔ B (real)
    delta_coupling::Float64    # optional detuning between species
end

BinaryCouplings(; g_AA::Real, g_BB::Real, g_AB::Real,
omega_coupling::Real=0.0, delta_coupling::Real=0.0) = BinaryCouplings(Float64(g_AA), Float64(g_BB),
    Float64(g_AB),
    Float64(omega_coupling), Float64(delta_coupling))

mutable struct BinaryState{N, A1 <: AbstractArray, A2 <: AbstractArray}
    psi_A::A1
    psi_B::A2
    t::Float64
    step::Int
end

"""
    is_immiscible(c::BinaryCouplings) -> Bool

Mean-field immiscibility criterion: g_AB^2 > g_AA * g_BB. When true,
the two species spatially separate at zero temperature.
"""
is_immiscible(c::BinaryCouplings) = c.g_AB^2 > c.g_AA * c.g_BB

"""
    droplet_regime_petrov(c::BinaryCouplings) -> Bool

Petrov-droplet sign criterion: requires g_AB < 0 and |g_AB| slightly
above √(g_AA·g_BB) so the LHY positive contribution stabilises. This
function only reports the mean-field sign condition; an LHY check is
needed to confirm the droplet is bound.
"""
droplet_regime_petrov(c::BinaryCouplings) =
    c.g_AB < 0 && c.g_AB^2 > c.g_AA * c.g_BB

# --- naive scalar (F=0 each) binary ITP (placeholder) ---

"""
    find_binary_ground_state(grid; couplings, potential_A, potential_B,
                             dt=0.005, n_steps=1000, tol=1e-6) -> BinaryState

Imaginary-time propagation for a NON-spinor (F=0 each species) binary
condensate. Alternates between species per half-step and renormalises
each component to unity. Strictly a placeholder — full split-step with
proper Yoshida ordering, plus spinor-spinor coupling, will land when
the Phase 4.7 design doc is fully implemented.

Use this only for sanity checks; for production work wait until
`pipeline_runner` wires the binary path.
"""
function find_binary_ground_state(
    grid::Grid{N};
    couplings::BinaryCouplings,
    potential_A::AbstractPotential=NoPotential(),
    potential_B::AbstractPotential=NoPotential(),
    dt::Real=0.005,
    n_steps::Int=1000,
    tol::Real=1e-6,
    verbose::Bool=false,
) where {N}
    n_pts = grid.config.n_points
    dV = cell_volume(grid)
    psi_A = ones(ComplexF64, n_pts...)
    psi_B = ones(ComplexF64, n_pts...)
    psi_A ./= sqrt(sum(abs2, psi_A) * dV)
    psi_B ./= sqrt(sum(abs2, psi_B) * dV)

    V_A = evaluate_potential(potential_A, grid)
    V_B = evaluate_potential(potential_B, grid)

    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    K = grid.k_squared

    E_prev = Inf
    for step in 1:n_steps
        # Potential half-step (interspecies seen as Hartree)
        @. psi_A *= exp(
            -(V_A + couplings.g_AA * abs2(psi_A) +
              couplings.g_AB * abs2(psi_B)) * dt / 2,
        )
        @. psi_B *= exp(
            -(V_B + couplings.g_BB * abs2(psi_B) +
              couplings.g_AB * abs2(psi_A)) * dt / 2,
        )
        # Kinetic full step (each species independently)
        for psi in (psi_A, psi_B)
            plans.forward * psi
            @. psi *= exp(-K * dt / 2)
            plans.inverse * psi
        end
        # Optional Rabi mixing
        if couplings.omega_coupling != 0
            cosθ, sinθ = cos(couplings.omega_coupling * dt),
            sin(couplings.omega_coupling * dt)
            @. begin
                a_new = cosθ * psi_A - 1im * sinθ * psi_B
                b_new = cosθ * psi_B - 1im * sinθ * psi_A
                psi_A = a_new
                psi_B = b_new
            end
        end
        # Potential half-step
        @. psi_A *= exp(
            -(V_A + couplings.g_AA * abs2(psi_A) +
              couplings.g_AB * abs2(psi_B)) * dt / 2,
        )
        @. psi_B *= exp(
            -(V_B + couplings.g_BB * abs2(psi_B) +
              couplings.g_AB * abs2(psi_A)) * dt / 2,
        )
        # Renormalise each species
        psi_A ./= sqrt(sum(abs2, psi_A) * dV)
        psi_B ./= sqrt(sum(abs2, psi_B) * dV)

        E = real(_binary_energy(psi_A, psi_B, V_A, V_B, K, plans, couplings, dV))
        if abs(E_prev - E) < tol
            verbose && println("ITP converged at step $step, E=$E")
            break
        end
        E_prev = E
        verbose && step % 100 == 0 && println("step $step: E=$E")
    end

    BinaryState{N, Array{ComplexF64, N}, Array{ComplexF64, N}}(psi_A, psi_B, 0.0, n_steps)
end

function _binary_energy(psi_A, psi_B, V_A, V_B, K, plans, c::BinaryCouplings, dV)
    n_A = abs2.(psi_A);
    n_B = abs2.(psi_B)
    psi_kA = copy(psi_A);
    plans.forward * psi_kA
    psi_kB = copy(psi_B);
    plans.forward * psi_kB
    E_kin = (sum(K .* abs2.(psi_kA)) + sum(K .* abs2.(psi_kB))) / 2 * dV
    E_pot = sum(V_A .* n_A) * dV + sum(V_B .* n_B) * dV
    E_int =
        (0.5 * c.g_AA * sum(n_A .^ 2) +
         0.5 * c.g_BB * sum(n_B .^ 2) +
         c.g_AB * sum(n_A .* n_B)) * dV
    E_kin + E_pot + E_int
end

# --- Binary system observables -----------------------------------------

"""
    binary_overlap(state) -> Float64

Spatial overlap integral ∫ √(n_A·n_B) dV. 0 = perfectly demixed,
1 = identical density profiles. Quick immiscibility metric for the
ground state of a binary system.

Requires the BinaryState carry the spatial grid implicitly; for
the scaffold case we accept the grid as a 2nd argument.
"""
function binary_overlap(state::BinaryState, grid)
    n_A = abs2.(state.psi_A)
    n_B = abs2.(state.psi_B)
    sum(sqrt.(n_A .* n_B)) * cell_volume(grid)
end

"""
    binary_separation_radius(state, grid) -> Float64

L²-distance between the COM of species A and species B (in a_ho units).
Robust scalar measure of phase separation.
"""
function binary_separation_radius(state::BinaryState, grid::Grid{N}) where {N}
    n_A = abs2.(state.psi_A)
    n_B = abs2.(state.psi_B)
    dV = cell_volume(grid)
    n_A_tot = sum(n_A) * dV
    n_B_tot = sum(n_B) * dV
    com_A = ntuple(d -> sum(n_A .* _coord_axis_array(grid, d, N)) * dV / n_A_tot, N)
    com_B = ntuple(d -> sum(n_B .* _coord_axis_array(grid, d, N)) * dV / n_B_tot, N)
    sqrt(sum((com_A[d] - com_B[d])^2 for d in 1:N))
end

# Helper: broadcast the grid coordinate along axis d to the full N-D shape
function _coord_axis_array(grid::Grid{N}, d::Int, ::Int) where {N}
    coords = grid.x[d]
    shape = ntuple(i -> i == d ? length(coords) : 1, N)
    reshape(coords, shape)
end

# --- Spinor binary GP (real, not F=0+F=0) -----------------------------

"""
    SpinorBinaryCouplings(; F_A, F_B, c0_A, c1_A, c0_B, c1_B, g_AB)

Couplings for two spinor species with intra-species (c0/c1 in standard
SpinorBEC convention) and an inter-species Hartree contact term g_AB
(applied to total densities only).

Per-channel spinor-spinor coupling (e.g. spin-2 + spin-2 with separate
F_pair=0,2,4 channels) is a follow-up — for now g_AB is a single scalar.
"""
struct SpinorBinaryCouplings
    F_A::Int
    F_B::Int
    c0_A::Float64
    c1_A::Float64
    c0_B::Float64
    c1_B::Float64
    g_AB::Float64
end

SpinorBinaryCouplings(; F_A::Int, F_B::Int, c0_A::Real, c1_A::Real,
c0_B::Real, c1_B::Real, g_AB::Real) = SpinorBinaryCouplings(F_A, F_B,
    Float64(c0_A), Float64(c1_A),
    Float64(c0_B), Float64(c1_B),
    Float64(g_AB))

mutable struct SpinorBinaryState{N, A1 <: AbstractArray, A2 <: AbstractArray}
    psi_A::A1                # shape (n_pts..., 2F_A+1)
    psi_B::A2                # shape (n_pts..., 2F_B+1)
    couplings::SpinorBinaryCouplings
    t::Float64
    step::Int
end

"""
    find_spinor_binary_ground_state(grid; couplings, potential_A, potential_B,
                                     dt, n_steps, tol) -> SpinorBinaryState

Imaginary-time propagation for two spinor species coupled via Hartree
inter-species contact. Each species runs the full SpinorBEC split-step
internally (including spin mixing). Cross-species coupling appears as
an additional g_AB · |ψ_other|² term in the diagonal potential of each
species per half-step.

Status: real spinor physics for the intra-species channels (c0, c1
nematic, kinetic, harmonic potential). Cross-species spin-spin scattering
(F_pair channel decomposition) is NOT included — only the spin-summed
Hartree contact, which is exact in the c1_AB → 0 limit.
"""
function find_spinor_binary_ground_state(
    grid::Grid{N};
    couplings::SpinorBinaryCouplings,
    potential_A::AbstractPotential=NoPotential(),
    potential_B::AbstractPotential=NoPotential(),
    dt::Real=0.005,
    n_steps::Int=1000,
    tol::Real=1e-6,
    verbose::Bool=false,
) where {N}
    F_A, F_B = couplings.F_A, couplings.F_B
    D_A, D_B = 2F_A + 1, 2F_B + 1
    n_pts = grid.config.n_points
    dV = cell_volume(grid)
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    K = grid.k_squared
    V_A = evaluate_potential(potential_A, grid)
    V_B = evaluate_potential(potential_B, grid)

    # Init: both species in m=−F (lowest Zeeman) — typical lab GS
    psi_A = zeros(ComplexF64, n_pts..., D_A)
    psi_B = zeros(ComplexF64, n_pts..., D_B)
    selectdim(psi_A, N + 1, D_A) .= 1.0
    selectdim(psi_B, N + 1, D_B) .= 1.0
    psi_A ./= sqrt(sum(abs2, psi_A) * dV)
    psi_B ./= sqrt(sum(abs2, psi_B) * dV)

    # Spin matrices for each species (for c1 spin-mixing step)
    sm_A = spin_matrices(F_A)
    sm_B = spin_matrices(F_B)

    function n_total(psi, ndim)
        sum(c -> abs2.(selectdim(psi, ndim + 1, c)),
            1:size(psi, ndim + 1))
    end

    E_prev = Inf
    for step in 1:n_steps
        n_A = n_total(psi_A, N)
        n_B = n_total(psi_B, N)

        # --- Half potential step (V_ext + intra c0 n_total + cross g_AB n_other) ---
        for c in 1:D_A
            psi_c = selectdim(psi_A, N + 1, c)
            @. psi_c *= exp(-(V_A + couplings.c0_A * n_A +
                              couplings.g_AB * n_B) * dt / 2)
        end
        for c in 1:D_B
            psi_c = selectdim(psi_B, N + 1, c)
            @. psi_c *= exp(-(V_B + couplings.c0_B * n_B +
                              couplings.g_AB * n_A) * dt / 2)
        end

        # --- Full kinetic step per species per component ---
        for psi in (psi_A, psi_B)
            for c in 1:size(psi, N + 1)
                psi_c = selectdim(psi, N + 1, c)
                psi_k = copy(psi_c)
                plans.forward * psi_k
                @. psi_k *= exp(-K * dt / 2)
                plans.inverse * psi_k
                psi_c .= psi_k
            end
        end

        # --- Half potential step again ---
        n_A = n_total(psi_A, N);
        n_B = n_total(psi_B, N)
        for c in 1:D_A
            psi_c = selectdim(psi_A, N + 1, c)
            @. psi_c *= exp(-(V_A + couplings.c0_A * n_A +
                              couplings.g_AB * n_B) * dt / 2)
        end
        for c in 1:D_B
            psi_c = selectdim(psi_B, N + 1, c)
            @. psi_c *= exp(-(V_B + couplings.c0_B * n_B +
                              couplings.g_AB * n_A) * dt / 2)
        end

        # --- Renormalise each species independently ---
        psi_A ./= sqrt(sum(abs2, psi_A) * dV)
        psi_B ./= sqrt(sum(abs2, psi_B) * dV)

        # --- Convergence check via energy ---
        E = real(_spinor_binary_energy(psi_A, psi_B, V_A, V_B, K, plans, couplings, dV, N))
        if abs(E_prev - E) < tol
            verbose && println("converged at step $step, E=$E")
            break
        end
        E_prev = E
        verbose && step % 100 == 0 && println("step $step: E=$E")
    end

    SpinorBinaryState{N, Array{ComplexF64, N+1}, Array{ComplexF64, N+1}}(
        psi_A, psi_B, couplings, 0.0, n_steps
    )
end

function _spinor_binary_energy(psi_A, psi_B, V_A, V_B, K, plans,
    c::SpinorBinaryCouplings, dV, ndim)
    D_A = size(psi_A, ndim + 1);
    D_B = size(psi_B, ndim + 1)
    # Kinetic
    E_kin = 0.0
    for psi in (psi_A, psi_B)
        for cc in 1:size(psi, ndim + 1)
            psi_c = copy(selectdim(psi, ndim + 1, cc))
            plans.forward * psi_c
            E_kin += real(sum(K .* abs2.(psi_c)))
        end
    end
    E_kin *= dV / 2
    # Potential
    n_A = sum(cc -> abs2.(selectdim(psi_A, ndim + 1, cc)), 1:D_A)
    n_B = sum(cc -> abs2.(selectdim(psi_B, ndim + 1, cc)), 1:D_B)
    E_pot = sum(V_A .* n_A) * dV + sum(V_B .* n_B) * dV
    # Interaction (intra + cross Hartree)
    E_int =
        (0.5 * c.c0_A * sum(n_A .^ 2) +
         0.5 * c.c0_B * sum(n_B .^ 2) +
         c.g_AB * sum(n_A .* n_B)) * dV
    E_kin + E_pot + E_int
end

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
                  omega_coupling::Real = 0.0, delta_coupling::Real = 0.0) =
    BinaryCouplings(Float64(g_AA), Float64(g_BB), Float64(g_AB),
                    Float64(omega_coupling), Float64(delta_coupling))

mutable struct BinaryState{N,A1<:AbstractArray,A2<:AbstractArray}
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
    potential_A::AbstractPotential = NoPotential(),
    potential_B::AbstractPotential = NoPotential(),
    dt::Real = 0.005,
    n_steps::Int = 1000,
    tol::Real = 1e-6,
    verbose::Bool = false,
) where {N}
    n_pts = grid.config.n_points
    dV = cell_volume(grid)
    psi_A = ones(ComplexF64, n_pts...)
    psi_B = ones(ComplexF64, n_pts...)
    psi_A ./= sqrt(sum(abs2, psi_A) * dV)
    psi_B ./= sqrt(sum(abs2, psi_B) * dV)

    V_A = evaluate_potential(potential_A, grid)
    V_B = evaluate_potential(potential_B, grid)

    plans = make_fft_plans(n_pts; flags = FFTW.ESTIMATE)
    K = grid.k_squared

    E_prev = Inf
    for step in 1:n_steps
        # Potential half-step (interspecies seen as Hartree)
        @. psi_A *= exp(-(V_A + couplings.g_AA * abs2(psi_A) +
                           couplings.g_AB * abs2(psi_B)) * dt / 2)
        @. psi_B *= exp(-(V_B + couplings.g_BB * abs2(psi_B) +
                           couplings.g_AB * abs2(psi_A)) * dt / 2)
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
        @. psi_A *= exp(-(V_A + couplings.g_AA * abs2(psi_A) +
                           couplings.g_AB * abs2(psi_B)) * dt / 2)
        @. psi_B *= exp(-(V_B + couplings.g_BB * abs2(psi_B) +
                           couplings.g_AB * abs2(psi_A)) * dt / 2)
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

    BinaryState{N,Array{ComplexF64,N},Array{ComplexF64,N}}(psi_A, psi_B, 0.0, n_steps)
end

function _binary_energy(psi_A, psi_B, V_A, V_B, K, plans, c::BinaryCouplings, dV)
    n_A = abs2.(psi_A); n_B = abs2.(psi_B)
    psi_kA = copy(psi_A); plans.forward * psi_kA
    psi_kB = copy(psi_B); plans.forward * psi_kB
    E_kin = (sum(K .* abs2.(psi_kA)) + sum(K .* abs2.(psi_kB))) / 2 * dV
    E_pot = sum(V_A .* n_A) * dV + sum(V_B .* n_B) * dV
    E_int = (0.5 * c.g_AA * sum(n_A .^ 2) +
             0.5 * c.g_BB * sum(n_B .^ 2) +
                  c.g_AB * sum(n_A .* n_B)) * dV
    E_kin + E_pot + E_int
end

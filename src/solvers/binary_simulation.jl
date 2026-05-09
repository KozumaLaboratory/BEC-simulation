# --- Binary (two-component) GP real-time propagation ---

export BinarySimulation, make_binary_simulation, binary_split_step!
export run_binary_simulation!, binary_norms, binary_total_energy

# Companion to `find_binary_ground_state` in foundation/binary_state.jl,
# completing the Phase 4.7 / Scenario #51 scaffold for the F=0 + F=0 case
# (each species treated as a scalar GP). The split-step is the same Strang
# layout as the imaginary-time version but with i in the exponent so the
# evolution stays unitary; norms are conserved per species without
# renormalisation.
#
# Physics:
#   i ∂_t ψ_A = (-½∇² + V_A + g_AA |ψ_A|² + g_AB |ψ_B|²) ψ_A + Ω/2 · ψ_B
#   i ∂_t ψ_B = (-½∇² + V_B + g_BB |ψ_B|² + g_AB |ψ_A|²) ψ_B + Ω/2 · ψ_A
#
# Spinor + DDI + cross-species spin-spin are tracked as future work in
# `docs/two_component_gp_design.md`.

"""
Real-time integrator state for a two-component scalar BEC. Holds the
two ψ buffers, the cached evaluated potentials, the shared FFT plans,
and the bookkeeping (t, step). Build via `make_binary_simulation`,
advance via `binary_split_step!`, and drive a full run via
`run_binary_simulation!`.
"""
mutable struct BinarySimulation{N, A1 <: AbstractArray, A2 <: AbstractArray, P, V}
    psi_A::A1
    psi_B::A2
    V_A::V
    V_B::V
    K::V
    plans::P
    couplings::BinaryCouplings
    grid::Grid{N}
    t::Float64
    step::Int
end

"""
    make_binary_simulation(grid; couplings, potential_A, potential_B,
                           psi_A_init, psi_B_init) -> BinarySimulation

Build a `BinarySimulation` ready to evolve in real time. `psi_A_init` /
`psi_B_init` are typically the output of `find_binary_ground_state` (or
any externally constructed initial condition with matching grid). When
omitted they default to a normalised uniform field.
"""
function make_binary_simulation(
    grid::Grid{N};
    couplings::BinaryCouplings,
    potential_A::AbstractPotential=NoPotential(),
    potential_B::AbstractPotential=NoPotential(),
    psi_A_init::Union{Nothing, AbstractArray}=nothing,
    psi_B_init::Union{Nothing, AbstractArray}=nothing,
) where {N}
    n_pts = grid.config.n_points
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    K = grid.k_squared
    V_A = evaluate_potential(potential_A, grid)
    V_B = evaluate_potential(potential_B, grid)
    dV = cell_volume(grid)
    psi_A = if psi_A_init === nothing
        a = ones(ComplexF64, n_pts...)
        a ./= sqrt(sum(abs2, a) * dV)
        a
    else
        ComplexF64.(psi_A_init)
    end
    psi_B = if psi_B_init === nothing
        b = ones(ComplexF64, n_pts...)
        b ./= sqrt(sum(abs2, b) * dV)
        b
    else
        ComplexF64.(psi_B_init)
    end
    BinarySimulation{N, typeof(psi_A), typeof(psi_B), typeof(plans), typeof(K)}(
        psi_A, psi_B, V_A, V_B, K, plans, couplings, grid, 0.0, 0
    )
end

"""
    binary_split_step!(sim, dt) -> sim

Advance one symmetric (Strang) step:

    V/2  →  K(full)  →  Rabi(full)  →  V/2

The mean-field potential includes intra-species (`g_AA |ψ_A|²`) and
inter-species (`g_AB |ψ_B|²`) Hartree terms. Rabi rotation is applied as
a 2×2 unitary mixing of the two species at every grid point; it is a
no-op when `omega_coupling == 0`. Detuning enters as a per-species
energy shift inside the V/2 step.
"""
function binary_split_step!(sim::BinarySimulation, dt::Real)
    psi_A, psi_B = sim.psi_A, sim.psi_B
    V_A, V_B, K = sim.V_A, sim.V_B, sim.K
    c = sim.couplings
    plans = sim.plans
    half = dt / 2
    Δ = c.delta_coupling

    # V/2 (pre): mean-field nonlinear + external + half detuning shift
    @. psi_A *= exp(-1im * (V_A + c.g_AA * abs2(psi_A) +
                            c.g_AB * abs2(psi_B) + Δ / 2) * half)
    @. psi_B *= exp(-1im * (V_B + c.g_BB * abs2(psi_B) +
                            c.g_AB * abs2(psi_A) - Δ / 2) * half)

    # K (full): kinetic in k-space. K = k² so exp(-i k²/2 · dt) is the
    # Schrödinger kinetic propagator; the dt/2 factor below already
    # encodes the (1/2) coefficient on k².
    plans.forward * psi_A
    @. psi_A *= exp(-1im * K * half)
    plans.inverse * psi_A
    plans.forward * psi_B
    @. psi_B *= exp(-1im * K * half)
    plans.inverse * psi_B

    # Rabi (full): rotates the two species into each other.
    if c.omega_coupling != 0
        cosθ = cos(c.omega_coupling * dt / 2)
        sinθ = sin(c.omega_coupling * dt / 2)
        @inbounds for i in eachindex(psi_A)
            a = psi_A[i];
            b = psi_B[i]
            psi_A[i] = cosθ * a - 1im * sinθ * b
            psi_B[i] = cosθ * b - 1im * sinθ * a
        end
    end

    # V/2 (post)
    @. psi_A *= exp(-1im * (V_A + c.g_AA * abs2(psi_A) +
                            c.g_AB * abs2(psi_B) + Δ / 2) * half)
    @. psi_B *= exp(-1im * (V_B + c.g_BB * abs2(psi_B) +
                            c.g_AB * abs2(psi_A) - Δ / 2) * half)

    sim.t += dt
    sim.step += 1
    sim
end

"""
    run_binary_simulation!(sim; duration, dt, save_every=0, on_save=nothing)

Drive `binary_split_step!` until `sim.t` reaches `duration` (relative to
the current `sim.t`). When `save_every > 0`, the optional `on_save`
callback is invoked every that many steps with the current `sim`.

Returns the final `sim` (mutated in place).
"""
function run_binary_simulation!(
    sim::BinarySimulation;
    duration::Real,
    dt::Real,
    save_every::Int=0,
    on_save::Union{Nothing, Function}=nothing,
)
    duration > 0 || throw(ArgumentError("duration must be positive"))
    dt > 0 || throw(ArgumentError("dt must be positive"))
    n_steps = max(1, round(Int, duration / dt))
    save_every > 0 && on_save !== nothing && on_save(sim)
    for _ in 1:n_steps
        binary_split_step!(sim, dt)
        if save_every > 0 && on_save !== nothing && (sim.step % save_every == 0)
            on_save(sim)
        end
    end
    sim
end

"""
    binary_norms(sim) -> (n_A, n_B)

Total particle number per species (∫ |ψ|² dV). Should be conserved by
`binary_split_step!` to ~1e-12 over short runs (degrades slowly under
operator splitting, exactly conserved if no Rabi mixing).
"""
function binary_norms(sim::BinarySimulation)
    dV = cell_volume(sim.grid)
    n_A = real(sum(abs2, sim.psi_A)) * dV
    n_B = real(sum(abs2, sim.psi_B)) * dV
    (n_A, n_B)
end

"""
    binary_total_energy(sim) -> Float64

Total Gross-Pitaevskii energy summed over both species:
kinetic (per species) + potential + intra/inter Hartree interaction.
Should drift only at O(dt²) under Strang splitting in the absence of
Rabi coupling.
"""
function binary_total_energy(sim::BinarySimulation)
    dV = cell_volume(sim.grid)
    real(
        _binary_energy(sim.psi_A, sim.psi_B, sim.V_A, sim.V_B,
            sim.K, sim.plans, sim.couplings, dV),
    )
end

# Naive scalar (F=0 each species) binary ITP — placeholder.
# Full split-step with Yoshida ordering + spinor cross-channel coupling
# lands when the Phase 4.7 design doc is fully implemented.

export find_binary_ground_state

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
    psi_kA = copy(psi_A)
    plans.forward * psi_kA
    psi_kB = copy(psi_B)
    plans.forward * psi_kB

    # Manual reductions instead of broadcast-then-sum: every line below
    # used to materialise an `n_pts`-shaped temporary (`n_A`, `n_B`,
    # `K .* abs2.(psi_kA)`, `V_A .* n_A`, `n_A .^ 2`, `n_A .* n_B`).
    # In-place loops keep the energy evaluation allocation-free aside
    # from the two FFT scratch copies.
    E_kin = 0.0
    @inbounds for i in eachindex(K, psi_kA, psi_kB)
        E_kin += K[i] * (abs2(psi_kA[i]) + abs2(psi_kB[i]))
    end
    # `plans.forward` is the unnormalised FFT, so Parseval carries 1/N_pts:
    # Σ_n|ψ_n|² = (1/N_pts) Σ_k|ψ̂_k|². Matches reference_kinetic_energy.
    E_kin *= 0.5 * dV / length(psi_A)

    E_pot = 0.0
    E_int_AA = 0.0
    E_int_BB = 0.0
    E_int_AB = 0.0
    @inbounds for i in eachindex(psi_A, psi_B, V_A, V_B)
        nAi = abs2(psi_A[i])
        nBi = abs2(psi_B[i])
        E_pot += V_A[i] * nAi + V_B[i] * nBi
        E_int_AA += nAi * nAi
        E_int_BB += nBi * nBi
        E_int_AB += nAi * nBi
    end
    E_pot *= dV
    E_int = (0.5 * c.g_AA * E_int_AA + 0.5 * c.g_BB * E_int_BB + c.g_AB * E_int_AB) * dV
    E_kin + E_pot + E_int
end

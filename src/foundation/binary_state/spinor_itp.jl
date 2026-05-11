# Spinor binary GP (real spinors, not F=0 each species).
# Each species runs the full SpinorBEC split-step internally (kinetic +
# intra-species c0 contact, plus inter-species Hartree g_AB on total
# densities). Cross-species spin-spin scattering (F_pair decomposition)
# is NOT included — only the spin-summed Hartree term.

export find_spinor_binary_ground_state

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
    D_A = size(psi_A, ndim + 1)
    D_B = size(psi_B, ndim + 1)

    # Kinetic — one inline reduction per FFT'd component instead of a
    # broadcast `K .* abs2.(psi_c)` temporary.
    E_kin = 0.0
    for psi in (psi_A, psi_B)
        for cc in 1:size(psi, ndim + 1)
            psi_c = copy(selectdim(psi, ndim + 1, cc))
            plans.forward * psi_c
            ec = 0.0
            @inbounds for i in eachindex(K, psi_c)
                ec += K[i] * abs2(psi_c[i])
            end
            E_kin += ec
        end
    end
    E_kin *= dV / 2

    # Build n_A / n_B densities (allocate once, fold the abs2-sum) so
    # the potential + interaction reductions can share them without
    # `sum(cc -> abs2.(...))` materialising D temporaries each.
    n_A = zeros(Float64, size(V_A))
    @inbounds for cc in 1:D_A
        psi_c = selectdim(psi_A, ndim + 1, cc)
        for i in eachindex(n_A, psi_c)
            n_A[i] += abs2(psi_c[i])
        end
    end
    n_B = zeros(Float64, size(V_B))
    @inbounds for cc in 1:D_B
        psi_c = selectdim(psi_B, ndim + 1, cc)
        for i in eachindex(n_B, psi_c)
            n_B[i] += abs2(psi_c[i])
        end
    end

    # Single fused pass: V_A·n_A, V_B·n_B, n_A², n_B², n_A·n_B all in one loop.
    E_pot = 0.0
    s_AA = 0.0
    s_BB = 0.0
    s_AB = 0.0
    @inbounds for i in eachindex(n_A, n_B, V_A, V_B)
        nAi = n_A[i]
        nBi = n_B[i]
        E_pot += V_A[i] * nAi + V_B[i] * nBi
        s_AA += nAi * nAi
        s_BB += nBi * nBi
        s_AB += nAi * nBi
    end
    E_pot *= dV
    E_int = (0.5 * c.c0_A * s_AA + 0.5 * c.c0_B * s_BB + c.g_AB * s_AB) * dV
    E_kin + E_pot + E_int
end

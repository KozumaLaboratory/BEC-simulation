# Oracle: J_z = L_z + ⟨F_z⟩ is conserved at B = 0 with the DDI active.
#
# At zero field the spinor-dipolar Hamiltonian (kinetic + axially symmetric trap
# + c₀ + c₁ + scalar LHY + DDI) is invariant under a SIMULTANEOUS rotation of
# spin and space about z. The DDI is the only term that couples the two sectors,
# and it is covariant under that joint rotation — not under either alone. Noether
# therefore gives an exact constant of motion,
#
#     J_z = L_z + ⟨F_z⟩,
#
# while L_z and F_z individually are free to move. That makes J_z the sharpest
# available oracle for the Einstein-de Haas / Barnett program: it is the ledger
# the whole "orbital angular momentum converted into magnetisation" claim is
# written in, and any drift in it is numerical.
#
# The gate is deliberately two-sided:
#   (a) J_z must be conserved, and
#   (b) F_z and L_z must actually MOVE and trade against each other.
# Without (b) a run that simply sat still would pass, which is a placeholder and
# not an oracle.
#
# Sizing note (2026-07-28): the drift in this quantity is dominated by density
# reaching the periodic box edge, NOT by dt or propagator order. Measured on the
# Eu-151 fixture: plain `split_step!` and `split_step_midpoint!` agree to 6
# decimals, dt 0.004 vs 0.001 agree to 5, while box 12 → 20 → 28 moves the drift
# 10% → 0.5% → 0.1% tracking the edge density. Size the box by edge fraction.

using Test
using SpinorBEC
using LinearAlgebra, FFTW

function _jz_fixture(; box, n, sigma, dt, n_steps, c_dd_on::Bool=true)
    atom = SpinorBEC.resolve_atom(:Eu151)
    N_atoms = 30000
    omega_ref = 628.3
    grid = make_grid(GridConfig(n, box))
    F = atom.F
    D = 2F + 1
    sm = spin_matrices(F)

    c0 = compute_c_total(atom; N_atoms, omega_ref)
    c1 = -0.005 * c0
    c_dd = c_dd_on ? compute_c_dd_dimless(atom; N_atoms, omega_ref) : 0.0
    a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
    eps_dd = SpinorBEC.compute_a_dd(atom) / atom.a_s
    c_lhy = scalar_lhy_coefficient(atom.a_s / a_ho, N_atoms; eps_dd)

    # Spin tilted out of the z axis (so ⟨F_z⟩ < F and the ladder has room to
    # move) times an ℓ=+1 phase winding (so L_z ≠ 0). Both sectors are loaded,
    # which is what lets the DDI trade between them.
    chi = exp(-im * (π / 3) * Matrix(sm.Fy)) * ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:D]
    psi = zeros(ComplexF64, grid.config.n_points..., D)
    for k in axes(psi, 3), j in axes(psi, 2), i in axes(psi, 1)
        x = grid.x[1][i];
        y = grid.x[2][j];
        z = grid.x[3][k]
        env = exp(-(x^2 + y^2 + 2z^2) / (2 * sigma^2)) * (x + im * y)
        for c in 1:D
            psi[i, j, k, c] = env * chi[c]
        end
    end
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))

    V = zeros(Float64, grid.config.n_points...)
    for I in CartesianIndices(V)
        V[I] = 0.5 * (grid.x[1][I[1]]^2 + grid.x[2][I[2]]^2 + 4.0 * grid.x[3][I[3]]^2)
    end

    ws = make_workspace(; grid, atom,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1); c_lhy),
        zeeman=TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
            ConstantWaveform(0.0), ConstantWaveform(0.0)),
        potential=NoPotential(),
        sim_params=SimParams(; dt, n_steps, imaginary_time=false, save_every=1),
        psi_init=psi, enable_ddi=c_dd_on, c_dd)
    copyto!(ws.potential_values, V)
    (ws, grid, sm)
end

function _measure(ws, grid, sm, plans)
    dV = cell_volume(grid)
    psi = Array(ws.state.psi)
    _, _, fz = spin_density_vector(psi, sm, 3)
    Fz = sum(fz) * dV
    Lz = orbital_angular_momentum(psi, grid, plans)
    nden = dropdims(sum(abs2, psi; dims=4); dims=4)
    xg, yg, _ = grid.x
    edge_lim = grid.config.box_size[1] / 2 - 0.5
    ef = 0.0
    for k in axes(nden, 3), j in axes(nden, 2), i in axes(nden, 1)
        (abs(xg[i]) > edge_lim || abs(yg[j]) > edge_lim) && (ef += nden[i, j, k])
    end
    (Fz=Fz, Lz=Lz, Jz=Fz + Lz, edge=ef / sum(nden))
end

@testset "J_z = L_z + F_z conserved at B=0 with DDI" begin
    # Fixture calibrated on CPU (2026-07-28): box 20 / n 40 / t = 1.2 gives
    # dJz/Jz₀ = 9.5e-4, ΔFz = -0.19, edge = 1.4e-6 in ~110 s. Enlarging to
    # box 24 / n 48 pushes the drift to 2.8e-4 and the edge to 3.8e-9 but costs
    # ~180 s; the thresholds below are set from the cheaper point with margin.
    dt = 0.004
    n_steps = 300                     # t_end = 1.2
    ws, grid, sm = _jz_fixture(; box=(20.0, 20.0, 8.0), n=(40, 40, 16),
        sigma=2.5, dt, n_steps)
    plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)

    m0 = _measure(ws, grid, sm, plans)
    for _ in 1:n_steps
        split_step!(ws)
    end
    m1 = _measure(ws, grid, sm, plans)

    # (a) The ledger closes. Measured 9.5e-4 of J_z₀; gated at 1% for margin.
    @test abs(m1.Jz - m0.Jz) < 0.01 * abs(m0.Jz)

    # (b) …and it closes because the two sectors traded, not because nothing
    # happened. Spin must have visibly left the z axis into orbital motion.
    # Measured ΔFz = -0.19.
    @test abs(m1.Fz - m0.Fz) > 0.05
    @test sign(m1.Fz - m0.Fz) != sign(m1.Lz - m0.Lz)
    @test isapprox(m1.Fz - m0.Fz, -(m1.Lz - m0.Lz); atol=0.01 * abs(m0.Jz))

    # (c) The box is doing its job — this is the term that actually controls the
    # drift, so a regression that shrinks the box should be visible here.
    # Measured 1.4e-6.
    @test m1.edge < 1.0e-4
end

@testset "J_z drift is set by the box, not by the propagator" begin
    # Same fixture, same dt, two propagators: plain Strang (which is only
    # 1st-order in ψ once the DDI is on) and the midpoint predictor-corrector
    # (2nd order). If they agree, the residual J_z drift is not a time-stepping
    # artefact and chasing it with smaller dt is wasted compute. Short run —
    # the two curves separate immediately if they are going to separate at all.
    dt = 0.004
    n_steps = 120
    results = map((split_step!, split_step_midpoint!)) do stepper!
        ws, grid, sm = _jz_fixture(; box=(20.0, 20.0, 8.0), n=(40, 40, 16),
            sigma=2.5, dt, n_steps)
        plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
        for _ in 1:n_steps
            stepper!(ws)
        end
        _measure(ws, grid, sm, plans)
    end
    @test isapprox(results[1].Jz, results[2].Jz; atol=1e-5)
    @test isapprox(results[1].Fz, results[2].Fz; atol=1e-5)
end

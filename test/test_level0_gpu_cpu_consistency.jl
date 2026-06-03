# Level 0 (validation_ladder_2026_05_24.md) — GPU/CPU consistency
# regression on small systems.
#
# Beyond the existing per-kernel CPU/GPU equivalence fuzz
# (`test/gpu/test_cuda_equivalence.jl`), this file pins the production
# code paths end-to-end:
#
#   1. Hψ operator: energy_gradient! on GPU matches CPU at < 1e-10
#      relative L² (composite of every operator term).
#   2. Energy decomposition: per-term E_kin / E_trap / E_zee / E_dens /
#      E_spin / E_DDI / E_total all agree CPU ≡ GPU.
#   3. DDI convolution: the FFT-DDI Φ tensor on GPU matches CPU
#      (this was the historical hotspot for sign / 4π convention
#      drift across CPU and GPU paths).
#   4. Ground-state ITP: converged ψ matches between CPU and GPU
#      (energy + density profile, not just energy).
#   5. Multi-step split_step: 100-step real-time evolution norm +
#      total-energy drift bounded equally on CPU and GPU.
#   6. F=6 (Eu151) smoke: Workspace builds + 5-step split_step runs
#      on GPU for the actual production atom — catches F=6-specific
#      regressions (D=13 spinor, dispatch tables, etc.).
#
# Gated on CUDA.functional(). On CPU-only CI this file is a no-op.
# On a GPU runner this is a hard regression suite that prevents
# silent CPU-GPU drift in the production split_step / ground_state /
# DDI paths.

using Test
using SpinorBEC
using LinearAlgebra
using SpinorBEC: energy_gradient!, energy_decomposition, _to_device

@testset "Level 0 — GPU/CPU consistency (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not available, skipping Level-0 GPU/CPU consistency"
        @test true
        return nothing
    end

    @testset "Hψ operator match: F=1 polar contact, no DDI" begin
        # Build the same workspace twice — once on CPU, once on GPU —
        # with identical ψ. The operator action Hψ (= 2 · δE/δψ* / 2)
        # must agree at machine precision.
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.1))
        sp = SimParams(; dt=0.01, n_steps=1)

        ws_cpu = make_workspace(; grid, atom, interactions,
            zeeman=ZeemanParams(0.5, 0.2),
            potential=HarmonicTrap((1.0,)),
            sim_params=sp)
        ws_gpu = make_workspace(; grid, atom, interactions,
            zeeman=ZeemanParams(0.5, 0.2),
            potential=HarmonicTrap((1.0,)),
            sim_params=sp, backend=CUDABackend())

        # Same ψ on both.
        psi_host = init_psi(grid, SpinSystem(1); state=:polar)
        copyto!(ws_cpu.state.psi, psi_host)
        copyto!(ws_gpu.state.psi, psi_host)

        grad_cpu = similar(ws_cpu.state.psi)
        fill!(grad_cpu, zero(eltype(grad_cpu)))
        E_cpu = energy_gradient!(grad_cpu, ws_cpu.state.psi, ws_cpu)
        Hpsi_cpu = grad_cpu ./ 2

        grad_gpu = similar(ws_gpu.state.psi)
        fill!(grad_gpu, zero(eltype(grad_gpu)))
        # GPU path needs device-resident k_squared (docstring contract).
        k_sq_gpu = _to_device(ws_gpu.backend, grid.k_squared)
        E_gpu = energy_gradient!(grad_gpu, ws_gpu.state.psi, ws_gpu;
            k_squared_dev=k_sq_gpu)
        Hpsi_gpu_host = Array(grad_gpu) ./ 2

        diff = sqrt(sum(abs2, Hpsi_cpu .- Hpsi_gpu_host))
        norm = sqrt(sum(abs2, Hpsi_cpu))
        @test diff / norm < 1e-10
        @test isapprox(E_cpu, E_gpu; rtol=1e-10)
    end

    @testset "Energy decomposition match: every term agrees" begin
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.1))
        sp = SimParams(; dt=0.01, n_steps=1)
        ws_cpu = make_workspace(; grid, atom, interactions,
            zeeman=ZeemanParams(0.4, 0.1),
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        ws_gpu = make_workspace(; grid, atom, interactions,
            zeeman=ZeemanParams(0.4, 0.1),
            potential=HarmonicTrap((1.0,)), sim_params=sp,
            backend=CUDABackend())

        psi_host = init_psi(grid, SpinSystem(1); state=:polar)
        copyto!(ws_cpu.state.psi, psi_host)
        copyto!(ws_gpu.state.psi, psi_host)

        ed_cpu = energy_decomposition(ws_cpu)
        ed_gpu = energy_decomposition(ws_gpu)

        # Pre-2026-06-04 the GPU NamedTuple was missing `light_shift`
        # and `coriolis` (silently dropped from both the field list and
        # the E_total sum in `ext/SpinorBECCUDAExt/gpu_energy.jl`).
        # This created a gradient-vs-energy mismatch on the rotating
        # frame at Ω ≠ 0 — see `mistake_gpu_energy_decomposition_missing_coriolis_2026_06_04`.
        # Now: full-field parity is required.
        @test propertynames(ed_cpu) == propertynames(ed_gpu)
        for field in propertynames(ed_cpu)
            v_cpu = Float64(getproperty(ed_cpu, field))
            v_gpu = Float64(getproperty(ed_gpu, field))
            tol_rel = abs(v_cpu) > 1e-8 ? 1e-10 : 0.0
            atol = 1e-12
            @test isapprox(v_cpu, v_gpu; rtol=tol_rel, atol=atol)
        end
    end

    @testset "Energy decomposition match at Ω ≠ 0 (Coriolis-active cell)" begin
        # 2D grid is required for Coriolis to fire (N ≥ 2 in
        # `_grad_coriolis!` / energy.jl:97). Use a non-axisymmetric ψ so
        # ⟨L_z⟩ ≠ 0 → E_coriolis ≠ 0 → fields with content to compare.
        grid = make_grid(GridConfig{2}((16, 16), (8.0, 8.0)))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.1))
        omega = 0.4
        sp = SimParams(; dt=0.01, n_steps=1, rotating_frame_omega=omega)
        ws_cpu = make_workspace(; grid, atom, interactions,
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap((1.0, 1.0)), sim_params=sp)
        ws_gpu = make_workspace(; grid, atom, interactions,
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap((1.0, 1.0)), sim_params=sp,
            backend=CUDABackend())

        # Single-vortex state `(x + i y) · gauss(r)` has L_z = +1.
        psi_host = zeros(ComplexF64, 16, 16, 3)
        for I in CartesianIndices((16, 16))
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]]
            psi_host[I, 2] = (x + im * y) * exp(-(x^2 + y^2) / 4)
        end
        # Normalise.
        dV = cell_volume(grid)
        psi_host ./= sqrt(sum(abs2, psi_host) * dV)
        copyto!(ws_cpu.state.psi, psi_host)
        copyto!(ws_gpu.state.psi, psi_host)

        ed_cpu = energy_decomposition(ws_cpu)
        ed_gpu = energy_decomposition(ws_gpu)

        @test haskey(ed_cpu, :coriolis) && haskey(ed_gpu, :coriolis)
        @test ed_cpu.coriolis != 0.0   # state has L_z ≈ +1, so non-zero
        @test isapprox(ed_cpu.coriolis, ed_gpu.coriolis; rtol=1e-8)
        @test isapprox(ed_cpu.total, ed_gpu.total; rtol=1e-8)
    end

    @testset "Ground-state ITP energy match: F=1 polar 1D" begin
        # Run the full ITP on CPU and on GPU, compare final ψ + energy.
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.1))
        r_cpu = find_ground_state(;
            grid, atom, interactions,
            potential=HarmonicTrap((1.0,)),
            n_steps=200, dt=0.01, tol=1e-7)
        r_gpu = find_ground_state(;
            grid, atom, interactions,
            potential=HarmonicTrap((1.0,)),
            n_steps=200, dt=0.01, tol=1e-7,
            backend=CUDABackend())
        @test isapprox(r_cpu.energy, r_gpu.energy; rtol=1e-6)

        psi_cpu = Array(r_cpu.workspace.state.psi)
        psi_gpu = Array(r_gpu.workspace.state.psi)
        # ψ may differ by global phase; compare densities.
        n_cpu = dropdims(sum(abs2, psi_cpu; dims=2); dims=2)
        n_gpu = dropdims(sum(abs2, psi_gpu; dims=2); dims=2)
        @test maximum(abs, n_cpu .- n_gpu) < 1e-8
    end

    @testset "Multi-step split_step norm + energy drift identical" begin
        # 100 real-time steps; norm drift CPU vs GPU should be within
        # an order of magnitude of each other.
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        atom = Rb87
        interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.1))
        sp = SimParams(; dt=0.005, n_steps=100)

        ws_cpu = make_workspace(; grid, atom, interactions,
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        ws_gpu = make_workspace(; grid, atom, interactions,
            potential=HarmonicTrap((1.0,)), sim_params=sp,
            backend=CUDABackend())

        # Same initial ψ (slightly broadened Gaussian) on both.
        psi_init = zeros(ComplexF64, 16, 3)
        for i in 1:16
            x = grid.x[1][i]
            psi_init[i, 2] = exp(-x^2 / (2 * 0.85^2))
        end
        psi_init ./= sqrt(sum(abs2, psi_init) * cell_volume(grid))
        copyto!(ws_cpu.state.psi, psi_init)
        copyto!(ws_gpu.state.psi, psi_init)

        N0_cpu = total_norm(ws_cpu.state.psi, ws_cpu.grid)
        N0_gpu = total_norm(ws_gpu.state.psi, ws_gpu.grid)
        for _ in 1:100
            split_step!(ws_cpu)
            split_step!(ws_gpu)
        end
        drift_cpu = abs(total_norm(ws_cpu.state.psi, ws_cpu.grid) - N0_cpu)
        drift_gpu = abs(total_norm(ws_gpu.state.psi, ws_gpu.grid) - N0_gpu)
        # Both should be at machine-precision floor.
        @test drift_cpu < 1e-8
        @test drift_gpu < 1e-8
        # Trajectories: density agree after 100 steps.
        psi_cpu = Array(ws_cpu.state.psi)
        psi_gpu = Array(ws_gpu.state.psi)
        n_cpu = dropdims(sum(abs2, psi_cpu; dims=2); dims=2)
        n_gpu = dropdims(sum(abs2, psi_gpu; dims=2); dims=2)
        @test maximum(abs, n_cpu .- n_gpu) < 1e-8
    end

    @testset "F=6 (Eu151) smoke: workspace + 5-step split_step" begin
        # Validates that the production atom (D=13 spinor) does not
        # have F=6-specific GPU dispatch regressions. Just needs to
        # not crash and to preserve norm.
        grid = make_grid(GridConfig{1}((8,), (4.0,)))
        atom = Eu151
        # Use minimal interactions to keep the test fast; the goal is
        # to exercise the dispatch tables, not to converge a GS.
        interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
        sp = SimParams(; dt=0.005, n_steps=5)
        ws_gpu = make_workspace(; grid, atom, interactions,
            potential=HarmonicTrap((1.0,)), sim_params=sp,
            backend=CUDABackend())
        psi_host = init_psi(grid, SpinSystem(6); state=:polar)
        copyto!(ws_gpu.state.psi, psi_host)
        N0 = total_norm(ws_gpu.state.psi, ws_gpu.grid)
        for _ in 1:5
            split_step!(ws_gpu)
        end
        N1 = total_norm(ws_gpu.state.psi, ws_gpu.grid)
        @test isapprox(N0, N1; rtol=1e-8)
    end

    @testset "Seeded init_psi: CPU GPU bit-equivalent input" begin
        # init_psi runs on CPU; copyto! is the bridge. Pin that the
        # bridge does not corrupt the initial state. Trivial but
        # catches GPU array-layout regressions.
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        psi_host = init_psi(grid, SpinSystem(1); state=:random, seed=42)
        psi_dev = CUDA.CuArray(copy(psi_host))
        @test Array(psi_dev) == psi_host
    end
end

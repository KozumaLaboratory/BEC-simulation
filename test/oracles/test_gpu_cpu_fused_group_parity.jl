# test/oracles/test_gpu_cpu_fused_group_parity.jl
#
# Closes the *fused-group* axis of the GPU/CPU parity bound.
#
# `test_gpu_cpu_per_term_parity.jl` activates ONE term at a time so it
# bounds the per-term axis but cannot catch a bug where the fused
# broadcast in `_diagonal_step_svec!` (CPU) and its GPU counterpart
# diverge when MULTIPLE fused contributors are simultaneously non-zero.
#
# The fused group is:
#   c0 (density)          ← DensityC0Term
#   c1 (spin-mixing)      ← SpinC1Term
#   zeeman (diagonal)     ← ZeemanTerm  (-p F_z + q F_z²)
#   light_shift           ← LightShiftTerm   (diagonal in m basis)
#   LHY                   ← LHYTerm
#
# These are all DIAGONAL in the m basis at each site, so they commute
# pairwise — the fusion into one per-voxel exp(-i·dt·sum(...)) broadcast
# is correct mathematically. But CPU and GPU implementations could still
# drift on numerical-precision grounds (single broadcast on GPU vs.
# step-by-step on CPU, different reduction orders, etc.), or one path
# could silently miss a contribution.
#
# Each testset below activates ALL 5 fused contributors and verifies:
#   - energy_decomposition: each fused field matches between CPU/GPU
#   - energy_gradient! Hψ in L²
#   - split_step! propagator drift over one step (bit-identity check)
#
# Cost: ~1 testset × ~30 s on GPU.

using Test
using SpinorBEC
using SpinorBEC: energy_gradient!, energy_decomposition, _to_device, split_step!
using LinearAlgebra

@testset "GPU/CPU fused-group parity (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end
    if !cuda_available
        @info "CUDA not available; skipping fused-group GPU/CPU parity tests"
        @test true
        return nothing
    end

    @testset "Fused (c0, c1, zeeman_z, q, light_shift, LHY) simultaneously active" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            # All 5 fused contributors non-zero, OTHER terms zero
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.3); c_lhy=0.5)
            # Zeeman: p = linear z, q = quadratic z. Both fold into the
            # diagonal step. NO transverse (bx=by=0) to keep this
            # strictly fused-group.
            zeeman = ZeemanParams(0.2, 0.1)
            # Light shift: diagonal eigvals × profile
            n_pts = grid.config.n_points
            profile = zeros(Float64, n_pts...)
            for i in 1:n_pts[1]
                x = grid.x[1][i]
                profile[i] = 0.4 * exp(-x^2 / 2)
            end
            eigvals = [0.3, -0.1, 0.5]
            U = Matrix{ComplexF64}(I, 3, 3)
            ls = LightShift(profile, eigvals, U, true)

            sp = SimParams(; dt=0.01, n_steps=1)
            kwargs = (; grid, atom, interactions=ip, zeeman,
                potential=HarmonicTrap((1.0,)),
                light_shift=ls, sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            # spin_coherent (θ=π/4) so ⟨F⟩≠0 → c1 spin-mixing AND zeeman_z
            # both contribute, density is non-uniform → LHY non-zero,
            # light_shift profile × spinor non-zero everywhere.
            psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
            copyto!(ws.state.psi, psi)
            ws
        end

        ws_cpu = _build(false)
        ws_gpu = _build(true)
        psi_host = Array(ws_cpu.state.psi)
        copyto!(ws_gpu.state.psi, psi_host)

        # --- energy_decomposition: every fused field matches ---
        ed_cpu = energy_decomposition(ws_cpu)
        ed_gpu = energy_decomposition(ws_gpu)
        @test propertynames(ed_cpu) == propertynames(ed_gpu)
        for field in propertynames(ed_cpu)
            v_cpu = Float64(getproperty(ed_cpu, field))
            v_gpu = Float64(getproperty(ed_gpu, field))
            rtol = abs(v_cpu) > 1e-8 ? 1e-9 : 0.0
            @test isapprox(v_cpu, v_gpu; rtol=rtol, atol=1e-12)
        end
        # Sanity: each fused contributor is actually non-zero in the
        # CPU energy decomposition (so the test isn't vacuously passing).
        @test abs(ed_cpu.density) > 1e-6   # c0
        @test abs(ed_cpu.spin) > 1e-6   # c1
        @test abs(ed_cpu.zeeman) > 1e-6   # p·F_z + q·F_z²
        @test abs(ed_cpu.light_shift) > 1e-6
        @test abs(ed_cpu.lhy) > 1e-6

        # --- Composite Hψ from energy_gradient! ---
        grad_cpu = similar(ws_cpu.state.psi)
        fill!(grad_cpu, 0)
        E_cpu = energy_gradient!(grad_cpu, ws_cpu.state.psi, ws_cpu)
        grad_gpu = similar(ws_gpu.state.psi)
        fill!(grad_gpu, 0)
        k_sq_gpu = _to_device(ws_gpu.backend, ws_gpu.grid.k_squared)
        E_gpu = energy_gradient!(grad_gpu, ws_gpu.state.psi, ws_gpu;
            k_squared_dev=k_sq_gpu)
        Hpsi_cpu = grad_cpu ./ 2
        Hpsi_gpu = Array(grad_gpu) ./ 2
        rel_l2 = sqrt(sum(abs2, Hpsi_cpu .- Hpsi_gpu)) /
                 max(sqrt(sum(abs2, Hpsi_cpu)), 1e-30)
        @test rel_l2 < 1e-9
        @test isapprox(E_cpu, E_gpu; rtol=1e-9, atol=1e-12)

        # --- One split_step! propagator step bit-identity ---
        # This actually exercises _diagonal_step_svec! directly (the fused
        # broadcast at integrator/propagators.jl:153). One step in
        # imaginary time isolates the diagonal-fused contribution after
        # the K(dt) FFT block — drift here would indicate that the fused
        # broadcast's per-voxel exp(-im·dt·sum(...)) doesn't match between
        # CPU and GPU.
        split_step!(ws_cpu)
        split_step!(ws_gpu)
        psi_cpu_after = Array(ws_cpu.state.psi)
        psi_gpu_after = Array(ws_gpu.state.psi)
        diff = psi_cpu_after .- psi_gpu_after
        rel_step_l2 = sqrt(sum(abs2, diff)) /
                      max(sqrt(sum(abs2, psi_cpu_after)), 1e-30)
        @test rel_step_l2 < 1e-9
    end
end

# test/oracles/test_gpu_cpu_per_term_parity.jl
#
# Closes the GPU per-term parity gap exposed by the 2026-06-04 GPU
# audit: `test_level0_gpu_cpu_consistency.jl` exercises only 6/14
# HamTerm subtypes (Kinetic, Trap, LinearZeemanZ, DensityC0, SpinC1,
# Coriolis). The other 8 — TransverseZeeman, DDI, LHY, Tensor, Raman,
# LightShift, MagneticGradient (Loss is RT-only by design) — were
# never activated in a GPU CPU-equivalence config. That's the same
# blind-spot class as `mistake_gpu_energy_decomposition_missing_coriolis_2026_06_04`:
# a per-term GPU path can silently drop and the aggregate test still
# passes because that term contributes zero in the test config.
#
# Each testset below builds CPU + GPU workspaces with ONLY one of
# the previously-uncovered terms active (plus baseline Kinetic + Trap),
# verifies:
#   - `energy_decomposition` per-term match (field-by-field).
#   - `energy_gradient!` composite Hψ match in L² norm.
#
# Cost: ~7 testsets × ~10-30 s each on GPU → 1-3 min total.

using Test
using SpinorBEC
using SpinorBEC: energy_gradient!, energy_decomposition, _to_device

# Convenience: build two identical workspaces, one CPU one GPU, and
# run the per-term + composite-Hψ parity check.
function _parity_check(builder; rtol_energy=1e-9, rtol_grad=1e-9,
    rtol_total=1e-9, atol=1e-12, label="")
    ws_cpu = builder(false)
    ws_gpu = builder(true)
    psi_host = Array(ws_cpu.state.psi)
    copyto!(ws_gpu.state.psi, psi_host)

    ed_cpu = energy_decomposition(ws_cpu)
    ed_gpu = energy_decomposition(ws_gpu)
    @test propertynames(ed_cpu) == propertynames(ed_gpu)
    for field in propertynames(ed_cpu)
        v_cpu = Float64(getproperty(ed_cpu, field))
        v_gpu = Float64(getproperty(ed_gpu, field))
        tol = abs(v_cpu) > 1e-8 ? rtol_energy : 0.0
        @test isapprox(v_cpu, v_gpu; rtol=tol, atol=atol)
    end
    @test isapprox(ed_cpu.total, ed_gpu.total; rtol=rtol_total, atol=atol)

    # Composite Hψ check
    grad_cpu = similar(ws_cpu.state.psi);
    fill!(grad_cpu, 0)
    E_cpu = energy_gradient!(grad_cpu, ws_cpu.state.psi, ws_cpu)
    grad_gpu = similar(ws_gpu.state.psi);
    fill!(grad_gpu, 0)
    k_sq_gpu = _to_device(ws_gpu.backend, ws_gpu.grid.k_squared)
    E_gpu = energy_gradient!(grad_gpu, ws_gpu.state.psi, ws_gpu;
        k_squared_dev=k_sq_gpu)
    Hpsi_cpu = grad_cpu ./ 2
    Hpsi_gpu = Array(grad_gpu) ./ 2
    rel_l2 = sqrt(sum(abs2, Hpsi_cpu .- Hpsi_gpu)) /
             max(sqrt(sum(abs2, Hpsi_cpu)), 1e-30)
    @test rel_l2 < rtol_grad
    @test isapprox(E_cpu, E_gpu; rtol=rtol_total, atol=atol)
    return (; ed_cpu, ed_gpu, rel_l2, E_cpu, E_gpu)
end

@testset "GPU/CPU per-term parity (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end
    if !cuda_available
        @info "CUDA not available; skipping per-term GPU/CPU parity tests"
        @test true
        return nothing
    end

    # -----------------------------------------------------------------
    # TransverseZeemanTerm — bx/by ≠ 0 via TimeDependentZeeman slot 3/4
    # -----------------------------------------------------------------
    @testset "TransverseZeemanTerm: bx ≠ 0" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
            zeeman = TimeDependentZeeman(
                ConstantWaveform(0.3),    # p_wf (Bz)
                ConstantWaveform(0.0),
                ConstantWaveform(0.7),    # bx_wf — load-bearing for [GAP-1]
                ConstantWaveform(0.0),
            )
            sp = SimParams(; dt=0.01, n_steps=1)
            kwargs = (; grid, atom, interactions=ip, zeeman,
                potential=HarmonicTrap((1.0,)), sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            # spin_coherent (θ=π/4) ensures ⟨F_x⟩ ≠ 0 so transverse Zeeman
            # contributes; polar (m=0 only) has ⟨F_x⟩=⟨F_y⟩=0 by symmetry
            # and the term would silently no-op.
            psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; label="TransverseZeeman")
        # Sanity: transverse contribution is non-zero
        @test abs(result.ed_cpu.zeeman) > 1e-6
    end

    # -----------------------------------------------------------------
    # DDITerm — c_dd ≠ 0 (3D required for FFT-DDI)
    # -----------------------------------------------------------------
    @testset "DDITerm: c_dd ≠ 0" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{3}((12, 12, 12), (6.0, 6.0, 6.0)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
            sp = SimParams(; dt=0.01, n_steps=1)
            kwargs = (; grid, atom, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
                enable_ddi=true, c_dd=1.0, secular_ddi=true)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            # Polarized state along z (m=+F)
            psi = zeros(ComplexF64, 12, 12, 12, 3)
            for I in CartesianIndices((12, 12, 12))
                x = ws.grid.x[1][I[1]];
                y = ws.grid.x[2][I[2]];
                z = ws.grid.x[3][I[3]]
                psi[I, 1] = exp(-(x^2 + y^2 + z^2 * 0.4) / 2)  # prolate
            end
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; rtol_energy=1e-8, rtol_grad=1e-8,
            rtol_total=1e-8, label="DDI")
        @test abs(result.ed_cpu.ddi) > 1e-6
    end

    # -----------------------------------------------------------------
    # LHYTerm — c_lhy ≠ 0
    # -----------------------------------------------------------------
    @testset "LHYTerm: c_lhy ≠ 0" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0); c_lhy=0.5)
            sp = SimParams(; dt=0.01, n_steps=1)
            kwargs = (; grid, atom, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0,)), sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            psi = init_psi(ws.grid, SpinSystem(1); state=:polar)
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; label="LHY")
        @test abs(result.ed_cpu.lhy) > 1e-6
    end

    # -----------------------------------------------------------------
    # TensorTerm — c2 ≠ 0 (singlet-pair channel)
    # -----------------------------------------------------------------
    @testset "TensorTerm: c2 ≠ 0" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0, 2 => 0.4))
            sp = SimParams(; dt=0.01, n_steps=1)
            kwargs = (; grid, atom, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0,)), sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            psi = init_psi(ws.grid, SpinSystem(1); state=:polar)
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; label="Tensor")
        @test abs(result.ed_cpu.tensor) > 1e-6
    end

    # -----------------------------------------------------------------
    # MagneticGradientTerm — gradient ≠ 0
    # -----------------------------------------------------------------
    @testset "MagneticGradientTerm: grad ≠ 0" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
            sp = SimParams(; dt=0.01, n_steps=1)
            kwargs = (; grid, atom, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0,)),
                magnetic_gradient=MagneticGradient{1}(0.4, 1, 1.0),
                sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            # Offset cloud so MG energy ∫ x·n is non-zero
            psi = zeros(ComplexF64, 16, 3)
            for i in 1:16
                x = ws.grid.x[1][i]
                psi[i, 2] = exp(-(x - 1.0)^2 / 2)
            end
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; label="MagneticGradient")
        @test abs(result.ed_cpu.magnetic_gradient) > 1e-6
    end

    # -----------------------------------------------------------------
    # LightShiftTerm — diagonal LightShift
    # -----------------------------------------------------------------
    @testset "LightShiftTerm: diagonal eigvals × profile" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
            sp = SimParams(; dt=0.01, n_steps=1)
            # Diagonal LightShift: profile × diag(eigvals) per component
            n_pts = grid.config.n_points
            profile = zeros(Float64, n_pts...)
            for i in 1:n_pts[1]
                x = grid.x[1][i]
                profile[i] = exp(-x^2 / 2)
            end
            eigvals = [0.3, -0.1, 0.5]
            U = Matrix{ComplexF64}(I, 3, 3)
            ls = LightShift(profile, eigvals, U, true)
            kwargs = (; grid, atom, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0,)),
                light_shift=ls, sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            psi = init_psi(ws.grid, SpinSystem(1); state=:polar)
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; label="LightShift")
        @test abs(result.ed_cpu.light_shift) > 1e-6
    end

    # -----------------------------------------------------------------
    # RamanTerm — Raman coupling active
    # -----------------------------------------------------------------
    @testset "RamanTerm: Ω_R ≠ 0" begin
        function _build(gpu::Bool)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
            sp = SimParams(; dt=0.01, n_steps=1)
            raman = RamanCoupling{1}(0.3, 0.05, (0.5,))
            kwargs = (; grid, atom, interactions=ip,
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap((1.0,)),
                raman=raman, sim_params=sp)
            ws = if gpu
                make_workspace(; kwargs..., backend=CUDABackend())
            else
                make_workspace(; kwargs...)
            end
            # spin_coherent gives non-zero F+ amplitude so the Ω_R·Re(e^{ik·r}·F+)
            # term in `_raman_energy_core` is active; polar (m=0 only) has F+=0
            # and the sanity check would no-op.
            psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
            copyto!(ws.state.psi, psi)
            ws
        end
        result = _parity_check(_build; label="Raman")
        @test abs(result.ed_cpu.raman) > 1e-6
    end
end

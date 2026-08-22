using SpinorBEC
using Test
using Random
using LinearAlgebra
using SpinorBEC: trapped_bdg_frequencies, bdg_symmetry_generators, bragg_response,
    constrained_hessian_params, energy_gradient!, cell_volume

# GPU gate for the #339 spectrum instruments — the ones that shipped with two
# oracles, a green CI, and no GPU execution at all.
#
# WHAT HAPPENED. `trapped_bdg_frequencies` and `bragg_response` merged with
# `test/oracles/test_trapped_bdg_frequencies.jl` and
# `test_bragg_response_spectrum.jl` green. Both oracles are **1D, F=1, CPU**.
# The first real GPU use was a 32³ × 13 ¹⁵¹Eu cell on an H100 in #383's
# production job, and it died on the first call:
#
#     KernelError: passing non-bitstype argument
#     Argument 4 ... Base.Broadcast.Extruded{Array{Float64, 4}, ...}
#
# `bdg_symmetry_generators`' rotation generator `(x∂_y − y∂_x)ψ` built its
# coordinate arrays from `grid.x`, a HOST `Vector` even for a GPU workspace, and
# a host array broadcast against a `CuArray` does not fall back to the CPU — it
# fails to compile. Fixed in `a0c14993` by one `_to_device` call.
#
# WHY THE ORACLES COULD NOT SEE IT. `ndim ≥ 2` is required before `_lz_action`
# is called at all, so a 1D fixture never reaches the line. **This file is 3D for
# that reason and the dimension is not negotiable** — an 8³ cell is cheap, a 1D
# one is free and useless.
#
# WHY IT IS A CLASS AND NOT AN INCIDENT. `bragg_response` had the SAME defect,
# in two places, and it was still there when this file was written: `kick` and
# `probe` are both built from `grid.x` and broadcast against `ws.state.psi`, and
# the design note claiming the two-argument `mapreduce` "stays GPU-legal" was
# true of the call shape and false of the arguments — `mapreduce` over a device
# view and a HOST probe array is the same compile failure. It was fixed with
# this file, not before it, because nothing had run it on a device.
#
# The checklist that generalises, for any new kernel or instrument: `grid.x`,
# `grid.dx`, `grid.k_squared` and any hand-built weight array are HOST arrays on
# a GPU workspace. Broadcasting one against ψ is a compile error, not a slow
# path. Move it with `_to_device` (or `_to_device_cached` for a
# workspace-lifetime array in a hot loop) and gate it here.
#
# Gated on `CUDA.functional()`; a no-op on CPU-only CI, which is where this
# suite runs. That is stated rather than assumed: **CI has no GPU, so "all
# green" says nothing about any line below.** The verification of record for
# this file is a manual/TSUBAME GPU run.

# Uniform spinor on a periodic 3D box with no trap: stationary by construction,
# which is what makes μ and every frequency built on it meaningful.
function _uniform_box_3d(; n=8, L=6.0, c0=1.0, c1=0.2, n0=1.0, backend, imaginary=true)
    ip = InteractionParams(Dict(0 => c0, 1 => c1))
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    ws = make_workspace(;
        grid, atom=Rb87, interactions=ip, potential=NoPotential(),
        sim_params=SimParams(; dt=0.002, n_steps=1, imaginary_time=imaginary),
        backend,
    )
    D = SpinorBEC.SpinSystem(Rb87.F).n_components
    ψ = zeros(ComplexF64, n, n, n, D)
    ψ[:, :, :, 2] .= sqrt(n0)          # F=1 polar
    (; ws, ψ, grid, ip)
end

@testset "#339 instruments on the GPU (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not functional — #339 GPU instrument parity skipped. " *
            "CI has no GPU, so this file being green says nothing about the " *
            "device paths; the verification of record is a manual GPU run."
        @test true
        return nothing
    end

    @testset "bdg_symmetry_generators: the exact line that died" begin
        # A NON-UNIFORM ψ, deliberately. On a uniform field every derivative
        # generator is identically zero and the comparison would pass while
        # measuring nothing — the compile failure would still be caught, but the
        # VALUE would not be, and a wrong-sign or wrong-axis rotation generator
        # is the next defect in this line's neighbourhood.
        fx_c = _uniform_box_3d(; backend=CPUBackend())
        fx_g = _uniform_box_3d(; backend=CUDABackend())
        n = 8
        ψh = zeros(ComplexF64, n, n, n, 3)
        g = fx_c.grid
        for k in 1:n, j in 1:n, i in 1:n
            x, y, z = g.x[1][i], g.x[2][j], g.x[3][k]
            ψh[i, j, k, 2] = (x + im * y) * exp(-(x^2 + y^2 + z^2) / 6)
        end

        gens_c = bdg_symmetry_generators(fx_c.ws, ψh)
        gens_g = bdg_symmetry_generators(fx_g.ws, CUDA.CuArray(ψh))

        @test [p.first for p in gens_c] == [p.first for p in gens_g]
        # 3D ⇒ the rotation generator exists. If it ever stops being produced,
        # this file goes back to testing nothing.
        @test :rotation_z in [p.first for p in gens_c]

        for ((nc, vc), (ng, vg)) in zip(gens_c, gens_g)
            @test nc === ng
            host = Array(vg)
            # Same arithmetic on the same Float64 data, elementwise — a
            # tolerance here would hide a genuine device/host difference.
            @test maximum(abs, host .- vc) < 1e-12 * max(1.0, maximum(abs, vc))
        end

        # POSITIVE CONTROL on the fixture: the rotation generator must be
        # substantially non-zero, or the elementwise agreement above is an
        # agreement about zeros.
        rot = last(gens_c[findfirst(p -> p.first === :rotation_z, gens_c)])
        @test maximum(abs, rot) > 1e-3
    end

    @testset "trapped_bdg_frequencies: ω agrees between devices in 3D" begin
        fx_c = _uniform_box_3d(; backend=CPUBackend())
        fx_g = _uniform_box_3d(; backend=CUDABackend())

        # Precondition — ψ really is stationary, on the CPU side at least.
        p = constrained_hessian_params(fx_c.ws, fx_c.ψ)
        grad = similar(fx_c.ψ)
        fill!(grad, 0)
        energy_gradient!(grad, fx_c.ψ, fx_c.ws)
        @test sqrt(sum(abs2, grad .- 2p.μ .* fx_c.ψ) * p.dV) < 1e-10

        # `nev` MUST clear the null manifold. Uniform F=1 polar breaks two spin
        # rotations, and each broken generator contributes its symplectic
        # partner, so the zero block is FOUR-dimensional — `nev=4` lands exactly
        # inside it. Measured: at `max_iter=40` the block had not descended and
        # returned excitations at ω ≈ 0.77 and 0.85 (which then disagreed
        # between devices, because they were unconverged); at `max_iter=250` it
        # converged onto the true lowest four, every one of them a Goldstone at
        # ω ≈ 3e-7, and the excitation control correctly went red on an
        # agreement about zeros. Both readings are honest; only `nev=8` is
        # useful.
        kw = (; nev=8, n_hessian=12, max_iter=250, hess_tol=1e-9)
        # The eigensolver's start vectors come from `randn(rng, …)` on the HOST
        # and are then moved to the device, so seeding the same rng gives both
        # arms the same subspace and the comparison is of the arithmetic, not of
        # two different random walks.
        rc = trapped_bdg_frequencies(fx_c.ws, fx_c.ψ; kw...,
            rng=MersenneTwister(20260819))
        rg = trapped_bdg_frequencies(fx_g.ws, CUDA.CuArray(fx_g.ψ); kw...,
            rng=MersenneTwister(20260819))

        @test length(rc.omega) == length(rg.omega)
        # Reduction health on the device side, not only agreement: a pair of
        # equally-broken arms would agree.
        @test rg.j_min > 0.99
        @test rg.pair_residual < 1e-6

        # COMPARE ONLY THE MODES BOTH ARMS CERTIFY, and this is not a loosened
        # tolerance — it is the difference between comparing two spectra and
        # comparing two iteration counts.
        #
        # Measured on an H100 at `max_iter=40`: two of four ω differed by 0.6 %
        # and 3.3 %, on a fixture where the generators agree to 1e-12 and the
        # Bragg time series to 1e-9. The device is not computing a different
        # spectrum; the Hessian block had not converged, and two backends'
        # rounding sends an unconverged LOBPCG down different paths through a
        # spectrum whose bottom is degenerate (uniform F=1 polar carries a spin
        # Goldstone manifold). `trapped_bdg_frequencies` says this in its own
        # docstring — "an unconverged Hessian mode makes every frequency built
        # from it suspect" — and the certified-subset form is the one
        # `test_bdg_low_modes_lobpcg.jl` already uses for the same reason.
        #
        # So: assert the block converged, and if it did not, say which modes
        # were dropped rather than quietly comparing fewer.
        if !(all(rc.hessian_converged) && all(rg.hessian_converged))
            @info "Hessian block did not fully converge; comparing certified modes only" cpu =
                rc.hessian_converged gpu = rg.hessian_converged cpu_res = rc.residuals gpu_res =
                rg.residuals
        end
        certified = [
            k for k in eachindex(rc.omega)
                  if rc.residuals[k] < 1e-6 && rg.residuals[k] < 1e-6
        ]
        # NON-VACUITY FIRST. An equivalence over an empty set passes for free,
        # which is the failure this repo has recorded elsewhere.
        @test !isempty(certified)
        for k in certified
            # `atol` carries the ω = 0 Goldstones, which have no relative scale.
            @test isapprox(rc.omega[k], rg.omega[k]; rtol=1e-6, atol=1e-8)
        end
        # POSITIVE CONTROL: at least one CERTIFIED mode is an actual excitation,
        # so the agreement is not an agreement about a null manifold. Asserted on
        # the CERTIFIED set and not on `spectrum_reached`, which only says an
        # excitation was RETURNED — the run that motivated this line returned two
        # and certified neither, and reported `spectrum_reached = true` while
        # every mode being compared was a Goldstone at ω ≈ 3e-7.
        @test rc.spectrum_reached
        excitations = [k for k in certified if rc.omega[k] > 1e-3]
        if isempty(excitations)
            println("  certified ω: ", [rc.omega[k] for k in certified])
            println("  all ω: ", rc.omega)
            println("  → every certified mode is a zero mode. Raise `nev` past the")
            println("    null manifold (F=1 polar breaks two spin rotations, so the")
            println("    zero block is 4-dimensional) or the comparison is about zeros.")
        end
        @test !isempty(excitations)
    end

    @testset "bragg_response: kick and probe reach the device" begin
        # Real-time workspace — `bragg_response` refuses an imaginary-time one.
        fx_c = _uniform_box_3d(; backend=CPUBackend(), imaginary=false)
        fx_g = _uniform_box_3d(; backend=CUDABackend(), imaginary=false)
        L = 6.0
        kv = (2π / L, 0.0, 0.0)      # one grid mode, commensurate with the box

        kw = (; k_vec=kv, t_total=0.4, amplitude=1e-3, channel=:density)
        rc = bragg_response(fx_c.ws, fx_c.ψ; kw...)
        rg = bragg_response(fx_g.ws, CUDA.CuArray(fx_g.ψ); kw...)

        @test length(rc.n_k) == length(rg.n_k)
        scale = maximum(abs, rc.n_k)
        @test scale > 0                       # the probe is not returning zeros
        for (a, b) in zip(rc.n_k, rg.n_k)
            @test abs(a - b) < 1e-9 * scale
        end
        @test isapprox(rc.peak_omega_density, rg.peak_omega_density;
            rtol=1e-6, atol=1e-9)
        # Propagator hygiene on the device arm. A response spectrum from a run
        # with visible drift is measuring the integrator.
        @test rg.norm_drift < 1e-10

        # And the spin channel, which takes the OTHER branch of the kick loop
        # (`w = m_values[c]`, with `w == 0` skipped for m = 0).
        rc_s = bragg_response(fx_c.ws, fx_c.ψ; kw..., channel=:spin_z)
        rg_s = bragg_response(fx_g.ws, CUDA.CuArray(fx_g.ψ); kw..., channel=:spin_z)
        for (a, b) in zip(rc_s.n_k, rg_s.n_k)
            @test abs(a - b) < 1e-9 * max(scale, maximum(abs, rc_s.n_k))
        end
    end
end

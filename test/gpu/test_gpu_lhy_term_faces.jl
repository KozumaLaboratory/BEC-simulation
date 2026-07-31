# The OTHER two LHY faces on a device, with a tabulated table.
#
# `test_gpu_tabulated_lhy_parity.jl` covers `_diagonal_step_svec!` — the fused
# production propagator. It does not touch:
#
#   * `apply_step!(::LHYTerm, …)`  — the standalone per-term propagator face
#   * `_grad_lhy!`                 — the gradient face, i.e. the L-BFGS path
#
# Both materialised V_LHY as `_lhy_V.(density, Ref(lhy))`. On CPU that is fine.
# On a device array carrying a `TabulatedLHY` it cannot work at all: the table is
# a host `Vector{Float64}`, so the broadcast fails with
#
#   KernelError: passing non-bitstype argument
#     .val is of type FullBdGLHY which is not isbits
#
# It needed three things at once to surface (`method: lbfgs` + a tabulated `lhy:`
# kind + `backend: gpu`), and until #179 the L-BFGS path never built a table, so
# no kernel was ever handed one. #179 exposed it, and
# `runs/eu_gs_phase_c1_B_kappa/config_texture_bscan_lhy_full_bdg.yaml` needs both
# fixes before it runs at all.
#
# The assertion is deliberately GPU == CPU rather than merely "does not throw":
# routing through `_lhy_potential_field` takes a *different* code path on the
# device (uploaded table + O(1) uniform-grid interpolation vs. the host's
# `searchsortedlast`), so "it ran" would not establish that it computed the same
# LHY.

using Test
using LinearAlgebra
import CUDA
using SpinorBEC
using SpinorBEC: _grad_lhy!, _c0c1_to_gS, apply_step!, LHYTerm

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU LHY term-face gate"
else
    @testset "GPU LHY: apply_step! and _grad_lhy! carry a tabulated table" begin
        F, D, n = 6, 13, 8
        grid = make_grid(GridConfig((n, n, n), (4.0, 4.0, 4.0)))
        atom = ATOM_REGISTRY[:Eu151]
        inter = InteractionParams(Dict(0 => 10.0, 1 => 0.1))
        sp = SimParams(; dt=0.001, n_steps=1)

        for kind in (:polar_contact, :icosahedral)
            psi_h = randn(ComplexF64, n, n, n, D)
            mk(be) = make_workspace(; grid, atom, interactions=inter, sim_params=sp,
                psi_init=psi_h, backend=be, spinor_lhy=kind,
                lhy_opts=LHYTableOpts(; n_max=200.0, n_points=200, n_atoms=1))
            ws_h = mk(CPUBackend())
            ws_d = mk(CUDABackend())

            @testset "$kind" begin
                # A workspace without a table would make every check below
                # vacuous — this is the positive control.
                @test ws_h.lhy isa SpinorBEC.TabulatedLHY
                @test ws_d.lhy isa SpinorBEC.TabulatedLHY

                # --- propagator face ---
                a = copy(psi_h)
                b = CUDA.CuArray(copy(psi_h))
                apply_step!(LHYTerm(), a, 0.01, false, ws_h)
                apply_step!(LHYTerm(), b, 0.01, false, ws_d)
                @test isapprox(a, Array(b); rtol=1e-6, atol=1e-10)
                @test !isapprox(a, psi_h; rtol=1e-8)      # it did something

                # --- gradient face (the L-BFGS path) ---
                n_pts = (n, n, n)
                gh = zeros(ComplexF64, n, n, n, D)
                gd = CUDA.zeros(ComplexF64, n, n, n, D)
                nh = dropdims(sum(abs2, psi_h; dims=4); dims=4)
                _grad_lhy!(gh, psi_h, ws_h, nh, n_pts, D, Val(3))
                _grad_lhy!(gd, CUDA.CuArray(psi_h), ws_d, CUDA.CuArray(nh),
                    n_pts, D, Val(3))
                @test isapprox(gh, Array(gd); rtol=1e-6, atol=1e-10)
                @test maximum(abs, gh) > 0                # the term contributed
            end
        end
    end
end

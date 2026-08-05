# `energy_gradient!` chose its backend branch from `psi`, but computes on
# `ws.state.psi` and writes `grad`. Those are three arrays, and only the last
# two have to agree.
#
# A ground state read back from jld2 is a host `Array` no matter which backend
# wrote it (`_save_gs_artifact` stores `_to_host`). Handing that host ψ to a GPU
# workspace — which is exactly what the GS stage-cache audit in
# `run_step_ground_state.jl` does on every cache hit — took the CPU branch,
# where the registry's device buffers met a host `grad` and every accumulate
# scalar-indexed:
#
#   nested task error: Scalar indexing is disallowed.
#     [1] _grad_kinetic!  src/hamiltonian/terms/kinetic.jl:86
#     ...
#     [5] verify_verdict  src/model/verdict_truth.jl:116
#
# So the audit could not run on GPU at all. It went unseen because it needs a
# cache HIT: the run that populates the cache computes its ground state and
# never reaches the load path. The second GPU run of the same ground state dies.
#
# The gate is GPU == CPU-branch value, not merely "does not throw" — routing a
# host ψ into a GPU workspace has to produce the same energy, not just survive.

using Test
import CUDA
using SpinorBEC
using SpinorBEC: energy_gradient!, gradient_only!, verify_verdict, MarkerVerdict

if !CUDA.functional()
    @info "CUDA not functional — skipping host-ψ/GPU-workspace gradient gate"
else
    @testset "energy_gradient!: host ψ into a GPU workspace" begin
        F, D, n = 6, 13, 8
        grid = make_grid(GridConfig((n, n, n), (4.0, 4.0, 4.0)))
        atom = ATOM_REGISTRY[:Eu151]
        inter = InteractionParams(Dict(0 => 10.0, 1 => 0.1))
        sp = SimParams(; dt=0.001, n_steps=1)
        psi_h = randn(ComplexF64, n, n, n, D)

        mk(be) = make_workspace(;
            grid, atom, interactions=inter, sim_params=sp, psi_init=psi_h, backend=be
        )
        ws_h = mk(CPUBackend())
        ws_d = mk(CUDABackend())

        gh = similar(psi_h)
        Eh = energy_gradient!(gh, psi_h, ws_h)

        # The failing call: host ψ, device workspace, device grad.
        gd = similar(ws_d.state.psi)
        Ed = energy_gradient!(gd, psi_h, ws_d)

        @test isfinite(Ed)
        @test isapprox(Ed, Eh; rtol=1e-8)
        @test isapprox(Array(gd), gh; rtol=1e-6, atol=1e-10)

        # Same answer whether ψ arrives on the host or the device.
        psi_d = CUDA.CuArray(psi_h)
        gd2 = similar(ws_d.state.psi)
        @test isapprox(energy_gradient!(gd2, psi_d, ws_d), Ed; rtol=1e-12)

        # `grad` is the one array that MUST be co-resident, and saying so beats
        # scalar-indexing to an answer.
        @test_throws ArgumentError energy_gradient!(similar(psi_h), psi_h, ws_d)
        @test_throws ArgumentError energy_gradient!(similar(ws_d.state.psi), psi_h, ws_h)

        # `gradient_only!` shares the body and shared the defect.
        go = similar(ws_d.state.psi)
        gradient_only!(go, psi_h, ws_d)
        @test isapprox(Array(go), gh; rtol=1e-6, atol=1e-10)
        @test_throws ArgumentError gradient_only!(similar(psi_h), psi_h, ws_d)

        # The production shape: `verify_verdict` is handed the host ψ that came
        # off disk together with the GPU workspace that will run the dynamics,
        # and used to allocate its own scratch as `similar(psi)` — host. This is
        # the exact call at run_step_ground_state.jl's cache-hit audit.
        v = MarkerVerdict(true, "grad_tol", false, NaN)
        a_h = verify_verdict(v, psi_h, ws_h; energy_recorded=Eh)
        a_d = verify_verdict(v, psi_h, ws_d; energy_recorded=Eh)
        @test a_h.checked && a_h.agrees
        @test a_d.checked && a_d.agrees
        @test isapprox(a_d.energy_rederived, a_h.energy_rederived; rtol=1e-8)

        # It still REJECTS on a device workspace — the audit has to keep its
        # teeth, not merely stop crashing.
        bad = verify_verdict(v, psi_h, ws_d; energy_recorded=Eh * 1.5)
        @test bad.checked && !bad.agrees
    end
end

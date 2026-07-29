# Gates for the L-BFGS hot-path rewrites (2026-07-29).
#
# Each optimisation below removed a redundant evaluation or replaced a
# per-component loop with a batched one. The risk in every case is that the
# fast path stops computing the same thing as the slow path it replaced, so
# each is gated against an independent statement of the original:
#
#   1. `gradient_only!` vs `energy_gradient!`      — same gradient, bitwise.
#   2. batched k-space filters vs the per-component `copy → fft → scale →
#      ifft → copy back` loops they replaced (Sobolev preconditioner, its
#      forward metric, the combined P_V^½ P_K P_V^½ preconditioner).
#   3. the line search returns the iterate its energy was measured at — the
#      driver now adopts that iterate instead of recomputing the retraction,
#      and reuses that energy instead of re-evaluating it, so a mismatch
#      would silently feed L-BFGS an energy from a different ψ.
#   4. `result.dE` reports a real energy change. It was identically zero from
#      step 2 onward because `E_prev` was assigned the energy AT the accepted
#      point rather than before the step.

using SpinorBEC
using LinearAlgebra
using Random
using Test

# --- Independent references: the pre-batching per-component loops ----------

function ref_kspace_loop!(v, ws, k2, scale)
    N = ndims(k2)
    n_pts = ntuple(d -> size(v, d), N)
    n_comp = ws.spin_matrices.system.n_components
    buf = similar(v, eltype(v), n_pts)
    for c in 1:n_comp
        idx = SpinorBEC._component_slice(N, n_pts, c)
        buf .= view(v, idx...)
        ws.fft_plans.forward * buf
        buf .*= scale
        ws.fft_plans.inverse * buf
        view(v, idx...) .= buf
    end
    v
end

ref_sobolev!(v, ws, k2, α) = ref_kspace_loop!(v, ws, k2, 1 ./ (1 .+ α .* k2))
ref_metric!(v, ws, k2, α) = ref_kspace_loop!(v, ws, k2, 1 .+ α .* k2)

function ref_combined!(v, ws, sqrt_pv, k2, αK)
    N = ndims(k2)
    n_pts = ntuple(d -> size(v, d), N)
    spv = reshape(sqrt_pv, n_pts..., 1)
    v .*= spv
    ref_kspace_loop!(v, ws, k2, 1 ./ (0.5 .* k2 .+ αK))
    v .*= spv
    v
end

reldiff(a, b) = maximum(abs, a .- b) / max(maximum(abs, b), eps())

@testset "LBFGS fast-path equivalence" begin
    grid = make_grid(GridConfig((12, 12, 8), (8.0, 8.0, 6.0)))
    atom = AtomSpecies("test", 2.5e-25, 1, 50e-10, 60e-10, 6.977e-23)
    base = (;
        grid, atom,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.5)),
        potential=HarmonicTrap((1.0, 1.0, 1.5)),
        initial_state=:polar,
        verbose=false,
    )

    # A representative, partially-converged iterate.
    seed = find_ground_state_lbfgs(; base..., n_steps=5, tol=0.0)
    ws = seed.workspace
    psi = copy(ws.state.psi)
    k2 = ws.grid.k_squared
    dV = cell_volume(grid)
    F = atom.F

    @testset "gradient_only! == energy_gradient!" begin
        g_full = similar(psi)
        g_only = similar(psi)
        E = SpinorBEC.energy_gradient!(g_full, psi, ws; k_squared_dev=k2)
        SpinorBEC.gradient_only!(g_only, psi, ws)
        @test g_only == g_full
        # Same ψ, same registry ⇒ the energy the driver skips is the energy it
        # would have recomputed.
        @test total_energy(ws) == E
    end

    @testset "batched Sobolev preconditioner == per-component loop" begin
        α = 0.37
        v = psi .* (2.0 + 0.5im)
        want = ref_sobolev!(copy(v), ws, k2, α)
        got = SpinorBEC._sobolev_precondition!(copy(v), ws, k2, α)
        @test reldiff(got, want) < 1.0e-12
        # α = 0 must stay an exact no-op.
        @test SpinorBEC._sobolev_precondition!(copy(v), ws, k2, 0.0) == v
    end

    @testset "batched Sobolev metric == per-component loop" begin
        α = 0.21
        v = psi .* (1.0 - 0.75im)
        want = ref_metric!(copy(v), ws, k2, α)
        got = SpinorBEC._sobolev_metric!(copy(v), ws, k2, α)
        @test reldiff(got, want) < 1.0e-12
    end

    @testset "batched combined preconditioner == per-component loop" begin
        αV, αK = 1.0, 0.5
        sqrt_pv = build_precond_sqrt_pv(ws, psi, αV)
        v = psi .* (0.5 + 1.25im)
        want = ref_combined!(copy(v), ws, sqrt_pv, k2, αK)
        got = combined_precondition!(copy(v), ws, sqrt_pv, k2, αK)
        @test reldiff(got, want) < 1.0e-12
    end

    @testset "line search returns the iterate its energy belongs to" begin
        g = similar(psi)
        E0 = SpinorBEC.energy_gradient!(g, psi, ws; k_squared_dev=k2)
        SpinorBEC._project_constraints!(g, psi, grid, nothing, F)

        # Sweep the direction scale so both branches (immediate accept +
        # expansion, and backtracking) and the "first doubling rejected"
        # corner are all exercised.
        for s in (1.0e-6, 1.0e-4, 1.0e-2, 1.0e-1, 1.0, 10.0), expand in (false, true)
            dirn = (-s) .* g
            slope = real(dot(g, dirn)) * dV
            α, E, psi_acc = SpinorBEC._line_search_energy_decrease(
                psi, dirn, E0, ws, grid, dV, nothing, F;
                slope=slope, expand=expand,
            )
            α == 0.0 && continue
            copyto!(ws.state.psi, psi_acc)
            @test total_energy(ws) == E
        end
    end

    @testset "threaded axpy is bit-identical to the broadcast" begin
        # The claim that lets the two-loop recursion be split at all: an
        # elementwise update rounds the same way whatever the chunking, so
        # `_axpy_threaded!` must agree with the broadcast to the last bit, at
        # sizes both below and above its threading threshold.
        rng = MersenneTwister(20260729)   # seeded: an unseeded draw makes the
        # gate's outcome a per-run lottery
        for len in (1 << 12, 1 << 15, 1 << 17)
            a = randn(rng, ComplexF64, len)
            b = randn(rng, ComplexF64, len)
            for c in (0.0, 1.0, -3.7182818, 1.0e-13)
                want = a .+ c .* b
                got = SpinorBEC._axpy_threaded!(copy(a), c, b)
                @test got == want
                # ...and the sign convention the first loop relies on.
                @test SpinorBEC._axpy_threaded!(copy(a), -c, b) == a .- c .* b
            end
        end
    end

    @testset "blocked real-dot: accuracy and reproducibility" begin
        # `_realdot_blocked` replaces `real(dot(a,b))` in the two-loop, so it is
        # NOT bit-identical to what it replaced. The claims are (i) it is no
        # less accurate than a sequential sum, and (ii) it is reproducible.
        #
        # The reference is `BigFloat` at 256 bits — exact next to either
        # Float64 result. The comparison partner is a plain single-accumulator
        # loop rather than BLAS `zdotc`, because zdotc's kernel is chosen per
        # CPU: comparing against it would make this gate's verdict depend on
        # which node ran it.
        #
        # `cancel = true` plants a huge cancelling pair in an otherwise
        # unit-scale vector, so `Σ|a_i b_i| / |Σ a_i b_i|` is ~1e10 and the two
        # summation orders can actually separate.
        naive(a, b) = begin
            s = 0.0
            for i in eachindex(a, b)
                s += real(a[i]) * real(b[i]) + imag(a[i]) * imag(b[i])
            end
            s
        end

        rng = MersenneTwister(20260729)
        for len in (1 << 13, 1 << 16), cancel in (false, true)
            a = randn(rng, ComplexF64, len)
            b = randn(rng, ComplexF64, len)
            if cancel
                a[1] = 1.0e10 + 0.0im
                b[1] = 1.0 + 0.0im
                a[len] = 1.0e10 + 0.0im
                b[len] = -1.0 + 0.0im
            end
            exact = sum(
                i ->
                    BigFloat(real(a[i])) * BigFloat(real(b[i])) +
                    BigFloat(imag(a[i])) * BigFloat(imag(b[i])),
                1:len,
            )
            scale = sum(i -> abs(a[i]) * abs(b[i]), 1:len)   # Σ|a_i||b_i|
            err_blocked = abs(BigFloat(SpinorBEC._realdot_blocked(a, b)) - exact)
            err_naive = abs(BigFloat(naive(a, b)) - exact)
            @test err_blocked <= err_naive + eps(scale)
            # Backward-stable in absolute terms too, not merely relatively.
            @test err_blocked <= 64 * eps() * scale
        end

        # Reproducibility: the block count is a constant, not `nthreads()`, so
        # repeated calls agree bit for bit however the threads are scheduled.
        # (Across DIFFERENT CPUs the vectorised inner loop may reassociate
        # differently — as `zdotc` already does — so the claim is thread-count
        # independence, not machine independence.)
        v = randn(rng, ComplexF64, 1 << 16)
        w = randn(rng, ComplexF64, 1 << 16)
        first = SpinorBEC._realdot_blocked(v, w)
        @test all(SpinorBEC._realdot_blocked(v, w) === first for _ in 1:8)
        # `_realdot_blocked(y, y)` is the `sum(abs2, y)` the two-loop needs.
        @test SpinorBEC._realdot_blocked(v, v) ≈ sum(abs2, v) rtol = 1.0e-14
    end

    @testset "dE is the step's energy change, not zero" begin
        # The trajectory is deterministic, so the 6-step run's last step is
        # exactly the 5-step run's endpoint → the 6-step run's reported dE must
        # be the gap between the two runs' energies. `dE > 0` alone would be a
        # weak (and, on a step where the line search fails, flaky) statement;
        # this one is an identity. The pre-fix bookkeeping reported 0.0.
        r5 = find_ground_state_lbfgs(; base..., n_steps=5, tol=0.0)
        r6 = find_ground_state_lbfgs(; base..., n_steps=6, tol=0.0)
        gap = abs(r6.energy - r5.energy)
        @test gap > 0            # still descending, so the gate has teeth
        @test r6.dE ≈ gap rtol = 1.0e-8
    end
end

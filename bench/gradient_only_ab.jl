# Measure a true gradient-only registry traversal against fused energy+gradient.
import CUDA
using SpinorBEC, FFTW, Test, Printf, Statistics
CUDA.allowscalar(false)

function run_cell(n, padded, T)
    grid = make_grid(GridConfig((n, n, n), (12.0, 12.0, 12.0)); dtype=T)
    psi = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=0.7, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    ws = make_workspace(; grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 100.0, 1 => 5.0)),
        zeeman=ZeemanParams(0.3, 0.1), potential=HarmonicTrap((1.0, 1.0, 1.5)),
        sim_params=SimParams(; dt=1e-4, n_steps=1), psi_init=psi,
        enable_ddi=true, c_dd=10.0, ddi_padding=padded,
        fft_flags=FFTW.ESTIMATE, backend=CUDABackend())
    g0, g1 = similar(ws.state.psi), similar(ws.state.psi)
    fused() = SpinorBEC.energy_gradient!(g0, ws.state.psi, ws)
    function gradient()
        SpinorBEC.apply_operator_via_registry!(g1, ws)
        g1 .*= 2
    end
    fused();
    gradient();
    CUDA.synchronize()
    error = maximum(abs, g1 .- g0) / maximum(abs, g0)
    @test error < (T === Float64 ? 1e-12 : 2e-6)
    samples = (Float64[], Float64[])
    for i in 1:12, arm in (isodd(i) ? (1, 2) : (2, 1))
        CUDA.synchronize()
        start = time_ns()
        arm == 1 ? fused() : gradient()
        CUDA.synchronize()
        push!(samples[arm], (time_ns() - start) / 1e6)
    end
    before, after = median.(samples)
    @printf(
        "GRADIENT_ONLY n=%d padded=%s type=%s before_ms=%.6f after_ms=%.6f speedup=%.3f error=%.3e\n",
        n, padded, T, before, after, before / after, error)
    flush(stdout)
end
@testset "gradient-only GPU traversal" begin
    for (n, T) in ((8, Float32), (8, Float64), (64, Float64), (128, Float64))
        for padded in (false, true)
            run_cell(n, padded, T)
            GC.gc(true)
            CUDA.reclaim()
        end
    end
end

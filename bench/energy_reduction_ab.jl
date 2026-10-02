# Same-process energy/gradient A/B against an unmodified source snapshot.
# julia --project=. bench/energy_reduction_ab.jl /path/to/baseline_gpu_energy.jl [64,128]
import CUDA
using SpinorBEC
using FFTW
using Printf
using Test

CUDA.allowscalar(false)
const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)
const SOURCE = read(ARGS[1], String)
const START = findfirst("function _gpu_energy_and_optional_grad(", SOURCE)
const STOP = findfirst("# Energy-only entry", SOURCE)
START === nothing && error("Baseline function missing")
STOP === nothing && error("Baseline function boundary missing")
const BODY = SOURCE[first(START):(first(STOP) - 1)]
Base.include_string(Ext,
    replace(BODY,
        "_gpu_energy_and_optional_grad" => "_gpu_energy_and_optional_grad_reference"),
    "baseline_gpu_energy.jl")

function fixture(n, padded; dtype=Float64)
    shape = n isa Integer ? (n, n, n) : n
    grid = make_grid(GridConfig(shape, (12.0, 12.0, 12.0)); dtype)
    psi = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=0.7, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    make_workspace(; grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 100.0, 1 => 5.0)),
        zeeman=ZeemanParams(0.3, 0.1),
        potential=HarmonicTrap((1.0, 1.0, 1.5)),
        sim_params=SimParams(; dt=1e-4, n_steps=1), psi_init=psi,
        enable_ddi=true, c_dd=10.0, ddi_padding=padded,
        fft_flags=FFTW.ESTIMATE, backend=CUDABackend())
end

function validate_edge_cases()
    @testset "anisotropic energy reductions" begin
        for dtype in (Float32, Float64), padded in (false, true)
            ws = fixture((8, 6, 10), padded; dtype)
            g0, g1 = similar(ws.state.psi), similar(ws.state.psi)
            @test eltype(ws.state.psi) == Complex{dtype}
            for gradients in (false, true)
                out0, out1 = gradients ? (g0, g1) : (nothing, nothing)
                e0 = Ext._gpu_energy_and_optional_grad_reference(ws, out0)
                e1 = Ext._gpu_energy_and_optional_grad(ws, out1)
                for field in propertynames(e0)
                    @test isapprox(getproperty(e0, field), getproperty(e1, field);
                        rtol=32eps(dtype), atol=32eps(dtype))
                end
                gradients && (@test Array(g0) == Array(g1))
            end
        end
    end
end

function run_cell(n, padded)
    ws = fixture(n, padded)
    before = Ext._gpu_energy_and_optional_grad_reference
    after = Ext._gpu_energy_and_optional_grad
    g0, g1 = similar(ws.state.psi), similar(ws.state.psi)
    @testset "energy/gradient A/B n=$n padded=$padded" begin
        for gradients in (false, true)
            out0, out1 = gradients ? (g0, g1) : (nothing, nothing)
            e0, e1 = before(ws, out0), after(ws, out1)
            for field in propertynames(e0)
                @test isapprox(getproperty(e0, field), getproperty(e1, field);
                    rtol=1e-11, atol=1e-12)
            end
            gradients && (@test Array(g0) == Array(g1))
            samples = (Float64[], Float64[])
            for i in 1:12
                for arm in (isodd(i) ? (1, 2) : (2, 1))
                    CUDA.synchronize()
                    t0 = time_ns()
                    arm == 1 ? before(ws, out0) : after(ws, out1)
                    CUDA.synchronize()
                    push!(samples[arm], (time_ns() - t0) / 1e6)
                end
            end
            medians = map(samples) do x
                y = sort(x)
                (y[6] + y[7]) / 2
            end
            @printf(
                "ENERGY_AB n=%d padded=%s gradient=%s before_ms=%.6f after_ms=%.6f speedup=%.3f\n",
                n, padded, gradients, medians[1], medians[2], medians[1] / medians[2])
            flush(stdout)
        end
    end
    nothing
end

println("device=", CUDA.name(CUDA.device()), " Julia=", VERSION)
validate_edge_cases()
for n in parse.(Int, split(length(ARGS) >= 2 ? ARGS[2] : "8,64,128", ","))
    for padded in (false, true)
        run_cell(n, padded)
        GC.gc(true)
        CUDA.reclaim()
    end
end

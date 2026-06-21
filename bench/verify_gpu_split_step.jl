# Correctness gate: GPU split_step! must match CPU to ~F64 round-off after
# the GPU DDI-rotation custom-kernel switch. Eu F=6 + DDI, both real & imag time.
#   julia --project=. bench/verify_gpu_split_step.jl [N]

import CUDA
using SpinorBEC
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32

function build(backend; it::Bool, psi0)
    grid = make_grid(GridConfig(ntuple(_ -> N, 3), ntuple(_ -> 12.0, 3)))
    sp = SimParams(; dt = 0.005, n_steps = 1, imaginary_time = it, normalize_every = 0)
    make_workspace(;
        grid, atom = Eu151,
        interactions = InteractionParams(Dict(0 => EU_c0, 1 => 0.3)),  # c1≠0 → spin-mixing too
        zeeman = ZeemanParams(EU_p_weak, 0.05),
        potential = HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params = sp, psi_init = copy(psi0),
        enable_ddi = true, c_dd = 100.0, backend = backend,
    )
end

psi0 = zeros(ComplexF64, N, N, N, 13)
for I in CartesianIndices((N, N, N))
    r2 = 0.0
    for d in 1:3; r2 += 0.0; end
    psi0[I, 1] = exp(-(sum((I[d] - N/2)^2 for d in 1:3)) / (N))
    psi0[I, 3] = 0.1 * psi0[I, 1]
    psi0[I, 7] = 0.05 * psi0[I, 1]
end

for it in (false, true)
    label = it ? "imag-time (ITP)" : "real-time (RTP)"
    ws_c = build(CPUBackend(); it, psi0)
    ws_g = build(CUDABackend(); it, psi0)
    for _ in 1:5
        split_step!(ws_c)
        split_step!(ws_g)
    end
    pc = ws_c.state.psi
    pg = Array(ws_g.state.psi)
    absdiff = maximum(abs.(pc .- pg))
    scale = maximum(abs.(pc))
    @printf("%-16s  max|Δ|=%.3e  rel=%.3e  (scale %.3e)\n",
            label, absdiff, absdiff / scale, scale)
    # CPU/GPU agree to FFT/gemm reassociation round-off (~1e-9 over 5 steps
    # of F64 with the DDI-convolve FFTs); 1e-7 catches real algorithmic bugs.
    @assert absdiff / scale < 1e-7 "GPU/CPU mismatch in $label"
end
println("GPU == CPU split_step parity OK")

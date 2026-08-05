# H100 device-kernel breakdown of the FUSED energy_gradient! (LBFGS hot path).
# Finds what to optimize next, H100-native (not 5070Ti).
using SpinorBEC; import CUDA
using SpinorBEC: energy_gradient!, _to_device
include(joinpath(@__DIR__, "..", "..", "bench", "eu151_params.jl"))
NG = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 128
L = 16.0
grid = make_grid(GridConfig(ntuple(_ -> NG, 3), ntuple(_ -> L, 3)))
psi0 = zeros(ComplexF64, grid.config.n_points..., 13)
for I in CartesianIndices(grid.config.n_points); psi0[I,1]=exp(-sum(grid.x[d][I[d]]^2 for d in 1:3)/2); end
ws = make_workspace(; grid, atom=Eu151,
    interactions=InteractionParams(Dict(0=>EU_c0, 1=>0.3*EU_c0)),
    zeeman=ZeemanParams(EU_p_weak,0.0), potential=HarmonicTrap((1.0,1.0,EU_λ_z)),
    sim_params=SimParams(;dt=0.005,n_steps=1), psi_init=psi0,
    enable_ddi=true, c_dd=100.0, secular_ddi=true, backend=CUDABackend())
dV=prod(grid.config.box_size ./ grid.config.n_points); ws.state.psi ./= sqrt(sum(abs2,ws.state.psi)*dV)
psi=copy(ws.state.psi); grad=similar(psi); ksq=_to_device(ws.backend, ws.grid.k_squared)
energy_gradient!(grad,psi,ws;k_squared_dev=ksq); CUDA.synchronize()   # warm
# aggregate device time over 10 gradient evals
prof = CUDA.@profile trace=true (for _ in 1:10; energy_gradient!(grad,psi,ws;k_squared_dev=ksq); end)
d = prof.device
using Printf
tot = sum(d.stop .- d.start)*1e6
@printf("N=%d^3  total device time over 10 grads = %.1f us  (%.1f us/grad)\n", NG, tot, tot/10)
# group by kernel name, top consumers
agg = Dict{String,Float64}(); cnt=Dict{String,Int}()
for i in eachindex(d.name)
    nm = String(d.name[i]); dur=(d.stop[i]-d.start[i])*1e6
    key = split(nm, "(")[1][1:min(end,55)]
    agg[key]=get(agg,key,0.0)+dur; cnt[key]=get(cnt,key,0)+1
end
println("--- top device kernels (µs total over 10 grads, %of device) ---")
for (k,v) in sort(collect(agg), by=x->-x[2])[1:min(end,12)]
    @printf("  %7.0f us  %5.1f%%  x%-4d  %s\n", v, 100v/tot, cnt[k], k)
end

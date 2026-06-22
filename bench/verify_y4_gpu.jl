import CUDA
using SpinorBEC, Printf
include(joinpath(@__DIR__,"eu151_params.jl"))
n=24; grid=make_grid(GridConfig((n,n,n),(12.0,12.0,12.0)))
sp=SimParams(; dt=0.002, n_steps=1, imaginary_time=false)
ws=make_workspace(; grid, atom=Eu151, interactions=InteractionParams(Dict(0=>EU_c0,1=>2.0)),
    potential=HarmonicTrap((1.0,1.0,EU_λ_z)), zeeman=ZeemanParams(EU_p_weak,0.05),
    sim_params=sp, enable_ddi=true, c_dd=100.0, backend=CUDABackend())
psi0=zeros(ComplexF64,n,n,n,13)
for I in CartesianIndices((n,n,n)); r2=sum((I[d]-n/2)^2 for d in 1:3)/n
    psi0[I,1]=exp(-r2); psi0[I,3]=0.15exp(-r2); psi0[I,7]=0.08exp(-r2); end
copyto!(ws.state.psi, CUDA.CuArray(psi0))
dV=prod(grid.config.box_size./grid.config.n_points); ws.state.psi ./= sqrt(sum(abs2,ws.state.psi)*dV)
E0=total_energy(ws); nrm0=total_norm(ws.state.psi,ws.grid)
out=run_simulation_yoshida!(ws; t_end=0.04, save_interval=0.02,
    adaptive=AdaptiveDtParams(dt_init=0.002,dt_min=1e-5,dt_max=0.01,tol=1e-7))
CUDA.synchronize()
E1=total_energy(ws); nrm1=total_norm(ws.state.psi,ws.grid)
@printf("GPU yoshida DDI: accepted=%d rejected=%d dE/E=%.2e dNorm=%.2e\n",
    out.n_accepted, out.n_rejected, abs((E1-E0)/E0), abs(nrm1-nrm0))
println("GPU_Y4_OK")

# Y4 triple-jump of midpoint cores — n_picard sweep (1 vs 2) for cost.
using SpinorBEC, Printf, LinearAlgebra
const SB = SpinorBEC
include(joinpath(@__DIR__, "eu151_params.jl"))
const N = 10; const T_FINAL = 0.08
const W1 = SB._YOSHIDA_W1; const W0 = SB._YOSHIDA_W0

function build(; c_dd)
    grid = make_grid(GridConfig(ntuple(_->N,3), ntuple(_->10.0,3)))
    psi0 = zeros(ComplexF64, N,N,N,13)
    for I in CartesianIndices((N,N,N))
        r2 = sum((I[d]-N/2)^2 for d in 1:3)/N
        psi0[I,1]=exp(-r2); psi0[I,3]=0.15exp(-r2); psi0[I,7]=0.08exp(-r2)
    end
    (; grid, atom=Eu151, psi0, c_dd)
end

# one midpoint Strang core (V_mid·K·V_mid), explicit n_picard, no t-advance
function mid_core!(ws, dt, np; t_base)
    nc = 13
    SB._half_potential_step_midpoint!(ws, dt/2, nc, 3, false; t_eval=t_base+dt/4, t_start=t_base, n_picard=np)
    SB._update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt, false)
    SB.apply_step!(SB.KineticTerm(), ws.state.psi, 0.0, false, ws)
    SB._half_potential_step_midpoint!(ws, dt/2, nc, 3, false; t_eval=t_base+3dt/4, t_start=t_base+dt/2, n_picard=np)
end

function y4!(ws, dt, np)
    t = ws.state.t
    mid_core!(ws, W1*dt, np; t_base=t);          t += W1*dt
    mid_core!(ws, W0*dt, np; t_base=t);          t += W0*dt
    mid_core!(ws, W1*dt, np; t_base=t)
    ws.state.t += dt; ws.state.step += 1
end

function run_to_T(cfg, dt, np)
    n_steps = Int(round(T_FINAL/dt))
    sp = SimParams(; dt=dt, n_steps=n_steps, imaginary_time=false)
    ws = make_workspace(; cfg.grid, cfg.atom,
        interactions=InteractionParams(Dict(0=>EU_c0, 1=>2.0)),
        zeeman=ZeemanParams(EU_p_weak, 0.05), potential=HarmonicTrap((1.0,1.0,EU_λ_z)),
        sim_params=sp, psi_init=copy(cfg.psi0), enable_ddi=(cfg.c_dd!=0), c_dd=cfg.c_dd)
    dV = prod(cfg.grid.config.box_size ./ cfg.grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi)*dV)
    for _ in 1:n_steps; y4!(ws, dt, np); end
    Array(ws.state.psi)
end

println("N=$N triple-jump Y4, n_picard sweep (⇒ order 4)")
for np in (1, 2, 3)
    cfg = build(c_dd=100.0)
    r = [run_to_T(cfg, dt, np) for dt in (0.004,0.002,0.001)]
    d = [maximum(abs, r[i].-r[i+1]) for i in 1:2]
    @printf("c_dd=100 np=%d  diffs=%.2e,%.2e order≈ %.3f\n", np, d[1], d[2], log2(d[1]/d[2]))
end

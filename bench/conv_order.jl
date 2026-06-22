# Strang dt-convergence order for DDI split_step on Eu F=6.
# order = log2( ‖ψ(dt)-ψ_ref‖ / ‖ψ(dt/2)-ψ_ref‖ ).  Strang ⇒ 2.0.
using SpinorBEC, Printf, LinearAlgebra

include(joinpath(@__DIR__, "eu151_params.jl"))

const N = 12
const T_FINAL = 0.05

function build(; c_dd, c1)
    grid = make_grid(GridConfig(ntuple(_->N,3), ntuple(_->10.0,3)))
    atom = Eu151
    psi0 = zeros(ComplexF64, N,N,N,13)
    for I in CartesianIndices((N,N,N))
        r2 = sum((I[d]-N/2)^2 for d in 1:3)/N
        psi0[I,1]=exp(-r2); psi0[I,3]=0.15exp(-r2); psi0[I,7]=0.08exp(-r2)
    end
    (; grid, atom, psi0, c_dd, c1)
end

# Freeze the mean field at each half-step ENTRY (snapshot ψ, pass as psi_mf
# to all substeps) — symmetric inner V at ~zero extra cost vs the predictor.
function step_frozen!(ws, buf)
    dt = ws.sim_params.dt
    t = ws.state.t
    nc = ws.spin_matrices.system.n_components
    copyto!(buf, ws.state.psi)
    SpinorBEC._half_potential_step!(ws, dt/2, nc, 3, false; t_eval=t+dt/4, t_start=t, psi_mf=buf)
    SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), ws.state.psi, 0.0, false, ws)
    copyto!(buf, ws.state.psi)
    SpinorBEC._half_potential_step!(ws, dt/2, nc, 3, false; t_eval=t+3dt/4, t_start=t+dt/2, psi_mf=buf)
    ws.state.t += dt; ws.state.step += 1
    nothing
end

# midpoint half-potential with tunable n_picard (omega=0 ⇒ no coriolis).
function step_midpoint_np!(ws, n_picard)
    dt = ws.sim_params.dt
    t = ws.state.t
    nc = ws.spin_matrices.system.n_components
    SpinorBEC._half_potential_step_midpoint!(ws, dt/2, nc, 3, false; t_eval=t+dt/4, t_start=t, n_picard=n_picard)
    SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), ws.state.psi, 0.0, false, ws)
    SpinorBEC._half_potential_step_midpoint!(ws, dt/2, nc, 3, false; t_eval=t+3dt/4, t_start=t+dt/2, n_picard=n_picard)
    ws.state.t += dt; ws.state.step += 1
    nothing
end

# stepper ∈ (:plain, :midpoint, :frozen)
function run_to_T(cfg, dt; stepper=:plain, n_picard=2)
    n_steps = Int(round(T_FINAL/dt))
    sp = SimParams(; dt=dt, n_steps=n_steps, imaginary_time=false)
    ws = make_workspace(; cfg.grid, cfg.atom,
        interactions=InteractionParams(Dict(0=>EU_c0, 1=>cfg.c1)),
        zeeman=ZeemanParams(EU_p_weak, 0.05), potential=HarmonicTrap((1.0,1.0,EU_λ_z)),
        sim_params=sp, psi_init=copy(cfg.psi0),
        enable_ddi=(cfg.c_dd!=0), c_dd=cfg.c_dd)
    dV = prod(cfg.grid.config.box_size ./ cfg.grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi)*dV)
    buf = stepper === :frozen ? similar(ws.state.psi) : nothing
    for _ in 1:n_steps
        if stepper === :midpoint
            step_midpoint_np!(ws, n_picard)
        elseif stepper === :frozen
            step_frozen!(ws, buf)
        else
            split_step!(ws)
        end
    end
    Array(ws.state.psi)
end

function order(cfg; stepper=:plain, n_picard=2, dts=(0.001,0.0005,0.00025))
    ref = run_to_T(cfg, dts[end]/4; stepper, n_picard)
    ds = [maximum(abs, run_to_T(cfg, dt; stepper, n_picard) .- ref) for dt in dts]
    ords = [log2(ds[i]/ds[i+1]) for i in 1:length(ds)-1]
    (ds, ords)
end

println("N=$N, T=$T_FINAL, threads=$(Threads.nthreads())")
println("MEANFIELD_MIDPOINT_ENABLED = ", SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[])
for (lbl, cfg) in (
    ("c_dd=0  split_step!", build(c_dd=0.0, c1=0.3)),
    ("c_dd=100 split_step!", build(c_dd=100.0, c1=0.3)),
)
    ds, ords = order(cfg)
    @printf("%-20s  diffs=%s  order≈ %s\n", lbl,
        join([@sprintf("%.2e",d) for d in ds], ","),
        join([@sprintf("%.3f",o) for o in ords], ","))
end
# toggle OFF → split_step! should revert to ~1st order for DDI
SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = false
let cfg = build(c_dd=100.0, c1=0.3)
    ds, ords = order(cfg)
    @printf("%-20s  diffs=%s  order≈ %s\n", "c_dd=100 toggle-off",
        join([@sprintf("%.2e",d) for d in ds], ","),
        join([@sprintf("%.3f",o) for o in ords], ","))
end
SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
# frozen + midpoint(n_picard=1,2) for c_dd=100
for (lbl, st, np) in (
        ("c_dd=100 frozen   ", :frozen, 0),
        ("c_dd=100 mid np=1 ", :midpoint, 1),
        ("c_dd=100 mid np=2 ", :midpoint, 2))
    cfg = build(c_dd=100.0, c1=0.3)
    ds, ords = order(cfg; stepper=st, n_picard=np)
    @printf("%-18s  diffs=%s  order≈ %s\n", lbl,
        join([@sprintf("%.2e",d) for d in ds], ","),
        join([@sprintf("%.3f",o) for o in ords], ","))
end

# Grid / box / dt convergence for a cell, in ONE julia session (one JIT payment),
# printing a single table that is cheap to re-read.
#
# Why this exists: the first two P0 runs disagreed on the peak density by 2x, and
# they differed in BOTH dt and box. One knob at a time, with dx quoted in L0 so
# it can be compared to the paper's dx = 1e-3, and with the edge density fraction
# printed on every row because a self-bound droplet that touches the boundary is
# measuring the box, not the droplet.
#
# Usage: julia --project=. runs/yls_barnett_f6/d_convergence_scan.jl P0 [rows=...]

using SpinorBEC
using Printf

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

function scan(name; rows, n_steps=8000, tol=1e-9, gpu=true)
    cell = CELLS[name]
    println("="^118)
    @printf("CONVERGENCE SCAN  cell %s : atom=%s F=%d eps_dd=%.4f N=%d l=%d\n",
        name, SpinorBEC.ATOM_REGISTRY[cell.atom].name,
        SpinorBEC.ATOM_REGISTRY[cell.atom].F, cell.eps_dd, cell.N, cell.l)
    println("  paper anchors: rho_max = 13000 D0 (l=0) / 8900 D0 (l=1); dx_paper = 1.0e-3 L0")
    println("="^118)
    @printf("%4s %6s %8s %9s %9s %8s %10s %9s %9s %9s %9s %8s\n",
        "n", "box/sig", "dt", "dx[L0]", "box[L0]", "steps", "rho_max", "edge", "dpsi",
        "<L_z>", "<f_z>", "J_z")
    println("-"^118)
    out = []
    for r in rows
        n = r.n
        b = build_cell(cell; n=n, box_sigma=r.box_sigma)
        res = run_itp(b; dt=r.dt, n_steps=get(r, :n_steps, n_steps), tol=tol,
            save_every=max(1, get(r, :n_steps, n_steps) ÷ 4),
            backend=(gpu ? CUDABackend() : CPUBackend()), verbose=false)
        m = measure(b, res.workspace.state.psi)
        @printf("%4d %6.2f %8.1e %9.2e %9.4f %8d %10.1f %9.2e %9.2e %+9.4f %+9.4f %+9.2e\n",
            n, r.box_sigma, r.dt, b.box / n / b.S, b.box / b.S,
            get(r, :n_steps, n_steps), m.rho_max_D0, m.edge_fraction, res.dpsi,
            m.L[3], m.f[3], m.Jz)
        flush(stdout)
        push!(out, (; r..., rho_max=m.rho_max_D0, edge=m.edge_fraction, dpsi=res.dpsi,
            Lz=m.L[3], fz=m.f[3], Jz=m.Jz, E=res.energy,
            dx_L0=b.box / n / b.S, box_L0=b.box / b.S))
    end
    println("-"^118)
    flush(stdout)
    out
end

function main_scan(args)
    name = isempty(args) ? "P0" : args[1]
    opts = Dict{String, String}()
    for a in args[2:end]
        k, v = split(a, "="; limit=2)
        opts[k] = v
    end
    g(k, d) = haskey(opts, k) ? parse(typeof(d), opts[k]) : d
    # dt first at fixed geometry, then box at fixed dt, then n at fixed box.
    rows = [
        (; n=64, box_sigma=1.5, dt=1e-3, n_steps=g("steps_lo", 20000)),
        (; n=64, box_sigma=1.5, dt=2e-3, n_steps=g("steps_lo", 20000)),
        (; n=64, box_sigma=1.5, dt=5e-3, n_steps=g("steps_lo", 20000)),
        (; n=64, box_sigma=2.5, dt=2e-3, n_steps=g("steps_lo", 20000)),
        (; n=64, box_sigma=1.0, dt=2e-3, n_steps=g("steps_lo", 20000)),
        (; n=96, box_sigma=1.5, dt=2e-3, n_steps=g("steps_lo", 20000)),
        (; n=128, box_sigma=1.5, dt=2e-3, n_steps=g("steps_hi", 20000)),
    ]
    scan(name; rows=rows, gpu=g("gpu", true))
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_scan(ARGS)

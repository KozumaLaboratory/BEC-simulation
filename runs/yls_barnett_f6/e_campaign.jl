# The campaign: every eGPE cell of issue #338 in one session, one protocol,
# results flushed and saved per cell so a partial run is still usable.
#
# Order is by decisiveness, not by tidiness:
#   P1  positive control      F=1 eps_dd=1.2 N=15000 l=1  -> paper's <L_z>=0.96, <f_z>=0.04
#   C1  the actual question   F=6 eps_dd=1.2 N=40000 l=1  -> does the Barnett transfer survive F=6?
#   A1  physical Eu           F=6 eps_dd=0.54            -> the theorem's prediction: expands
#   B1  F=6 at the paper's N  F=6 eps_dd=1.2 N=15000 l=1  -> predicted below threshold (N/N_c=0.52)
#   P0  paper GS              F=1 l=0                    -> paper's rho_max = 13000 D0
#   C0  F=6 GS                F=6 l=0 N=40000
#   P1m/C1m chirality mirrors (l -> -l); the field mirror lives in c_larmor_rtp.jl
#
# Usage: julia --project=. runs/yls_barnett_f6/e_campaign.jl [cells=P1,C1,...] [n=96] ...

using SpinorBEC
using Printf
using JLD2

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

const PAPER_ANCHORS = Dict(
    "P0" => (; rho_max=13000.0, Lz=0.0, fz=0.0),
    "P1" => (; rho_max=8900.0, Lz=0.96, fz=0.04),
)

function run_one(name; n, dt, n_steps, box_sigma, tol, gpu, method=:lbfgs)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    @printf("\n%s\n", "="^100)
    @printf("CELL %-5s atom=%-12s F=%2d eps_dd=%.4f N=%7d l=%+d | N/N_c = %.3f (N_c=%.4g)\n",
        name, b.atom.name, b.F, cell.eps_dd, cell.N, cell.l,
        cell.N / b.v.N_c, b.v.N_c)
    @printf("  grid %d^3  box %.4f L0  dx %.3e L0 (paper 1.0e-3)  dt %.2e (%.2e T0)  steps %d\n",
        n, b.box / b.S, b.box / n / b.S, dt, dt / b.S^2, n_steps)
    flush(stdout)
    t0 = time()
    res = run_itp(b; dt=dt, n_steps=n_steps, tol=tol, method=method,
        save_every=max(1, n_steps ÷ 10), verbose=false,
        backend=(gpu ? CUDABackend() : CPUBackend()))
    wall = time() - t0
    m = measure(b, res.workspace.state.psi)
    m0 = measure(b, b.psi0)
    e = energy_decomposition(res.workspace)
    @printf("  method=%s wall %.0f s  converged=%s  dpsi=%.2e  grad_norm=%.2e  E=%+.6f internal = %+.1f hbar^2/ML0^2\n",
        method, wall, res.converged, get(res, :dpsi, NaN), get(res, :grad_norm, NaN),
        res.energy, res.energy * b.S^2)
    @printf("  rho_max  seed %8.0f -> final %8.0f D0   (variational %8.0f)\n",
        m0.rho_max_D0, m.rho_max_D0, b.v.rho_max)
    @printf("  <L> = (%+.5f,%+.5f,%+.5f)   <f> = (%+.5f,%+.5f,%+.5f)\n", m.L..., m.f...)
    @printf("  J_z = %+.6f  (target l = %+d, drift %.2e)\n", m.Jz, cell.l, abs(m.Jz - cell.l))
    @printf("  sigma_x %.5f -> %.5f L0 ; sigma_z %.5f -> %.5f L0 ; edge frac %.2e -> %.2e\n",
        m0.sigma_x_L0, m.sigma_x_L0, m0.sigma_z_L0, m.sigma_z_L0,
        m0.edge_fraction, m.edge_fraction)
    @printf("  |f|/(F rho) = %.4f   E_terms: kin %+.4f  contact %+.4f  ddi %+.4f  lhy %+.4f\n",
        m.polarization, e.kinetic, e.density, e.ddi, e.lhy)
    @printf("  (contact+ddi)/contact = %+.6f  (must be 1 - eps_dd = %+.6f if flux closure holds)\n",
        (e.density + e.ddi) / e.density, 1 - cell.eps_dd)
    print("  n_m  :")
    for (c, p) in enumerate(m.pops)
        @printf(" %+d:%.4f", b.F - (c - 1), p)
    end
    println()
    print("  m+v_m:")
    for (c, w) in enumerate(m.windings)
        @printf(" %+.2f", (b.F - (c - 1)) + w)
    end
    println("   (all should equal l)")
    if haskey(PAPER_ANCHORS, name)
        a = PAPER_ANCHORS[name]
        @printf("  ANCHOR vs paper: rho_max %.0f vs %.0f (%.1f %%) | L_z %+.4f vs %+.3f | f_z %+.5f vs %+.3f\n",
            m.rho_max_D0, a.rho_max, 100(m.rho_max_D0 - a.rho_max) / a.rho_max,
            m.L[3], a.Lz, m.f[3], a.fz)
    end
    flush(stdout)

    out = joinpath(@__DIR__, "out")
    mkpath(out)
    jldsave(joinpath(out, "campaign_$(name)_n$(n).jld2");
        psi=Array(res.workspace.state.psi), cell=Dict(pairs(cell)),
        n=n, dt=dt, n_steps=n_steps, box_sigma=box_sigma,
        S=b.S, L0=b.L0, a_ho=b.a_ho, omega_ref=b.omega_ref, box=b.box,
        c0=b.c0, c_dd=b.c_dd, c_lhy=b.c_lhy, N_c=b.v.N_c,
        converged=res.converged, dpsi=get(res, :dpsi, NaN),
        grad_norm=get(res, :grad_norm, NaN), energy=res.energy,
        measured=Dict(pairs(m)), seed_measured=Dict(pairs(m0)),
        energies=Dict(k => getproperty(e, k) for k in propertynames(e)
                      if getproperty(e, k) isa Number),
        git_hash=strip(read(`git rev-parse HEAD`, String)))
    (; name, m, res, b)
end

function main_campaign(args)
    opts = Dict{String, String}()
    for a in args
        k, v = split(a, "="; limit=2)
        opts[k] = v
    end
    g(k, d) = haskey(opts, k) ? parse(typeof(d), opts[k]) : d
    cells = haskey(opts, "cells") ? split(opts["cells"], ",") :
            ["P1", "C1", "A1", "B1", "P0", "C0", "P1m", "C1m"]
    n = g("n", 96)
    dt = g("dt", 2e-3)
    n_steps = g("n_steps", 20000)
    box_sigma = g("box_sigma", 1.5)
    tol = g("tol", 1e-9)
    gpu = g("gpu", true)
    method = Symbol(get(opts, "method", "lbfgs"))

    rows = []
    for c in cells
        try
            push!(rows, run_one(String(c); n=n, dt=dt, n_steps=n_steps,
                box_sigma=box_sigma, tol=tol, gpu=gpu, method=method))
        catch err
            @printf("\nCELL %s FAILED: %s\n", c, sprint(showerror, err))
            flush(stdout)
        end
    end

    println("\n", "="^100)
    println("SUMMARY")
    println("="^100)
    @printf("%-5s %-12s %3s %8s %8s %6s %10s %10s %+9s %+9s %9s %9s\n",
        "cell", "atom", "F", "eps_dd", "N", "l", "N/N_c", "rho_max", "L_z", "f_z", "J_z-l",
        "edge")
    for r in rows
        c = CELLS[r.name]
        @printf("%-5s %-12s %3d %8.4f %8d %6d %10.3f %10.0f %+9.4f %+9.5f %9.1e %9.1e\n",
            r.name, r.b.atom.name, r.b.F, c.eps_dd, c.N, c.l, c.N / r.b.v.N_c,
            r.m.rho_max_D0, r.m.L[3], r.m.f[3], abs(r.m.Jz - c.l), r.m.edge_fraction)
    end
    println("\n  paper: P0 rho_max 13000 D0 ; P1 rho_max 8900 D0, L_z 0.96, f_z 0.04")
    flush(stdout)
    rows
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_campaign(ARGS)

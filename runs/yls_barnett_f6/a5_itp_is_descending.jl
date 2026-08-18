# Is the ITP actually descending on THIS Hamiltonian?
#
# Symptom: seeded with the paper's variational droplet, the ITP drifts to a
# ~45 % lower peak density and reports a FINAL energy above the energy of its own
# seed. Imaginary-time propagation with renormalization must not increase the
# energy, so either
#   (a) the seed's on-grid energy is much higher than its closed-form value, or
#   (b) the step is too large for a strict descent (a dt artifact), or
#   (c) the propagator and the energy functional are not the same Hamiltonian
#       — the one pairing the repo's FD oracle does NOT cover, because that gate
#       compares `apply_operator!` against `energy_contribution`, while the ITP
#       walks `apply_step!`.
#
# All three are distinguished by printing E every step for a few steps at several
# dt. (a) shows up as a large seed offset, (b) as a descent that appears once dt
# is small enough, (c) as an increase that survives dt -> 0.

using SpinorBEC
using Printf

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

function descent_probe(name; n=64, box_sigma=2.5, dts=(1e-2, 2e-3, 1e-4, 1e-6),
    n_probe=20, gpu=true)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)

    println("="^90)
    @printf("ITP DESCENT PROBE  cell %s  n=%d  box=%.4f L0  dx=%.3e L0\n",
        name, n, b.box / b.S, b.box / n / b.S)
    println("="^90)

    # seed energy on this grid vs the closed form at the same (lambda, sigma)
    ws0 = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=1e-6, n_steps=1),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=b.psi0,
        backend=(gpu ? CUDABackend() : CPUBackend()))
    E_seed = total_energy(ws0) * b.S^2
    @printf("  seed E on grid   = %+12.3f hbar^2/(M L0^2)\n", E_seed)
    @printf("  variational E    = %+12.3f  (closed form at the same lambda, sigma)\n",
        b.v.E)
    @printf("  seed rho_max     = %12.0f D0  (closed form %.0f)\n",
        measure(b, b.psi0).rho_max_D0, b.v.rho_max)
    println()

    for dt in dts
        ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=dt, n_steps=1, imaginary_time=true),
            enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
            ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=b.psi0,
            backend=(gpu ? CUDABackend() : CPUBackend()))
        Es = Float64[total_energy(ws) * b.S^2]
        for _ in 1:n_probe
            split_step!(ws)
            SpinorBEC._normalize_psi!(ws.state.psi, ws.grid,
                ws.spin_matrices.system.n_components, length(ws.grid.config.n_points))
            push!(Es, total_energy(ws) * b.S^2)
        end
        d = diff(Es)
        n_up = count(>(0), d)
        @printf("  dt=%9.1e : E %+12.3f -> %+12.3f  | steps that RAISED E: %2d/%d  | max rise %+.3e\n",
            dt, Es[1], Es[end], n_up, length(d), maximum(d))
        n_up > 0 && @printf("               first few dE: %s\n",
            join((@sprintf("%+.3e", x) for x in d[1:min(5, end)]), " "))
    end
    println()
end

function main_a5(args)
    names = isempty(args) ? ["P0"] : args
    for nm in names
        descent_probe(String(nm))
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_a5(ARGS)

# ---------------------------------------------------------------------------
# Independent ITP loop built from the generic `split_step!` + renormalisation,
# to compare its fixed point against `find_ground_state`'s. `find_ground_state`
# uses a merged/leapfrog arrangement (V blocks shared across the loop boundary);
# this is the plain Strang sequence. Both are ITP on the same Hamiltonian, so
# they must land on the same state.
# ---------------------------------------------------------------------------
function plain_itp(name; n=64, box_sigma=2.5, dt=2e-3, n_steps=20000, every=2000,
    gpu=true)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=dt, n_steps=n_steps, imaginary_time=true),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=b.psi0,
        backend=(gpu ? CUDABackend() : CPUBackend()))
    nc = ws.spin_matrices.system.n_components
    nd = length(ws.grid.config.n_points)
    println("="^90)
    @printf("PLAIN split_step! ITP  cell %s  n=%d box=%.4f L0 dx=%.2e L0 dt=%.1e steps=%d\n",
        name, n, b.box / b.S, b.box / n / b.S, dt, n_steps)
    @printf("  step %8s %14s %12s %10s\n", "t", "E [h^2/ML0^2]", "rho_max D0", "sigma_x L0")
    for s in 0:n_steps
        if s % every == 0
            m = measure(b, ws.state.psi)
            @printf("  %8d %8.2f %14.3f %12.1f %10.5f\n", s, s * dt,
                total_energy(ws) * b.S^2, m.rho_max_D0, m.sigma_x_L0)
            flush(stdout)
        end
        s == n_steps && break
        split_step!(ws)
        SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, nc, nd)
    end
    @printf("  closed-form variational: E %+.3f  rho_max %.0f   | paper rho_max 13000 (l=0)\n",
        b.v.E, b.v.rho_max)
    (; b, ws)
end

# ---------------------------------------------------------------------------
# Cross-check with a minimiser that never propagates: L-BFGS on
# `energy_gradient!`, which is the registry's FD-gated gradient face. If ITP and
# L-BFGS disagree, the propagator and the energy functional are not the same
# Hamiltonian. If they agree, the energy functional itself prefers this state and
# the disagreement is with the paper, not with the code.
# ---------------------------------------------------------------------------
function lbfgs_check(name; n=64, box_sigma=2.5, n_steps=3000, gpu=true)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    r = find_ground_state(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        psi_init=b.psi0, enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        method=:lbfgs, n_steps=n_steps, tol=1e-10,
        backend=(gpu ? CUDABackend() : CPUBackend()), verbose=false)
    m = measure(b, r.workspace.state.psi)
    m0 = measure(b, b.psi0)
    println("="^90)
    @printf("L-BFGS  cell %s  n=%d box=%.4f L0\n", name, n, b.box / b.S)
    @printf("  seed      : E %+12.3f  rho_max %10.1f\n",
        total_energy(make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            sim_params=SimParams(; dt=1e-6, n_steps=1), enable_ddi=true, c_dd=b.c_dd,
            ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=b.psi0,
            backend=(gpu ? CUDABackend() : CPUBackend()))) * b.S^2, m0.rho_max_D0)
    @printf("  L-BFGS    : E %+12.3f  rho_max %10.1f  grad_norm %.3e  converged=%s\n",
        r.energy * b.S^2, m.rho_max_D0, get(r, :grad_norm, NaN), r.converged)
    @printf("  ITP       : E     -653.832  rho_max     7100.8   (measured above)\n")
    @printf("  variational: E %+12.3f  rho_max %10.1f | paper rho_max 13000\n",
        b.v.E, b.v.rho_max)
    (; r, m, b)
end

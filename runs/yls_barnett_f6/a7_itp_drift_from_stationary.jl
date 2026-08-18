# Is the ITP/energy disagreement a finite-dt artifact or a face mismatch?
#
# In a harmonic trap, ITP and L-BFGS agree to ~1e-6 for contact, contact+LHY,
# contact+DDI and contact+LHY+DDI (a6). In free space on the droplet they differ
# by 26 % in energy and 44 % in peak density. The droplet regime is stiff: the
# contact and DDI energies are +31340 and -37608 for a net -6268, a 5:1
# cancellation, so an O(dt^p) splitting error is huge relative to the quantity
# being minimised.
#
# The test that separates the two explanations: start ITP AT the L-BFGS stationary
# point (grad_norm ~1e-7 — the energy functional says this state is stationary)
# and measure how far ITP drifts away, as a function of dt.
#   * drift shrinking as a power of dt  -> finite-dt splitting artifact
#   * drift independent of dt           -> the propagator is a different Hamiltonian
# A face mismatch cannot be made small by refining dt; a splitting error must be.

using SpinorBEC
using Printf

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

function drift_probe(name; n=64, box_sigma=2.5, dts=(4e-3, 2e-3, 5e-4, 1.25e-4),
    n_drift=400, gpu=true)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    common = (; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        backend=(gpu ? CUDABackend() : CPUBackend()))

    lb = find_ground_state(; common..., psi_init=b.psi0, method=:lbfgs,
        n_steps=3000, tol=1e-10, verbose=false)
    psi_star = Array(lb.workspace.state.psi)
    m_star = measure(b, psi_star)
    println("="^100)
    @printf("ITP DRIFT FROM THE L-BFGS STATIONARY POINT   cell %s  n=%d box=%.4f L0\n",
        name, n, b.box / b.S)
    @printf("  L-BFGS state: E = %+12.3f  rho_max = %10.1f D0  grad_norm = %.2e\n",
        lb.energy * b.S^2, m_star.rho_max_D0, get(lb, :grad_norm, NaN))
    @printf("  paper: rho_max = 13000 D0 (l=0) ; variational closed form %.0f\n", b.v.rho_max)
    println("  Same number of ITP steps at each dt, so shorter dt = shorter imaginary")
    println("  time; the comparison is the drift PER unit imaginary time.")
    println("-"^100)
    @printf("  %9s %8s %14s %12s %12s %14s\n",
        "dt", "t_total", "E after", "dE", "rho_max", "|dE|/t")
    for dt in dts
        ws = make_workspace(; common..., psi_init=copy(psi_star),
            sim_params=SimParams(; dt=dt, n_steps=n_drift, imaginary_time=true))
        nc = ws.spin_matrices.system.n_components
        nd = length(ws.grid.config.n_points)
        E0 = total_energy(ws) * b.S^2
        for _ in 1:n_drift
            split_step!(ws)
            SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, nc, nd)
        end
        E1 = total_energy(ws) * b.S^2
        m = measure(b, ws.state.psi)
        t = dt * n_drift
        @printf("  %9.2e %8.3f %14.3f %+12.4f %12.1f %14.4e\n",
            dt, t, E1, E1 - E0, m.rho_max_D0, abs(E1 - E0) / t)
        flush(stdout)
    end
    println("-"^100)
    println("  If |dE|/t is roughly constant, the drift is a genuine (wrong-direction)")
    println("  flow; if it falls with dt, it is a splitting artifact.")
    (; b, lb, psi_star)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && drift_probe(isempty(ARGS) ? "P0" : ARGS[1])

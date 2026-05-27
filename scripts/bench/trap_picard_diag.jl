using SpinorBEC
using Printf

# Does trap Picard converge in 2 iterations on the lab path?
# Compare ‖ψ_exit_picard_k - ψ_exit_picard_{k+1}‖ for k = 1..3.

const N = 16
const ATOM = Rb87

function _make_grid()
    make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
end

function _seed_psi!(ws, grid)
    psi = ws.state.psi
    D = size(psi, 4)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]];
        y = grid.x[2][I[2]];
        z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / 2)
        for c in 1:D
            psi[I, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 3)
    nothing
end

function _build_ws(dt::Float64)
    grid = _make_grid()
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(50.0, 1.0),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=1.0,
        backend=CPUBackend(),
    )
    _seed_psi!(ws, grid)
    ws
end

@printf("=== Trap Picard convergence diagnostic ===\n")

for h in (4e-3, 2e-3, 1e-3)
    ws = _build_ws(h)
    psi0 = copy(ws.state.psi)
    n_comp = ws.spin_matrices.system.n_components

    # Compare trap n_picard ∈ {1, 2, 3, 4}
    psi_results = Dict{Int, Array}()
    for np in 1:4
        copyto!(ws.state.psi, psi0)
        SpinorBEC._half_potential_step_trap!(
            ws, h / 2, n_comp, 3, false;
            t_eval=(ws.state.t + h / 4), t_start=ws.state.t, n_picard=np,
        )
        psi_results[np] = copy(ws.state.psi)
    end

    d12 = sqrt(sum(abs2, psi_results[1] - psi_results[2]))
    d23 = sqrt(sum(abs2, psi_results[2] - psi_results[3]))
    d34 = sqrt(sum(abs2, psi_results[3] - psi_results[4]))
    @printf("h=%.0e  trap n_picard 1→2: %.3e  2→3: %.3e  3→4: %.3e",
        h, d12, d23, d34)
    if d23 > 1e-14 && d12 > 1e-14
        rate = d23 / d12
        @printf("  contraction: %.3f\n", rate)
    else
        @printf("  (machine eps)\n")
    end

    # Also compare trap converged vs midpoint converged
    copyto!(ws.state.psi, psi0)
    SpinorBEC._half_potential_step_midpoint!(
        ws, h / 2, n_comp, 3, false;
        t_eval=(ws.state.t + h / 4), t_start=ws.state.t, n_picard=4,
    )
    psi_mid = copy(ws.state.psi)
    d_trap_mid = sqrt(sum(abs2, psi_results[4] - psi_mid))
    @printf("         ‖trap(p=4) - mid(p=4)‖ = %.3e\n", d_trap_mid)
end

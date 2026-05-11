using SpinorBEC
using Printf

# Quick diagnostic: does n_picard actually change the V-step output?
# Setup is the same Rb87 F=1 lab path used in midpoint_order_phase2a.jl.
# We snapshot ψ, run one V step at n_picard=1, snapshot output, reset,
# run one V step at n_picard=2, snapshot, compare.

const N = 16
const ATOM = Rb87

function _make_grid()
    make_grid(GridConfig((N, N, N), (8.0, 8.0, 8.0)))
end

function _seed_psi!(ws, grid)
    psi = ws.state.psi
    D = size(psi, 4)
    @inbounds for I in CartesianIndices((N, N, N))
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
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

@printf("=== Picard diagnostic: does n_picard change V-step output? ===\n")

for h in (4e-3, 2e-3, 1e-3)
    ws = _build_ws(h)
    psi0 = copy(ws.state.psi)
    n_comp = ws.spin_matrices.system.n_components

    # Run with n_picard=1
    SpinorBEC._half_potential_step_midpoint!(
        ws, h / 2, n_comp, 3, false;
        t_eval=ws.state.t + h / 4, t_start=ws.state.t, n_picard=1,
    )
    psi_p1 = copy(ws.state.psi)

    # Reset and run with n_picard=2
    copyto!(ws.state.psi, psi0)
    SpinorBEC._half_potential_step_midpoint!(
        ws, h / 2, n_comp, 3, false;
        t_eval=ws.state.t + h / 4, t_start=ws.state.t, n_picard=2,
    )
    psi_p2 = copy(ws.state.psi)

    # Reset and run with n_picard=3
    copyto!(ws.state.psi, psi0)
    SpinorBEC._half_potential_step_midpoint!(
        ws, h / 2, n_comp, 3, false;
        t_eval=ws.state.t + h / 4, t_start=ws.state.t, n_picard=3,
    )
    psi_p3 = copy(ws.state.psi)

    # Reset and run with n_picard=4
    copyto!(ws.state.psi, psi0)
    SpinorBEC._half_potential_step_midpoint!(
        ws, h / 2, n_comp, 3, false;
        t_eval=ws.state.t + h / 4, t_start=ws.state.t, n_picard=4,
    )
    psi_p4 = copy(ws.state.psi)

    d12 = sqrt(sum(abs2, psi_p1 - psi_p2))
    d23 = sqrt(sum(abs2, psi_p2 - psi_p3))
    d34 = sqrt(sum(abs2, psi_p3 - psi_p4))
    @printf("h=%.0e   ‖p1-p2‖=%.3e  ‖p2-p3‖=%.3e  ‖p3-p4‖=%.3e",
        h, d12, d23, d34)
    if d12 < 1e-15 && d23 < 1e-15
        @printf("   ⚠️  Picard NOT iterating (n_picard kwarg ignored?)\n")
    else
        r1 = d23 / d12; r2 = d34 / d23
        @printf("   contraction ratios: %.3f, %.3f\n", r1, r2)
    end
end

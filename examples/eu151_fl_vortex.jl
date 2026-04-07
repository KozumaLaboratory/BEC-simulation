# Eu151 Ground State: Flower (FL) magnetic vortex ansatz
#
# At each grid point, the spin points in the (cosφ, sinφ, 0) direction,
# where φ = atan(y, x). This gives:
#   - Mz = 0 (no z component)
#   - |F| = F (full polarization, in-plane)
#   - ∇·F = 0 (perfect flux closure, minimizes DDI energy)
#
# Compare E(FL, Mz=0) vs E(uniform, Mz=-6): if FL is lower, it's the true
# ground state. This is the signature of a magnetic vortex phase.

using SpinorBEC, JLD2, Printf
using LinearAlgebra
import CUDA

function build_fl_state(grid::Grid{3}, F::Int; sigma::Float64=2.5)
    nx, ny, nz = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, nx, ny, nz, D)

    sm = spin_matrices(F)
    # Rotation Ry(π/2): rotates |m=+F⟩ to (+x direction)
    # c_m = d^F_{m,+F}(π/2) (column of exp(-iπFy/2))
    U_y = exp(-im * Float64(π)/2 * Matrix(sm.Fy))
    c_base = U_y[:, 1]  # column for initial |m=+F⟩ (c=1)

    for I in CartesianIndices((nx, ny, nz))
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        r2 = x^2 + y^2 + z^2
        amp = sqrt(exp(-r2 / (2 * sigma^2)))

        phi_r = atan(y, x)

        # Apply Rz(phi_r) after Ry(π/2):
        # U = Rz(phi) × Ry(π/2), so (U|F⟩)_m = exp(-i m phi) c_base[m]
        for c in 1:D
            m = F - (c - 1)
            psi[I, c] = amp * c_base[c] * cis(-m * phi_r)
        end
    end

    # Normalize
    dV = cell_volume(grid)
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
    psi
end

function run_fl_vortex(;
    nx::Int = 64,
    box::Float64 = 12.0,
    c_total::Float64 = 4689.0,
    c_dd::Float64 = 7647.0,
    c_lhy::Float64 = 1135.0,
    dt::Float64 = 0.0001,
    n_steps::Int = 10000,
    tol::Float64 = 1e-7,
    save_path::String = "output/eu151_fl_vortex.jld2",
    log_path::String = "output/eu151_fl_vortex.log",
    backend::AbstractBackend = CUDABackend(),
)
    grid = make_grid(GridConfig((nx, nx, nx), (box, box, box)))
    atom = Eu151
    F = atom.F
    sys = SpinSystem(F)

    base_ip = interaction_params_from_constraint(; c_total, c1_ratio=0.0, F)
    interactions = InteractionParams(base_ip.c0, base_ip.c1, c_lhy, base_ip.c_extra)
    trap = HarmonicTrap((1.0, 1.0, 130.0 / 110.0))

    println("Threads: ", Threads.nthreads())
    println("FL vortex ansatz: 64^3 box=12, c1_ratio=0, c_lhy=$c_lhy")
    println()

    psi_init = build_fl_state(grid, F; sigma=2.5)
    mz_init = magnetization(psi_init, grid, sys)
    @printf("FL initial state: Mz = %.4f (should be ~0)\n", mz_init)

    println("\nStarting ITP from FL ansatz...")

    gs = find_ground_state(;
        grid, atom, interactions,
        zeeman = ZeemanParams(0.0, 0.0),
        potential = trap,
        dt, n_steps, tol,
        psi_init = psi_init,
        enable_ddi = true,
        c_dd,
        backend,
    )

    psi_host = SpinorBEC._to_host(gs.workspace.state.psi)
    mz_final = magnetization(psi_host, grid, sys)

    println()
    @printf("E_FL = %.4f\n", gs.energy)
    @printf("dE = %.3g, dpsi = %.3g\n", gs.dE, gs.dpsi)
    @printf("Mz_final = %.4f (started at %.4f)\n", mz_final, mz_init)
    @printf("converged = %s\n", gs.converged)

    JLD2.jldsave(save_path;
        psi=psi_host,
        energy=gs.energy,
        mz=mz_final,
        dE=gs.dE,
        dpsi=gs.dpsi,
    )
    println("\nSaved to $save_path")

    gs.energy
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_fl_vortex()
end

#!/usr/bin/env julia
# Does their 3-point FD Laplacian explain the Fig. 4B residual?
#
#     julia --project=. scripts/validation/matsui_fd_laplacian_probe.jl <reference_run_dir>
#
# On a periodic grid the 3-point FD Laplacian is DIAGONAL IN FOURIER SPACE, with
# eigenvalue Σ_d (2/dx_d²)(1 − cos(k_d dx_d)) in place of |k|². So their operator
# is reproduced exactly by substituting `grid.k_squared` — the algorithm, the
# integrator and every other term stay untouched. Nothing knowingly-inexact goes
# into the production Hamiltonian; this is a script, and the substitution is
# surgical because the DDI builds its own half-grid `k` from `grid.k` / `grid.dk`
# and never reads `grid.k_squared`.
#
# POSITIVE CONTROL, and the reason this script is longer than it looks: the
# hand-built path must first reproduce the pipeline's own number with the exact
# Laplacian. Without that, "FD gave X" says nothing about FD — it could be any
# difference between this script and run_yaml. Two nulls in this campaign were
# wrong for exactly that reason.

using SpinorBEC
using CodecZstd
using JLD2
using Printf

const OMEGA_REF = 691.1504
const KAPPA = 1.181818
const DURATION = 3.4558
const DT = 1.0e-3

"FD eigenvalue array, in place of |k|²."
function fd_k_squared(grid)
    n = grid.config.n_points
    dx = grid.dx
    out = similar(grid.k_squared)
    for I in CartesianIndices(n)
        s = 0.0
        for d in 1:length(n)
            kd = grid.k[d][I[d]]
            s += 2 * (1 - cos(kd * dx[d])) / dx[d]^2
        end
        out[I] = s
    end
    out
end

function run_one(; B_nT, c0, c1, n, box, fd::Bool, backend)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> box, 3)))
    fd && (grid.k_squared .= fd_k_squared(grid))

    atom = Eu151
    inter = InteractionParams(Dict(0 => c0, 1 => c1))
    pot = HarmonicTrap((1.0, 1.0, KAPPA))
    mu_B = 9.27400949e-24
    hbar = 1.054571817e-34
    # H_Z = -p F_z with p = -g_F mu_B B (Kawaguchi-Ueda), matching Units.bfield_to_p.
    p_of(B_T) = -atom.g_F * mu_B * B_T / (hbar * OMEGA_REF)
    q = 2π * 1.0 / OMEGA_REF                       # their ZeemanQ = 1.0 Hz
    # Dimensionless, and the same 211.0214 the static comparison matched to
    # their cdd expression at 7 s.f. make_workspace refuses to guess it.
    c_dd = compute_c_dd_dimless(atom; N_atoms=50_000, omega_ref=OMEGA_REF)

    gs = find_ground_state(; grid, atom, interactions=inter,
        zeeman=ZeemanParams(p_of(1.04e-6), q), potential=pot,
        dt=0.005, n_steps=4000, tol=1e-10, initial_state=:m_minus_F,
        enable_ddi=true, c_dd, secular_ddi=true,
        ddi_padding=true, ddi_trunc_radius=-1.0, backend, verbose=false)

    ws = make_workspace(; grid, atom, interactions=inter,
        zeeman=ZeemanParams(p_of(B_nT * 1e-9), q), potential=pot,
        sim_params=SimParams(; dt=DT, n_steps=round(Int, DURATION / DT),
            save_every=10^9),
        psi_init=Array(gs.workspace.state.psi), enable_ddi=true, c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, backend)
    res = run_simulation!(ws)
    psi = Array(res.psi_final)
    w = [sum(abs2, selectdim(psi, 4, c)) for c in 1:size(psi, 4)]
    w[end] / sum(w)                                 # m = -F fraction
end

_probe_backend() =
    isdefined(Main, :CUDA) && Base.invokelatest(Main.CUDA.functional) ?
    CUDABackend() : CPUBackend()

function main(ref_dir)
    # Resolved couplings, read off the pipeline's own record rather than rebuilt.
    c0, c1, npts, boxs = jldopen(joinpath(ref_dir, "point_002.jld2"), "r") do g
        (g["interactions_c0"], g["interactions_c1"], g["grid_n_points"], g["grid_box_size"])
    end
    n = Int(npts[1])
    box = Float64(boxs[1])
    @printf("from the reference run: c0 = %.4f  c1 = %.4f  grid %d^3  box %.3f\n",
        c0, c1, n, box)

    backend = _probe_backend()
    println("\n--- positive control: hand-built path vs the pipeline, exact Laplacian ---")
    ctrl = run_one(; B_nT=-2.0, c0, c1, n, box, fd=false, backend)
    @printf("hand-built, exact  : %.6f\n", ctrl)
    @printf("pipeline (45-field): %.6f\n", 0.195201)
    @printf("relative difference: %.2e   %s\n", abs(ctrl - 0.195201) / 0.195201,
        if abs(ctrl - 0.195201) / 0.195201 < 5e-3
            "OK — the path is faithful"
        else
            "FAIL — do not read the FD number below"
        end)

    println("\n--- the measurement ---")
    for B in (-3.0, -2.5, -2.0, -1.5)
        e = run_one(; B_nT=B, c0, c1, n, box, fd=false, backend)
        f = run_one(; B_nT=B, c0, c1, n, box, fd=true, backend)
        @printf("B = %5.1f nT   exact %.6f   FD %.6f   FD-exact %+.6f (%+.1f %%)\n",
            B, e, f, f - e, 100 * (f - e) / e)
    end
    println("\nMatsui at -2.0 nT: 0.247500.  Ours (exact) 0.195201, a 21 % gap.")
    println("If FD moves ours UP toward 0.2475, their Laplacian is the explanation.")
    println("If it moves DOWN, FD is excluded and it makes the disagreement worse.")
end

isempty(ARGS) && error("usage: matsui_fd_laplacian_probe.jl <reference_run_dir>")
main(ARGS[1])

# Li-Saito Fig. 5: a one-dimensional supersolid of magnetic vortices.
#
#   "Figure 5 shows the density and spin distributions of the ground state, in
#    which multiple droplets with magnetic vortices are aligned along the x axis
#    with alternate circulations of the magnetic vortices. This state can be
#    called a one-dimensional supersolid ... If the trap in the y or z direction
#    in Fig. 5 is removed, the ground state becomes a large single droplet with
#    a magnetic vortex."
#
# Cell (paper's caption): F = 1, N = 4e5, eps_dd = 1.4, B_z = 0, in
#   V = M(wx^2 x^2 + wy^2 y^2 + wz^2 z^2)/2 with (wx, wy, wz)/2pi =
#   (100, 1500, 6000) Hz  ->  in units of w_ref = 2pi*110 Hz:
#   (0.9091, 13.636, 54.545).
#
# WHAT IS ACTUALLY BEING TESTED. "The ground state is periodic" is a claim about
# which of two states is lower, so BOTH are converged from their own seed and
# compared by energy, exactly as the bistability arm does:
#
#   :chain    — n_drop magnetic vortices along x with ALTERNATING circulation
#   :single   — one magnetic vortex, no modulation
#
# Seeding the answer and reporting that it converged would not distinguish "the
# supersolid is the ground state" from "the supersolid is a local minimum the
# relaxation could not leave".
#
# Usage:
#   julia --project=. -e 'import CUDA' \
#     -e 'include("runs/saito_li_torus/h9_supersolid.jl"); main(["seed=chain"])'
#   keys: seed=chain|single n_drop= nx= ny= nz= box_x= box_y= box_z= iters=
#         smoke=true backend=cpu

using SpinorBEC
using SpinorBEC: make_grid, GridConfig, Grid, SpinSystem, spin_matrices,
    cell_volume, total_density, spin_density_vector, energy_decomposition,
    find_ground_state, InteractionParams, ZeemanParams, HarmonicTrap,
    ATOM_REGISTRY, Units, compute_a_dd, compute_c_dd_dimless,
    scalar_lhy_coefficient, effective_eps_dd
using Printf
using LinearAlgebra
using JLD2

const OMEGA_REF_SS = 691.15                     # 2 pi * 110 Hz
const ATOM_F1 = ATOM_REGISTRY[:Eu151_f1_effective]
const A_HO_SS = sqrt(Units.HBAR / (ATOM_F1.mass * OMEGA_REF_SS))
const A_HO_UM_SS = A_HO_SS * 1e6
const N_SS = 400_000
const EPS_DD_SS = 1.4
# 2 pi * (100, 1500, 6000) Hz in units of w_ref
const TRAP_SS = (2π * 100 / OMEGA_REF_SS, 2π * 1500 / OMEGA_REF_SS,
    2π * 6000 / OMEGA_REF_SS)

"""
Chain of `n_drop` in-plane magnetic vortices along x with alternating
circulation, on a Thomas-Fermi-like envelope.

The texture is built from ONE smooth azimuth field
`Theta(r) = sum_k s_k atan2(y, x - x_k)` rather than by pasting per-droplet
patches together: a patched texture is discontinuous between droplets and the
solver spends its first hundred iterations repairing the seam. `s_k = (-1)^k`
is the alternation the paper reports.

`n_drop = 1` with `s = +1` is the single-vortex control.
"""
function seed_chain(grid::Grid{3}, F::Int; n_drop::Int, spacing, mu, trap,
    core=0.25, alternate=true)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    centers = [(k - (n_drop + 1) / 2) * spacing for k in 1:n_drop]
    signs = [alternate ? (isodd(k) ? 1.0 : -1.0) : 1.0 for k in 1:n_drop]
    binom = [sqrt(float(binomial(2F, c - 1))) for c in 1:D]
    ch = sh = sqrt(0.5)                       # theta = pi/2, fully in-plane
    @inbounds for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V = 0.5 * (trap[1]^2 * x^2 + trap[2]^2 * y^2 + trap[3]^2 * z^2)
        amp2 = mu - V
        amp2 > 0 || continue
        amp = sqrt(amp2)
        Θ = 0.0
        for k in 1:n_drop
            dx = x - centers[k]
            Θ += signs[k] * atan(y, dx)
            amp *= tanh(sqrt(dx^2 + y^2) / core)   # pre-form each vortex core
        end
        ph = Θ + π / 2                         # n_hat = phi_hat (flux closure)
        for c in 1:D
            m = F - (c - 1)
            psi[I, c] = amp * binom[c] * ch^(F + m) * sh^(F - m) * cis(-m * ph)
        end
    end
    s = sum(abs2, psi) * cell_volume(grid)
    s > 0 || error("seed is empty — mu too small for this trap/box")
    psi ./ sqrt(s)
end

"Density modulation along x: contrast of rho(x) integrated over y,z."
function modulation(psi, grid::Grid{3})
    rho = total_density(psi isa Array ? psi : Array(psi), 3)
    line = vec(sum(rho; dims=(2, 3)))
    # only the region carrying the cloud
    keep = line .> 0.05 * maximum(line)
    seg = line[keep]
    length(seg) < 8 && return (; contrast=NaN, n_peaks=0, line, keep)
    # interior local maxima
    pk = [i for i in 2:(length(seg) - 1) if seg[i] > seg[i - 1] && seg[i] > seg[i + 1]]
    tr = [i for i in 2:(length(seg) - 1) if seg[i] < seg[i - 1] && seg[i] < seg[i + 1]]
    contrast = if isempty(pk) || isempty(tr)
        0.0
    else
        (maximum(seg[pk]) - minimum(seg[tr])) / (maximum(seg[pk]) + minimum(seg[tr]))
    end
    (; contrast, n_peaks=length(pk), line, keep)
end

function main(args::Vector{String}=String[])
    opts = Dict{String, String}()
    for a in args
        occursin('=', a) || continue
        k, v = split(a, '='; limit=2)
        opts[k] = v
    end
    smoke = get(opts, "smoke", "false") == "true"
    which = Symbol(get(opts, "seed", "chain"))
    n_drop = parse(Int, get(opts, "n_drop", "5"))
    nx = parse(Int, get(opts, "nx", smoke ? "64" : "192"))
    ny = parse(Int, get(opts, "ny", smoke ? "24" : "48"))
    nz = parse(Int, get(opts, "nz", smoke ? "24" : "48"))
    bx = parse(Float64, get(opts, "box_x", "16.0"))
    by = parse(Float64, get(opts, "box_y", "2.4"))
    bz = parse(Float64, get(opts, "box_z", "1.2"))
    iters = parse(Int, get(opts, "iters", smoke ? "25" : "4000"))
    be = get(opts, "backend", "gpu") == "cpu" ? CPUBackend() : CUDABackend()
    which === :single && (n_drop = 1)

    a_dd = compute_a_dd(ATOM_F1)
    a_s = a_dd / EPS_DD_SS
    atom = AtomSpecies(ATOM_F1.name, ATOM_F1.mass, ATOM_F1.F, a_s, 0.0,
        ATOM_F1.mu_mag, ATOM_F1.g_F)
    c0 = 4π * (a_s / A_HO_SS) * N_SS
    c_dd = compute_c_dd_dimless(atom; N_atoms=N_SS, omega_ref=OMEGA_REF_SS)
    c_lhy = scalar_lhy_coefficient(a_s / A_HO_SS, N_SS; eps_dd=EPS_DD_SS)

    grid = make_grid(GridConfig{3}((nx, ny, nz), (bx, by, bz)))
    # TF chemical potential for the seed envelope (3D, contact only). Only the
    # SEED depends on it; the solver moves off it immediately.
    mu = 0.5 * (15 * c0 * TRAP_SS[1] * TRAP_SS[2] * TRAP_SS[3] / (8π))^(2 / 5)
    spacing = bx / (n_drop + 1)
    psi0 = seed_chain(grid, atom.F; n_drop=n_drop, spacing=spacing, mu=mu,
        trap=TRAP_SS, alternate=(which === :chain))

    @printf("\n### Fig. 5 supersolid   seed=%s  n_drop=%d  n=(%d,%d,%d)  box=(%.1f,%.1f,%.1f)\n",
        which, n_drop, nx, ny, nz, bx, by, bz)
    @printf("  trap w/w_ref = (%.4f, %.4f, %.4f)   [2pi x (100,1500,6000) Hz]\n",
        TRAP_SS...)
    @printf("  a_s = %.4f a_B   c0 = %.2f   c_dd = %.2f   c_lhy = %.2f   eps_dd = %.6f\n",
        a_s / Units.BOHR_RADIUS, c0, c_dd, c_lhy,
        effective_eps_dd(atom.F, c0, c_dd))
    @printf("  TF mu (seed only) = %.3f   droplet spacing = %.3f a_ho\n", mu, spacing)

    ip = InteractionParams(Dict(0 => c0); c_lhy=c_lhy)
    pot = HarmonicTrap(TRAP_SS...)
    t0 = time()
    gs = find_ground_state(; grid=grid, atom=atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=pot,
        psi_init=psi0, enable_ddi=true, c_dd=c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        method=:lbfgs, n_steps=iters, tol=1e-10, backend=be, verbose=false)
    wall = time() - t0
    ws = gs.workspace
    psi = ws.state.psi
    e = energy_decomposition(ws)
    m = modulation(psi, grid)
    rho = total_density(Array(psi), 3)
    dV = cell_volume(grid)
    np = grid.config.n_points
    edge = 0.0
    @inbounds for I in CartesianIndices(rho)
        if I[1] == 1 || I[2] == 1 || I[3] == 1 ||
            I[1] == np[1] || I[2] == np[2] || I[3] == np[3]
            edge += rho[I] * dV
        end
    end
    sm = spin_matrices(atom.F)
    fx, fy, fz = spin_density_vector(Array(psi), sm, 3)
    pol = sum(sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)) * dV /
          (atom.F * sum(rho) * dV)

    @printf("  wall %.1f s   grad_norm = %.3e\n", wall, get(gs, :grad_norm, NaN))
    @printf("  E/N = %.8f hbar w_ref\n", e.total)
    for k in sort(collect(propertynames(e)); by=string)
        k === :total && continue
        v = getproperty(e, k)
        v isa Real && abs(v) > 1e-10 && @printf("     %-10s = %+12.5f\n", k, v)
    end
    @printf("  density modulation along x: contrast = %.4f over %d interior peaks\n",
        m.contrast, m.n_peaks)
    @printf("  |f|/(F rho) = %.4f     edge fraction = %.3e\n", pol, edge)
    @printf("  <f> = (%+.5f, %+.5f, %+.5f)\n",
        sum(fx) * dV, sum(fy) * dV, sum(fz) * dV)

    if !smoke
        tag = @sprintf("fig5_%s_nd%d_n%dx%dx%d", which, n_drop, nx, ny, nz)
        jldsave(joinpath(@__DIR__, "out", "$tag.jld2"); psi=Array(psi),
            n=(nx, ny, nz), box=(bx, by, bz), seed=which, n_drop=n_drop,
            E=e.total, contrast=m.contrast, n_peaks=m.n_peaks, edge=edge,
            line=m.line, trap=TRAP_SS,
            git_hash=strip(read(`git rev-parse HEAD`, String)))
        println("  wrote out/$tag.jld2")
    end
    (; E=e.total, m, edge, pol)
end

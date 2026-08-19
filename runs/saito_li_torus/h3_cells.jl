# eGPE cells for issue #336 (Li & Saito, arXiv:2402.18885).
#
# ONE protocol. Cells differ only in (seed topology, B_z, N, grid, box); the
# solver, the couplings, the seed construction and every observable are shared,
# so a difference between two cells is a difference in the physics.
#
# Units are the CONFIG's, not a rescaled set: omega_ref = 2 pi * 110 Hz,
# a_ho = 0.78029 um, exactly as `config.yaml`. The variational sigma_r lands at
# 0.588 a_ho, which is already a well-scaled internal length, so there is no
# reason to rescale (contrast `runs/yls_barnett_f6/b_egpe_cells.jl`, where
# a_ho = L0 would have forced dt ~ 1e-7).
#
# SOLVER: L-BFGS, not imaginary time. Free-space dipolar droplets have a
# dt-displaced ITP fixed point -- 44 % wrong in peak density while reporting
# dpsi = 3e-6, and grid- and box-independent, so a convergence scan certifies
# the wrong answer. Measured on the sibling droplet; see
# `runs/yls_barnett_f6/README.md` section 2.
#
# Usage:
#   julia --project=. -e 'import CUDA' \
#     -e 'include("runs/saito_li_torus/h3_cells.jl"); main(["T"])'
#   julia --project=. -e 'import CUDA' \
#     -e 'include("runs/saito_li_torus/h3_cells.jl"); main(["T","C","smoke=true"])'
#
# keys: n= box_xy= box_z= smoke= backend=cpu|gpu iters= out=

using SpinorBEC
using SpinorBEC: make_grid, GridConfig, Grid, SpinSystem, spin_matrices,
    cell_volume, make_fft_plans, total_density, spin_density_vector,
    orbital_angular_momentum_vector, energy_decomposition, make_workspace,
    find_ground_state, InteractionParams, ZeemanParams, HarmonicTrap,
    SimParams, ATOM_REGISTRY, Units, compute_a_dd, compute_c_dd_dimless,
    compute_c_total, scalar_lhy_coefficient, effective_eps_dd
using Printf
using LinearAlgebra
using FFTW
using JLD2

include(joinpath(@__DIR__, "..", "yls_barnett_f6", "a2_variational_stability.jl"))

const A_B = Units.BOHR_RADIUS
const OMEGA_REF = 691.15
const ATOM_BASE = ATOM_REGISTRY[:Eu151]
const A_HO = sqrt(Units.HBAR / (ATOM_BASE.mass * OMEGA_REF))    # m
const A_HO_UM = A_HO * 1e6
const TRAP_OMEGA = 0.01          # residual cage; 6.1e-5 of |E|/N, see a3 gate
# Fraction of the norm allowed in the outermost voxel shell. The converged
# torus sits at 1.2e-6, so 1e-4 is ~100x looser than a good cell and still
# 4 orders below the cells that turned out to be box-filling clouds.
const EDGE_MAX = 1.0e-4

# ---------------------------------------------------------------------------
# cells
# ---------------------------------------------------------------------------
# `seed`: :torus -> the paper's magnetic vortex (Eq. 2-3), :cigar -> the
# z-polarized prolate droplet that is its bistable partner (paper Fig. 3(a)).
# `Bz_mG` in milligauss, the paper's unit in Fig. 3.
const CELLS = Dict(
    "T" => (; seed=:torus, N=15000, eps_dd=1.3, Bz_mG=0.0),
    "C" => (; seed=:cigar, N=15000, eps_dd=1.3, Bz_mG=0.0),
)
"Field-ladder cells, built on demand: T@0.05 / C@0.05 / ..."
function cell_for(name::AbstractString)
    haskey(CELLS, name) && return CELLS[name]
    m = match(r"^([TC])@([0-9.]+)$", name)
    if m === nothing
        known = join(sort(collect(keys(CELLS))), ", ")
        error("unknown cell $name (have $known, or T@<mG> / C@<mG>)")
    end
    (; seed=(m[1] == "T" ? :torus : :cigar), N=15000, eps_dd=1.3,
        Bz_mG=parse(Float64, m[2]))
end

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------

"""
Everything a cell needs. `a_s` is lowered until `a_dd/a_s == eps_dd` — the
paper's own route to eps_dd > 1, with the moment (hence a_dd) fixed by the
atom. Consequently `c_dd` is the NATURAL value and only `c_total` moves; see
`g2_resolved_coefficients.jl` for why scaling both squares the ratio.
"""
function build_cell(cell; n=(64, 64, 64), box=(6.5, 6.5, 3.5), seed_scale=1.0)
    F = ATOM_BASE.F
    a_dd = compute_a_dd(ATOM_BASE)
    a_s = a_dd / cell.eps_dd
    atom = AtomSpecies(ATOM_BASE.name, ATOM_BASE.mass, F, a_s, 0.0,
        ATOM_BASE.mu_mag, ATOM_BASE.g_F)

    c0 = 4π * (a_s / A_HO) * cell.N
    c_dd = compute_c_dd_dimless(atom; N_atoms=cell.N, omega_ref=OMEGA_REF)
    c_lhy = scalar_lhy_coefficient(a_s / A_HO, cell.N; eps_dd=cell.eps_dd)

    v = droplet(; eps_dd=cell.eps_dd, N=cell.N, F=F, l=0)
    v.bound || error("cell has no bound variational droplet (N_c = $(v.N_c))")
    L0_over_aho = a_s * cell.N / A_HO
    sr = v.sigma_r * L0_over_aho * seed_scale       # a_ho
    sz = v.sigma_z * L0_over_aho * seed_scale
    lam = v.lambda

    grid = make_grid(GridConfig{3}(n, box))
    psi0 = cell.seed === :torus ? seed_torus(grid, F; lam, sr, sz) :
           seed_cigar(grid, F; sr, sz)

    # H = -p F_z; p = -g_F mu_B B / (hbar omega_ref) lives once in Units.
    p = SpinorBEC.Units.bfield_to_p_gauss(cell.Bz_mG * 1e-3, atom.g_F, OMEGA_REF)

    (; cell, atom, F, a_s, a_dd, c0, c_dd, c_lhy, grid, psi0, v, box, n, p,
        L0_over_aho, sr, sz, lam,
        eps_dd_check=effective_eps_dd(F, c0, c_dd))
end

"""
The paper's Eq. (2)-(3): Psi = sqrt(rho_v) exp(-i S_z phi) zeta^(y), with
rho_v proportional to r^(2 lam) exp(-r^2/sr^2 - z^2/sz^2).

`zeta^(y)` is |m_y = +F>, i.e. R_z(pi/2) R_y(pi/2) |m = +F>; combined with the
exp(-i S_z phi) rotation the m-component phase is exp(-i m (phi + pi/2)), so the
magnetization points along phi_hat at every point. Each m != 0 therefore carries
a charge-m vortex on the axis, and only m = 0 survives the central hole — the
paper's own observation about Fig. 1(b).
"""
function seed_torus(grid::Grid{3}, F::Int; lam, sr, sz, axis=3)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    # unit vector of the symmetry axis and the two in-plane directions
    e3 = if axis == 1
        (1.0, 0.0, 0.0)
    elseif axis == 2
        (0.0, 1.0, 0.0)
    else
        (0.0, 0.0, 1.0)
    end
    e1 = if axis == 1
        (0.0, 1.0, 0.0)
    elseif axis == 2
        (0.0, 0.0, 1.0)
    else
        (1.0, 0.0, 0.0)
    end
    e2 = cross3(e3, e1)
    binom = [sqrt(float(binomial(2F, F - (F - (c - 1))))) for c in 1:D]
    @inbounds for I in CartesianIndices(n_pts)
        r = (grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]])
        u = dot3(r, e1)
        v = dot3(r, e2)
        w = dot3(r, e3)                      # along the symmetry axis
        rho2 = u^2 + v^2
        amp = sqrt(rho2^lam * exp(-rho2 / sr^2 - w^2 / sz^2))
        amp > 0 || continue
        # magnetization along the azimuthal direction about the axis:
        # phi_hat = e3 x r_perp / |r_perp|
        rperp = (u .* e1 .+ v .* e2)
        nrm = sqrt(rho2)
        nrm > 1e-14 || continue
        nh = cross3(e3, rperp ./ nrm)
        th = acos(clamp(nh[3], -1.0, 1.0))
        ph = atan(nh[2], nh[1])
        # Spin-coherent state along nh:
        #   c_m = e^{-i m ph} sqrt(C(2F,F-m)) cos^{F+m}(th/2) sin^{F-m}(th/2)
        # MEASURED, not assumed. Adding the Condon-Shortley (-1)^{F-m} — which
        # the textbook d^F_{m,F} carries — puts the realised magnetization at
        # (-n_x, -n_y, +n_z), i.e. the azimuth off by pi, against this repo's
        # `spin_matrices` convention. For an axis along z that is a uniform
        # flip and merely reverses the (degenerate) circulation, so it hides;
        # for a tilted axis it destroys the circulation entirely (<f.phi_hat>
        # went to 0.000 while the density stayed a perfect torus).
        ch, sh = cos(th / 2), sin(th / 2)
        for c in 1:D
            m = F - (c - 1)
            psi[I, c] = amp * binom[c] * ch^(F + m) * sh^(F - m) * cis(-m * ph)
        end
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

dot3(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
cross3(a, b) = (a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3],
    a[1] * b[2] - a[2] * b[1])

"""
The bistable partner (paper Fig. 3(a)): a cigar, spin polarized along z, with
NO winding. Prolate along z because that is the shape a z-polarized dipolar
droplet takes (head-to-tail attraction), which is the opposite anisotropy from
the torus — so the two seeds are genuinely in different basins.
"""
function seed_cigar(grid::Grid{3}, F::Int; sr, sz)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    # Eu has g_F > 0 and H_zee = -p F_z with p < 0 for Bz > 0, so the Zeeman
    # ground state is m = -F. Seed the cigar there; at Bz = 0 the sign is free.
    w_r = 0.6 * sr
    w_z = 2.5 * sz
    @inbounds for I in CartesianIndices(n_pts)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        psi[I, D] = exp(-(x^2 + y^2) / (2w_r^2) - z^2 / (2w_z^2))
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

# ---------------------------------------------------------------------------
# observables
# ---------------------------------------------------------------------------

"""
Phase winding of component `c` on a circle of radius `r` in the z = 0 plane.

Returned together with the minimum |psi| on the loop: a winding read off a
contour where the amplitude is at the noise floor is not a measurement, and the
issue's acceptance criterion is explicit that a masked zero must be
distinguishable from a real one.
"""
function component_winding(psi, grid::Grid{3}, c::Int; r::Float64, n_theta::Int=512)
    iz = argmin(abs.(grid.x[3]))
    tot, prev, amp_min, amp_max = 0.0, NaN, Inf, 0.0
    for j in 0:n_theta
        th = 2π * j / n_theta
        ix = argmin(abs.(grid.x[1] .- r * cos(th)))
        iy = argmin(abs.(grid.x[2] .- r * sin(th)))
        z = psi[ix, iy, iz, c]
        amp_min = min(amp_min, abs(z))
        amp_max = max(amp_max, abs(z))
        ph = angle(z)
        if !isnan(prev)
            d = ph - prev
            d > π && (d -= 2π)
            d < -π && (d += 2π)
            tot += d
        end
        prev = ph
    end
    (; winding=tot / 2π, amp_min, amp_max)
end

function measure(b, psi, ws)
    grid, F = b.grid, b.F
    sm = spin_matrices(F)
    D = 2F + 1
    dV = cell_volume(grid)
    psi_h = psi isa Array ? psi : Array(psi)

    plans = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    L = orbital_angular_momentum_vector(psi_h, grid, plans)
    fx, fy, fz = spin_density_vector(psi_h, sm, 3)
    f = (sum(fx) * dV, sum(fy) * dV, sum(fz) * dV)

    rho = total_density(psi_h, 3)
    rho_max = maximum(rho)
    x2 = y2 = z2 = r_w = 0.0
    @inbounds for I in CartesianIndices(rho)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        w = rho[I] * dV
        x2 += w * x^2
        y2 += w * y^2
        z2 += w * z^2
        r_w += w * sqrt(x^2 + y^2)
    end

    # ring radius of the density maximum on z = 0 (the torus radius the paper
    # plots), distinct from the density-weighted <r> above
    iz = argmin(abs.(grid.x[3]))
    r_peak, rho_peak_plane = 0.0, -Inf
    @inbounds for i in axes(rho, 1), j in axes(rho, 2)
        if rho[i, j, iz] > rho_peak_plane
            rho_peak_plane = rho[i, j, iz]
            r_peak = hypot(grid.x[1][i], grid.x[2][j])
        end
    end

    edge = 0.0
    np = grid.config.n_points
    @inbounds for I in CartesianIndices(rho)
        if I[1] == 1 || I[2] == 1 || I[3] == 1 ||
            I[1] == np[1] || I[2] == np[2] || I[3] == np[3]
            edge += rho[I] * dV
        end
    end

    pops = [sum(abs2, view(psi_h,:,:,:,c)) * dV for c in 1:D]
    wind = [component_winding(psi_h, grid, c; r=max(r_peak, 2 * step_of(grid, 1)))
            for c in 1:D]

    e = energy_decomposition(ws)
    terms = Dict{Symbol, Float64}()
    for k in propertynames(e)
        k === :total && continue
        v = getproperty(e, k)
        v isa Real && (terms[k] = Float64(v))
    end
    sum_abs = sum(abs, values(terms))
    e_lhy = get(terms, :lhy, 0.0)
    e_s = get(terms, :density, 0.0)
    e_ddi = get(terms, :ddi, 0.0)

    (; L, f, rho_max, rho_max_N=rho_max / _um3_per_aho3(),
        r_peak, r_mean=r_w, sigma_x=sqrt(x2), sigma_z=sqrt(z2),
        aspect=sqrt(x2 / z2), edge_fraction=edge, pops,
        windings=[w.winding for w in wind],
        wind_amp=[(w.amp_min, w.amp_max) for w in wind],
        polarization=sum(sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)) * dV /
                     (F * sum(rho) * dV),
        E=e.total, terms, sum_abs,
        lhy_frac_of_total=abs(e_lhy) / abs(e.total),
        lhy_frac_of_sum=abs(e_lhy) / sum_abs,
        flux_closure_ratio=(e_s == 0 ? NaN : e_ddi / e_s),
        cancellation_ratio=abs(e.total) / sum_abs)
end

step_of(grid, d) = grid.x[d][2] - grid.x[d][1]
# |psi|^2 is normalised to 1 over the box in a_ho^3; the paper plots rho in
# N um^-3, i.e. (density in um^-3)/N = |psi|^2 / a_ho[um]^3.
_um3_per_aho3() = A_HO_UM^3

function report(tag, b, psi, ws, gs)
    m = measure(b, psi, ws)
    F = b.F
    println("-"^78)
    @printf("%s  seed=%s  N=%d  eps_dd=%.4f  Bz=%.4f mG  n=%s box=%s\n",
        tag, b.cell.seed, b.cell.N, b.cell.eps_dd, b.cell.Bz_mG, b.n, b.box)
    @printf("  couplings: c0=%.4f c_dd=%.4f c_lhy=%.4f  eps_dd_eff=%.6f  p=%.4e\n",
        b.c0, b.c_dd, b.c_lhy, b.eps_dd_check, b.p)
    gs === nothing || @printf("  solver: grad_norm=%.3e  iters=%s  E_solver=%.8f\n",
        get(gs, :grad_norm, NaN), get(gs, :iterations, "?"), get(gs, :energy, NaN))
    println()
    @printf("  E/N total        = %+.6f hbar w_ref\n", m.E)
    for k in sort(collect(keys(m.terms)); by=string)
        abs(m.terms[k]) > 1e-12 || continue
        @printf("     %-14s = %+12.5f   (%5.2f %% of sum|E_i|)\n",
            k, m.terms[k], 100 * abs(m.terms[k]) / m.sum_abs)
    end
    @printf("  |E_LHY|/|E_tot|  = %.3f      <- droplets legitimately exceed the\n",
        m.lhy_frac_of_total)
    @printf("  |E_LHY|/sum|E_i| = %.4f     campaign's 15 %% guard; stated, not hidden\n",
        m.lhy_frac_of_sum)
    @printf("  E_ddi/E_s        = %+.6f    (flux closure predicts -eps_dd = %.4f)\n",
        m.flux_closure_ratio, -b.cell.eps_dd)
    @printf("  cancellation |E|/sum|E_i| = %.4f  (< 0.05 => ITP is dt-limited here)\n",
        m.cancellation_ratio)
    println()
    @printf("  rho_max          = %.5f N um^-3   (%.4e um^-3)\n",
        m.rho_max_N, m.rho_max_N * b.cell.N)
    @printf("  r_peak (ring)    = %.5f a_ho = %.5f um\n", m.r_peak, m.r_peak * A_HO_UM)
    @printf("  <r>              = %.5f a_ho = %.5f um\n", m.r_mean, m.r_mean * A_HO_UM)
    @printf("  sigma_x, sigma_z = %.5f, %.5f a_ho   aspect = %.4f\n",
        m.sigma_x, m.sigma_z, m.aspect)
    @printf("  <L>              = (%+.5f, %+.5f, %+.5f)\n", m.L...)
    @printf("  <f>              = (%+.5f, %+.5f, %+.5f)\n", m.f...)
    @printf("  |f|/(F rho)      = %.4f  (paper: ~1 except near the centre)\n",
        m.polarization)
    # A cloud touching the wall has no meaningful energy, and printing the
    # number in a column is not enough: on 2026-08-19 the field ladder was read
    # as "a converged cigar branch exists and is lower in energy" from cells
    # carrying 4.2e-1 and 8.3e-3 of the norm on the boundary, both printed and
    # both skipped. So the verdict is stated, not left to the reader.
    if m.edge_fraction > EDGE_MAX
        @printf("  edge density     = %.3e   *** UNUSABLE: > %.0e of the norm is on\n",
            m.edge_fraction, EDGE_MAX)
        println(
            "                     the boundary. This cell is not a self-bound state; " *
            "its\n                     energy is a box artifact. Enlarge the box and rerun.",
        )
    else
        @printf("  edge density     = %.3e  (box adequacy; also gates <L_z>)\n",
            m.edge_fraction)
    end
    print("  n_m   :")
    for (c, p) in enumerate(m.pops)
        @printf(" %+d:%.4f", F - (c - 1), p)
    end
    println()
    print("  v_m   :")
    for (c, w) in enumerate(m.windings)
        @printf(" %+d:%+.2f", F - (c - 1), w)
    end
    println()
    print("  |psi| range on the winding loop (a masked zero looks like a real one):")
    println()
    for (c, (lo, hi)) in enumerate(m.wind_amp)
        m.pops[c] > 1e-8 || continue
        @printf("     m=%+d  n_m=%.2e  |psi| in [%.2e, %.2e]  ratio %.1e\n",
            F - (c - 1), m.pops[c], lo, hi, lo / max(hi, eps()))
    end
    m
end

# ---------------------------------------------------------------------------
# solve
# ---------------------------------------------------------------------------

function solve_cell(b; backend=CUDABackend(), iters=4000, tol=1e-10, verbose=false)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    pot = HarmonicTrap(TRAP_OMEGA, TRAP_OMEGA, TRAP_OMEGA)
    gs = find_ground_state(;
        grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(b.p, 0.0), potential=pot,
        psi_init=b.psi0, enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        method=:lbfgs, n_steps=iters, tol=tol,
        backend=backend, verbose=verbose)
    # `find_ground_state` hands back the workspace it converged in, so the
    # energy decomposition below is read from the same operator set the solver
    # descended -- rebuilding one here would be a second statement of the
    # Hamiltonian and could silently disagree.
    ws = gs.workspace
    (ws.state.psi, ws, gs)
end

"rho(r, z=0), azimuthally averaged — the curve of the paper's Fig. 2(a)."
function radial_profile(b, psi; nbins=64)
    grid = b.grid
    psi_h = psi isa Array ? psi : Array(psi)
    rho = total_density(psi_h, 3)
    iz = argmin(abs.(grid.x[3]))
    rmax = min(maximum(grid.x[1]), maximum(grid.x[2]))
    edges = range(0, rmax; length=nbins + 1)
    acc = zeros(nbins)
    cnt = zeros(Int, nbins)
    for i in axes(rho, 1), j in axes(rho, 2)
        r = hypot(grid.x[1][i], grid.x[2][j])
        k = searchsortedlast(edges, r)
        (1 <= k <= nbins) || continue
        acc[k] += rho[i, j, iz]
        cnt[k] += 1
    end
    rs = [(edges[k] + edges[k + 1]) / 2 for k in 1:nbins]
    (; r_aho=rs, r_um=rs .* A_HO_UM,
        rho_N_um3=[cnt[k] > 0 ? acc[k] / cnt[k] / _um3_per_aho3() : NaN
                   for k in 1:nbins],
        counts=cnt)
end

# ---------------------------------------------------------------------------
# driver
# ---------------------------------------------------------------------------

function main(args::Vector{String}=String[])
    opts = Dict{String, String}()
    cells = String[]
    for a in args
        if occursin('=', a)
            k, v = split(a, '='; limit=2)
            opts[k] = v
        else
            push!(cells, a)
        end
    end
    isempty(cells) && (cells = ["T"])
    smoke = get(opts, "smoke", "false") == "true"
    nn = parse(Int, get(opts, "n", smoke ? "24" : "64"))
    nz = parse(Int, get(opts, "nz", string(nn)))
    bxy = parse(Float64, get(opts, "box_xy", "6.5"))
    bz = parse(Float64, get(opts, "box_z", "3.5"))
    iters = parse(Int, get(opts, "iters", smoke ? "20" : "4000"))
    be = get(opts, "backend", "gpu") == "cpu" ? CPUBackend() : CUDABackend()
    outdir = get(opts, "out", joinpath(@__DIR__, "out"))
    mkpath(outdir)

    results = Dict{String, Any}()
    for name in cells
        c = cell_for(name)
        b = build_cell(c; n=(nn, nn, nz), box=(bxy, bxy, bz))
        @printf("\n### cell %s   (%s seed, Bz = %.4f mG)  n=%s box=%s iters=%d\n",
            name, c.seed, c.Bz_mG, (nn, nn, nz), (bxy, bxy, bz), iters)
        t0 = time()
        psi, ws, gs = solve_cell(b; backend=be, iters=iters,
            verbose=get(opts, "verbose", "false") == "true")
        @printf("  wall %.1f s\n", time() - t0)
        m = report(name, b, psi, ws, gs)
        prof = radial_profile(b, psi)
        results[name] = (; measured=m, profile=prof, cell=c,
            n=(nn, nn, nz), box=(bxy, bxy, bz), iters,
            git_hash=strip(read(`git rev-parse HEAD`, String)))
        if !smoke
            # The grid and box go in the FILENAME: the convergence arms are the
            # same cell at different resolutions, and a name that omits them
            # silently overwrites the arm it is supposed to be compared with.
            tag = @sprintf("%s_n%dx%d_box%gx%g", replace(name, "@" => "_"),
                nn, nz, bxy, bz)
            jldsave(joinpath(outdir, "cell_$tag.jld2");
                psi=Array(psi), profile=prof, cell=c, n=(nn, nn, nz),
                box=(bxy, bxy, bz),
                git_hash=strip(read(`git rev-parse HEAD`, String)))
        end
    end
    results
end

# eGPE cells for issue #338. ONE protocol; cells differ only in
# (atom/F, eps_dd, N, l, q, grid). Everything else -- seed construction, dt,
# convergence gate, and the way every conserved quantity is read -- is shared,
# so a difference between two cells is a difference in the physics and not in
# the wiring.
#
# Numerical unit choice. The paper's model depends only on (eps_dd, N, F, l), so
# the internal length unit is free. Setting a_ho = L0 = a_s N makes the repo's
# dimensionless eGPE literally the paper's Eq. (S3), but then the droplet is
# ~0.08 a_ho across and dt must be ~1e-7. Instead we set a_ho = L0/S with S
# chosen so the variational sigma_r lands at `sigma_target` a_ho. Conversions:
#     n/D0        = |psi|^2 * S^3
#     E [hbar^2/(M L0^2)] = E [hbar*omega_ref] * S^2
#     t [T0]      = t [1/omega_ref] / S^2
#     B_tilde     = -b_y [hbar*omega_ref] * S^2      (our H = -b.F, paper's +gmu_B B.S)
# The seed is the paper's own variational torus (Eq. S5) times exp(i l phi), with
# the flux-closure texture exp(-i S_z phi) zeta^(y).
#
# Usage:
#   julia --project=. runs/yls_barnett_f6/b_egpe_cells.jl <cell> [key=value ...]
#   cells: P0 P1 B0 B1 B1q A1 ... (see CELLS below); `smoke=true` shrinks everything.

using SpinorBEC
using Printf
using JLD2
using LinearAlgebra
using FFTW

include(joinpath(@__DIR__, "a2_variational_stability.jl"))

const a0 = SpinorBEC.Units.BOHR_RADIUS
const hbar = SpinorBEC.Units.HBAR

# --------------------------------------------------------------------------
# cell definitions
# --------------------------------------------------------------------------
# `seed_N` lets an unbound cell borrow the seed size from a bound configuration,
# so that "it expanded" is a result about the physics and not about a seed that
# was never a droplet in the first place.
const CELLS = Dict(
# name        atom                        eps_dd    N      l  q_phys  seed_N
    "P0" => (; atom=:Eu151_f1_effective, eps_dd=1.2, N=15000, l=0, q_phys=false, seed_N=15000),
    "P1" => (; atom=:Eu151_f1_effective, eps_dd=1.2, N=15000, l=1, q_phys=false, seed_N=15000),
    "P1m" => (; atom=:Eu151_f1_effective, eps_dd=1.2, N=15000, l=-1, q_phys=false, seed_N=15000),
    "B0" => (; atom=:Eu151, eps_dd=1.2, N=15000, l=0, q_phys=false, seed_N=40000),
    "B1" => (; atom=:Eu151, eps_dd=1.2, N=15000, l=1, q_phys=false, seed_N=40000),
    "C0" => (; atom=:Eu151, eps_dd=1.2, N=40000, l=0, q_phys=false, seed_N=40000),
    "C1" => (; atom=:Eu151, eps_dd=1.2, N=40000, l=1, q_phys=false, seed_N=40000),
    "C1m" => (; atom=:Eu151, eps_dd=1.2, N=40000, l=-1, q_phys=false, seed_N=40000),
    "C1q" => (; atom=:Eu151, eps_dd=1.2, N=40000, l=1, q_phys=true, seed_N=40000),
    "A1" => (; atom=:Eu151, eps_dd=0.5402, N=15000, l=1, q_phys=false, seed_N=40000),
    "A1big" => (; atom=:Eu151, eps_dd=0.5402, N=1000000, l=1, q_phys=false, seed_N=40000),
)

# --------------------------------------------------------------------------
# setup
# --------------------------------------------------------------------------

"""
Everything a cell needs: tuned atom, unit scale S, dimensionless couplings,
grid and the seed wave function.
"""
function build_cell(cell; n=96, box_sigma=1.5, sigma_target=1.5, seed_scale=1.0)
    base = SpinorBEC.ATOM_REGISTRY[cell.atom]
    F = base.F
    a_dd = SpinorBEC.compute_a_dd(base)
    a_s = a_dd / cell.eps_dd
    atom = AtomSpecies(base.name, base.mass, F, a_s, 0.0, base.mu_mag, base.g_F)

    # Seed geometry from the paper's variational solution. For a cell whose own
    # eps_dd admits NO bound state at any N (the physical-Eu cell, eps_dd = 0.54:
    # N_c = Inf by the theorem), borrow the droplet geometry from eps_dd = 1.2 at
    # the same F and l, so that "it expanded" is a statement about the physics and
    # not about a seed that was never droplet-shaped. `v_native.bound == false` is
    # recorded on the returned object.
    v_native = droplet(; eps_dd=cell.eps_dd, N=cell.seed_N, F=F, l=abs(cell.l))
    v = if v_native.bound
        v_native
    else
        vb = droplet(; eps_dd=1.2, N=cell.seed_N, F=F, l=abs(cell.l))
        vb.bound || error("no bound seed geometry available even at eps_dd=1.2 " *
                         "for F=$F l=$(cell.l) N=$(cell.seed_N) (N_c = $(vb.N_c))")
        @info "cell has N_c = $(v_native.N_c) at its own eps_dd=$(cell.eps_dd); " *
              "seeding with the eps_dd=1.2 droplet geometry"
        merge(vb, (; N_c=v_native.N_c, bound=false))
    end
    S = sigma_target / v.sigma_r                    # a_ho = L0 / S
    L0 = a_s * cell.N
    a_ho = L0 / S
    omega_ref = hbar / (atom.mass * a_ho^2)

    c0 = 4π * (a_s / a_ho) * cell.N
    c_dd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=cell.N, omega_ref=omega_ref)
    c_lhy = SpinorBEC.scalar_lhy_coefficient(a_s / a_ho, cell.N; eps_dd=cell.eps_dd)

    box = box_sigma * 2 * (v.r_torus + 2 * v.sigma_r) * S    # cover torus + tails
    grid = make_grid(GridConfig{3}((n, n, n), (box, box, box)))
    psi0 = seed_psi(grid, F, cell.l;
        lam=v.lambda, sr=v.sigma_r * S * seed_scale, sz=v.sigma_z * S * seed_scale)

    (; cell, atom, F, a_s, S, L0, a_ho, omega_ref, c0, c_dd, c_lhy, grid, psi0, v, box, n)
end

"Paper's variational torus (Eq. S5) with flux-closure texture, times exp(i l phi)."
function seed_psi(grid::Grid{3}, F::Int, l::Int; lam, sr, sz)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    sm = spin_matrices(F)
    c_base = exp(-1im * (π / 2) * Matrix(sm.Fy))[:, 1]   # |m_y = +F>
    @inbounds for I in CartesianIndices(n_pts)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        r2 = x^2 + y^2
        amp = sqrt(r2^lam * exp(-r2 / sr^2 - z^2 / sz^2))
        phi = atan(y, x)
        for c in 1:D
            m = F - (c - 1)
            psi[I, c] = amp * c_base[c] * cis(-m * (phi + π / 2) + l * phi)
        end
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

# --------------------------------------------------------------------------
# observables --- read the same way for every cell
# --------------------------------------------------------------------------

"Phase winding of component c on a circle of radius `r` in the z=0 plane."
function component_winding(psi, grid::Grid{3}, c::Int; r::Float64, n_theta::Int=256)
    n_pts = grid.config.n_points
    iz = argmin(abs.(grid.x[3]))
    tot = 0.0
    prev = NaN
    amp_min = Inf
    for j in 0:n_theta
        th = 2π * j / n_theta
        x, y = r * cos(th), r * sin(th)
        ix = argmin(abs.(grid.x[1] .- x))
        iy = argmin(abs.(grid.x[2] .- y))
        z = psi[ix, iy, iz, c]
        amp_min = min(amp_min, abs(z))
        ph = angle(z)
        if !isnan(prev)
            d = ph - prev
            d > π && (d -= 2π)
            d < -π && (d += 2π)
            tot += d
        end
        prev = ph
    end
    (; winding=tot / 2π, amp_min)
end

function measure(b, psi)
    grid, F = b.grid, b.F
    sys = SpinSystem(F)
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
    # second moments and the torus radius (density-weighted)
    x2 = y2 = z2 = r_w = 0.0
    @inbounds for I in CartesianIndices(rho)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        w = rho[I] * dV
        x2 += w * x^2
        y2 += w * y^2
        z2 += w * z^2
        r_w += w * sqrt(x^2 + y^2)
    end
    # edge fraction: density in the outermost shell of voxels, the box-adequacy gate
    edge = 0.0
    np = grid.config.n_points
    @inbounds for I in CartesianIndices(rho)
        if I[1] == 1 || I[2] == 1 || I[3] == 1 || I[1] == np[1] || I[2] == np[2] ||
           I[3] == np[3]
            edge += rho[I] * dV
        end
    end
    pops = [sum(abs2, view(psi_h, :, :, :, c)) * dV for c in 1:D]
    wind = [component_winding(psi_h, grid, c; r=r_w) for c in 1:D]

    (; L, f, Jz=L[3] + f[3],
        rho_max_D0=rho_max * b.S^3,
        r_torus_L0=r_w / b.S, sigma_x_L0=sqrt(x2) / b.S, sigma_z_L0=sqrt(z2) / b.S,
        shape=sqrt(x2 / z2), x2, y2, z2, edge_fraction=edge,
        pops, windings=[w.winding for w in wind],
        polarization=sum(sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)) * dV / (F * sum(rho) * dV))
end

function report(tag, b, psi; itp=nothing)
    m = measure(b, psi)
    F = b.F
    println("-"^78)
    @printf("%s  (atom=%s F=%d eps_dd=%.4f N=%d l=%d)\n", tag,
        b.atom.name, F, b.cell.eps_dd, b.cell.N, b.cell.l)
    itp === nothing || @printf("  ITP: converged=%s  dpsi=%.3e  E=%.6f (internal)\n",
        itp.converged, itp.dpsi, itp.energy)
    @printf("  rho_max          = %10.1f D0\n", m.rho_max_D0)
    @printf("  <L>              = (%+.5f, %+.5f, %+.5f)\n", m.L...)
    @printf("  <f>              = (%+.5f, %+.5f, %+.5f)\n", m.f...)
    @printf("  J_z = L_z + f_z  = %+.6f      (must equal l = %d)\n", m.Jz, b.cell.l)
    @printf("  torus radius     = %.5f L0    sigma_x = %.5f L0   sigma_z = %.5f L0\n",
        m.r_torus_L0, m.sigma_x_L0, m.sigma_z_L0)
    @printf("  shape sqrt(<x2>/<z2>) = %.4f\n", m.shape)
    @printf("  |f|/(F rho)      = %.4f   (paper: ~1, fully polarized)\n", m.polarization)
    @printf("  edge density frac= %.3e  (box adequacy)\n", m.edge_fraction)
    print("  populations n_m  :")
    for (c, p) in enumerate(m.pops)
        @printf(" m=%+d:%.4f", F - (c - 1), p)
    end
    println()
    print("  windings v_m     :")
    for (c, w) in enumerate(m.windings)
        @printf(" m=%+d:%+.2f", F - (c - 1), w)
    end
    println()
    print("  m + v_m          :")
    for (c, w) in enumerate(m.windings)
        @printf(" %+.2f", (F - (c - 1)) + w)
    end
    println("      (paper: all equal l)")
    m
end

# --------------------------------------------------------------------------
# ITP
# --------------------------------------------------------------------------

# `method`: :lbfgs is the DEFAULT here, deliberately. Measured 2026-08-18
# (a7_itp_drift_from_stationary.jl): in this free-space droplet regime the
# imaginary-time fixed point is DISPLACED BY THE TIME STEP -- started at the
# L-BFGS stationary point (grad_norm 1e-7), ITP drifts away with |dE|/t = 177 /
# 128 / 16.8 / 0.53 at dt = 4e-3 / 2e-3 / 5e-4 / 1.25e-4, i.e. an O(dt^~2.5)
# splitting artifact that only vanishes as dt -> 0. At dt = 2e-3 it settles 26 %
# high in energy and 44 % low in peak density WHILE REPORTING dpsi = 3e-6, so the
# convergence flag is no guard at all. The cause is the stiffness of the droplet:
# contact +31340 against DDI -37608 for a net -6268, so the splitting error is
# large compared with the binding energy being resolved. In a harmonic trap the
# same terms agree with L-BFGS to ~1e-6 (a6_which_term_disagrees.jl) -- it is the
# free-space cancellation that exposes it.
function run_itp(b; dt=2e-4, n_steps=20000, tol=1e-11, backend=CUDABackend(), verbose=false,
    save_every=max(1, n_steps ÷ 20), method::Symbol=:lbfgs)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    method === :lbfgs && return find_ground_state(;
        grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        psi_init=b.psi0, enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        method=:lbfgs, n_steps=max(n_steps, 3000), tol=max(tol, 1e-10),
        backend=backend, verbose=verbose)
    find_ground_state(;
        grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0),
        potential=NoPotential(),
        psi_init=b.psi0,
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        dt=dt, n_steps=n_steps, tol=tol,
        save_every=save_every,
        backend=backend, verbose=verbose,
    )
end

function main(args)
    name = isempty(args) ? "P0" : args[1]
    opts = Dict{String, String}()
    for a in args[2:end]
        k, v = split(a, "="; limit=2)
        opts[k] = v
    end
    getopt(k, d) = haskey(opts, k) ? parse(typeof(d), opts[k]) : d
    smoke = getopt("smoke", false)

    cell = CELLS[name]
    n = getopt("n", smoke ? 32 : 96)
    dt = getopt("dt", 2e-4)
    n_steps = getopt("n_steps", smoke ? 300 : 20000)
    sigma_target = getopt("sigma_target", 1.5)
    box_sigma = getopt("box_sigma", 1.5)
    seed_scale = getopt("seed_scale", 1.0)
    gpu = getopt("gpu", true)
    verbose = getopt("verbose", false)
    save_every = getopt("save_every", 0)

    b = build_cell(cell; n=n, box_sigma=box_sigma, sigma_target=sigma_target,
        seed_scale=seed_scale)
    println("="^78)
    @printf("CELL %s : atom=%s F=%d eps_dd=%.4f N=%d l=%d q_phys=%s\n",
        name, b.atom.name, b.F, cell.eps_dd, cell.N, cell.l, cell.q_phys)
    println("="^78)
    @printf("  a_s = %.3f a0   L0 = %.3f um   a_ho = L0/%.2f = %.4f um\n",
        b.a_s / a0, b.L0 * 1e6, b.S, b.a_ho * 1e6)
    @printf("  omega_ref = %.4f rad/s   T0 = 1/(omega_ref) * S^2 = %.4f s\n",
        b.omega_ref, b.S^2 / b.omega_ref)
    @printf("  c0 = %.2f   c_dd = %.4f   c_lhy = %.2f   (c_dd F^2 / (3 c0) = %.5f = eps_dd?)\n",
        b.c0, b.c_dd, b.c_lhy, b.c_dd * b.F^2 / (3 * b.c0))
    @printf("  variational seed: lambda=%.3f sigma_r=%.5f L0 sigma_z=%.5f L0 r_torus=%.5f L0\n",
        b.v.lambda, b.v.sigma_r, b.v.sigma_z, b.v.r_torus)
    @printf("  N_c(this cell)  = %.4g   N/N_c = %.3f\n", b.v.N_c, cell.N / b.v.N_c)
    @printf("  grid %d^3, box %.4f a_ho = %.5f L0, dx = %.4g a_ho = %.3g L0\n",
        n, b.box, b.box / b.S, b.box / n, b.box / n / b.S)
    @printf("  dt = %.3g (internal) = %.3g T0 ; n_steps = %d\n", dt, dt / b.S^2, n_steps)
    println()

    report("SEED", b, b.psi0)
    println()
    flush(stdout)
    t0 = time()
    r = run_itp(b; dt=dt, n_steps=n_steps, verbose=verbose,
        save_every=(save_every > 0 ? save_every : max(1, n_steps ÷ 20)),
        backend=(gpu ? CUDABackend() : CPUBackend()))
    @printf("\n  ITP wall time: %.1f s\n\n", time() - t0)
    m = report("AFTER ITP", b, r.workspace.state.psi; itp=r)

    e = energy_decomposition(r.workspace)
    println("  energy decomposition (internal units, per particle):")
    for k in propertynames(e)
        v = getproperty(e, k)
        v isa Number && abs(v) > 0 && @printf("    %-14s %+14.6f  (%+14.3f in hbar^2/M L0^2)\n",
            String(k), v, v * b.S^2)
    end
    lhy_frac = abs(getproperty(e, :lhy)) / abs(e.total)
    @printf("  |E_LHY| / |E_total| = %.3f\n", lhy_frac)

    out = joinpath(@__DIR__, "out")
    mkpath(out)
    tag = "$(name)_n$(n)_$(smoke ? "smoke" : "prod")"
    jldsave(joinpath(out, "itp_$(tag).jld2");
        psi=Array(r.workspace.state.psi),
        cell=Dict(pairs(cell)), n=n, dt=dt, n_steps=n_steps,
        S=b.S, L0=b.L0, a_ho=b.a_ho, omega_ref=b.omega_ref, box=b.box,
        c0=b.c0, c_dd=b.c_dd, c_lhy=b.c_lhy,
        converged=r.converged, dpsi=r.dpsi, energy=r.energy,
        measured=Dict(pairs(m)), git_hash=strip(read(`git rev-parse HEAD`, String)))
    println("\n  saved: ", joinpath(out, "itp_$(tag).jld2"))
    (b, r, m)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)

# Type-C measurement of a converged saito_li_torus cell against Saito & Li
# Fig. 1(b)/1(d)/2(a). Issue #336.
#
# Usage: julia --project=. runs/saito_li_torus/g6_measure.jl <run_dir> [<run_dir> ...]
#
# Reports, per cell:
#   * the producing commit and the resolved coefficients READ BACK FROM THE
#     RESULT FILE (not from the YAML — the point file records what ran);
#   * the azimuthally-averaged rho(r, z=0) profile in the paper's own units
#     (rho/N in um^-3 vs r in um), written to CSV next to the run;
#   * peak density, torus radius, FWHM, rho(0) against the digitised anchors;
#   * the LHY share of the total energy, which the campaign guard disqualifies
#     above 15 % — a droplet can legitimately exceed that, so it is quoted
#     rather than silently passed;
#   * the per-component phase winding, measured per component and not globally,
#     with the detector's own convergence flag;
#   * |f|/rho, the fully-polarised assumption Eq. (1) rests on;
#   * the J_z ledger.

using SpinorBEC
using JLD2
using Printf
using LinearAlgebra

const A_HO_UM = 0.7802927  # recomputed below from the stored units; this is a fallback
const UM = 1e-6

# Digitised Fig. 2(a), F=6 N=15000 eps_dd=1.3 (g3_digitise_fig2a.py).
const PAPER = (peak_rho_over_N=0.509, r_peak_um=0.815,
    fwhm_lo_um=0.528, fwhm_hi_um=1.109, rho0_over_N=0.011)

"""Azimuthal average of the density in the midplane perpendicular to `axis`,
as a function of distance from that axis. A fixed z=0 slice instead misreads any
droplet whose symmetry axis is not z — and at B=0 the orientation is a free
parameter of a degenerate family."""
function radial_profile_about(dens, grid, com, axis; nbins=200)
    X = (grid.x[1], grid.x[2], grid.x[3])
    rmax = minimum(maximum(abs, X[d]) for d in 1:3)
    edges = range(0, rmax; length=nbins + 1)
    sums = zeros(nbins)
    cnts = zeros(Int, nbins)
    half = maximum(grid.dx)          # one-cell-thick midplane slab
    for I in CartesianIndices(dens)
        r = (X[1][I[1]] - com[1], X[2][I[2]] - com[2], X[3][I[3]] - com[3])
        along = r[1] * axis[1] + r[2] * axis[2] + r[3] * axis[3]
        abs(along) <= half || continue
        rp = sqrt(max(0.0, r[1]^2 + r[2]^2 + r[3]^2 - along^2))
        b = searchsortedlast(edges, rp)
        (b < 1 || b > nbins) && continue
        sums[b] += dens[I]
        cnts[b] += 1
    end
    centers = [(edges[b] + edges[b + 1]) / 2 for b in 1:nbins]
    vals = [cnts[b] > 0 ? sums[b] / cnts[b] : NaN for b in 1:nbins]
    (centers, vals)
end

function analyse(dir)
    pf = joinpath(dir, "point_001.jld2")
    isfile(pf) || (println("!! no point_001.jld2 in $dir"); return nothing)
    f = jldopen(pf, "r")
    psi = f["psi"]
    n_pts = f["grid_n_points"]
    box = f["grid_box_size"]
    E = f["energy"]
    c0 = f["interactions_c0"]
    c1 = f["interactions_c1"]
    c_lhy = f["interactions_c_lhy"]
    lhy_kind = f["lhy_kind"]
    code_rev = f["code_rev"]
    conv = f["converged"]
    close(f)

    atom = SpinorBEC.ATOM_REGISTRY[:Eu151]
    N_atoms = 15000
    omega_ref = 691.15
    a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
    a_ho_um = a_ho / UM
    F = atom.F
    D = size(psi, 4)
    c_dd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N_atoms, omega_ref=omega_ref)
    eps_dd = c_dd * F^2 / (3 * (c0 + F^2 * c1))

    grid = SpinorBEC.make_grid(
        SpinorBEC.GridConfig(Tuple(Int.(n_pts)), Tuple(Float64.(box))))
    dV = SpinorBEC.cell_volume(grid)
    kz = argmin(abs.(grid.x[3]))

    println("="^74)
    println(dir)
    println("="^74)
    @printf("  commit %s   grid %s box %s   converged=%s\n",
        first(code_rev, 12), n_pts, box, conv)
    @printf("  c0=%.4f c1=%.4f c_dd=%.4f c_lhy=%.4f lhy=%s  => eps_dd=%.4f\n",
        c0, c1, c_dd, c_lhy, lhy_kind, eps_dd)

    norm = sum(abs2, psi) * dV
    @printf("  norm  int|psi|^2 dV = %.8f   (must be 1)\n", norm)
    @printf("  E/N (internal) = %.7f\n", E)

    # ---- energy decomposition. Rebuilt rather than read back, because the
    #      point file stores only the total. `ddi_padding=true` /
    #      `ddi_trunc_radius=-1.0` are the YAML surface's defaults
    #      (DDI_PADDED_DEFAULT, DDI_TRUNC_RADIUS_DEFAULT); make_workspace's own
    #      defaults are OFF, so omitting them here would silently measure a
    #      DIFFERENT Hamiltonian from the one that produced psi.
    ip = SpinorBEC.InteractionParams(Dict(0 => c0, 1 => c1); c_lhy=c_lhy)
    ws = SpinorBEC.make_workspace(;
        grid, atom, interactions=ip,
        zeeman=SpinorBEC.ZeemanParams(), potential=SpinorBEC.NoPotential(),
        sim_params=SpinorBEC.SimParams(; dt=1.0e-3, n_steps=1, save_every=1),
        psi_init=psi, enable_ddi=true, c_dd=c_dd,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=:scalar)
    ed = SpinorBEC.energy_decomposition(ws)
    @printf("  E rebuilt      = %.7f   (point file %.7f, dev %.2e)\n",
        ed.total, E, abs(ed.total - E))
    println("  -- energy decomposition (per particle, internal units) --")
    for k in propertynames(ed)
        k === :total && continue
        v = getproperty(ed, k)
        v isa Number || continue
        abs(v) < 1e-12 && continue
        @printf("     %-14s %+12.6f   %6.2f %% of |total|\n",
            String(k), v, 100 * abs(v) / abs(ed.total))
    end
    edd = Dict(pairs(ed))
    terms = [abs(v) for (k, v) in edd if k !== :total && v isa Number]
    gross = sum(terms)
    E_lhy = get(edd, :lhy, 0.0)
    E_s = get(edd, :density, 0.0)
    E_ddi = get(edd, :ddi, 0.0)
    # Quoting LHY against |E_total| is what the 15 % campaign guard does, and in
    # a droplet the total is a small residue of large cancelling terms, so that
    # ratio exceeds 100 % without meaning anything is wrong. Quote BOTH.
    @printf("  LHY share: %.1f %% of |E_total|, %.1f %% of sum|E_term|\n",
        100 * abs(E_lhy) / abs(ed.total), 100 * abs(E_lhy) / gross)
    R = abs(ed.total) / gross
    @printf("  cancellation ratio R = |E_total|/sum|E_term| = %.4f  %s\n", R,
        R < 0.05 ? "(< 0.05: the ITP dt-limited regime — this is why method=lbfgs)" : "")
    # Flux closure: for a divergence-free fully polarised magnetisation the DDI
    # energy is EXACTLY -eps_dd times the contact energy. Sharpest available
    # gate on the DDI prefactor and the eps_dd bookkeeping together.
    if E_s != 0
        @printf("  flux-closure identity: E_ddi/E_s = %.4f vs -eps_dd = %.4f  (dev %.2f %%)\n",
            E_ddi / E_s, -eps_dd, 100 * abs(E_ddi / E_s / (-eps_dd) - 1))
    end

    # ---- orientation. At B=0 with c1=0 the Hamiltonian is invariant under
    #      SIMULTANEOUS space+spin rotation (the DDI locks the two together but
    #      leaves the diagonal SO(3) free), so a converged droplet may sit in any
    #      orientation of that degenerate family. The SORTED eigenvalues of the
    #      second-moment tensor are rotation-invariant and so identify the object;
    #      the axis itself does not. Measure both before profiling, or a rotated
    #      copy reads as a different state.
    dens = zeros(Float64, size(psi)[1:3])
    for c in 1:D
        dens .+= abs2.(@view psi[:, :, :, c])
    end
    X = (grid.x[1], grid.x[2], grid.x[3])
    com = zeros(3)
    for a in 1:3, I in CartesianIndices(dens)
        com[a] += dens[I] * X[a][I[a]]
    end
    com .*= dV
    M = zeros(3, 3)
    for I in CartesianIndices(dens)
        r = (X[1][I[1]] - com[1], X[2][I[2]] - com[2], X[3][I[3]] - com[3])
        w = dens[I]
        for a in 1:3, b in 1:3
            M[a, b] += w * r[a] * r[b]
        end
    end
    M .*= dV
    ev = eigen(Symmetric(M))
    lam = sort(ev.values)
    # a torus is THIN along its symmetry axis -> smallest second moment
    axis = ev.vectors[:, argmin(ev.values)]
    axis[argmax(abs.(axis))] < 0 && (axis = -axis)
    @printf("  second moments (sorted, rotation-invariant) = [%.5f, %.5f, %.5f]\n",
        lam[1], lam[2], lam[3])
    @printf("  symmetry axis = (%+.3f, %+.3f, %+.3f)   |axis.z| = %.4f  -> %s\n",
        axis[1], axis[2], axis[3], abs(axis[3]),
        abs(axis[3]) > 0.99 ? "along z" : "TILTED off z (degenerate partner)")
    @printf("  centre of mass = (%+.4f, %+.4f, %+.4f)\n", com[1], com[2], com[3])

    # ---- density profile in the paper's units, taken about the MEASURED axis
    centers, vals = radial_profile_about(dens, grid, com, axis)
    r_um = centers .* a_ho_um
    rho_over_N = vals ./ a_ho_um^3          # rho/N [um^-3] = n / a_ho^3[um^3]
    ok = .!isnan.(rho_over_N)
    ipk = argmax(replace(rho_over_N, NaN => -Inf))
    pk = rho_over_N[ipk]
    rpk = r_um[ipk]
    half = pk / 2
    lo = findlast(i -> i < ipk && rho_over_N[i] < half, eachindex(rho_over_N))
    hi = findfirst(i -> i > ipk && rho_over_N[i] < half, eachindex(rho_over_N))
    rho0 = rho_over_N[findfirst(ok)]

    println()
    println("  -- Fig 2(a) comparison (rho/N in um^-3, r in um) --")
    @printf("  %-22s %10s %10s %8s\n", "", "ours", "paper", "dev")
    @printf("  %-22s %10.3f %10.3f %7.1f%%\n", "peak rho/N",
        pk, PAPER.peak_rho_over_N, 100 * (pk / PAPER.peak_rho_over_N - 1))
    @printf("  %-22s %10.3f %10.3f %7.1f%%\n", "torus radius r_peak",
        rpk, PAPER.r_peak_um, 100 * (rpk / PAPER.r_peak_um - 1))
    if lo !== nothing && hi !== nothing
        @printf("  %-22s %10.3f %10.3f %7.1f%%\n", "FWHM lo",
            r_um[lo], PAPER.fwhm_lo_um, 100 * (r_um[lo] / PAPER.fwhm_lo_um - 1))
        @printf("  %-22s %10.3f %10.3f %7.1f%%\n", "FWHM hi",
            r_um[hi], PAPER.fwhm_hi_um, 100 * (r_um[hi] / PAPER.fwhm_hi_um - 1))
    end
    @printf("  %-22s %10.3f %10.3f\n", "rho(r=0)/N", rho0, PAPER.rho0_over_N)

    csv = joinpath(dir, "radial_profile.csv")
    open(csv, "w") do io
        println(io, "r_um,rho_over_N_um^-3")
        for i in eachindex(r_um)
            isnan(rho_over_N[i]) && continue
            @printf(io, "%.6f,%.8f\n", r_um[i], rho_over_N[i])
        end
    end
    println("  profile -> ", csv)

    # ---- density at the box edge: is the droplet actually self-bound inside?
    edge = maximum(
        x -> x,
        [
            rho_over_N[i] for i in eachindex(r_um)
            if r_um[i] > 0.9 * maximum(r_um) && !isnan(rho_over_N[i])
        ],
    )
    @printf("  density at box edge / peak = %.2e  (self-bound needs << 1)\n", edge / pk)

    # ---- polarisation |f|/rho
    sm = SpinorBEC.spin_matrices(F)
    Fx, Fy, Fz = Matrix(sm.Fx), Matrix(sm.Fy), Matrix(sm.Fz)
    ipk_i = 0;
    ipk_j = 0;
    best = -1.0
    for j in axes(psi, 2), i in axes(psi, 1)
        n = sum(c -> abs2(psi[i, j, kz, c]), 1:D)
        if n > best
            best = n;
            ipk_i = i;
            ipk_j = j
        end
    end
    sp = ComplexF64[psi[ipk_i, ipk_j, kz, c] for c in 1:D]
    nloc = sum(abs2, sp)
    fx = real(sp' * Fx * sp);
    fy = real(sp' * Fy * sp);
    fz = real(sp' * Fz * sp)
    @printf("  |f|/rho at the density peak = %.4f  (F = %d; Eq.(1) assumes ~F)\n",
        sqrt(fx^2 + fy^2 + fz^2) / nloc, F)
    @printf("     f = (%.3f, %.3f, %.3f)/rho  -> in-plane fraction %.4f\n",
        fx / nloc, fy / nloc, fz / nloc,
        sqrt(fx^2 + fy^2) / sqrt(fx^2 + fy^2 + fz^2))

    # ---- per-component winding, at the torus radius
    println()
    println("  -- per-component phase winding at r = r_peak (expect v_m = -m) --")
    r_int = rpk / a_ho_um
    print("     m :")
    for c in 1:D
        @printf(" %4d", F - (c - 1))
    end
    println()
    print("   v_m :")
    bad = 0
    for c in 1:D
        w = SpinorBEC.component_phase_winding(psi, grid, c; radius=r_int)
        if w.converged
            @printf(" %4d", w.winding)
            w.winding == -(F - (c - 1)) || (bad += 1)
        else
            print("    ?")
            bad += 1
        end
    end
    println()
    println(
        if bad == 0
            "     all components match v_m = -m"
        elseif abs(axis[3]) <= 0.99
            "     $bad component(s) differ — EXPECTED: v_m = -m is a statement in " *
            "the basis\n     quantised along the TORUS AXIS, and this cell's axis " *
            "is tilted off z.\n     Not a disagreement with the paper."
        else
            "     $bad component(s) disagree or unresolved"
        end,
    )

    # ---- J_z ledger. L_z = -i(x d_y - y d_x) is ill-defined in a periodic box;
    #      it is quoted here only because the box-edge density above shows the
    #      droplet is entirely interior, which is the condition that makes it
    #      meaningful. If that ratio is not tiny, ignore L_z.
    sys = SpinorBEC.SpinSystem(F)
    plans = SpinorBEC.make_fft_plans(Tuple(Int.(n_pts)))
    Lz = SpinorBEC.orbital_angular_momentum(psi, grid, plans)
    Sz = SpinorBEC.magnetization(psi, grid, sys)
    @printf("\n  J_z ledger:  L_z = %+.6f   F_z = %+.6f   J_z = %+.6f\n",
        Lz, Sz, Lz + Sz)
    (; dir, pk, rpk, E, n_pts)
end

results = [analyse(d) for d in ARGS]

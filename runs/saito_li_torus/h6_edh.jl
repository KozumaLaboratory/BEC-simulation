# Einstein-de Haas rotation of the torus droplet --- the paper's Fig. 4, at F=6.
#
# Protocol, verbatim from Li & Saito:
#   "the initial droplet state is prepared for zero magnetic field with the
#    symmetry axis in the y direction, and the magnetic field B_z is turned on
#    at t = 0 ... the droplet begins to rotate around the z axis, where the
#    total angular momentum F_z + L_z is maintained to be zero."
#
# So: converge the B=0 torus with its axis along y, then QUENCH B_z on (no ramp)
# and propagate in real time.
#
# WHY J_z IS CONSERVED HERE. With B along z the Hamiltonian is invariant under
# rotations about z, so J_z = L_z + f_z is a constant of the motion. It is NOT
# conserved for a field off the z axis. The ledger is therefore a gate on the
# integrator, not a physics result --- it is reported as such.
#
# FIELD. The paper uses B_z = 0.05 and 0.1 mG on an F=1 torus whose stability
# limit is 0.17 mG. The F=6 torus here dies between 50 and 70 uG (section 3.8 of
# README.md), so the same fraction of the limit is 15 and 30 uG. Using the
# paper's 0.1 mG would simply destroy the object.
#
# BOX. The symmetry axis starts along y and rotates INTO the xy-plane, while the
# torus plane always contains z. The droplet therefore needs the full radial
# extent (2.54 a_ho) along all three axes: a cube, not the oblate box the
# z-axis ground state runs in.
#
# Usage:
#   julia --project=. -e 'import CUDA' \
#     -e 'include("runs/saito_li_torus/h6_edh.jl"); main(["Bz=0.015"])'
#   keys: Bz=<mG> n= box= dt= t_end= save_every= smoke=true backend=cpu

using SpinorBEC
using SpinorBEC: SimulationCallbacks, run_simulation!, SimParams, NoPotential
using Printf
using LinearAlgebra
using FFTW
using JLD2

include(joinpath(@__DIR__, "h3_cells.jl"))

"Sorted eigenvalues of <r_a r_b> plus the symmetry axis (smallest moment, oblate)."
function moment_axis(psi, grid::Grid{3})
    psi_h = psi isa Array ? psi : Array(psi)
    rho = total_density(psi_h, 3)
    dV = cell_volume(grid)
    T = zeros(3, 3)
    tot = 0.0
    @inbounds for I in CartesianIndices(rho)
        r = (grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]])
        w = rho[I] * dV
        tot += w
        for a in 1:3, b in a:3
            T[a, b] += w * r[a] * r[b]
        end
    end
    for a in 1:3, b in 1:(a - 1)
        T[a, b] = T[b, a]
    end
    T ./= tot
    ev = eigen(Symmetric(T))
    (; eig=ev.values, axis=ev.vectors[:, 1])
end

"""
Ground state of the torus with its symmetry axis along `axis`, at B = 0.

At B = 0 the Hamiltonian is rotationally invariant, so this must land on the
same energy as the z-axis ground state. That equality is checked, and it is the
gate on the generalized seed: a seed that built the wrong texture for axis != z
would converge somewhere else.
"""
function ground_state_axis(; axis=2, n=(64, 64, 64), box=(6.5, 6.5, 6.5),
    backend=CUDABackend(), iters=4000)
    cell = (; seed=:torus, N=15000, eps_dd=1.3, Bz_mG=0.0)
    b = build_cell(cell; n=n, box=box)
    psi0 = seed_torus(b.grid, b.F; lam=b.lam, sr=b.sr, sz=b.sz, axis=axis)
    b = merge(b, (; psi0=psi0))
    psi, ws, gs = solve_cell(b; backend=backend, iters=iters)
    (b, psi, ws, gs)
end

function main(args::Vector{String}=String[])
    opts = Dict{String, String}()
    for a in args
        occursin('=', a) || continue
        k, v = split(a, '='; limit=2)
        opts[k] = v
    end
    smoke = get(opts, "smoke", "false") == "true"
    nn = parse(Int, get(opts, "n", smoke ? "32" : "64"))
    bx = parse(Float64, get(opts, "box", "6.5"))
    Bz_mG = parse(Float64, get(opts, "Bz", "0.015"))
    dt = parse(Float64, get(opts, "dt", "5.0e-4"))
    t_end = parse(Float64, get(opts, "t_end", smoke ? "0.2" : "10.0"))
    be = get(opts, "backend", "gpu") == "cpu" ? CPUBackend() : CUDABackend()
    n_steps = ceil(Int, t_end / dt)
    save_every = parse(Int, get(opts, "save_every", string(max(1, n_steps ÷ 200))))
    outdir = joinpath(@__DIR__, "out")
    mkpath(outdir)

    @printf("\n### EdH quench: Bz = %.4f mG, cube box %.2f a_ho, n=%d, dt=%.1e, t_end=%.2f\n",
        Bz_mG, bx, nn, dt, t_end)

    # ---- 1. B = 0 ground state with the axis along y ---------------------
    b, psi0, ws0, gs0 = ground_state_axis(; axis=2, n=(nn, nn, nn),
        box=(bx, bx, bx), backend=be, iters=(smoke ? 40 : 4000))
    m0 = moment_axis(psi0, b.grid)
    e0 = energy_decomposition(ws0)
    @printf("  GS(axis=y): E/N = %.8f   grad_norm = %.3e\n", e0.total,
        get(gs0, :grad_norm, NaN))
    @printf("     moment eigenvalues = [%.5f, %.5f, %.5f]  axis = (%+.4f, %+.4f, %+.4f)\n",
        m0.eig..., m0.axis...)
    @printf("     (the z-axis ground state in its own box gives E/N = -1.575563;\n")
    @printf("      B=0 is rotationally invariant, so these must agree)\n")

    # ---- 2. quench B_z on and propagate ----------------------------------
    p = SpinorBEC.Units.bfield_to_p_gauss(Bz_mG * 1e-3, b.atom.g_F, OMEGA_REF)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    pot = HarmonicTrap(TRAP_OMEGA, TRAP_OMEGA, TRAP_OMEGA)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(p, 0.0), potential=pot,
        sim_params=SimParams(; dt=dt, n_steps=n_steps, save_every=save_every,
            imaginary_time=false),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        psi_init=Array(psi0), backend=be)

    plans = make_fft_plans(b.grid.config.n_points; flags=FFTW.ESTIMATE)
    sm = spin_matrices(b.F)
    dV = cell_volume(b.grid)
    rec = (t=Float64[], Lx=Float64[], Ly=Float64[], Lz=Float64[],
        fx=Float64[], fy=Float64[], fz=Float64[], phi=Float64[],
        e1=Float64[], e2=Float64[], e3=Float64[], norm=Float64[],
        rho_max=Float64[], edge=Float64[])
    np = b.grid.config.n_points
    function sample!(w)
        psi_h = Array(w.state.psi)
        L = orbital_angular_momentum_vector(psi_h, b.grid, plans)
        fx, fy, fz = spin_density_vector(psi_h, sm, 3)
        ma = moment_axis(psi_h, b.grid)
        rho = total_density(psi_h, 3)
        edge = 0.0
        @inbounds for I in CartesianIndices(rho)
            if I[1] == 1 || I[2] == 1 || I[3] == 1 ||
                I[1] == np[1] || I[2] == np[2] || I[3] == np[3]
                edge += rho[I] * dV
            end
        end
        push!(rec.t, w.state.t)
        push!(rec.Lx, L[1]);
        push!(rec.Ly, L[2]);
        push!(rec.Lz, L[3])
        push!(rec.fx, sum(fx) * dV);
        push!(rec.fy, sum(fy) * dV)
        push!(rec.fz, sum(fz) * dV)
        # azimuth of the symmetry axis in the xy-plane: THE rotation angle
        ax = ma.axis
        push!(rec.phi, atan(ax[2], ax[1]))
        push!(rec.e1, ma.eig[1]);
        push!(rec.e2, ma.eig[2]);
        push!(rec.e3, ma.eig[3])
        push!(rec.norm, sum(abs2, psi_h) * dV)
        push!(rec.rho_max, maximum(rho) / A_HO_UM^3)
        push!(rec.edge, edge)
    end
    sample!(ws)
    cbs = SimulationCallbacks(;
        on_step=(w, step, times, energies) -> begin
            step % save_every == 0 && sample!(w)
            nothing
        end,
    )
    t0 = time()
    run_simulation!(ws; callbacks=cbs)
    wall = time() - t0

    # ---- 3. report -------------------------------------------------------
    Jz = rec.Lz .+ rec.fz
    # unwrap the axis azimuth; the axis is a DIRECTOR (n and -n are the same
    # torus), so the angle is defined mod pi, not mod 2pi.
    phi_u = copy(rec.phi)
    for i in 2:length(phi_u)
        d = phi_u[i] - phi_u[i - 1]
        while d > π / 2
            d -= π
        end
        while d < -π / 2
            d += π
        end
        phi_u[i] = phi_u[i - 1] + d
    end
    t_ms = rec.t .* (1000 / OMEGA_REF)

    println()
    println("="^78)
    @printf("EdH QUENCH  Bz = %.4f mG = %.1f uG   p = %+.6f   F=6 N=15000 eps_dd=1.3\n",
        Bz_mG, Bz_mG * 1000, p)
    println("="^78)
    @printf("  %d steps, wall %.1f s (%.2f ms/step), t_end = %.3f = %.2f ms, %d samples\n",
        n_steps, wall, 1000wall / n_steps, t_end, t_end * 1000 / OMEGA_REF, length(rec.t))
    @printf("  norm drift    = %.3e   (integrator gate)\n",
        maximum(abs.(rec.norm .- rec.norm[1])))
    @printf("  max edge frac = %.3e   (box gate; the object must not touch the wall)\n",
        maximum(rec.edge))
    println()
    println("  THE J_z LEDGER   (B is along z, so J_z = L_z + f_z is conserved)")
    @printf("    J_z(0)   = %+.6e\n", Jz[1])
    @printf("    max|J_z| = %+.6e   drift = %.3e\n", maximum(abs.(Jz)),
        maximum(abs.(Jz .- Jz[1])))
    @printf("    f_z: %+.5f -> %+.5f   (swing %.5f)\n", rec.fz[1], rec.fz[end],
        maximum(rec.fz) - minimum(rec.fz))
    @printf("    L_z: %+.5f -> %+.5f   (swing %.5f)\n", rec.Lz[1], rec.Lz[end],
        maximum(rec.Lz) - minimum(rec.Lz))
    corr =
        let a = rec.fz .- sum(rec.fz) / length(rec.fz), c = rec.Lz .- sum(rec.Lz) / length(rec.Lz)
            sum(a .* c) / sqrt(sum(abs2, a) * sum(abs2, c))
        end
    @printf("    corr(f_z, L_z) = %+.6f   (EdH says -1: spin gained = orbital lost)\n", corr)
    println()
    println("  MECHANICAL ROTATION about z (azimuth of the symmetry axis, mod pi)")
    @printf("    phi: %.2f deg -> %.2f deg   total swing %.2f deg\n",
        rad2deg(phi_u[1]), rad2deg(phi_u[end]),
        rad2deg(maximum(phi_u) - minimum(phi_u)))
    if length(t_ms) > 4
        k = max(2, length(t_ms) ÷ 4)
        rate = (phi_u[k] - phi_u[1]) / (t_ms[k] - t_ms[1])
        @printf("    initial rate = %+.4f deg/ms  (over the first quarter)\n",
            rad2deg(rate))
    end
    println()
    println("  SHAPE (sorted moment eigenvalues; a rigid rotation leaves them fixed)")
    for (lab, v) in (("e1", rec.e1), ("e2", rec.e2), ("e3", rec.e3))
        @printf("    %s  %.6f -> %.6f   swing %.3f %%\n", lab, v[1], v[end],
            100 * (maximum(v) - minimum(v)) / abs(v[1]))
    end
    @printf("  rho_max: %.5f -> %.5f N um^-3 (%.2f %%)\n", rec.rho_max[1],
        rec.rho_max[end], 100 * (rec.rho_max[end] - rec.rho_max[1]) / rec.rho_max[1])

    println()
    println("  t[ms]      f_z         L_z         J_z        phi[deg]   edge")
    stride = max(1, length(rec.t) ÷ 20)
    for i in 1:stride:length(rec.t)
        @printf("  %7.3f  %+.6f  %+.6f  %+.3e  %8.3f  %.2e\n",
            t_ms[i], rec.fz[i], rec.Lz[i], Jz[i], rad2deg(phi_u[i]), rec.edge[i])
    end

    if !smoke
        # dt and t_end belong in the NAME: the dt-convergence arm is the same
        # field at half the step, and a tag that omits dt silently overwrites
        # the very run it is supposed to be compared with (it did, once).
        tag = @sprintf("edh_Bz%.0fuG_n%d_dt%.0em_t%.0f", Bz_mG * 1000, nn,
            dt * 1e4, t_end)
        jldsave(joinpath(outdir, "$tag.jld2"); rec=rec, Jz=Jz, phi_u=phi_u,
            t_ms=t_ms, Bz_mG=Bz_mG, p=p, n=nn, box=bx, dt=dt,
            psi_final=Array(ws.state.psi),
            git_hash=strip(read(`git rev-parse HEAD`, String)))
        open(joinpath(outdir, "$tag.csv"), "w") do io
            println(io, "t_ms,fx,fy,fz,Lx,Ly,Lz,Jz,phi_deg,e1,e2,e3,norm,rho_max,edge")
            for i in eachindex(rec.t)
                println(
                    io,
                    join(
                        (t_ms[i], rec.fx[i], rec.fy[i], rec.fz[i],
                            rec.Lx[i], rec.Ly[i], rec.Lz[i], Jz[i],
                            rad2deg(phi_u[i]), rec.e1[i], rec.e2[i], rec.e3[i],
                            rec.norm[i], rec.rho_max[i], rec.edge[i]), ","),
                )
            end
        end
        println("\n  wrote out/$tag.{jld2,csv}")
    end
    (; rec, Jz, phi_u, t_ms, b)
end

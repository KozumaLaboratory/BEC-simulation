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

"""
Sorted eigenvalues of the CENTRAL second-moment tensor
`<(r-R)_a (r-R)_b>`, the symmetry axis (smallest moment, oblate) and the
centre of mass `R`.

Subtracting R is not optional. Without it the tensor is
`<r_a r_b> = <(r-R)_a (r-R)_b> + R_a R_b`, so a droplet sitting 0.77 a_ho off
the origin reports a moment of 0.649 where the shape contributes 0.055 — it
reads as a long cigar while being a perfectly good torus. That happened here:
the F=1 EdH cell came back "prolate" with eigenvalues [0.136, 0.146, 0.649]
while its energy matched the on-axis ground state to six digits, which is the
tell — a genuinely different shape does not have the same energy.

`R` is returned as well, because in a QUENCH a drifting droplet also
contaminates the rotation angle: the azimuth of the symmetry axis is measured
about the box origin, so an orbiting droplet mixes orbital motion into what is
meant to be the object's own rotation.
"""
function moment_axis(psi, grid::Grid{3})
    psi_h = psi isa Array ? psi : Array(psi)
    rho = total_density(psi_h, 3)
    dV = cell_volume(grid)
    T = zeros(3, 3)
    com = zeros(3)
    tot = 0.0
    @inbounds for I in CartesianIndices(rho)
        r = (grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]])
        w = rho[I] * dV
        tot += w
        for a in 1:3
            com[a] += w * r[a]
            for b in a:3
                T[a, b] += w * r[a] * r[b]
            end
        end
    end
    T ./= tot
    com ./= tot
    for a in 1:3, b in a:3
        T[a, b] -= com[a] * com[b]
    end
    for a in 1:3, b in 1:(a - 1)
        T[a, b] = T[b, a]
    end
    ev = eigen(Symmetric(T))
    (; eig=ev.values, axis=ev.vectors[:, 1], com=com)
end

"""
Rotate a spinor field by 90 degrees about x, exactly.

    R_x(90): (x, y, z) -> (x, -z, y),  so  psi'(r) = U psi(R^-1 r)
    with R^-1: (x, y, z) -> (x, z, -y)  and  U = exp(-i (pi/2) F_x).

On an FFT grid x_k = -L/2 + k dx the point -x_k is x_{n-k} (index n wraps to
0 by periodicity), so the spatial part is an index permutation and the
rotation is EXACT — no interpolation, no resampling. It requires equal n and
equal box length in y and z, which is asserted.

Why do this instead of seeding along y and relaxing: at B = 0 the Hamiltonian
is rotationally invariant, so the orientation is an exact zero mode. A soft,
imperfectly converged ground state is then free to rotate, and for the F=1
cell it did — the axis came out along z when the protocol needs y. Rotating an
already-converged state cannot drift, and the rotated state is stationary by
symmetry rather than by iteration.
"""
function rotate90_x(psi::Array{ComplexF64, 4}, grid::Grid{3}, F::Int)
    n = grid.config.n_points
    n[2] == n[3] || error("rotate90_x needs n_y == n_z (got $(n[2]), $(n[3]))")
    isapprox(grid.config.box_size[2], grid.config.box_size[3]) ||
        error("rotate90_x needs box_y == box_z")
    D = 2F + 1
    U = exp(-1im * (π / 2) * Matrix(spin_matrices(F).Fx))
    out = similar(psi)
    ny = n[2]
    @inbounds for k in 1:n[3], j in 1:n[2], i in 1:n[1]
        # psi'(x_i, y_j, z_k) = U psi(x_i, z_k, -y_j)
        jm = mod(ny - (j - 1), ny) + 1        # index of -y_j
        s = @view psi[i, k, jm, :]
        for c in 1:D
            acc = zero(ComplexF64)
            for d in 1:D
                acc += U[c, d] * s[d]
            end
            out[i, j, k, c] = acc
        end
    end
    out
end

"""
Ground state of the torus with its symmetry axis along `axis`, at B = 0.

At B = 0 the Hamiltonian is rotationally invariant, so this must land on the
same energy as the z-axis ground state. That equality is checked, and it is the
gate on the generalized seed: a seed that built the wrong texture for axis != z
would converge somewhere else.
"""
function ground_state_axis(; axis=2, n=(64, 64, 64), box=(6.5, 6.5, 6.5),
    backend=CUDABackend(), iters=4000, cellname="T",
    rotate_from_z::Bool=false)
    cell = merge(cell_for(cellname), (; Bz_mG=0.0))
    b = build_cell(cell; n=n, box=box)
    if rotate_from_z
        # converge along z (where nothing is soft), then rotate exactly
        bz = merge(b, (; psi0=seed_torus(b.grid, b.F; lam=b.lam, sr=b.sr,
            sz=b.sz, axis=3)))
        psi_z, ws_z, gs_z = solve_cell(bz; backend=backend, iters=iters)
        psi_y = rotate90_x(Array(psi_z), b.grid, b.F)
        by = merge(b, (; psi0=psi_y))
        # ONE L-BFGS step's worth of polish is not applied: the rotated state
        # is stationary by symmetry and re-running the solver would re-open the
        # orientation mode. Its energy is measured instead, and must equal the
        # z-axis energy.
        ws_y = make_workspace(; grid=b.grid, atom=b.atom,
            interactions=InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy),
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap(TRAP_OMEGA, TRAP_OMEGA, TRAP_OMEGA),
            sim_params=SimParams(; dt=1e-4, n_steps=1),
            enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
            ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=psi_y,
            backend=backend)
        ez = energy_decomposition(ws_z).total
        ey = energy_decomposition(ws_y).total
        println("  rotation gate: E(z-axis) = ", round(ez; digits=10),
            "  E(rotated) = ", round(ey; digits=10),
            "  dev = ", round(abs(ey - ez) / abs(ez); sigdigits=3))
        abs(ey - ez) / abs(ez) < 1e-6 ||
            error(
                "rotation changed the energy by $(abs(ey-ez)/abs(ez)) — " *
                "the rotation is not exact on this grid",
            )
        return (by, ws_y.state.psi, ws_y, gs_z)
    end
    psi0 = seed_torus(b.grid, b.F; lam=b.lam, sr=b.sr, sz=b.sz, axis=axis)
    b = merge(b, (; psi0=psi0))
    psi, ws, gs = solve_cell(b; backend=backend, iters=iters)
    _assert_is_the_torus(ws, b, axis)
    (b, psi, ws, gs)
end

"""
Refuse a relaxed state that is not the torus we asked for.

The `rotate_from_z` path has an energy gate; this path had none -- it printed
the moment eigenvalues and left the reading to the reader. On 2026-08-20 a box
scan run without `orient=rotate` relaxed instead into a PROLATE state with
eigenvalues (3.92, 3.92, 5.19) against the torus's (0.055, 0.146, 0.146) and a
POSITIVE E/N of +0.114, i.e. an unbound object roughly 5x too big. It then
expanded onto the wall, and the f_z it produced was read as an EdH response.
At B = 0 the orientation is an exact zero mode, which is why this basin is
reachable at all and why `orient=rotate` exists.

A torus has a DEGENERATE pair of moment eigenvalues (its symmetry axis) and is
OBLATE about it -- the distinct eigenvalue is the SMALL one. A self-bound
droplet in a negligible trap has E/N < 0.
"""
function _assert_is_the_torus(ws, b, axis)
    e = moment_axis(ws.state.psi, b.grid).eig      # ascending
    etot = energy_decomposition(ws).total
    d12, d23 = abs(e[2] - e[1]), abs(e[3] - e[2])
    # OBLATE (a torus): the degenerate pair is the LARGE two and the distinct
    # eigenvalue is the small one, so the top gap closes -- (0.055, 0.146,
    # 0.146) gives d23 = 0 < d12. PROLATE is the mirror image, (3.92, 3.92,
    # 5.19) with d12 = 0 < d23, and that is the basin this gate exists to
    # reject. Both have a degenerate pair, so degeneracy alone does not
    # separate them; the shape does.
    ok_shape = d23 < d12
    deg_rel = min(d12, d23) / max(e[3], eps())
    ok_deg = deg_rel < 0.02
    ok_bound = etot < 0
    if !(ok_deg && ok_shape && ok_bound)
        error("the relaxed state is NOT the torus: moment eigenvalues = " *
              "$(round.(e; digits=5)), E/N = $(round(etot; digits=6)). " *
              "degenerate pair: $(ok_deg ? "ok" : "NO (rel gap $(round(deg_rel; sigdigits=3)))"); " *
              "oblate: $(ok_shape ? "ok" : "NO -- this is prolate"); " *
              "self-bound: $(ok_bound ? "ok" : "NO -- E/N >= 0, it will expand"). " *
              "At B=0 the orientation is an exact zero mode; use orient=rotate.")
    end
    nothing
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
    # `cell=` selects the physics: "T" is the F=6 extrapolation, "E1" is the
    # paper's OWN Fig. 4 cell (F=1, N=15000, eps_dd=1.2, B_z = 0.05/0.1 mG).
    cellname = get(opts, "cell", "T")
    # `orient=rotate`: converge along z and rotate 90 deg exactly, instead of
    # seeding along y and hoping the zero mode does not move.
    rotate_from_z = get(opts, "orient", "seed") == "rotate"
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
        box=(bx, bx, bx), backend=be, iters=(smoke ? 40 : 4000),
        cellname=cellname, rotate_from_z=rotate_from_z)
    m0 = moment_axis(psi0, b.grid)
    e0 = energy_decomposition(ws0)
    @printf("  GS(axis=y): E/N = %.8f   grad_norm = %.3e\n", e0.total,
        get(gs0, :grad_norm, NaN))
    @printf("     moment eigenvalues = [%.5f, %.5f, %.5f]  axis = (%+.4f, %+.4f, %+.4f)\n",
        m0.eig..., m0.axis...)
    println("     (B=0 is rotationally invariant, so this must equal the z-axis")
    println("      ground state of the same cell: F=6 T gives E/N = -1.575563)")

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
        rho_max=Float64[], edge=Float64[],
        cx=Float64[], cy=Float64[], cz=Float64[])
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
        push!(rec.cx, ma.com[1]);
        push!(rec.cy, ma.com[2]);
        push!(rec.cz, ma.com[3])
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
    # Derive the physics line from the cell. It was the LITERAL string
    # "F=6 N=15000 eps_dd=1.3" until 2026-08-20, so every `cell=E1` run
    # printed a banner describing a different cell -- and the only way to tell
    # which had actually run was to recognise p = -2.8627 as g_F = 4.5.
    @printf("EdH QUENCH  Bz = %.4f mG = %.1f uG   p = %+.6f   cell=%s F=%d N=%d eps_dd=%.2f\n",
        Bz_mG, Bz_mG * 1000, p, cellname, b.F, b.cell.N, b.cell.eps_dd)
    println("="^78)
    @printf("  %d steps, wall %.1f s (%.2f ms/step), t_end = %.3f = %.2f ms, %d samples\n",
        n_steps, wall, 1000wall / n_steps, t_end, t_end * 1000 / OMEGA_REF, length(rec.t))
    # WRITE THE VERDICT, do not print a column and leave the reading to the
    # reader. On 2026-08-20 a box scan launched without `dt=` picked up the
    # default 5e-4 -- fine for the F=6 cell it was tuned on, unstable for E1 --
    # and ran to max edge 9.2e-2 with f_z drifting to -0.40. The number was
    # right there in the output and got read as data. h3 already had this fixed;
    # this file did not.
    ndrift = maximum(abs.(rec.norm .- rec.norm[1]))
    medge = maximum(rec.edge)
    @printf("  norm drift    = %.3e   (integrator gate)   %s\n", ndrift,
        ndrift < 1e-6 ? "ok" : "*** UNUSABLE: the integrator is not conserving norm")
    @printf("  max edge frac = %.3e   (box gate)          %s\n", medge,
        medge < EDGE_MAX ? "ok" :
        "*** UNUSABLE: the object is on the wall; f_z/L_z here are not the droplet's")
    drift = maximum(sqrt.(rec.cx .^ 2 .+ rec.cy .^ 2 .+ rec.cz .^ 2))
    @printf("  max |COM|     = %.3e a_ho  (the rotation angle is measured about the\n", drift)
    @printf("                  box origin, so a drifting droplet mixes orbit into it)\n")
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
        # Every axis a convergence arm can vary belongs in the NAME: the
        # dt arm is the same field at half the step, and the BOX arm is the
        # same field in a wider box. A tag that omits one silently overwrites
        # the very run it is supposed to be compared with (dt did, once; box
        # was added when h19 showed the dipolar field reaches well past where
        # the density has died, making the box a live axis here).
        tag = @sprintf("edh_%s_Bz%.0fuG_n%d_box%.1f_dt%.0em_t%.0f", cellname,
            Bz_mG * 1000, nn, bx, dt * 1e4, t_end)
        jldsave(joinpath(outdir, "$tag.jld2"); rec=rec, Jz=Jz, phi_u=phi_u,
            t_ms=t_ms, Bz_mG=Bz_mG, p=p, n=nn, box=bx, dt=dt,
            psi_final=Array(ws.state.psi),
            git_hash=strip(read(`git rev-parse HEAD`, String)))
        open(joinpath(outdir, "$tag.csv"), "w") do io
            println(io,
                "t_ms,fx,fy,fz,Lx,Ly,Lz,Jz,phi_deg,e1,e2,e3,norm,rho_max,edge,cx,cy,cz")
            for i in eachindex(rec.t)
                println(
                    io,
                    join(
                        (t_ms[i], rec.fx[i], rec.fy[i], rec.fz[i],
                            rec.Lx[i], rec.Ly[i], rec.Lz[i], Jz[i],
                            rad2deg(phi_u[i]), rec.e1[i], rec.e2[i], rec.e3[i],
                            rec.norm[i], rec.rho_max[i], rec.edge[i],
                            rec.cx[i], rec.cy[i], rec.cz[i]), ","),
                )
            end
        end
        println("\n  wrote out/$tag.{jld2,csv}")
    end
    (; rec, Jz, phi_u, t_ms, b)
end

# Mechanical Larmor precession (paper Fig. 2), same protocol for every cell.
#
# Protocol, from the paper: take the l=1 stationary state at B=0, ramp B_y
# linearly from 0 to B_tilde over t = 0..0.05 T0, then hold. Measure
#   * <L>(t), <f>(t)                       --- the precession itself
#   * omega_L by BOTH a sinusoid fit AND the extremum spacing. The spacing is
#     model-independent; a fit can return a number from a curve that is not a
#     sinusoid at all.
#   * the SORTED EIGENVALUES of the second-moment tensor <r_a r_b>. This is the
#     quantitative form of the paper's claim that the cloud "rotates without
#     changing its shape": under a rigid rotation the eigenvalues are invariant
#     while <x^2>, <z^2> individually swap. Tracking <x^2>/<z^2> alone would
#     report a shape change that is only the rotation.
#   * the J_z ledger, and the norm.
#
# Sign convention: our H = -(b.F) + q F_z^2 with b = -g_F mu_B B, and the paper's
# H = +g mu_B B.S, so b_y = -B_tilde / S^2 (internal units). The mirror arm flips
# BOTH l and B_y --- flipping only one is not a mirror operation.
#
# Usage:
#   julia --project=. runs/yls_barnett_f6/c_larmor_rtp.jl <cell> B=1000 [n=64] [...]

using SpinorBEC
using Printf
using JLD2
using LinearAlgebra
using FFTW

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

"Second-moment tensor eigenvalues (sorted) + the raw tensor, density-weighted."
function moment_tensor(psi, grid::Grid{3})
    psi_h = psi isa Array ? psi : Array(psi)
    rho = total_density(psi_h, 3)
    dV = cell_volume(grid)
    T = zeros(3, 3)
    @inbounds for I in CartesianIndices(rho)
        r = (grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]])
        w = rho[I] * dV
        for a in 1:3, bb in a:3
            T[a, bb] += w * r[a] * r[bb]
        end
    end
    for a in 1:3, bb in 1:(a - 1)
        T[a, bb] = T[bb, a]
    end
    (; T, eig=sort(eigvals(Symmetric(T))))
end

"Extremum times of a sampled signal by parabolic interpolation on interior peaks."
function extremum_times(t, y)
    out = Float64[]
    for i in 2:(length(y) - 1)
        if (y[i] - y[i - 1]) * (y[i + 1] - y[i]) < 0
            # parabolic vertex through the three points
            d = (y[i - 1] - 2y[i] + y[i + 1])
            shift = d == 0 ? 0.0 : 0.5 * (y[i - 1] - y[i + 1]) / d
            push!(out, t[i] + shift * (t[i + 1] - t[i]))
        end
    end
    out
end

"omega from mean spacing of consecutive extrema (half a period apart)."
function omega_from_extrema(t, y)
    ex = extremum_times(t, y)
    length(ex) < 3 && return (; omega=NaN, n=length(ex), spread=NaN)
    gaps = diff(ex)
    (; omega=π / (sum(gaps) / length(gaps)), n=length(ex),
        spread=(maximum(gaps) - minimum(gaps)) / (sum(gaps) / length(gaps)))
end

"omega from least-squares sinusoid fit y = A sin(w t) + B cos(w t) + C, scanned in w."
function omega_from_fit(t, y; w_lo, w_hi, n_scan=4000)
    best = (; omega=NaN, resid=Inf)
    for w in range(w_lo, w_hi; length=n_scan)
        M = hcat(sin.(w .* t), cos.(w .* t), ones(length(t)))
        c = M \ y
        r = sum(abs2, M * c - y)
        r < best.resid && (best = (; omega=w, resid=r))
    end
    # local refine
    dw = (w_hi - w_lo) / n_scan
    for w in range(best.omega - 2dw, best.omega + 2dw; length=400)
        M = hcat(sin.(w .* t), cos.(w .* t), ones(length(t)))
        c = M \ y
        r = sum(abs2, M * c - y)
        r < best.resid && (best = (; omega=w, resid=r))
    end
    best
end

function run_larmor(name; B_tilde=1000.0, n=64, t_end_T0=0.5, dt=2e-4, save_every=50,
    q_scale=0.0, mirror=false, gpu=true, kwargs...)
    cell0 = CELLS[name]
    l = mirror ? -cell0.l : cell0.l
    cell = merge(cell0, (; l=l))
    b = build_cell(cell; n=n, kwargs...)

    # seed: prefer the converged ITP state for this cell if present
    f_itp = joinpath(@__DIR__, "out", "itp_$(name)_n$(n)_prod.jld2")
    psi0 = if isfile(f_itp) && !mirror
        d = load(f_itp)
        @printf("  seeding from %s (converged=%s)\n", basename(f_itp), d["converged"])
        d["psi"]
    else
        isfile(f_itp) || @warn "no converged ITP state at $f_itp; seeding from the variational torus"
        b.psi0
    end

    B_signed = mirror ? -B_tilde : B_tilde
    by_internal = -B_signed / b.S^2            # H = -b.F  vs  paper +g mu_B B.S
    t_ramp = 0.05 * b.S^2                      # 0.05 T0 in internal time
    t_end = t_end_T0 * b.S^2
    n_steps = ceil(Int, t_end / dt)

    by_wf = PiecewiseLinearWaveform([0.0, t_ramp, t_end], [0.0, by_internal, by_internal])
    # q F_z^2: physically q is on the field axis, which here is y, while the code
    # implements q F_z^2. `q_scale` is therefore a SENSITIVITY knob, not the
    # physical term -- see the report in README.md.
    q_internal = q_scale * abs(by_internal)
    q_wf = PiecewiseLinearWaveform([0.0, t_ramp, t_end], [0.0, q_internal, q_internal])
    zeeman = TimeDependentZeeman(ConstantWaveform(0.0), q_wf, nothing, by_wf)

    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=zeeman, potential=NoPotential(),
        sim_params=SimParams(; dt=dt, n_steps=n_steps, save_every=save_every,
            imaginary_time=false),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        psi_init=psi0, backend=(gpu ? CUDABackend() : CPUBackend()))

    plans = make_fft_plans(b.grid.config.n_points; flags=FFTW.ESTIMATE)
    sm = spin_matrices(b.F)
    rec = (t=Float64[], Lx=Float64[], Ly=Float64[], Lz=Float64[],
        fx=Float64[], fy=Float64[], fz=Float64[],
        e1=Float64[], e2=Float64[], e3=Float64[], norm=Float64[], rho_max=Float64[])
    function sample!(ws)
        psi_h = Array(ws.state.psi)
        L = orbital_angular_momentum_vector(psi_h, b.grid, plans)
        fx, fy, fz = spin_density_vector(psi_h, sm, 3)
        dV = cell_volume(b.grid)
        mt = moment_tensor(psi_h, b.grid)
        push!(rec.t, ws.state.t)
        push!(rec.Lx, L[1]); push!(rec.Ly, L[2]); push!(rec.Lz, L[3])
        push!(rec.fx, sum(fx) * dV); push!(rec.fy, sum(fy) * dV)
        push!(rec.fz, sum(fz) * dV)
        push!(rec.e1, mt.eig[1]); push!(rec.e2, mt.eig[2]); push!(rec.e3, mt.eig[3])
        push!(rec.norm, sum(abs2, psi_h) * dV)
        push!(rec.rho_max, maximum(total_density(psi_h, 3)) * b.S^3)
    end
    sample!(ws)
    cbs = SimulationCallbacks(on_step=(w, step, times, energies) -> begin
        step % save_every == 0 && sample!(w)
        nothing
    end)
    t0 = time()
    run_simulation!(ws; callbacks=cbs)
    wall = time() - t0

    # --- analysis, in paper units -----------------------------------------
    t_T0 = rec.t ./ b.S^2
    keep = t_T0 .>= 0.05                       # after the ramp
    tt = t_T0[keep]
    gamma_B = B_tilde                          # gamma = 1 in paper units
    f_perp = sqrt.(rec.fx .^ 2 .+ rec.fz .^ 2)
    L_perp = sqrt.(rec.Lx .^ 2 .+ rec.Lz .^ 2)
    fp = length(f_perp[keep]) > 0 ? sum(f_perp[keep]) / count(keep) : NaN
    Lp = length(L_perp[keep]) > 0 ? sum(L_perp[keep]) / count(keep) : NaN
    w_pred = fp * gamma_B / (Lp + fp)

    println()
    println("="^78)
    @printf("LARMOR  cell=%s%s  B_tilde=%+.1f  F=%d  eps_dd=%.4f N=%d l=%+d q_scale=%.1e\n",
        name, mirror ? " (MIRROR: l and B_y both flipped)" : "", B_signed, b.F,
        cell.eps_dd, cell.N, cell.l, q_scale)
    println("="^78)
    @printf("  wall %.1f s for %d steps (%.2f ms/step), t_end = %.3f T0, %d samples\n",
        wall, n_steps, 1000wall / n_steps, t_end_T0, length(rec.t))
    @printf("  b_y internal = %+.6f ; q internal = %.3e ; t_ramp = %.4g internal\n",
        by_internal, q_internal, t_ramp)
    @printf("  norm drift  = %.3e\n", maximum(abs.(rec.norm .- rec.norm[1])))
    @printf("  <f_perp> after ramp = %.5f   <L_perp> = %.5f\n", fp, Lp)
    @printf("  predicted omega_L = f_perp gamma B_y/(L_perp+f_perp) = %.4f  (/2pi = %.4f)\n",
        w_pred, w_pred / 2π)
    for (lab, sig) in (("L_x", rec.Lx[keep]), ("L_z", rec.Lz[keep]))
        ex = omega_from_extrema(tt, sig)
        ft = omega_from_fit(tt, sig; w_lo=0.05 * max(w_pred, 1.0), w_hi=4 * max(w_pred, 1.0))
        @printf("  %s : omega(extremum spacing) = %8.4f (n_ex=%d, spread %.1f %%) | omega(fit) = %8.4f | /2pi = %7.4f\n",
            lab, ex.omega, ex.n, 100ex.spread, ft.omega, ft.omega / 2π)
    end
    e1r = (maximum(rec.e1) - minimum(rec.e1)) / abs(rec.e1[1])
    e2r = (maximum(rec.e2) - minimum(rec.e2)) / abs(rec.e2[1])
    e3r = (maximum(rec.e3) - minimum(rec.e3)) / abs(rec.e3[1])
    @printf("  SHAPE (sorted moment-tensor eigenvalue swing over the whole run):\n")
    @printf("    e1 %.3f %%   e2 %.3f %%   e3 %.3f %%   <-- 'rotates without changing shape'\n",
        100e1r, 100e2r, 100e3r)
    @printf("  rho_max: %.0f -> %.0f D0 (%.2f %% change)\n", rec.rho_max[1], rec.rho_max[end],
        100 * (rec.rho_max[end] - rec.rho_max[1]) / rec.rho_max[1])

    out = joinpath(@__DIR__, "out")
    mkpath(out)
    tag = "$(name)_B$(round(Int,B_signed))_n$(n)$(mirror ? "_mirror" : "")$(q_scale>0 ? "_q$(q_scale)" : "")"
    jldsave(joinpath(out, "larmor_$(tag).jld2");
        rec=Dict(pairs(rec)), t_T0=t_T0, B_tilde=B_signed, q_scale=q_scale,
        S=b.S, n=n, dt=dt, mirror=mirror, cell=Dict(pairs(cell)),
        omega_pred=w_pred, f_perp=fp, L_perp=Lp,
        git_hash=strip(read(`git rev-parse HEAD`, String)))
    println("  saved: ", joinpath(out, "larmor_$(tag).jld2"))
    (; b, rec, t_T0, w_pred)
end

function main_larmor(args)
    name = isempty(args) ? "P1" : args[1]
    opts = Dict{String, String}()
    for a in args[2:end]
        k, v = split(a, "="; limit=2)
        opts[k] = v
    end
    g(k, d) = haskey(opts, k) ? parse(typeof(d), opts[k]) : d
    run_larmor(name; B_tilde=g("B", 1000.0), n=g("n", 64), t_end_T0=g("t_end", 0.5),
        dt=g("dt", 2e-4), save_every=g("save_every", 50), q_scale=g("q_scale", 0.0),
        mirror=g("mirror", false), gpu=g("gpu", true))
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_larmor(ARGS)

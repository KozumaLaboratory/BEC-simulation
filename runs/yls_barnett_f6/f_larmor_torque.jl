# Question 3: the precession frequency, and the mechanism behind it.
#
# The paper's claim is Eq. (4): d<J>/dt = gamma <f> x B, from which it derives
#   omega_L = f_perp gamma B_y / (L_perp + f_perp)
# and plots that line through its Fig. 2(c) points. Reproducing the FULL Fig. 2(c)
# needs ~5e6 steps per field value (dt ~ 1e-7 T0 over 0.5 T0 — the paper's own
# cost), which is not the cheap way to test the claim.
#
# The claim IS the torque law, so measure the torque. Apply a constant B_y to the
# converged l=1 state and measure d<J>/dt directly over a short window, then
# compare component by component with gamma <f> x B. That is in-regime (B_y = 1000,
# the paper's own value), needs a few thousand steps, and tests the actual
# mechanism rather than fitting a frequency to a truncated oscillation. The
# frequency then follows from the paper's own formula with OUR measured f_perp and
# L_perp.
#
# This is the same shape as the Barnett-REDO lesson: a static torque budget on a
# saved state settled in seconds what hour-long A/B runs had not.
#
# Sign convention: our H = -(b.F) + q F_z^2 with b = -g_F mu_B B, so the paper's
# B_tilde maps to b_y = -B_tilde/S^2 in internal units. gamma = 1 in paper units.

using SpinorBEC
using Printf
using JLD2
using LinearAlgebra
using FFTW

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

function torque_probe(name; B_tilde=1000.0, n=64, box_sigma=2.5, dt=2e-4,
    n_steps=4000, n_sample=20, gpu=true, reconverge=false)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    f_camp = joinpath(@__DIR__, "out", "campaign_$(name)_n$(n).jld2")
    # A saved psi is an ARRAY: dropping it onto a grid with a different box
    # silently dilates the physical state, so a box scan MUST re-converge rather
    # than reload. (The first version of this scan reloaded, and the torque ratio
    # came out 1.00 only at the box the state had been converged in — the scan was
    # measuring its own re-gridding.)
    psi0 = if reconverge
        r = run_itp(b; method=:lbfgs, n_steps=3000, tol=1e-10,
            backend=(gpu ? CUDABackend() : CPUBackend()))
        @printf("  re-converged at box_sigma=%.2f (grad_norm %.2e)\n", box_sigma,
            get(r, :grad_norm, NaN))
        Array(r.workspace.state.psi)
    elseif isfile(f_camp)
        d = load(f_camp)
        @printf("  seeding from %s (grad_norm %.2e)\n", basename(f_camp),
            get(d, "grad_norm", NaN))
        d["psi"]
    else
        error("no converged state at $f_camp — run e_campaign.jl for cell $name first")
    end

    by = -B_tilde / b.S^2                       # H = -b.F  vs paper's +g mu_B B.S
    zeeman = ZeemanParams(0.0, 0.0)             # z-linear and q both zero
    tdz = TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
        nothing, ConstantWaveform(by))
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=tdz, potential=NoPotential(),
        sim_params=SimParams(; dt=dt, n_steps=n_steps, imaginary_time=false),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        psi_init=psi0, backend=(gpu ? CUDABackend() : CPUBackend()))

    plans = make_fft_plans(b.grid.config.n_points; flags=FFTW.ESTIMATE)
    sm = spin_matrices(b.F)
    dV = cell_volume(b.grid)
    read_LJ = () -> begin
        psi_h = Array(ws.state.psi)
        L = orbital_angular_momentum_vector(psi_h, b.grid, plans)
        fx, fy, fz = spin_density_vector(psi_h, sm, 3)
        f = (sum(fx) * dV, sum(fy) * dV, sum(fz) * dV)
        (L, f, L .+ f)
    end

    ts, Js, fs, Ls = Float64[], Vector{Float64}[], Vector{Float64}[], Vector{Float64}[]
    every = max(1, n_steps ÷ n_sample)
    for s in 0:n_steps
        if s % every == 0
            L, f, J = read_LJ()
            push!(ts, ws.state.t / b.S^2)       # paper units (T0)
            push!(Ls, collect(L)); push!(fs, collect(f)); push!(Js, collect(J))
        end
        s == n_steps && break
        split_step!(ws)
    end

    # measured d<J>/dt in paper units, by least squares over the window
    A = hcat(ts, ones(length(ts)))
    dJdt = [ (A \ [J[k] for J in Js])[1] for k in 1:3 ]
    # predicted gamma <f> x B with gamma = 1, B = (0, B_tilde, 0)
    f0 = fs[1]
    pred = [f0[2] * 0 - f0[3] * B_tilde,        # (f x B)_x = f_y B_z - f_z B_y
        0.0,                                    # (f x B)_y = f_z B_x - f_x B_z
        f0[1] * B_tilde - 0.0]                  # (f x B)_z = f_x B_y - f_y B_x
    f_perp = sqrt(f0[1]^2 + f0[3]^2)
    L0v = Ls[1]
    L_perp = sqrt(L0v[1]^2 + L0v[3]^2)
    omega_L = f_perp * B_tilde / (L_perp + f_perp)

    println("="^96)
    @printf("TORQUE TEST of Eq. (4)   cell %s  F=%d  B_tilde=%+.1f  window %.3e T0  (%d steps)\n",
        name, b.F, B_tilde, ts[end], n_steps)
    println("="^96)
    @printf("  initial <L> = (%+.5f,%+.5f,%+.5f)   <f> = (%+.5f,%+.5f,%+.5f)\n", L0v..., f0...)
    @printf("  %-6s %16s %16s %12s\n", "comp", "d<J>/dt measured", "gamma <f> x B", "ratio")
    for (k, lab) in enumerate(("x", "y", "z"))
        r = abs(pred[k]) > 1e-8 * B_tilde ? dJdt[k] / pred[k] : NaN
        @printf("  %-6s %16.4f %16.4f %12s\n", lab, dJdt[k], pred[k],
            isnan(r) ? "(pred~0)" : @sprintf("%.5f", r))
    end
    @printf("\n  f_perp = %.5f   L_perp = %.5f   |J| drift over window = %.2e\n",
        f_perp, L_perp, norm(Js[end] - Js[1]))
    @printf("  omega_L = f_perp gamma B_y/(L_perp+f_perp) = %.4f T0^-1  => omega_L/2pi = %.4f\n",
        omega_L, omega_L / 2π)
    @printf("  precession period = %.5f T0 = %.2f ms   (T0 = %.4f s)\n",
        2π / omega_L, 1e3 * 2π / omega_L * b.S^2 / b.omega_ref, b.S^2 / b.omega_ref)
    out = joinpath(@__DIR__, "out")
    mkpath(out)
    jldsave(joinpath(out, "torque_$(name)_B$(round(Int,B_tilde))_n$(n).jld2");
        ts=ts, Js=Js, fs=fs, Ls=Ls, dJdt=dJdt, pred=pred, f_perp=f_perp,
        L_perp=L_perp, omega_L=omega_L, B_tilde=B_tilde, S=b.S,
        T0_seconds=b.S^2 / b.omega_ref, cell=Dict(pairs(cell)),
        git_hash=strip(read(`git rev-parse HEAD`, String)))
    flush(stdout)
    (; dJdt, pred, f_perp, L_perp, omega_L, b)
end

function main_f(args)
    names = isempty(args) ? ["P1", "C1"] : args
    for nm in names
        torque_probe(String(nm))
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_f(ARGS)

# ---------------------------------------------------------------------------
# Box dependence of the torque, and the physical-unit frequency table.
#
# <L_z> is ill-defined on a periodic box (x and y jump at the edge) — the defect
# that was misdiagnosed four times in the Barnett REDO. So the torque must be read
# as a RATIO (measured/predicted), not as an absolute, and the ratio is what has to
# converge under box variation.
# ---------------------------------------------------------------------------
function torque_box_scan(name; B_tilde=1000.0, n=64, boxes=(1.5, 2.5, 3.5), gpu=true)
    println("="^96)
    @printf("TORQUE BOX SCAN  cell %s  B_tilde=%.0f  (the ratio is what must converge)\n",
        name, B_tilde)
    println("="^96)
    println("  each row RE-CONVERGES the l=1 state in its own box (L-BFGS) first")
    @printf("  %8s %10s %14s %14s %12s %14s %10s\n",
        "box/sig", "box[L0]", "dJx/dt meas", "gamma(fxB)_x", "ratio",
        "dJz/dt (pred 0)", "f_perp")
    for bs in boxes
        r = try
            torque_probe(name; B_tilde=B_tilde, n=n, box_sigma=bs, gpu=gpu,
                reconverge=true)
        catch e
            @printf("  %8.2f FAILED: %s\n", bs, sprint(showerror, e))
            continue
        end
        @printf("  %8.2f %10.4f %14.4f %14.4f %12.6f %14.4f %10.5f\n",
            bs, r.b.box / r.b.S, r.dJdt[1], r.pred[1], r.dJdt[1] / r.pred[1],
            r.dJdt[3], r.f_perp)
        flush(stdout)
    end
end

"Physical units for each cell: T0, B0, and the Larmor frequency at B_tilde."
function physical_table(names; B_tilde=1000.0, n=64)
    hbar = SpinorBEC.Units.HBAR
    muB = SpinorBEC.Units.BOHR_MAGNETON
    println("="^110)
    println("PHYSICAL UNITS AND THE PREDICTED LARMOR FREQUENCY")
    println("="^110)
    @printf("%-5s %3s %8s %8s %9s %9s %9s %10s %10s %10s %10s\n",
        "cell", "F", "eps_dd", "N", "a_s[a0]", "L0[um]", "T0[s]", "B0[nT]",
        "B_y[nT]", "f_L[Hz]", "period[ms]")
    for nm in names
        f = joinpath(@__DIR__, "out", "torque_$(nm)_B$(round(Int,B_tilde))_n$(n).jld2")
        isfile(f) || (@printf("%-5s  (no torque file)\n", nm); continue)
        d = load(f)
        cell = CELLS[nm]
        base = SpinorBEC.ATOM_REGISTRY[cell.atom]
        a_dd = SpinorBEC.compute_a_dd(base)
        a_s = a_dd / cell.eps_dd
        L0 = a_s * cell.N
        T0 = base.mass * L0^2 / hbar
        g_muB = base.mu_mag / base.F
        B0 = hbar^2 / (base.mass * L0^2 * g_muB)
        omega = d["omega_L"]                         # in T0^-1
        @printf("%-5s %3d %8.4f %8d %9.2f %9.3f %9.4f %10.4f %10.3f %10.4f %10.2f\n",
            nm, base.F, cell.eps_dd, cell.N, a_s / SpinorBEC.Units.BOHR_RADIUS,
            L0 * 1e6, T0, B0 * 1e9, B_tilde * B0 * 1e9,
            omega / (2π * T0), 1e3 * 2π / omega * T0)
    end
    println()
    println("  Published field-offset systematic on the Eu apparatus: +/- 10 nT.")
    println("  Compare the B_y column against it BEFORE reading the f_L column as a")
    println("  measurable prediction.")
end

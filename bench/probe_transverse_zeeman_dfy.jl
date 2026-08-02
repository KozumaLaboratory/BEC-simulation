#!/usr/bin/env julia
# Which term sets the sign of d<Fy>/dt in the combined-spin-step fixture?
#
#   julia --project=. bench/probe_transverse_zeeman_dfy.jl
#
# `test/hamiltonian/test_combined_spin_step.jl:146,148` asserts `fy > 1e-4`
# after ONE step from m = +F under `H = -(bx F_x + bz F_z) + q F_z^2`, on the
# analytic ground that
#
#     d<Fy>/dt = i<[H, Fy]> = bx <Fz>  > 0   for bx > 0, <Fz> = +F.
#
# It measures -1.64e-3: right magnitude, wrong sign, 16x the threshold. Both
# the sequential and the combined path give the same wrong sign, so this is not
# a fusion/combination discrepancy — it is shared.
#
# But that fixture also switches on c_dd = 100, c0 = 50, c1 = 1 and q = 0.1,
# none of which the analytic claim accounts for, so as written it cannot
# distinguish "the transverse Zeeman propagator has an inverted sign" from "the
# other terms dominate and the test's premise is wrong". This turns the terms
# on one at a time.
#
# The transverse sign oracle in test/oracles/test_hamiltonian_sign_oracles.jl
# is green, but it measures the ITP GROUND STATE direction (+Bx -> <Fx> > 0),
# not one real-time step, so it does not cover this.
#
# Positive control: every row is run at +bx and -bx. If fy does not flip with
# bx, the measurement is not reading the transverse drive at all and no row
# means anything.

using SpinorBEC
using Printf

const GRID = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
const DT = 0.002

function fy_after_one_step(; bx, bz, q, c0, c1, c_dd, combined::Bool)
    sp = SimParams(; dt=DT, n_steps=1, imaginary_time=false)
    zeeman = TimeDependentZeeman(
        ConstantWaveform(bz), ConstantWaveform(q),
        ConstantWaveform(bx), ConstantWaveform(0.0),
    )
    ws = make_workspace(;
        grid=GRID, atom=Eu151,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman, potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp, enable_ddi=(c_dd != 0.0), c_dd=(c_dd == 0.0 ? NaN : c_dd),
    )
    copyto!(ws.state.psi, init_psi(GRID, SpinSystem(6); state=:m_plus_F))
    SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, 13, 3)
    # `split_step_combined!` refuses workspaces it cannot represent (c2 != 0,
    # and the rows below that switch interactions off). Report that rather than
    # dropping the whole table.
    try
        combined ? SpinorBEC.split_step_combined!(ws) : SpinorBEC.split_step!(ws)
    catch e
        e isa AssertionError || e isa ArgumentError || rethrow()
        return NaN
    end
    _, fy, _ = SpinorBEC.spin_density_vector(Array(ws.state.psi), ws.spin_matrices, 3)
    sum(fy) * SpinorBEC.cell_volume(ws.grid)
end

# Analytic prediction for the isolated transverse drive, <Fz> = F = 6 and the
# state normalised to one particle: d<Fy>/dt * dt = bx * F * dt.
predict(bx) = bx * 6 * DT

const ROWS = [
    ("zeeman only  (bx)", (bz=0.0, q=0.0, c0=0.0, c1=0.0, c_dd=0.0)),
    ("+ bz",              (bz=0.5, q=0.0, c0=0.0, c1=0.0, c_dd=0.0)),
    ("+ q",               (bz=0.5, q=0.1, c0=0.0, c1=0.0, c_dd=0.0)),
    ("+ contact c0",      (bz=0.5, q=0.1, c0=50.0, c1=0.0, c_dd=0.0)),
    ("+ spin c1",         (bz=0.5, q=0.1, c0=50.0, c1=1.0, c_dd=0.0)),
    ("+ DDI (fixture)",   (bz=0.5, q=0.1, c0=50.0, c1=1.0, c_dd=100.0)),
]

println("Transverse-Zeeman d<Fy>/dt probe — Eu151 F=6, 8^3, dt=$DT, one step from m=+F")
println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
println()
@printf("%-20s %-10s %12s %12s %12s %s\n",
    "terms enabled", "path", "fy(+bx)", "fy(-bx)", "predicted", "sign ok?")

for (label, kw) in ROWS, (pname, comb) in (("sequential", false), ("combined", true))
    fp = fy_after_one_step(; bx=0.4, kw..., combined=comb)
    fm = fy_after_one_step(; bx=-0.4, kw..., combined=comb)
    flips = sign(fp) != sign(fm) && abs(fp) > 0 && abs(fm) > 0
    ok = fp > 0 ? "yes" : "NO"
    @printf("%-20s %-10s %12.4e %12.4e %12.4e %s%s\n",
        label, pname, fp, fm, predict(0.4), ok,
        flips ? "" : "   [!! does not flip with bx — control failed]")
    flush(stdout)
end

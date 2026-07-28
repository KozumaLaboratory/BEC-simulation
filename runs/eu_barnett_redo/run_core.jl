# Decisive core for the rotation-driven magnetisation study (see README.md).
#
# Three stages: GS (static field along +x) -> stir (field rotating in the
# xy-plane at rate Omega) -> quench (B -> 0). One cell per invocation:
#
#   BR_CELL=plus        Omega > 0, DDI on      the J_z ledger
#   BR_CELL=minus       Omega < 0, DDI on      chirality (exact mirror of plus)
#   BR_CELL=zero        Omega = 0, DDI on      zero point (static field, no torque)
#   BR_CELL=plus_nodd   Omega > 0, DDI OFF     mechanism control
#
# The +- arms are mirror images by construction: Bx is IDENTICAL between them
# and only By is negated (reflection in the xz-plane, under which Omega -> -Omega,
# F_z -> -F_z, L_z -> -L_z and the GS spin along -x is invariant).
# `SinusoidalWaveform` is sin, so phase_x = -pi/2 puts B(0) = -x in EVERY cell,
# aligned with the ground-state spin -- no nutation kick in either arm.
#
# The workspace is built directly rather than through run_yaml because the J_z
# ledger needs a dense observable time series: reconstructing it from saved psi
# would cost ~25 GB per cell, against 21 GB free on the TSUBAME group volume.
import CUDA
using SpinorBEC
using JLD2, FFTW, Printf, LinearAlgebra

const CELL  = get(ENV, "BR_CELL", "plus")
const SMOKE = get(ENV, "SMOKE", "0") == "1"
const OUT   = joinpath(@__DIR__, "data")
mkpath(OUT)

CELL in ("plus", "minus", "zero", "plus_nodd") ||
    error("BR_CELL must be plus / minus / zero / plus_nodd, got \"$CELL\"")

const BACKEND = if CUDA.functional()
    CUDABackend()
elseif SMOKE
    CPUBackend()
else
    error("CUDA not functional — refusing a silent CPU fallback for a production cell")
end

# ---- parameters -------------------------------------------------------------
# Box sized by EDGE DENSITY, not cloud RMS: the J_z drift is a periodic-box
# artefact, flat in dt and in propagator order (test/oracles/test_jz_conservation_ddi.jl).
# R_TF ~ 5, so +-14 leaves ~3 Thomas-Fermi radii for the stirred cloud.
# n = 96 = 2^5*3 is FFT-friendly; the previous round's n = 112 = 2^4*7 was
# measured at ~66x the per-step cost of n = 80, and that factor-7 transform is
# a large part of why.
const NPTS    = SMOKE ? (32, 32, 16)    : (96, 96, 40)
const BOX     = SMOKE ? (16.0, 16.0, 8.0) : (28.0, 28.0, 12.0)
const OMEGA_TRAP = (1.0, 1.0, 2.0)
const N_ATOMS = 30000
const OMEGA_REF = 628.3                  # rad/s
const B_GAUSS = 9.216e-4                 # |p| = 15 (magnetostriction regime)
const OMEGA   = CELL == "zero" ? 0.0 : 0.74
const DDI_ON  = CELL != "plus_nodd"
# Overridable so a short job can measure s/step on the PRODUCTION grid and set
# the batch walltime from a number instead of an estimate. A 20-minute probe
# schedules in minutes where a 6-hour job waits over an hour.
const GS_STEPS = parse(Int, get(ENV, "BR_GS_STEPS", SMOKE ? "200" : "4000"))
const GS_DT    = 0.004
const T_STIR   = parse(Float64, get(ENV, "BR_T_STIR", SMOKE ? "0.4" : "30.0"))
const T_QUENCH = parse(Float64, get(ENV, "BR_T_QUENCH", SMOKE ? "0.4" : "50.0"))
const DT       = SMOKE ? 0.004 : 4.0e-4
const REC_EVERY = SMOKE ? 10 : 250
const PSI_FRAMES = 8                     # sparse full frames, for the vortex figure

# Mirror arms: Bx identical, By negated (phase_y = pi <=> By -> -By).
const PHASE_X = -π / 2
const PHASE_Y = CELL == "minus" ? 0.0 : π

const ATOM = SpinorBEC.resolve_atom(:Eu151)
const F_AT = ATOM.F
const D    = 2F_AT + 1
const SM   = spin_matrices(F_AT)
const P_ZEE = SpinorBEC.Units.bfield_to_p(B_GAUSS, ATOM.g_F, OMEGA_REF)
# q ∝ |B|^2: at 9.2e-4 G this is ~1e-3 Hz against omega_ref/2pi = 100 Hz, i.e.
# 1e-5 of the trap scale. Set to zero rather than carried as a rounding artefact.
const Q_ZEE = 0.0

const GRID = make_grid(GridConfig(NPTS, BOX))
const DV   = cell_volume(GRID)
const C0   = compute_c_total(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const C1   = -0.005 * C0
const C_DD = DDI_ON ? compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF) : 0.0
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const EPS_DD = SpinorBEC.compute_a_dd(ATOM) / ATOM.a_s
# Corrected scalar LHY coefficient (PR #108). The previous round's auto-derive
# was short by pi*(a_s/a_ho)*sqrt(N) = 3.87x here, putting LHY at 1.6% of the
# mean field instead of 6.2%.
const C_LHY = scalar_lhy_coefficient(ATOM.a_s / A_HO, N_ATOMS; eps_dd=EPS_DD)

const V_TRAP = let V = zeros(Float64, NPTS...)
    for I in CartesianIndices(V)
        V[I] = 0.5 * sum(OMEGA_TRAP[d]^2 * GRID.x[d][I[d]]^2 for d in 1:3)
    end
    V
end

interactions() = InteractionParams(Dict(0 => C0, 1 => C1); c_lhy=C_LHY)

function build_ws(psi_init, zee, sp)
    ws = make_workspace(; grid=GRID, atom=ATOM, interactions=interactions(),
        zeeman=zee, potential=NoPotential(), sim_params=sp,
        psi_init=psi_init, enable_ddi=DDI_ON, c_dd=C_DD, backend=BACKEND)
    copyto!(ws.potential_values, V_TRAP)
    ws
end

# ---- observables ------------------------------------------------------------
const PLANS = make_fft_plans(NPTS; flags=FFTW.ESTIMATE)
const EDGE_LIM = BOX[1] / 2 - 0.5

"""
(t, Fx, Fy, Fz, |F|, Lz, Jz, edge_frac, norm) for the current state.

`edge_frac` travels with every row because it, not dt, is what controls J_z
conservation — a reader must be able to see the ledger's error budget without
re-running anything.
"""
function observe(psi_host, t)
    fx, fy, fz = spin_density_vector(psi_host, SM, 3)
    Fx = sum(fx) * DV; Fy = sum(fy) * DV; Fz = sum(fz) * DV
    Lz = orbital_angular_momentum(psi_host, GRID, PLANS)
    nden = dropdims(sum(abs2, psi_host; dims=4); dims=4)
    tot = sum(nden); ef = 0.0
    xg, yg, _ = GRID.x
    for k in axes(nden, 3), j in axes(nden, 2), i in axes(nden, 1)
        (abs(xg[i]) > EDGE_LIM || abs(yg[j]) > EDGE_LIM) && (ef += nden[i, j, k])
    end
    (t, Fx, Fy, Fz, sqrt(Fx^2 + Fy^2 + Fz^2), Lz, Fz + Lz, ef / tot, tot * DV)
end

function write_csv(path, rows)
    open(path, "w") do io
        println(io, "t,Fx,Fy,Fz,Fmag,Lz,Jz,edge_frac,norm")
        for r in rows
            @printf(io, "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.3e,%.8f\n", r...)
        end
    end
    println("[redo] wrote $path"); flush(stdout)
end

# ---- stage 1: ground state --------------------------------------------------
# Seed the spin coherent state ALONG -x, which is where the Zeeman ground state
# is: p < 0 for g_F > 0, so <F> sits anti-parallel to B. Seeding along +x (as
# the previous round did) puts the seed on the unstable maximum and relies on an
# instability to flip it.
function gs_seed()
    chi = exp(-im * π * Matrix(SM.Fz)) * exp(-im * (π / 2) * Matrix(SM.Fy)) *
          ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:D]
    psi = zeros(ComplexF64, NPTS..., D)
    σ = 2.5
    for k in axes(psi, 3), j in axes(psi, 2), i in axes(psi, 1)
        x = GRID.x[1][i]; y = GRID.x[2][j]; z = GRID.x[3][k]
        env = exp(-(x^2 + y^2 + OMEGA_TRAP[3] * z^2) / (2σ^2))
        for c in 1:D
            psi[i, j, k, c] = env * chi[c]
        end
    end
    psi ./ sqrt(sum(abs2, psi) * DV)
end

function run_gs()
    zee = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(Q_ZEE),
        ConstantWaveform(P_ZEE), ConstantWaveform(0.0),   # B along +x
    )
    ws = build_ws(gs_seed(), zee,
        SimParams(; dt=GS_DT, n_steps=GS_STEPS, imaginary_time=true, normalize_every=0))
    μ = 0.0
    for step in 1:GS_STEPS
        split_step!(ws)
        nrm = sqrt(sum(abs2, ws.state.psi) * DV)
        if nrm > 0
            μ = -log(nrm) / (2 * GS_DT)
            ws.state.psi ./= nrm
        end
        if step % max(1, GS_STEPS ÷ 10) == 0
            @printf("  ITP %d/%d  mu=%.6f\n", step, GS_STEPS, μ); flush(stdout)
        end
    end
    psi = Array(ws.state.psi)
    o = observe(psi, 0.0)
    @printf("[redo] GS: <F> = (%+.4f, %+.4f, %+.4f)  |F| = %.4f  Lz = %+.4f  edge = %.2e\n",
            o[2], o[3], o[4], o[5], o[6], o[8]); flush(stdout)
    abs(o[2]) > 0.9 * F_AT || @warn "GS spin is not polarised along x — check the seed" o
    psi
end

# ---- stages 2-3: stir / quench ----------------------------------------------
function run_dynamics(psi0, stage_sym, t0, rows, frames)
    dur = stage_sym === :stir ? T_STIR : T_QUENCH
    n_steps = round(Int, dur / DT)
    zee = if stage_sym === :stir
        freq = OMEGA / (2π)
        TimeDependentZeeman(
            ConstantWaveform(0.0), ConstantWaveform(Q_ZEE),
            SinusoidalWaveform(; amplitude=P_ZEE, frequency=freq, phase=PHASE_X),
            SinusoidalWaveform(; amplitude=P_ZEE, frequency=freq, phase=PHASE_Y),
        )
    else
        TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
                            ConstantWaveform(0.0), ConstantWaveform(0.0))
    end
    ws = build_ws(psi0, zee,
        SimParams(; dt=DT, n_steps, imaginary_time=false, save_every=n_steps))
    frame_every = max(1, n_steps ÷ PSI_FRAMES)

    push!(rows, observe(Array(ws.state.psi), t0))
    t_start = time()
    for step in 1:n_steps
        # 2nd order with the DDI active: plain split_step! freezes the dipolar
        # mean field at each V(dt/2) boundary and drops to O(dt) once c_dd > 0.
        split_step_midpoint!(ws)
        if step % REC_EVERY == 0
            push!(rows, observe(Array(ws.state.psi), t0 + step * DT))
        end
        if step % frame_every == 0
            push!(frames, (t0 + step * DT, ComplexF32.(Array(ws.state.psi))))
        end
        if step % max(1, n_steps ÷ 10) == 0
            el = time() - t_start
            @printf("  %s %d/%d  t=%.3f  Fz=%+.4f Lz=%+.4f Jz=%+.4f edge=%.1e  [%.0fs, ETA %.0fs]\n",
                    stage_sym, step, n_steps, t0 + step * DT,
                    rows[end][4], rows[end][6], rows[end][7], rows[end][8],
                    el, el / step * (n_steps - step)); flush(stdout)
        end
    end
    Array(ws.state.psi)
end

# ---- main -------------------------------------------------------------------
println("="^74)
println("BARNETT REDO — cell=$CELL  Omega=$OMEGA  DDI=$DDI_ON  smoke=$SMOKE")
@printf("  grid=%s box=%s dt=%g  stir=%g quench=%g\n", NPTS, BOX, DT, T_STIR, T_QUENCH)
@printf("  p=%.4f (B=%g G)  c0=%.1f c1=%.3f c_dd=%.3f c_lhy=%.4g eps_dd=%.4f\n",
        P_ZEE, B_GAUSS, C0, C1, C_DD, C_LHY, EPS_DD)
@printf("  phase_x=%+.4f phase_y=%+.4f  => B(0) = (%+.3f, %+.3f) x |p|\n",
        PHASE_X, PHASE_Y, sin(PHASE_X), sin(PHASE_Y))
println("="^74); flush(stdout)

rows = NTuple{9, Float64}[]
frames = Tuple{Float64, Array{ComplexF32, 4}}[]

psi_gs = run_gs()
psi_stir = run_dynamics(psi_gs, :stir, 0.0, rows, frames)
run_dynamics(psi_stir, :quench, T_STIR, rows, frames)

tag = SMOKE ? "smoke_$CELL" : CELL
write_csv(joinpath(OUT, "ledger_$tag.csv"), rows)

jldopen(joinpath(OUT, "frames_$tag.jld2"), "w") do f
    f["cell"] = CELL; f["omega"] = OMEGA; f["ddi"] = DDI_ON
    f["box"] = collect(BOX); f["n"] = collect(NPTS); f["t_stir"] = T_STIR
    for (i, (t, psi)) in enumerate(frames)
        f["frame_$(lpad(i, 3, '0'))/t"] = t
        f["frame_$(lpad(i, 3, '0'))/psi"] = psi
    end
    f["n_frames"] = length(frames)
end

# J_z is NOT conserved during the stir — the rotating field is an external
# torque and injecting angular momentum is the whole point of that stage. It IS
# conserved during the quench (B = 0), so that stage alone is the ledger, and
# its drift is the error bar on the conversion. Reporting a single start-to-end
# "drift" would conflate the physics with the numerics.
const IQ = findfirst(r -> r[1] >= T_STIR, rows)
jz_stir0, jz_stirE = rows[1][7], rows[IQ][7]
jz_q0,    jz_qE    = rows[IQ][7], rows[end][7]
fz_q0,    fz_qE    = rows[IQ][4], rows[end][4]
lz_q0,    lz_qE    = rows[IQ][6], rows[end][6]
conv = abs(fz_qE - fz_q0)
leak = abs(jz_qE - jz_q0)

@printf("\n[redo] DONE %s\n", CELL)
println("  stir (B on, J_z injected — not a conservation law here):")
@printf("    J_z %+.4f -> %+.4f   L_z %+.4f -> %+.4f   F_z %+.4f -> %+.4f\n",
        jz_stir0, jz_stirE, rows[1][6], rows[IQ][6], rows[1][4], rows[IQ][4])
println("  quench (B = 0, J_z conserved — THE ledger):")
@printf("    J_z %+.4f -> %+.4f   leak %.4f\n", jz_q0, jz_qE, leak)
@printf("    L_z %+.4f -> %+.4f   F_z %+.4f -> %+.4f   conversion %.4f\n",
        lz_q0, lz_qE, fz_q0, fz_qE, conv)
if conv < 1e-3
    # The Omega = 0 control converts nothing by construction; a leak/conversion
    # ratio there is 0/0 and means nothing.
    @printf("    (no conversion to speak of — leak %.2e is the whole signal)\n", leak)
else
    @printf("    leak / conversion = %.1f%%   %s\n", 100 * leak / conv,
            leak < 0.1 * conv ? "OK" : "TOO LARGE — enlarge the box before believing this")
end
@printf("  max edge_frac %.2e  (target <= 1e-6)\n", maximum(r[8] for r in rows))

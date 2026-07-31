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
# Output root. Defaults to the run directory, but BR_OUT can send results
# somewhere off the group volume. That is not a nicety: the group Lustre area is
# shared with two other users holding ~900 GB between them, and when it filled,
# a production cell died with a Bus error -- JLD2 mmaps its output, so a full
# filesystem is SIGBUS rather than a clean write error.
#
# Preferred destination: /gs/bs/work/<n>/<user>, which is a per-user area on a
# DIFFERENT filesystem (40 PB, no per-user block quota). $HOME also works and is
# a separate quota too, but it is only 25 GB -- fine for the ledger CSVs, not for
# a depot plus snapshots.
const OUT   = get(ENV, "BR_OUT", joinpath(@__DIR__, "data"))
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
# The box still gets sized by EDGE DENSITY (per axis, target <= 1e-6) so the
# wall cannot contaminate anything -- but it is NOT what drove the J_z leak.
# That reading, and the smooth fixture behind it in
# test/oracles/test_jz_conservation_ddi.jl, did not survive the production runs:
# fixing edge_z from 1.35e-3 to 1.0e-9 left the leak unchanged (1.63 -> 1.74),
# and the dx series below cut it 27x while the edge fraction got WORSE.
#
# FFT sizes keep small prime factors AND must be EVEN (GridConfig rejects odd
# n_points): 128 = 2^7, 80 = 2^4*5. 81 = 3^4 is FFT-friendly but odd, and it
# cost a whole submitted batch -- the smoke geometry is 32^3, so it never
# exercised the production grid. The previous round
# measured n = 112 = 2^4*7 at ~66x the per-step cost of n = 80, and that
# factor-7 transform is a large part of why.
#
# GEOMETRY IS MEASURED, NOT GUESSED (2026-07-29 dx-convergence series, probe
# stage lengths, fixed box 28x28x12):
#
#   dx     J_z at quench start    leak    conversion   leak/conv
#   0.44         7.754            6.265     0.851        736%
#   0.29        12.207            2.985     1.406        212%
#   0.22        12.495            0.230     1.447        15.9%
#
# All three quantities converge: the stir output moves +2.4% over the last
# refinement, the conversion +2.9%, and the leak collapses 27x. dx = 0.22 is
# therefore the production resolution. It is the ONLY knob that mattered --
# box, dt, periodic images and the Ronen cutoff were each ruled out by direct
# measurement, and the static DDI-torque scan explains why: the discretised
# kernel conserves J_z to 1e-16 for smooth states and violates it at O(1) once
# the state carries grid-scale structure.
#
# dt = 1e-3, not 4e-4: halving dt reproduces the leak to six digits, so the
# error is spatial and the finer step bought nothing but 2.5x the cost.
#
# The z half-box is 9 (not 6, not 12): at omega_z = 2 the cloud is thinner in z, but not
# nearly as much thinner as the first pass assumed. The 2026-07-28 batch ran
# box_z = 12 and its frames carry 1.3e-3 of the density in the outermost 0.5 of
# z against 3.5e-6 in x and y -- 1350x the 1e-6 target, and invisible because
# `edge_frac` only scanned x and y. Geometry is env-overridable so the leak can
# be scanned instead of argued about (see probe_leak.sh).
#
# Half-width 12 is sized from that batch's own z profile, not guessed: the z
# marginal decays with a length of ~0.45 from 2.4e-3 at |z| = 4.8, so reaching
# the 1e-6 target needs |z| >~ 8.5. 12 leaves margin for the extra spreading a
# non-reflecting boundary allows.
# n_z = 80, not 48: doubling box_z at fixed n_z would put dx_z = 0.5 against a
# healing length of ~0.2. z is the TIGHTEST axis (omega_z = 2), so it needs the
# finest resolution, not the coarsest. 80 = 2^4*5 keeps dx_z = 0.30, matching
# dx_xy = 0.29, at 2x the cell count of the 2026-07-28 batch.
const NPTS = let s = get(ENV, "BR_N", "")
    isempty(s) ? (SMOKE ? (32, 32, 16) : (128, 128, 80)) :
    NTuple{3, Int}(parse.(Int, split(s, ",")))
end
const BOX = let s = get(ENV, "BR_BOX", "")
    isempty(s) ? (SMOKE ? (16.0, 16.0, 8.0) : (28.0, 28.0, 18.0)) :
    NTuple{3, Float64}(parse.(Float64, split(s, ",")))
end
# Zero-padded, image-free DDI convolution. Off by default: it is ~8x the FFT
# work, and whether the images matter at all is exactly what the probe measures.
const DDI_PAD = get(ENV, "BR_PAD", "0") == "1"
# Real-space cutoff on the dipolar kernel. NaN = none (the default the batch ran
# with); 0 = auto (half the smallest box unpadded, the box diagonal padded);
# > 0 = that radius. A cutoff is what makes the discrete kernel the exact
# transform of a definite real-space interaction rather than a conditionally
# convergent lattice sum, so it is a candidate for the J_z leak in its own right.
const DDI_TRUNC = parse(Float64, get(ENV, "BR_TRUNC", "NaN"))
const OMEGA_TRAP = (1.0, 1.0, 2.0)
const N_ATOMS = 30000
const OMEGA_REF = 628.3                  # rad/s
const B_GAUSS = 9.216e-4                 # |p| = 15 (magnetostriction regime)
# Stir rate. `zero` pins it to 0 regardless — that cell IS the no-rotation
# control and must not be reachable by a typo in BR_OMEGA.
#
# The efficiency dF_z/|dL_z| = 0.99 was measured at Omega = 0.74 only. Whether it
# is universal or an accident of that rate is the obvious next question, and it
# has a prediction attached: the efficiency follows from J_z conservation plus
# the DDI being the only spin-orbit channel, neither of which references Omega,
# so it should be FLAT. The injected L_z, by contrast, is a driven response and
# should depend on Omega strongly.
const OMEGA   = CELL == "zero" ? 0.0 : parse(Float64, get(ENV, "BR_OMEGA", "0.74"))
const DDI_ON  = CELL != "plus_nodd"
# Overridable so a short job can measure s/step on the PRODUCTION grid and set
# the batch walltime from a number instead of an estimate. A 20-minute probe
# schedules in minutes where a 6-hour job waits over an hour.
const GS_STEPS = parse(Int, get(ENV, "BR_GS_STEPS", SMOKE ? "200" : "4000"))
const GS_DT    = 0.004
const T_STIR   = parse(Float64, get(ENV, "BR_T_STIR", SMOKE ? "0.4" : "30.0"))
const T_QUENCH = parse(Float64, get(ENV, "BR_T_QUENCH", SMOKE ? "0.4" : "50.0"))
const DT       = parse(Float64, get(ENV, "BR_DT", SMOKE ? "0.004" : "1.0e-3"))
const REC_EVERY = max(1, round(Int, 0.1 / DT))
const TAG_SUFFIX = get(ENV, "BR_TAG", "")
# Sparse full frames, for the vortex figure. 0 writes none — a geometry probe
# only needs the ledger, and the frames are 600 MB a cell.
const PSI_FRAMES = parse(Int, get(ENV, "BR_FRAMES", "8"))

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

# Validate the geometry BEFORE anything expensive. `GridConfig` requires even
# n_points, and the smoke path uses its own 32^3 grid, so a bad production
# geometry is invisible to `SMOKE=1` and only surfaces on the cluster. A batch
# of four jobs died 12 s in on n_z = 81 (odd) for exactly this reason.
# BR_CHECK=1 exits here, which makes a pre-submit geometry check free.
for (d, (np_, L)) in enumerate(zip(NPTS, BOX))
    iseven(np_) || error("n_points[$d] = $np_ is odd — GridConfig requires even")
    np_ > 0 || error("n_points[$d] = $np_ must be positive")
    L > 0 || error("box[$d] = $L must be positive")
end
let dxs = ntuple(d -> BOX[d] / NPTS[d], 3)
    @printf("  geometry OK: n=%s box=%s dx=(%.4f, %.4f, %.4f)\n", NPTS, BOX, dxs...)
    get(ENV, "BR_CHECK", "0") == "1" && exit(0)
end

# Orszag 2/3 dealiasing. The per-term J_z torque budget on a real post-quench
# state (torque_budget.jl) put the violation in the KINETIC term, ~5x the DDI:
# L_z does not map the discrete k-grid onto itself, so whatever the state carries
# near the Nyquist edge leaks angular momentum. The 2/3 filter removes exactly
# that band, which is why it is the direct treatment rather than yet more dx.
#
# Deliberately NO explicit k_cut: `DEALIAS_K_CUT` hard-codes a box of 12 on every
# axis, so on this 28x28x18 box it would cut the occupied band roughly in half.
# The default (n_d / 3 per axis, index space) is box-independent and is what we
# want.
if get(ENV, "BR_DEALIAS", "0") == "1"
    SpinorBEC.DEALIAS_2_3_ENABLED[] = true
    println("  dealias: Orszag 2/3 ON (index-space n/3 per axis, no k_cut override)")
end

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
        psi_init=psi_init, enable_ddi=DDI_ON, c_dd=C_DD, ddi_padding=DDI_PAD,
        ddi_trunc_radius=DDI_TRUNC, backend=BACKEND)
    copyto!(ws.potential_values, V_TRAP)
    ws
end

# ---- observables ------------------------------------------------------------
const PLANS = make_fft_plans(NPTS; flags=FFTW.ESTIMATE)
# Outermost 0.5 length-units of each axis, INDEPENDENTLY. The 2026-07-28 batch
# scanned one shared limit over x and y only; z was the tightest axis and the
# one that was never looked at.
const EDGE_LIM = ntuple(d -> BOX[d] / 2 - 0.5, 3)

"""
(t, Fx, Fy, Fz, |F|, Lz, Jz, edge_x, edge_y, edge_z, edge_frac, norm).

The edge fractions travel with every row because the box, not dt, is what
controls J_z conservation — a reader must be able to see the ledger's error
budget without re-running anything. `edge_frac` is the max over the axes, which
is the number the box has to be sized against.
"""
function observe(psi_host, t)
    fx, fy, fz = spin_density_vector(psi_host, SM, 3)
    Fx = sum(fx) * DV; Fy = sum(fy) * DV; Fz = sum(fz) * DV
    Lz = orbital_angular_momentum(psi_host, GRID, PLANS)
    nden = dropdims(sum(abs2, psi_host; dims=4); dims=4)
    tot = sum(nden)
    xg, yg, zg = GRID.x
    ex = ey = ez = 0.0
    for k in axes(nden, 3), j in axes(nden, 2), i in axes(nden, 1)
        n = nden[i, j, k]
        abs(xg[i]) > EDGE_LIM[1] && (ex += n)
        abs(yg[j]) > EDGE_LIM[2] && (ey += n)
        abs(zg[k]) > EDGE_LIM[3] && (ez += n)
    end
    ex /= tot; ey /= tot; ez /= tot
    (t, Fx, Fy, Fz, sqrt(Fx^2 + Fy^2 + Fz^2), Lz, Fz + Lz,
     ex, ey, ez, max(ex, ey, ez), tot * DV)
end

function write_csv(path, rows; quiet::Bool=false)
    tmp = path * ".tmp"
    open(tmp, "w") do io
        println(io, "t,Fx,Fy,Fz,Fmag,Lz,Jz,edge_x,edge_y,edge_z,edge_frac,norm")
        for r in rows
            @printf(io, "%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.3e,%.3e,%.3e,%.3e,%.8f\n", r...)
        end
    end
    mv(tmp, path; force=true)   # atomic: a kill mid-write cannot truncate the ledger
    quiet || (println("[redo] wrote $path"); flush(stdout))
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
            o[2], o[3], o[4], o[5], o[6], o[11]); flush(stdout)
    abs(o[2]) > 0.9 * F_AT || @warn "GS spin is not polarised along x — check the seed" o
    psi
end

# ---- stages 2-3: stir / quench ----------------------------------------------
function run_dynamics(psi0, stage_sym, t0, rows, frames; ledger_path=nothing)
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
    frame_every = PSI_FRAMES <= 0 ? typemax(Int) : max(1, n_steps ÷ PSI_FRAMES)

    push!(rows, observe(Array(ws.state.psi), t0))
    t_start = time()
    for step in 1:n_steps
        # 2nd order with the DDI active: plain split_step! freezes the dipolar
        # mean field at each V(dt/2) boundary and drops to O(dt) once c_dd > 0.
        split_step_midpoint!(ws)
        if step % REC_EVERY == 0
            push!(rows, observe(Array(ws.state.psi), t0 + step * DT))
            # Flush the ledger on every observation. It is a few hundred rows,
            # so rewriting is free, and it means a walltime kill leaves usable
            # data instead of nothing — which is what lets the batch be
            # submitted with a tight h_rt (short jobs schedule in minutes; the
            # 6-hour requests sat in qw for over an hour).
            ledger_path === nothing || write_csv(ledger_path, rows; quiet=true)
        end
        if step % frame_every == 0
            push!(frames, (t0 + step * DT, ComplexF32.(Array(ws.state.psi))))
        end
        if step % max(1, n_steps ÷ 10) == 0
            el = time() - t_start
            @printf("  %s %d/%d  t=%.3f  Fz=%+.4f Lz=%+.4f Jz=%+.4f edge=%.1e  [%.0fs, ETA %.0fs]\n",
                    stage_sym, step, n_steps, t0 + step * DT,
                    rows[end][4], rows[end][6], rows[end][7], rows[end][11],
                    el, el / step * (n_steps - step)); flush(stdout)
        end
    end
    Array(ws.state.psi)
end

# ---- main -------------------------------------------------------------------
println("="^74)
println("BARNETT REDO — cell=$CELL  Omega=$OMEGA  DDI=$DDI_ON  smoke=$SMOKE")
@printf("  grid=%s box=%s dt=%g  stir=%g quench=%g  ddi_padding=%s\n",
        NPTS, BOX, DT, T_STIR, T_QUENCH, DDI_PAD)
@printf("  p=%.4f (B=%g G)  c0=%.1f c1=%.3f c_dd=%.3f c_lhy=%.4g eps_dd=%.4f\n",
        P_ZEE, B_GAUSS, C0, C1, C_DD, C_LHY, EPS_DD)
@printf("  phase_x=%+.4f phase_y=%+.4f  => B(0) = (%+.3f, %+.3f) x |p|\n",
        PHASE_X, PHASE_Y, sin(PHASE_X), sin(PHASE_Y))
println("="^74); flush(stdout)

rows = NTuple{12, Float64}[]
frames = Tuple{Float64, Array{ComplexF32, 4}}[]

tag = (SMOKE ? "smoke_$CELL" : CELL) * TAG_SUFFIX
ledger = joinpath(OUT, "ledger_$tag.csv")

psi_gs = run_gs()
psi_stir = run_dynamics(psi_gs, :stir, 0.0, rows, frames; ledger_path=ledger)
run_dynamics(psi_stir, :quench, T_STIR, rows, frames; ledger_path=ledger)

write_csv(ledger, rows)

isempty(frames) || jldopen(joinpath(OUT, "frames_$tag.jld2"), "w") do f
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
            leak < 0.1 * conv ? "OK" : "TOO LARGE — REFINE dx before believing this (not the box: measured 2026-07-29)")
end
@printf("  max edge fraction: x %.2e  y %.2e  z %.2e   (target <= 1e-6 on EVERY axis)\n",
        maximum(r[8] for r in rows), maximum(r[9] for r in rows),
        maximum(r[10] for r in rows))
# One line per run, appended, so a geometry scan is a file rather than a pile of logs.
open(joinpath(OUT, "leak_scan.csv"), "a") do io
    @printf(io, "%s,%s,\"%s\",\"%s\",%g,%d,%.6f,%.6f,%.6f,%.3e,%.3e,%.3e\n",
            tag, CELL, NPTS, BOX, DT, DDI_PAD ? 1 : 0, leak, conv,
            lz_qE - lz_q0, maximum(r[8] for r in rows), maximum(r[9] for r in rows),
            maximum(r[10] for r in rows))
end

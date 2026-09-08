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
# Stir-stage field. 9.216e-4 G gives |p| = 15, and that value was never a physics
# choice: it is the largest field at which the LAB-FRAME split-step runs at a
# trap-scale dt. The Larmor angle per step is p*F*dt, so |p| = 15 at dt = 1e-3 is
# 5.2 deg, while 1 G (|p| = 16276) is 98 rad — 31x past the aliasing bound of pi, and
# Klaus et al. 2022's 5.333 G is 166x past it. The escape for real laboratory fields is
# `kind: rotating_basis`, which this driver does not use.
#
# Overridable because the field is a physics axis that has never been scanned: the
# conversion happens at B = 0 regardless, so a STRONGER stir field may inject more
# without costing anything — the DDI anisotropy is then more rigidly locked to B_hat.
# Raising it costs accuracy rather than time (dt is not rescaled automatically), so a
# high-field arm must be paired with a dt check.
const B_GAUSS = parse(Float64, get(ENV, "BR_B_GAUSS", "9.216e-4"))
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
# Observation interval in time units, not steps, so it survives a change of dt.
# 0.1 is the published cadence (802 rows over the 80-unit protocol, already enough
# for an animation at 60 fps). Halve it when the RAMP stages matter visually: a
# 5-unit tilt is 50 frames at 0.1 and 100 at 0.05.
const REC_DT = parse(Float64, get(ENV, "BR_REC_DT", "0.1"))
const REC_EVERY = max(1, round(Int, REC_DT / DT))
const TAG_SUFFIX = get(ENV, "BR_TAG", "")
# Sparse full frames, for the vortex figure. 0 writes none — a geometry probe
# only needs the ledger, and the frames are 600 MB a cell.
const PSI_FRAMES = parse(Int, get(ENV, "BR_FRAMES", "8"))

# Mirror arms: Bx identical, By negated (phase_y = pi <=> By -> -By).
const PHASE_X = -π / 2
const PHASE_Y = CELL == "minus" ? 0.0 : π

# Polar angle of B from +z. DEFAULT 90 degrees = the field strictly in the xy-plane,
# which is what every cell in the README ran and what makes <F_z>(0) = 0.
#
# WHY IT IS A KNOB NOW. At theta = 90 the +-Omega arms are related by a pi rotation
# about x (B_x -> B_x, B_y -> -B_y, B_z -> -B_z, F_z -> -F_z, L_z -> -L_z), and with
# B_z = 0 that maps the +Omega run onto the -Omega run exactly -- which is why they
# agree bit-for-bit and why the sign reversal is a symmetry rather than a
# measurement. Tilt the field and the SAME rotation flips B_z too, so the partner of
# (+Omega, +B_z) is (-Omega, -B_z): at fixed tilt the two senses of rotation are no
# longer symmetry-related and a genuine chirality asymmetry becomes measurable.
# Klaus et al. 2022 tilt by 35 degrees; so does the thesis protocol.
#
# The cost is a pedestal: at 35 degrees <F_z>(0) = -6 cos(35) = -4.92 against a
# Barnett signal of ~1, so the RATIO dF_z/|dL_z| stays readable while the sign story
# does not. `BR_BZSIGN=-1` negates the axial component, which together with
# CELL=minus builds the TRUE mirror of a tilted arm -- the control that must agree.
const THETA = deg2rad(parse(Float64, get(ENV, "BR_THETA", "90")))
const BZ_SIGN = parse(Float64, get(ENV, "BR_BZSIGN", "1"))

# Protocol shape. `sudden` is the published one: the field appears already rotating,
# and it is kick-free ONLY because at theta = 90 the ground-state spin is collinear
# with it (measured: the angle between the GS spin and B_stir(0) is 0 deg at theta =
# 90, but 110 deg at 35 deg, with sin = 0.94 — near-maximal torque). So a tilted
# `sudden` arm starts with a violent nutation, which is the failure
# `runs/magnetic_stirrer/magnetic_stirrer_adiabatic_omega_p0p5.yaml` already
# recorded: "the spin failed to track the new B direction, so DDI anisotropy
# rotation had no spin sector to act on".
#
# `adiabatic` is the Klaus-style shape: prepare along +z, tilt slowly at fixed |B|
# (omega_L >> dtheta/dt), spin phi up slowly, then hold, then quench. The spin stays
# ANTI-parallel to B_hat throughout, i.e. in the Zeeman GROUND state — which is the
# side `edh-requires-anti-aligned-preparation` measured at -0.45 % against +16.5 %,
# so a weak or absent cascade here is a RESULT and not a failure of the ramp. The
# ramp's own success is checked separately, by tracking the alignment.
const PROTOCOL = get(ENV, "BR_PROTOCOL", "sudden")
PROTOCOL in ("sudden", "adiabatic") ||
    error("BR_PROTOCOL must be sudden or adiabatic, got \"$PROTOCOL\"")
const T_TILT   = parse(Float64, get(ENV, "BR_T_TILT", SMOKE ? "0.2" : "5.0"))
const T_SPINUP = parse(Float64, get(ENV, "BR_T_SPINUP", SMOKE ? "0.2" : "5.0"))

# --- the ending the protocol actually calls for ------------------------------
# The field starts along +z (THETA_GS = 0) with the spin anti-parallel at m=-F,
# tilts to THETA for the stir, and should come BACK to +z at the end — weak, so
# that it supplies a quantisation axis without dragging the spin back with it.
# B along z keeps [H, J_z] = 0 (axisymmetric trap, Zeeman ∝ F_z and F_z^2, DDI
# invariant under a simultaneous z rotation), so Noether still holds exactly:
# a weak axial field is strictly better than B = 0, which has no axis at all.
#
# DEFAULTS REPRODUCE THE OLD BEHAVIOUR: B_FINAL = 0 and T_RAMPDOWN = 0 give the
# instantaneous B -> 0 quench that every run before 2026-08-28 used, so the
# existing comparison set is not silently redefined.
const B_FINAL_GAUSS = parse(Float64, get(ENV, "BR_B_FINAL_GAUSS", "0.0"))
# Two stages, not one, and in this order: rotate at the full field (where
# adiabatic following is cheap), THEN lower |B| (where there is no direction to
# follow). Ramping both at once would have to be adiabatic at the WEAK field,
# which is the hardest point of the whole schedule for no gain.
const T_ROT_BACK   = parse(Float64, get(ENV, "BR_T_ROT_BACK", SMOKE ? "0.2" : "0.0"))
const T_FIELD_DOWN = parse(Float64, get(ENV, "BR_T_FIELD_DOWN", SMOKE ? "0.2" : "0.0"))
const T_RAMPDOWN = T_ROT_BACK + T_FIELD_DOWN
# P_FINAL is defined next to P_ZEE below: it needs ATOM, which is not in scope here.

const ATOM = SpinorBEC.resolve_atom(:Eu151)
const F_AT = ATOM.F
const D    = 2F_AT + 1
const SM   = spin_matrices(F_AT)
const P_ZEE = SpinorBEC.Units.bfield_to_p(B_GAUSS, ATOM.g_F, OMEGA_REF)
# The field held after the ramp-down, in the same p units. 0 (default) = the
# historical B -> 0 quench; non-zero leaves a weak axial field along BZ_SIGN * z.
const P_FINAL = SpinorBEC.Units.bfield_to_p(B_FINAL_GAUSS, ATOM.g_F, OMEGA_REF)
# Axial and in-plane components of the SAME |B|, so tilting does not change the
# field magnitude (the paper's own systematic: tilting shifts |B| unless the coils
# are re-set, and it is corrected for there).
const P_AXIAL = BZ_SIGN * P_ZEE * cos(THETA)
const P_PERP  = P_ZEE * sin(THETA)
# The ADIABATIC protocol prepares along +z and tilts from there, so its ground state
# is at theta = 0 while THETA is the TARGET tilt.
const THETA_GS = PROTOCOL == "adiabatic" ? 0.0 : THETA
p_axial_of(theta) = BZ_SIGN * P_ZEE * cos(theta)
p_perp_of(theta) = P_ZEE * sin(theta)
# Chirality: phi -> -phi, i.e. p_y negated. Same operation as the published arms'
# "negate B_y", written once so the ramp stages and the steady stage cannot disagree.
const CHIR = CELL == "minus" ? -1.0 : 1.0
# Ground-state spin sits ANTI-parallel to B (p < 0 for g_F > 0), so the seed points
# along -B_hat = (-sin θ, 0, -sign·cos θ): polar angle acos(-sign·cos θ), azimuth π.
# At θ = 90 this is acos(0) = π/2 and reduces to the previous seed exactly; at the
# adiabatic protocol's θ_GS = 0 it is acos(-1) = π, i.e. the spin along -z.
const SEED_POLAR = acos(clamp(-BZ_SIGN * cos(THETA_GS), -1.0, 1.0))
# Where the quench begins. The published protocol has one stir stage, so it is
# T_STIR; the adiabatic one has two ramps in front of the same steady stage. Every
# downstream reduction slices on THIS, not on T_STIR — reading an adiabatic ledger
# with the published boundary would take the last 10 units of the steady stage and
# call them the quench.
const T_QUENCH_START = PROTOCOL == "adiabatic" ? T_TILT + T_SPINUP + T_STIR : T_STIR
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
# ---- z-integrated maps, for an animation ------------------------------------
# A density/vortex movie needs MANY frames and a full psi frame is 273 MB at
# production size, so the 8 frames `PSI_FRAMES` keeps are 0.5 s of video at 15 fps
# and cannot be more. The z-integrated maps are 240x240 Float32 = 230 kB, so an
# 800-frame movie is 180 MB. Off by default; `BR_COLFRAMES=1` turns it on and the
# maps are written every observation, i.e. at the ledger's own cadence.
#
# This recomputes the density that `observe` also builds. That is one extra pass
# over the host array against a split step, and keeping it separate means the
# claim-carrying observable path is untouched by a visualisation flag.
const COL_FRAMES = get(ENV, "BR_COLFRAMES", "0") == "1"

function column_maps(psi_host)
    nden = dropdims(sum(abs2, psi_host; dims=4); dims=4)
    _, _, fz = spin_density_vector(psi_host, SM, 3)
    (Float32.(dropdims(sum(nden; dims=3); dims=3) .* DV),
     Float32.(dropdims(sum(fz; dims=3); dims=3) .* DV))
end

# The mid-plane spinor, for a PHASE census. Column maps cannot answer whether the
# injected L_z sits in quantised vortices: a z-integrated density washes out cores and
# carries no phase at all. A single z slice does, at 240x240x13 ComplexF32 = 3.0 MB,
# so a coarse cadence is affordable where full psi frames (273 MB each) are not.
#
# WHY THIS EXISTS AT ALL. The study's own vortex check was listed as optional and never
# run, and the psi frames it would have needed are unusable: `frames_plus.jld2` has no
# superblock, and the other three open but contain zeros — nonzero element counts of
# 272, 247, 222 ... falling by exactly 25 per frame out of 17 M. They were written
# 2026-07-28, when the group volume was full (1053/1000 GB), and JLD2 mmaps its output,
# so a full filesystem yields a right-sized file of zeros instead of an error.
const SLICE_EVERY = parse(Float64, get(ENV, "BR_SLICE_DT", "0"))   # 0 = off

function midplane_slice(psi_host)
    kz = size(psi_host, 3) ÷ 2 + 1
    ComplexF32.(psi_host[:, :, kz, :])
end

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
    chi = exp(-im * π * Matrix(SM.Fz)) * exp(-im * SEED_POLAR * Matrix(SM.Fy)) *
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
    # THETA_GS, not THETA. Under the adiabatic protocol the ground state is prepared at
    # theta = 0 and the tilt stage ramps from there; building it at THETA instead put
    # the field 35 degrees away from where the tilt stage starts, so the field JUMPED
    # 35 degrees at t = 0 and the "adiabatic" ramp was recovering from a kick. It shows
    # up as a 15-degree spin lag at the tilt end (alignment 0.966, not ~1) and a 16 %
    # drop in |F| across a ramp that should not depolarise at all.
    zee = TimeDependentZeeman(
        ConstantWaveform(p_axial_of(THETA_GS)), ConstantWaveform(Q_ZEE),
        ConstantWaveform(p_perp_of(THETA_GS)), ConstantWaveform(0.0),
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
    # Anti-parallel to B_hat, not "along x": at theta = 90 those coincide, and the
    # first version of this guard would have fired a false warning on every tilted
    # arm (<F_x> = -6 sin(35) = -3.44, well under 0.9 F).
    let along = -(o[2] * sin(THETA) + o[4] * BZ_SIGN * cos(THETA))
        along > 0.9 * F_AT ||
            @warn "GS spin is not anti-parallel to B — check the seed" along F_AT THETA o
    end
    psi
end

# ---- the shape of the field ramp-down ---------------------------------------
# The adiabaticity condition on |B| is LOCAL: |dp/dt| < A p^2, because the gap
# holding the spin-mixing channel shut is p itself. A ramp that is linear in p
# therefore satisfies it at the start and violates it by three orders at the
# end, and paying for that with a longer linear ramp is the wrong currency:
# constant-A costs T = (1/|p_f| - 1/|p_i|) / A, while linear-at-the-same-final-A
# costs (|p_i| - |p_f|) / (A p_f^2). At A = 0.1 that is 20.5 against 3.7e4 --
# a factor 1800, and the whole reason "adiabatic is impossible here" was wrong
# when I first said it on 2026-09-09.
#
# Constant A is harmonic interpolation in p: 1/p linear in t. Same endpoints,
# same monotonicity, exponentially more time spent where the gap is small.
const FIELD_DOWN_SHAPE = get(ENV, "BR_FIELD_DOWN_SHAPE", "linear")
FIELD_DOWN_SHAPE in ("linear", "adiabatic") ||
    error("BR_FIELD_DOWN_SHAPE must be linear or adiabatic, got $FIELD_DOWN_SHAPE")
# B_FINAL = 0 has no adiabatic ramp AT ALL: 1/p_f diverges, and physically you
# cannot follow a gap that closes to zero. Refuse rather than silently fall back
# to linear, which would report an adiabatic run that was not one.
if FIELD_DOWN_SHAPE == "adiabatic" && P_FINAL == 0
    error("BR_FIELD_DOWN_SHAPE=adiabatic needs BR_B_FINAL_GAUSS > 0; " *
          "a gap that closes to zero cannot be followed at any ramp rate")
end

_field_down_amp(t) =
    if FIELD_DOWN_SHAPE == "linear"
        P_ZEE + (P_FINAL - P_ZEE) * (t / T_FIELD_DOWN)
    else
        s = t / T_FIELD_DOWN
        1 / ((1 - s) / P_ZEE + s / P_FINAL)
    end

# The achieved A, printed so the log states it rather than the submitter claiming it.
field_down_A() = T_FIELD_DOWN <= 0 ? NaN :
    FIELD_DOWN_SHAPE == "adiabatic" ?
        abs(1 / P_FINAL - 1 / P_ZEE) / T_FIELD_DOWN :        # constant along the ramp
        abs(P_FINAL - P_ZEE) / T_FIELD_DOWN / P_FINAL^2      # worst point (the end)

# ---- stages 2-3: stir / hold ------------------------------------------------
stage_duration(s) =
    s === :stir     ? T_STIR   :
    s === :tilt     ? T_TILT   :
    s === :spinup   ? T_SPINUP :
    s === :steady   ? T_STIR   :
    s === :rotate_back ? T_ROT_BACK :
    s === :field_down  ? T_FIELD_DOWN : T_QUENCH

# theta(t) and phi(t) sampled into InterpolatedWaveforms rather than stored as
# closures: CLAUDE.md's rule is to pre-evaluate `t -> ...` before a waveform reaches
# a Workspace field, and a ramp of cos/sin of a linear function is not piecewise
# linear, so sampling is the honest form. One sample per 10 steps, floor 64.
# `amp_of(t)` is the field MAGNITUDE in p units, defaulting to the stir value. It
# exists because the protocol ends by bringing B back to +z and WEAK, and until
# 2026-08-28 the magnitude was fixed inside a stage: theta and phi were functions
# of t, |B| was the constant P_ZEE, so "ramp the field down" was inexpressible.
# The quench then set all four waveforms to zero, which removes the quantisation
# axis entirely rather than leaving a small one.
function ramp_zee(theta_of, phi_of, T; amp_of = _ -> P_ZEE)
    n = max(64, ceil(Int, T / (10 * DT)))
    ts = collect(range(0.0, T; length=n + 1))
    # p_axial_of / p_perp_of carry the full P_ZEE, so rescale by amp/P_ZEE rather
    # than rebuilding them — that keeps BZ_SIGN and the sign convention in one place.
    sc = [P_ZEE == 0 ? 0.0 : amp_of(t) / P_ZEE for t in ts]
    pz = [s * p_axial_of(theta_of(t)) for (s, t) in zip(sc, ts)]
    px = [s * p_perp_of(theta_of(t)) * cos(phi_of(t)) for (s, t) in zip(sc, ts)]
    py = [s * CHIR * p_perp_of(theta_of(t)) * sin(phi_of(t)) for (s, t) in zip(sc, ts)]
    # q is even in B, so it scales as (|B|/B_stir)^2.
    qs = [Q_ZEE * s^2 for s in sc]
    TimeDependentZeeman(InterpolatedWaveform(ts, pz), InterpolatedWaveform(ts, qs),
                        InterpolatedWaveform(ts, px), InterpolatedWaveform(ts, py))
end

# Azimuth reached by the end of the spin-up, so the steady stage continues the same
# phase instead of restarting it: phi(t) = OMEGA t^2 / (2 T) integrates a rate ramped
# linearly from 0 to OMEGA.
const PHI_AFTER_SPINUP = OMEGA * T_SPINUP / 2

# B_hat at the end of a stage, for the adiabaticity check.
bhat_at(theta, phi) = (sin(theta) * cos(phi), CHIR * sin(theta) * sin(phi),
                       BZ_SIGN * cos(theta))
stage_end_bhat(s) =
    s === :tilt   ? bhat_at(THETA, 0.0) :
    s === :spinup ? bhat_at(THETA, PHI_AFTER_SPINUP) :
    s === :steady ? bhat_at(THETA, PHI_AFTER_SPINUP + OMEGA * T_STIR) :
    # The ramp-down ends with B back along +z. Whether the SPIN follows it there is
    # the measurement, not a check — a weak final field is chosen precisely so it
    # cannot drag the spin back, so this alignment is EXPECTED to be poor and the
    # warning it prints is information, not a failure.
    s === :rotate_back ? bhat_at(0.0, 0.0) :
    s === :field_down  ? bhat_at(0.0, 0.0) : nothing

function run_dynamics(psi0, stage_sym, t0, rows, frames; ledger_path=nothing,
                      colframes=nothing, slices=nothing, last_slice=Ref(-Inf))
    dur = stage_duration(stage_sym)
    n_steps = round(Int, dur / DT)
    freq = OMEGA / (2π)
    zee = if stage_sym === :stir
        # The PUBLISHED shape, untouched: the field appears already rotating, with
        # B_perp(0) ANTI-parallel to the ground-state field, so the spin starts
        # PARALLEL to B (Zeeman-highest) and collinear — torque-free only because
        # theta = 90 leaves nothing out of plane.
        TimeDependentZeeman(
            ConstantWaveform(P_AXIAL), ConstantWaveform(Q_ZEE),
            SinusoidalWaveform(; amplitude=P_PERP, frequency=freq, phase=PHASE_X),
            SinusoidalWaveform(; amplitude=P_PERP, frequency=freq, phase=PHASE_Y),
        )
    elseif stage_sym === :tilt
        ramp_zee(t -> THETA * (t / T_TILT), _ -> 0.0, T_TILT)
    elseif stage_sym === :spinup
        ramp_zee(_ -> THETA, t -> OMEGA * t^2 / (2 * T_SPINUP), T_SPINUP)
    elseif stage_sym === :steady
        # Exact sinusoids continuing the spin-up's phase; p_x = P sin(Ωt + φ0 + π/2)
        # is P cos(φ0 + Ωt), p_y = CHIR P sin(φ0 + Ωt).
        pp = p_perp_of(THETA)
        TimeDependentZeeman(
            ConstantWaveform(p_axial_of(THETA)), ConstantWaveform(Q_ZEE),
            SinusoidalWaveform(; amplitude=pp, frequency=freq,
                               phase=PHI_AFTER_SPINUP + π / 2),
            SinusoidalWaveform(; amplitude=CHIR * pp, frequency=freq,
                               phase=PHI_AFTER_SPINUP),
        )
    elseif stage_sym === :rotate_back
        # theta THETA -> 0 at the FULL stir field. Ordering matters and this is the
        # easy one: adiabatic following needs dtheta/dt << omega_L, and at the stir
        # field omega_L = 15 against dtheta/dt = 0.611/T = 0.12, a factor 123. Doing
        # this at the WEAK field instead would put omega_L at 1.6 and the margin at
        # 13 — still adiabatic, but for no reason, since |B| need not be small yet.
        # phi keeps turning so the shrinking in-plane component does not jerk.
        ramp_zee(t -> THETA * (1 - t / T_ROT_BACK),
                 t -> PHI_AFTER_SPINUP + OMEGA * (T_STIR + t), T_ROT_BACK)
    elseif stage_sym === :field_down
        # |B| P_ZEE -> P_FINAL along +z. This comment used to say "no direction
        # change, so there is no adiabaticity condition to satisfy at all".
        # That is true of the DIRECTION and false of the MAGNITUDE, and the
        # magnitude is the whole point of the stage: lowering |B| closes the
        # Zeeman gap that was holding the spin-mixing channel shut, so there is
        # an adiabaticity condition and it is the hardest one in the schedule.
        # Measured 2026-09-09: with the linear shape below, A = |dp/dt|/gap^2
        # crosses 1 at p = 22.1 (1.36 mG) and reaches 2050 at the final 30 uG,
        # i.e. the last 4.4 % of the ramp is crossed 62x faster than the
        # spin-mixing time 1/(c_dd n) = 2.74. Omega = 0 oscillates for this
        # reason and no other -- the DDI-off arm is flat to 1e-4.
        ramp_zee(_ -> 0.0, _ -> 0.0, T_FIELD_DOWN; amp_of = _field_down_amp)
    else
        # The hold. P_FINAL = 0 (the default) reproduces the historical B = 0
        # quench exactly; a non-zero value leaves a weak axial field, which is
        # what the protocol wants and what keeps a quantisation axis.
        q_final = P_ZEE == 0 ? 0.0 : Q_ZEE * (P_FINAL / P_ZEE)^2
        TimeDependentZeeman(ConstantWaveform(BZ_SIGN * P_FINAL), ConstantWaveform(q_final),
                            ConstantWaveform(0.0), ConstantWaveform(0.0))
    end
    ws = build_ws(psi0, zee,
        SimParams(; dt=DT, n_steps, imaginary_time=false, save_every=n_steps))
    frame_every = PSI_FRAMES <= 0 ? typemax(Int) : max(1, n_steps ÷ PSI_FRAMES)

    let psi0_host = Array(ws.state.psi)
        push!(rows, observe(psi0_host, t0))
        colframes === nothing || push!(colframes, (t0, column_maps(psi0_host)...))
        if slices !== nothing && t0 - last_slice[] >= SLICE_EVERY - 1e-9
            push!(slices, (t0, midplane_slice(psi0_host)))
            last_slice[] = t0
        end
    end
    t_start = time()
    for step in 1:n_steps
        # 2nd order with the DDI active: plain split_step! freezes the dipolar
        # mean field at each V(dt/2) boundary and drops to O(dt) once c_dd > 0.
        split_step_midpoint!(ws)
        if step % REC_EVERY == 0
            psi_host = Array(ws.state.psi)
            push!(rows, observe(psi_host, t0 + step * DT))
            colframes === nothing ||
                push!(colframes, (t0 + step * DT, column_maps(psi_host)...))
            if slices !== nothing && (t0 + step * DT) - last_slice[] >= SLICE_EVERY - 1e-9
                push!(slices, (t0 + step * DT, midplane_slice(psi_host)))
                last_slice[] = t0 + step * DT
            end
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
    psi_end = Array(ws.state.psi)
    # WHETHER THE RAMP WAS ACTUALLY ADIABATIC IS MEASURED, NOT ASSERTED. The spin
    # should stay anti-parallel to B_hat, so <F>·(-B_hat)/|F| = 1. A ramp that is too
    # fast shows up here as a projection well below 1 (the spin left behind) and/or
    # |F| < F (it depolarised) — the failure mode the sudden-tilt batch hit.
    let bh = stage_end_bhat(stage_sym)
        if bh !== nothing
            o = observe(psi_end, t0 + dur)
            align = -(o[2] * bh[1] + o[3] * bh[2] + o[4] * bh[3]) / max(o[5], eps())
            @printf("  [adiabaticity] %s end: <F>.(-Bhat)/|F| = %+.5f   |F| = %.4f (F = %d)\n",
                    stage_sym, align, o[5], F_AT)
            align > 0.98 ||
                @warn "spin is NOT tracking B — ramp too fast for omega_L" stage_sym align
        end
    end
    psi_end
end

# ---- main -------------------------------------------------------------------
println("="^74)
println("BARNETT REDO — cell=$CELL  Omega=$OMEGA  DDI=$DDI_ON  smoke=$SMOKE")
@printf("  grid=%s box=%s dt=%g  stir=%g quench=%g  ddi_padding=%s\n",
        NPTS, BOX, DT, T_STIR, T_QUENCH, DDI_PAD)
@printf("  p=%.4f (B=%g G)  c0=%.1f c1=%.3f c_dd=%.3f c_lhy=%.4g eps_dd=%.4f\n",
        P_ZEE, B_GAUSS, C0, C1, C_DD, C_LHY, EPS_DD)
@printf("  phase_x=%+.4f phase_y=%+.4f  => B_perp(0) = (%+.3f, %+.3f) x |p_perp|\n",
        PHASE_X, PHASE_Y, sin(PHASE_X), sin(PHASE_Y))
@printf("  theta=%.2f deg  bz_sign=%+g  => p_axial=%+.4f p_perp=%+.4f  seed polar=%.2f deg\n",
        rad2deg(THETA), BZ_SIGN, P_AXIAL, P_PERP, rad2deg(SEED_POLAR))
println("="^74); flush(stdout)

rows = NTuple{12, Float64}[]
frames = Tuple{Float64, Array{ComplexF32, 4}}[]

tag = (SMOKE ? "smoke_$CELL" : CELL) * TAG_SUFFIX
ledger = joinpath(OUT, "ledger_$tag.csv")
# Refuse to share an output file with a concurrent job. Four Omega-scan runs once
# resolved to the same ledger name (the geometry selector overwrote BR_TAG) and
# raced on write_csv's tmp+rename until two died with ENOENT -- and the two that
# survived had silently overwritten each other's data. A lock file makes that a
# startup error instead of a corrupted result.
let lock = ledger * ".lock"
    if isfile(lock) && time() - mtime(lock) < 86400
        error("$ledger is already claimed by a running job (see $lock). " *
              "Two jobs resolving to one output name will race and corrupt it — " *
              "give this run its own BR_TAG.")
    end
    write(lock, string(get(ENV, "JOB_ID", "?"), " ", gethostname()))
    atexit(() -> (rm(lock; force=true); nothing))
end

const COLF = COL_FRAMES ?
    Tuple{Float64, Matrix{Float32}, Matrix{Float32}}[] : nothing
const SLICES = SLICE_EVERY > 0 ?
    Tuple{Float64, Array{ComplexF32, 3}}[] : nothing
const LAST_SLICE = Ref(-Inf)

# ---- restart: pick up a saved psi instead of redoing the first 33 units -----
# The first four stages (tilt, spin up, stir, rotate back) do not depend on what
# field_down does afterwards, so an arm that only changes the ramp shape can
# reuse them. frames_*.jld2 already holds psi at exactly t = 33.0 (frame 32 of
# 48), which is the end of rotate_back, so the reuse is exact and not an
# interpolation.
#
# The guards matter more than the saving: the whole point is comparing two ramp
# shapes from the SAME state, so a restart that silently grabbed a different
# time, a different grid, or another arm's cell would produce a comparison of
# nothing. Each of those is checked and refused, not warned about.
const RESTART_FRAMES = get(ENV, "BR_RESTART_FRAMES", "")
const RESTART_T = parse(Float64, get(ENV, "BR_RESTART_T", "0"))

function load_restart()
    isfile(RESTART_FRAMES) || error("BR_RESTART_FRAMES not found: $RESTART_FRAMES")
    # Restarting anywhere other than the end of rotate_back would skip a stage
    # this driver would otherwise run, so the two runs would not share a history.
    want = T_QUENCH_START + T_ROT_BACK
    isapprox(RESTART_T, want; atol=1e-6) || error(
        "BR_RESTART_T=$RESTART_T but this config ends rotate_back at $want. " *
        "Restarting elsewhere silently changes the protocol.")
    jldopen(RESTART_FRAMES, "r") do f
        f["cell"] == CELL || error("frames cell=$(f["cell"]) but BR_CELL=$CELL")
        f["omega"] == OMEGA || error("frames omega=$(f["omega"]) but BR_OMEGA=$OMEGA")
        f["ddi"] == DDI_ON || error("frames ddi=$(f["ddi"]) but DDI_ON=$DDI_ON")
        collect(f["n"]) == collect(NPTS) ||
            error("frames grid $(f["n"]) != this run's $(NPTS)")
        collect(f["box"]) ≈ collect(BOX) ||
            error("frames box $(f["box"]) != this run's $(BOX)")
        n = f["n_frames"]
        ts = [f["frame_" * lpad(i, 3, '0') * "/t"] for i in 1:n]
        k = argmin(abs.(ts .- RESTART_T))
        # Exact, not nearest: a 0.3-unit slip is invisible in the ledger and
        # would move the comparison's zero point.
        isapprox(ts[k], RESTART_T; atol=1e-6) || error(
            "no frame at t=$RESTART_T (nearest $(ts[k])). Frames: $(ts)")
        psi = ComplexF64.(f["frame_" * lpad(k, 3, '0') * "/psi"])
        # A file of right-sized zeros passes every structural check above; the
        # 2026-07-28 incident is why this one exists.
        pk = maximum(abs2, psi)
        pk > 1e-8 || error("restart frame peak |psi|^2 = $pk — the file is garbage")
        nrm = sum(abs2, psi) * prod(step.(GRID.x))
        @printf("[redo] restart from %s frame_%s  t=%.3f  peak|psi|^2=%.4g  norm=%.6f\n",
                basename(RESTART_FRAMES), lpad(k, 3, '0'), ts[k], pk, nrm); flush(stdout)
        isapprox(nrm, 1.0; atol=1e-3) ||
            error("restart frame norm $nrm != 1 — wrong grid weights or a bad file")
        psi
    end
end

if !isempty(RESTART_FRAMES)
    PROTOCOL == "adiabatic" ||
        error("restart is only defined for BR_PROTOCOL=adiabatic")
    T_FIELD_DOWN > 0 || error("restart with T_FIELD_DOWN=0 would run only the hold")
    psi_r = load_restart()
    @printf("[redo] field_down shape=%s  T=%.3f  A=|dp/dt|/gap^2=%.4g\n",
            FIELD_DOWN_SHAPE, T_FIELD_DOWN, field_down_A()); flush(stdout)
    # No observe() here: run_dynamics records its own t0 row, and two rows at
    # t = 33 would make every downstream index-by-time off by one.
    psi_r = run_dynamics(psi_r, :field_down, RESTART_T, rows, frames;
                         ledger_path=ledger, colframes=COLF, slices=SLICES,
                         last_slice=LAST_SLICE)
    run_dynamics(psi_r, :quench, RESTART_T + T_FIELD_DOWN, rows, frames;
                 ledger_path=ledger, colframes=COLF, slices=SLICES,
                 last_slice=LAST_SLICE)
elseif PROTOCOL == "adiabatic"
    psi_gs = run_gs()
    psi = run_dynamics(psi_gs, :tilt, 0.0, rows, frames;
                       ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
    psi = run_dynamics(psi, :spinup, T_TILT, rows, frames;
                       ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
    psi = run_dynamics(psi, :steady, T_TILT + T_SPINUP, rows, frames;
                       ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
    if T_ROT_BACK > 0
        psi = run_dynamics(psi, :rotate_back, T_QUENCH_START, rows, frames;
                           ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
    end
    if T_FIELD_DOWN > 0
        psi = run_dynamics(psi, :field_down, T_QUENCH_START + T_ROT_BACK, rows, frames;
                           ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
    end
    run_dynamics(psi, :quench, T_QUENCH_START + T_RAMPDOWN, rows, frames;
                 ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
else
    psi_gs = run_gs()
    psi_stir = run_dynamics(psi_gs, :stir, 0.0, rows, frames;
                            ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
    run_dynamics(psi_stir, :quench, T_QUENCH_START, rows, frames;
                 ledger_path=ledger, colframes=COLF, slices=SLICES, last_slice=LAST_SLICE)
end

write_csv(ledger, rows)

# One flat array per quantity rather than a group per frame: an animation reads
# the whole stack once, and 800 JLD2 groups is slower to open than the data is to
# read.
# WRITE, THEN READ BACK AND CHECK THE CONTENT IS SANE. This is not belt-and-braces:
# the 2026-07-28 psi frames are 2.18 GB files of ZEROS — `frames_plus.jld2` has no
# superblock at all and the other three open cleanly with nonzero element counts of
# 272, 247, 222 ... falling by exactly 25 per frame out of 17 M. The group volume was
# full that day and JLD2 mmaps its output, so the write "succeeded" and produced
# right-sized garbage. Nothing downstream could tell, and the study's vortex check was
# therefore not merely undone but UNDOABLE from the archive.
#
# So: reopen every artefact and require a peak density within a factor 100 of the one
# just held in memory. A file that fails this is renamed .CORRUPT rather than left to
# be mistaken for evidence.
function verify_jld2(path, expect_peak, key, reader)
    ok = false
    try
        jldopen(path, "r") do g
            got = reader(g)
            ok = isfinite(got) && got > expect_peak / 100 && got < expect_peak * 100
            @printf("[redo] verify %s: %s = %.4e against %.4e in memory -> %s\n",
                    basename(path), key, got, expect_peak, ok ? "OK" : "MISMATCH")
        end
    catch e
        @printf("[redo] verify %s: UNREADABLE (%s)\n", basename(path),
                sprint(showerror, e)[1:min(80, end)])
    end
    ok || (mv(path, path * ".CORRUPT"; force=true);
           @warn "artefact did not read back as written — renamed .CORRUPT" path)
    ok
end

COLF === nothing || jldopen(joinpath(OUT, "colmaps_$tag.jld2"), "w") do f
    f["cell"] = CELL; f["omega"] = OMEGA; f["ddi"] = DDI_ON
    f["box"] = collect(BOX); f["n"] = collect(NPTS)
    # `t_stir` is read as "when does the quench begin" by the animation, so it must
    # be the boundary and not the steady stage's length — they differ by the two
    # ramps under the adiabatic protocol.
    f["t_stir"] = T_QUENCH_START; f["t_quench"] = T_QUENCH
    f["protocol"] = PROTOCOL; f["theta_deg"] = rad2deg(THETA)
    f["t_tilt"] = T_TILT; f["t_spinup"] = T_SPINUP; f["t_steady"] = T_STIR
    f["x"] = collect(GRID.x[1]); f["y"] = collect(GRID.x[2])
    f["t"] = Float64[c[1] for c in COLF]
    f["n_col"] = cat((c[2] for c in COLF)...; dims=3)
    f["fz_col"] = cat((c[3] for c in COLF)...; dims=3)
    f["n_frames"] = length(COLF)
end
COLF === nothing || verify_jld2(joinpath(OUT, "colmaps_$tag.jld2"),
    maximum(maximum(c[2]) for c in COLF), "peak column density",
    g -> maximum(g["n_col"]))

SLICES === nothing || let path = joinpath(OUT, "slices_$tag.jld2")
    jldopen(path, "w") do f
        f["cell"] = CELL; f["omega"] = OMEGA; f["ddi"] = DDI_ON
        f["box"] = collect(BOX); f["n"] = collect(NPTS)
        f["t_stir"] = T_QUENCH_START; f["protocol"] = PROTOCOL
        f["theta_deg"] = rad2deg(THETA); f["bz_sign"] = BZ_SIGN
        f["x"] = collect(GRID.x[1]); f["y"] = collect(GRID.x[2])
        f["t"] = Float64[s[1] for s in SLICES]
        f["n_slices"] = length(SLICES)
        for (i, (t, sl)) in enumerate(SLICES)
            f["slice_$(lpad(i, 3, '0'))/t"] = t
            f["slice_$(lpad(i, 3, '0'))/psi"] = sl
        end
    end
    pk = maximum(abs2, SLICES[end][2])
    verify_jld2(path, pk, "peak |psi|^2 of the last slice",
                g -> maximum(abs2, g["slice_$(lpad(g["n_slices"], 3, '0'))/psi"]))
end

isempty(frames) || jldopen(joinpath(OUT, "frames_$tag.jld2"), "w") do f
    f["cell"] = CELL; f["omega"] = OMEGA; f["ddi"] = DDI_ON
    f["box"] = collect(BOX); f["n"] = collect(NPTS); f["t_stir"] = T_QUENCH_START
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
# ★窓の始まりは **磁場が軸方向になった後**。`T_QUENCH_START` ではない。
#
# 2026-09-02 に rotate_back / field_down の段を足したとき、この行を更新しなかった。
# その 2 段では磁場が傾いているので J_z は正当に変わる ── それを窓に含めると
# 「leak」が必ず大きく出る。30 mG の +Omega 腕はそれで
#     leak / conversion = 48.9%   TOO LARGE — REFINE dx before believing this
# と自己申告したが、軸方向になった後 (t >= 31) だけで測ると 7e-5、5 桁小さい。
# 結果は無効ではなかったが、**警告が無意味になる方が有害** ── 本物の漏れが
# 48.9 % の中に隠れて区別できなくなる。
# T_RAMPDOWN = T_ROT_BACK + T_FIELD_DOWN で、どちらも既定 0 なので、
# 旧プロトコルの窓は一切変わらない。
const T_LEDGER_START = T_QUENCH_START + T_RAMPDOWN
const IQ = findfirst(r -> r[1] >= T_LEDGER_START, rows)
jz_stir0, jz_stirE = rows[1][7], rows[IQ][7]
jz_q0,    jz_qE    = rows[IQ][7], rows[end][7]
fz_q0,    fz_qE    = rows[IQ][4], rows[end][4]
lz_q0,    lz_qE    = rows[IQ][6], rows[end][6]
conv = abs(fz_qE - fz_q0)
leak = abs(jz_qE - jz_q0)

@printf("\n[redo] DONE %s\n", CELL)
if T_RAMPDOWN > 0
    # @printf の書式はコンパイル時定数でなければならない（`*` 連結も不可）ので 1 行。
    @printf("  ledger window starts at t = %.1f (stir %.1f + rampdown %.1f) — the rampdown is NOT in it: B is tilted there and J_z legitimately moves\n", T_LEDGER_START, T_QUENCH_START, T_RAMPDOWN)
end
println("  stir + rampdown (B on/tilted, J_z injected — not a conservation law here):")
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

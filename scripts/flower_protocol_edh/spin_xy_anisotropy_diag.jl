# scripts/flower_protocol_edh/spin_xy_anisotropy_diag.jl
# ============================================================
# Diagnostic: at B < 60 uG the TRANSVERSE SPIN field (Fx,Fy) develops a
# spurious x/y-axis (C4) pattern. Hypothesis: the transverse-spin SSB at
# ultra-low field is broken only by FFT/FP roundoff (which has the cubic
# grid's C4 symmetry), because the ITP gets NO isotropic symmetry-breaking
# seed. An isotropic random seed should de-pin the azimuth.
#
# For each (seed, DDI) we run ITP from m_plus_F (+ optional white noise),
# then measure the C4 content of the transverse spin in the z-midplane:
#   g(phi) = sum over (r) of |F_perp|^2 in angular bin phi
#   C4 = |sum_phi g(phi) e^{4 i phi}| / sum_phi g(phi)
#   azimuth = (1/2) arg < (Fx + i Fy)^2 >   (nematic axis of transverse spin)
#
# Decision:
#   * C4 large & azimuth pinned to {0, 90} for ALL seeds  => grid-pinned (numerical).
#   * azimuth rotates with the random seed                 => physical SSB; x/y was
#     just the roundoff-preferred direction -> fix = isotropic seed.
#   * DDI off removes it                                    => DDI-mediated.
#
# ENV knobs (all optional):
#   DIAG_B_UG    default 10       field in micro-gauss
#   DIAG_GRID    default 48       cubic grid n
#   DIAG_BOX     default 18.0
#   DIAG_STEPS   default 40000    ITP step cap
#   DIAG_DT      default 0.005
#   DIAG_TOL     default 1e-9     ITP energy tol
#   DIAG_NOISE   default 0.02     white-noise amp for seeded runs
#   DIAG_SEEDS   default "0,1,2"  0 = no seed; >0 = add_white_noise! seed
#   DIAG_DDI     default "on,off"
#   DIAG_SMOKE   default ""       set "1" -> tiny (grid 16, steps 30, seeds 0)

import CUDA
using SpinorBEC
using Printf, LinearAlgebra
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
                 find_ground_state_lbfgs,
                 CUDABackend, CPUBackend, init_psi, add_white_noise!, SpinSystem

const F = 6
const D = 2F + 1

geti(k, d) = (v = get(ENV, k, ""); isempty(v) ? d : parse(typeof(d), v))
gets(k, d) = get(ENV, k, d)

const SMOKE = gets("DIAG_SMOKE", "") == "1"
const B_UG  = geti("DIAG_B_UG", 10.0)
const NX    = SMOKE ? 16 : geti("DIAG_GRID", 48)
const BOX   = geti("DIAG_BOX", 18.0)
const STEPS = SMOKE ? 30 : geti("DIAG_STEPS", 10_000)   # ITP warmup; LBFGS does real convergence
const DT    = geti("DIAG_DT", 0.005)
const TOL   = geti("DIAG_TOL", 1.0e-9)
const LBFGS_STEPS = SMOKE ? 20 : geti("DIAG_LBFGS_STEPS", 2000)
const LBFGS_TOL   = geti("DIAG_LBFGS_TOL", 1.0e-7)
const SOBOLEV     = geti("DIAG_SOBOLEV", 0.5)
const NOISE = geti("DIAG_NOISE", 0.02)
const SEEDS = SMOKE ? [0] : parse.(Int, split(gets("DIAG_SEEDS", "0,1,2"), ","))
const DDIS  = SMOKE ? ["on"] : split(gets("DIAG_DDI", "on,off"), ",")

function spin_matrices_F6()
    mv = collect(F:-1:-F)
    Fz = zeros(ComplexF64, D, D); Fp = zeros(ComplexF64, D, D)
    for c in 1:D
        Fz[c, c] = mv[c]
        c < D && (Fp[c, c + 1] = sqrt(F * (F + 1) - mv[c + 1] * (mv[c + 1] + 1)))
    end
    Fm = Fp'
    (Fp + Fm) / 2, (Fp - Fm) / (2im), Fz
end
const FX, FY, FZ = spin_matrices_F6()

# C4 content + nematic azimuth of the transverse spin in the z-midplane.
function transverse_c4(psi, grid)
    nx, ny, nz, _ = size(psi)
    zc = nz ÷ 2 + 1
    xs = grid.x[1]; ys = grid.x[2]
    nbin = 72
    g = zeros(nbin)                      # |F_perp|^2 binned by angle
    s2 = ComplexF64(0)                   # < (Fx + i Fy)^2 > for nematic axis
    wsum = 0.0
    @inbounds for j in 1:ny, i in 1:nx
        ψ = @view psi[i, j, zc, :]
        fx = real(ψ' * (FX * ψ)); fy = real(ψ' * (FY * ψ))
        fp2 = fx^2 + fy^2
        x = xs[i]; y = ys[j]
        r2 = x^2 + y^2
        r2 < 1e-9 && continue
        φ = atan(y, x)
        b = mod(floor(Int, (φ + π) / (2π) * nbin), nbin) + 1
        g[b] += fp2
        s2 += (fx + im * fy)^2
        wsum += fp2
    end
    # 4th angular harmonic of g(phi): magnitude + PHASE (petal orientation).
    φb = [(-π + (b - 0.5) * 2π / nbin) for b in 1:nbin]
    c4c = sum(g .* cis.(4 .* φb))
    c4 = abs(c4c) / max(sum(g), 1e-30)
    c4_phase = rad2deg(angle(c4c) / 4)   # petal axis in deg; 0 = x/y, ±22.5 = diagonal
    azimuth = rad2deg(angle(s2) / 2)     # nematic axis in degrees (0 or 90 = x/y)
    (; c4, c4_phase, azimuth, fperp_total=wsum)
end

function run_one(preset, zeeman, backend, seed::Int, ddi::Bool)
    sys = SpinSystem(preset.atom.F)
    psi0 = init_psi(preset.grid, sys; state=:m_plus_F)
    seed > 0 && add_white_noise!(psi0, NOISE, seed, preset.grid)
    # ITP warmup (stalls near zero field) ...
    gs = find_ground_state(;
        grid=preset.grid, atom=preset.atom, interactions=preset.interactions,
        zeeman=zeeman, potential=preset.potential,
        psi_init=psi0, dt=DT, n_steps=STEPS, tol=TOL, save_every=500,
        enable_ddi=ddi, c_dd=preset.c_dd, secular_ddi=false,
        backend=backend, verbose=false,
    )
    # ... then LBFGS polish to the true variational minimum (the gotcha's cure).
    gl = find_ground_state_lbfgs(;
        grid=preset.grid, atom=preset.atom, interactions=preset.interactions,
        zeeman=zeeman, potential=preset.potential,
        psi_init=Array{ComplexF64}(gs.workspace.state.psi),
        n_steps=LBFGS_STEPS, tol=LBFGS_TOL, m_lbfgs=10, sobolev_alpha=SOBOLEV,
        enable_ddi=ddi, c_dd=preset.c_dd, secular_ddi=false,
        backend=backend, verbose=false,
    )
    psi = Array{ComplexF64}(gl.workspace.state.psi)
    m = transverse_c4(psi, preset.grid)
    (; seed, ddi, E=gl.energy, grad_norm=gl.grad_norm, m.c4, m.c4_phase, m.azimuth, m.fperp_total)
end

function main()
    preset = eu151_preset(; n_atoms=50_000, n_pts=(NX, NX, NX),
        box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, 1.181818), omega_ref=691.1504)
    p = Units.bfield_to_p(B_UG * 1e-6, preset.atom.g_F, preset.omega_ref)
    zeeman = ZeemanParams(p, 0.0)
    backend = CUDA.functional() ? CUDABackend() : CPUBackend()
    @printf("[diag] B=%.1f uG  p=%.3e  grid=%d^3  box=%.1f  steps=%d  backend=%s%s\n",
        B_UG, p, NX, BOX, STEPS, backend, SMOKE ? "  [SMOKE]" : "")
    println("seed ddi | E         grad_norm | C4      C4phase(deg)  azimuth(deg) |F_perp|^2_tot")
    println("-"^88)
    for ddis in DDIS, seed in SEEDS
        r = run_one(preset, zeeman, backend, seed, ddis == "on")
        @printf("%-4d %-3s | %-9.5g %-9.2e | %-7.4f %-+12.2f %-+12.2f %.3e\n",
            r.seed, ddis, r.E, r.grad_norm, r.c4, r.c4_phase, r.azimuth, r.fperp_total)
        flush(stdout)
    end
    println("\nDECISIVE READ (C4phase = petal axis; 0=on x/y, +-22.5=diagonal):")
    println(" * C4phase locked near 0 for ALL seeds (DDI on) => petals grid-pinned to x/y (numerical).")
    println(" * C4phase rotates with seed                    => physical SSB, orientation degenerate.")
    println(" * DDI=off |F_perp|^2 ~ 0 (already shown)        => texture is DDI-generated.")
end

main()

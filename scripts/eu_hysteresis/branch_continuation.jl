# Static branch continuation for the κ-dependent ¹⁵¹Eu (F=6) hysteresis loop:
# walk ONE metastable branch along B until it ceases to exist, i.e. locate a
# SPINODAL. The pair of spinodals is the τ→∞ loop width the rate scan has to
# saturate to (`scripts/eu_hysteresis/ramp_scan.jl` measures the dynamic loop).
#
# Why static, when the loop is a dynamical observable: a ramp's loop width is
# (spinodal separation) + (dynamical lag), and only the lag depends on rate. The
# static branch extent is the lag-free limit, it costs ~1 min/cell against ~40
# min for one slow ramp, and — the reason it exists — the previous campaign left
# ONE END of the loop as a lower bound (`> 100 µG`) because it only ever ramped.
# A branch that is still a local minimum at the edge of the scanned window is a
# lower bound whether you reach it statically or dynamically; the cure is to
# scan until the branch actually dies, which is affordable only statically.
#
# Two guards, both load-bearing, because "the branch died" and "the solver gave
# up" produce the same picture:
#
#   1. ε-LADDER ON EVERY CELL. On this soft (Goldstone) manifold a fixed pin
#      stalls at |∇E| ~ 1e-2, four orders above the gate, with converged=false.
#      A stalled cell is not merely an unconverged row — it is the WARM SEED for
#      the next cell, so one stall propagates and the continuation falls off the
#      branch for solver reasons at a field that then gets reported as a
#      spinodal. Every cell walks a descending ε ladder ending at the campaign
#      pin.
#   2. ORDER-PARAMETER RESPONSE TO A STRONGER POLISH (`dfperp_polish`). |∇E|
#      alone does not certify a minimum here: a gradient of 3.6e-4 was once
#      0.59 off in ⟨F⊥⟩. After the last rung each cell is polished again with
#      the same iteration budget and the MOVEMENT of ⟨F⊥⟩ is recorded. A cell
#      whose order parameter is still moving is not settled, and the analysis
#      refuses those rows rather than reading a spinodal off them.
#
# Unpadded DDI (`ddi_padding=false`, the `make_workspace` default) — matching
# the ramp drivers and the existing GS library, so a seed produced here is
# stationary under the ramp that consumes it. The padded kernel is the more
# accurate one; its shift is common-mode in the branch DIFFERENCE this campaign
# reads (measured 2026-08-06: total E moves 4.1e-3, B_eq moves 0.20 µG = 0.33 %,
# ⟨F⊥⟩ per state agrees to 0.3 %), which is why consistency wins here. Flip with
# HB_PADDING=1 and re-converge EVERYTHING if you want the other epoch.
#
# Env:
#   HB_KAPPA=1.8            trap oblateness ω_z/ω_⊥
#   HB_GRID=32  HB_BOX=24.0
#   HB_BMIN=20 HB_BMAX=200 HB_DB=5      field ladder [µG] (inclusive, |ΔB|)
#   HB_DIR=up|down          direction of travel; the anchor sits at the START
#   HB_ANCHOR_FILE=         jld2 holding `psi` to anchor from (preferred)
#   HB_ANCHOR_STATE=flower  else ITP from this init_psi state
#   HB_PIN=0.002            campaign pin ε [p-units]; the ladder ENDS here
#   HB_LADDER=0.008,0.004,0.002        per-cell ε ladder (descending, ends HB_PIN)
#   HB_LADDER_ANCHOR=0.02,0.01,0.005,0.002
#   HB_LBFGS=400  HB_ITP=2000  HB_TOL=1e-5
#   HB_CERT=1               the dfperp_polish certification pass (2× the last rung)
#   HB_PADDING=0            DDI image padding
#   HB_OUT=figs/eu_hysteresis/branch
#   HB_SMOKE=1              grid 16, 3 cells, tiny caps — every path in ≤ 2 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_hysteresis/branch_continuation.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, find_ground_state, find_ground_state_lbfgs,
    init_psi, add_white_noise!, SpinSystem, static_zeeman, upsample_spinor,
    magnetization, orbital_angular_momentum, CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave, jldopen
using Printf

include(joinpath(@__DIR__, "..", "eu_ramp_common.jl"))   # spin_scalars

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
getl(k, d) = sort(parse.(Float64, split(get(ENV, k, d), ",")); rev=true)

const SMOKE = get(ENV, "HB_SMOKE", "") == "1"
const KAPPA = getf("HB_KAPPA", 1.8)
# SMOKE shrinks the iteration caps and the cell count, NOT the grid. The grid has
# to match the anchor file's, so a 16³ smoke could never render the production
# path — it would fail on the anchor and the smoke would be testing its own
# shortcut instead of the run it is standing in for.
const GRID_N = Int(getf("HB_GRID", 32))
const BOX = getf("HB_BOX", 24.0)
const DB = getf("HB_DB", 5.0)
const BMIN = getf("HB_BMIN", 20.0)
const BMAX = getf("HB_BMAX", 200.0)
const DIR = let d = lowercase(get(ENV, "HB_DIR", "up"))
    d in ("up", "down") || error("HB_DIR must be up|down, got `$d`")
    d
end
const PIN = getf("HB_PIN", 0.002)
# Two rungs even in SMOKE: a single-rung ladder does not execute the warm-restart
# between rungs, which is the part that can be wrong.
const LADDER = SMOKE ? [2PIN, PIN] : getl("HB_LADDER", "0.008,0.004,0.002")
const LADDER_A = SMOKE ? [4PIN, PIN] : getl("HB_LADDER_ANCHOR", "0.02,0.01,0.005,0.002")
const LBFGS = SMOKE ? 40 : Int(getf("HB_LBFGS", 400))
const ITP = SMOKE ? 150 : Int(getf("HB_ITP", 2000))
const TOL = getf("HB_TOL", 1e-5)
const CERT = get(ENV, "HB_CERT", "1") == "1"
# Eigenvector-residual polish on the FINAL rung. L-BFGS accepts steps by an
# energy comparison, so it floors at √eps·‖g‖ and reports `converged=false` for a
# state that is as good as the method can make it; `residual_polish` drives
# (H−μ)ψ→0 instead and is not energy-gated. Off by default (~20×120 HvPs); turn
# on for the anchor and for the cells bracketing a spinodal, where the gradient
# floor IS the certificate.
const RESID = get(ENV, "HB_RESIDUAL", "0") == "1"
const PADDING = get(ENV, "HB_PADDING", "0") == "1"
const OUT = get(ENV, "HB_OUT", "figs/eu_hysteresis/branch")
mkpath(OUT)

# The ladder must land ON the campaign pin: a cell finishing at a different ε is
# a state of a different Hamiltonian, and mixing those across a branch is how a
# spinodal moves for bookkeeping reasons.
for (nm, l) in (("HB_LADDER", LADDER), ("HB_LADDER_ANCHOR", LADDER_A))
    isapprox(last(l), PIN; rtol=1e-12) ||
        error("$nm must END at HB_PIN=$PIN (descending); got $(join(l, ","))")
end

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)

p_of(B_uG) = Units.bfield_to_p(B_uG * 1e-6, ATOM.g_F, PRESET.omega_ref)
# ε is in p-units; `p_of(1.0)` is p per µG, so the pin as a physical transverse
# field is ε / |p_of(1)|. This printed 135176 µG until the 1e6 in it was removed —
# the µG→Gauss factor is already inside `p_of`. The number matters: it is the
# residual transverse field the whole result assumes the lab has nulled to, and it
# goes into the shielding row of the deliverable.
const B_PER_EPS = PIN / abs(p_of(1.0))

base_kw(p, ε) = (; grid=PRESET.grid, atom=ATOM,
    interactions=PRESET.interactions, potential=PRESET.potential,
    zeeman=static_zeeman(; Bz=p, Bx=ε, q=0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND,
    ddi_padding=PADDING, ddi_trunc_radius=-1.0)

const B_LADDER = let
    n = max(1, round(Int, abs(BMAX - BMIN) / DB) + 1)
    v = collect(range(min(BMIN, BMAX), max(BMIN, BMAX); length=n))
    v = DIR == "up" ? v : reverse(v)
    # SMOKE keeps the real endpoints and the real ΔB and only takes the first few
    # cells, so the anchor it renders is the anchor production will use.
    SMOKE ? v[1:min(3, length(v))] : v
end

"""Full scalar set at one ψ. `Lz` needs an FFT plan set, so it is taken from the
solver's own workspace rather than rebuilt."""
function cell_scalars(psi, fft_plans)
    s = spin_scalars(psi, PRESET.grid)
    Lz = orbital_angular_momentum(psi, PRESET.grid, fft_plans)
    Sz = magnetization(psi, PRESET.grid, SYS)
    (; s.fz, s.fperp, Lz, Sz, Jz=Lz + Sz)
end

"""Walk `ladder` (descending ε) from `psi0`, warm-starting each rung. Returns the
state at the LAST rung plus the per-rung trace and — when `CERT` — the movement
of ⟨F⊥⟩ under a second polish of the same budget at the final ε.

`dfperp_polish` is the certification: |∇E| < tol does not establish that a soft
cell reached the branch minimum, so the order parameter's response to more
optimisation is measured directly instead of assumed."""
function solve_cell(psi0, p; ladder, cap)
    psi = Array{ComplexF64}(psi0)
    rungs = NamedTuple[]
    local gl
    for (j, ε) in enumerate(ladder)
        gl = find_ground_state_lbfgs(; base_kw(p, ε)..., psi_init=psi,
            n_steps=cap, tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false,
            residual_polish=(RESID && j == length(ladder)))
        psi = Array{ComplexF64}(gl.workspace.state.psi)
        sc = cell_scalars(psi, gl.workspace.fft_plans)
        push!(rungs, (; eps=ε, E=gl.energy, grad=gl.grad_norm,
            conv=gl.converged, stop=gl.stop_reason, sc.fperp, sc.fz))
    end
    sc = cell_scalars(psi, gl.workspace.fft_plans)
    dfp = NaN
    if CERT
        g2 = find_ground_state_lbfgs(; base_kw(p, last(ladder))..., psi_init=psi,
            n_steps=cap, tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false,
            residual_polish=RESID)
        psi2 = Array{ComplexF64}(g2.workspace.state.psi)
        sc2 = cell_scalars(psi2, g2.workspace.fft_plans)
        dfp = sc2.fperp - sc.fperp
        # Keep the POLISHED state: it is the better one by construction, and the
        # next cell warm-starts from it.
        psi, sc, gl = psi2, sc2, g2
    end
    (; psi, E=gl.energy, grad=gl.grad_norm, conv=gl.converged,
        stop=String(gl.stop_reason), floor_limited=gl.floor_limited,
        last_step=gl.last_step, sc..., dfperp_polish=dfp, rungs)
end

"""Anchor ψ: an explicit file (upsampled if it is on a coarser cubic grid) or an
ITP solve from an `init_psi` state. A file anchor is checked against the preset —
a state from another parameter epoch is not on this branch at all."""
function anchor_psi(p)
    f = get(ENV, "HB_ANCHOR_FILE", "")
    if isempty(f)
        st = Symbol(get(ENV, "HB_ANCHOR_STATE", "flower"))
        @printf("  anchor: ITP %d from :%s\n", ITP, st)
        psi0 = init_psi(PRESET.grid, SYS; state=st)
        add_white_noise!(psi0, 0.02, 1, PRESET.grid)
        gs = find_ground_state(; base_kw(p, first(LADDER_A))..., psi_init=psi0,
            dt=0.002, n_steps=ITP, tol=1e-12, save_every=max(1, ITP ÷ 4),
            verbose=false)
        return Array{ComplexF64}(gs.workspace.state.psi)
    end
    isfile(f) || error("HB_ANCHOR_FILE=$f does not exist")
    psi, meta = jldopen(f, "r") do h
        g(k, d) = haskey(h, k) ? h[k] : d
        (Array{ComplexF64}(h["psi"]),
            (; c0=g("c0", NaN), c1=g("c1", NaN), c_dd=g("c_dd", NaN),
                n=g("grid_n_points", nothing), box=g("grid_box_size", nothing),
                B=g("B_uG", NaN), grad=g("grad_norm", NaN)))
    end
    for (nm, got, want) in (("c0", meta.c0, PRESET.interactions.c[0]),
        ("c1", meta.c1, PRESET.interactions.c[1]),
        ("c_dd", meta.c_dd, PRESET.c_dd))
        isnan(got) && continue
        abs(got - want) / max(abs(want), 1e-30) < 1e-8 || error("""
            anchor/preset mismatch on $nm: stored $got vs preset $want.
            The anchor was converged in another parameter epoch; it is not a
            state of this Hamiltonian and continuing from it measures that
            mismatch. anchor = $f""")
    end
    n_src = meta.n === nothing ? nothing : first(meta.n)
    if n_src !== nothing && n_src != GRID_N
        n_src < GRID_N || error("anchor grid $n_src > target $GRID_N (no downsample)")
        meta.box === nothing || all(≈(BOX), meta.box) ||
            error("anchor box $(meta.box) ≠ $BOX — upsample assumes the same box")
        @printf("  anchor: %s  (upsample %d³ → %d³, B=%.1f µG |∇E|=%.1e)\n",
            f, n_src, GRID_N, meta.B, meta.grad)
        psi = upsample_spinor(psi, GRID_N)
    else
        @printf("  anchor: %s  (B=%.1f µG |∇E|=%.1e)\n", f, meta.B, meta.grad)
    end
    psi
end

# ---------------------------------------------------------------------- driver

@printf("""
Eu branch continuation: κ=%.2f grid=%d³ box=%.1f  %s  %s%s
  B: %.1f → %.1f µG, ΔB=%.2f (%d cells, dir=%s)
  pin ε=%.4g p-units = %.4f µG   ladder=%s (anchor %s)
  LBFGS cap=%d  tol=%.0e  DDI padding=%s  cert=%s
""",
    KAPPA, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU",
    OUT, SMOKE ? "  [SMOKE]" : "",
    first(B_LADDER), last(B_LADDER), DB, length(B_LADDER), DIR,
    PIN, B_PER_EPS, join(LADDER, ","), join(LADDER_A, ","),
    LBFGS, TOL, PADDING, CERT)
flush(stdout)

# `stop_reason` is carried because `converged=false` conflates two opposite
# outcomes: a solve still descending when it ran out of steps (`max_steps` —
# unusable) and one that hit the line search's energy-comparison floor
# (`line_search_stalled` — as converged as the method can get). A spinodal read
# off a `max_steps` row is a solver artefact.
const COLS = (:cell, :B_uG, :E, :grad_norm, :converged, :stop_reason,
    :floor_limited, :fz, :fperp, :Lz, :Sz, :Jz, :dfperp_polish,
    :last_step, :wall_s)

rows = NamedTuple[]
write_frames() = open(joinpath(OUT, "frames.csv"), "w") do io
    writedlm(io, reshape(String.(collect(COLS)), 1, :))
    for r in rows
        writedlm(io, reshape(Any[getfield(r, k) for k in COLS], 1, :))
    end
end

seed = nothing
for (i, b) in enumerate(B_LADDER)
    global seed
    dir = joinpath(OUT, @sprintf("cell_%03d", i))
    pf = joinpath(dir, "psi.jld2")
    p = p_of(b)

    if isfile(pf)      # resume: psi.jld2 is written LAST, so it marks completion
        r = jldopen(pf, "r") do h
            seed = Array{ComplexF64}(h["psi"])
            g(k, d) = haskey(h, k) ? h[k] : d
            (; E=h["E_total"], grad=h["grad_norm"], conv=h["converged"],
                dfp=h["dfperp_polish"], ls=h["last_step"],
                stop=g("stop_reason", "?"), fl=g("floor_limited", false),
                Lz=g("Lz", NaN), Sz=g("Sz", NaN), Jz=g("Jz", NaN))
        end
        sc = spin_scalars(seed, PRESET.grid)
        push!(rows, (; cell=i, B_uG=b, E=r.E, grad_norm=r.grad, converged=r.conv,
            stop_reason=r.stop, floor_limited=r.fl,
            sc.fz, sc.fperp, r.Lz, r.Sz, r.Jz,
            dfperp_polish=r.dfp, last_step=r.ls, wall_s=0.0))
        @printf("[cell %03d B=%7.2f µG] RESUME  E=%.6f |∇E|=%.1e ⟨F⊥⟩=%.4f\n",
            i, b, r.E, r.grad, sc.fperp)
        flush(stdout)
        write_frames()
        continue
    end

    t0 = time()
    if seed === nothing
        @printf("[cell %03d B=%7.2f µG] ANCHOR\n", i, b)
        flush(stdout)
        c = solve_cell(anchor_psi(p), p; ladder=LADDER_A, cap=LBFGS)
    else
        c = solve_cell(seed, p; ladder=LADDER, cap=LBFGS)
    end
    seed = c.psi
    HAS_GPU && CUDA.synchronize()

    mkpath(dir)
    tmp = pf * ".tmp"
    jldsave(tmp; psi=c.psi, t=0.0, step=0,
        grid_n_points=PRESET.grid.config.n_points,
        grid_box_size=PRESET.grid.config.box_size, atom_name=ATOM.name,
        c0=PRESET.interactions.c[0], c1=PRESET.interactions.c[1],
        c_lhy=PRESET.interactions.c_lhy, c_dict=PRESET.interactions.c,
        zeeman_p=p, zeeman_q=0.0, c_dd=PRESET.c_dd,
        dt=0.002, imaginary_time=true,
        B_uG=b, kappa=KAPPA, pin_bx=PIN, pin_eps=PIN, ddi_padding=PADDING,
        E_total=c.E, E=c.E, grad_norm=c.grad, converged=c.conv,
        stop_reason=c.stop, floor_limited=c.floor_limited,
        last_step=c.last_step, dfperp_polish=c.dfperp_polish,
        fperp=c.fperp, fz=c.fz, Lz=c.Lz, Sz=c.Sz, Jz=c.Jz)
    mv(tmp, pf; force=true)

    push!(rows, (; cell=i, B_uG=b, E=c.E, grad_norm=c.grad, converged=c.conv,
        stop_reason=c.stop, floor_limited=c.floor_limited,
        c.fz, c.fperp, c.Lz, c.Sz, c.Jz, c.dfperp_polish,
        last_step=c.last_step, wall_s=round(time() - t0; digits=1)))
    write_frames()
    @printf("[cell %03d B=%7.2f µG] E=%.6f |∇E|=%.1e (%s) ⟨F⊥⟩=%.4f ⟨F_z⟩=%+.4f J_z=%+.4f  dF⊥(polish)=%+.1e  %.0fs\n",
        i, b, c.E, c.grad, c.stop, c.fperp, c.fz, c.Jz,
        c.dfperp_polish, time() - t0)
    for r in c.rungs
        @printf("      ε=%.4g E=%.6f |∇E|=%.1e ⟨F⊥⟩=%.4f (%s)\n",
            r.eps, r.E, r.grad, r.fperp, r.stop)
    end
    flush(stdout)
end

@printf("ALLDONE  %d cells → %s/frames.csv\n", length(rows), OUT)

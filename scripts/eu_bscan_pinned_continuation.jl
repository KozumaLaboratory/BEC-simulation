# B-scan of the weak-field ¹⁵¹Eu (F=6) + DDI ground state with a FIXED
# symmetry-breaking pin, warm-continued in B — the data source for a
# "state vs magnetic field" animation.
#
# Physics: below ~60 µG the Eu+DDI GS lives on a soft Goldstone manifold
# (broken axial U(1) e^{-iθ(L_z+F_z)}); un-pinned optimisation wanders and
# the flower orientation is roundoff/seed-selected. We add ONE fixed
# transverse pin b_x = ε (conjugate to the broken transverse-spin order),
# held constant across every B, so the orientation is locked ⇒ the animation
# does not flicker as B changes. A fixed absolute ε strengthens (relative to
# p ∝ B) exactly as B → 0, i.e. where the pin is most needed.
#
# Efficiency: continuation. The anchor is the HIGH-B end (Zeeman-protected,
# stiff, easy) via ITP→LBFGS; every lower-B cell warm-starts from its
# higher-B neighbour and only needs a short LBFGS polish. The hard soft
# manifold is reached gradually with a good seed each step.
#
# Env:
#   BS_GRID=64  BS_BOX=24.0  BS_NB=101  BS_BMIN=0.0  BS_BMAX=100.0  (µG)
#   BS_TRAP_Z=1.1818          trap aspect ω_z/ω_⊥ — this is κ
#   BS_DIR=down|up            continuation direction; `up` + BS_ANCHOR_STATE=flower
#                             is the branch a hysteresis loop needs at κ ≥ 1.0
#   BS_ANCHOR_STATE=m_plus_F  seed for the first (anchor) cell
#   BS_PIN_EPS=1e-3           fixed transverse pin b_x (dimensionless p-units)
#   BS_ITP=2000  BS_LBFGS_ANCHOR=400  BS_LBFGS_CELL=120
#   BS_NEWTON_ANCHOR=1  (Newton-polish the stiff anchor; OFF for soft cells)
#   BS_SAVE_PSI=1       persist full ψ per frame (else only midplane CSVs)
#   BS_OUT=figs/eu_bscan_pinned
#   BS_SMOKE=1          grid16, NB5, itp150, lbfgs40 — every path in ≤2 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_bscan_pinned_continuation.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, find_ground_state, find_ground_state_lbfgs,
    init_psi, add_white_noise!, SpinSystem, static_zeeman, energy_decomposition,
    component_populations, _spin_expectation_fields, pin_transverse_field,
    CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave, jldopen
using Printf

geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const SMOKE = get(ENV, "BS_SMOKE", "") == "1"
const NX    = SMOKE ? 16 : Int(geti("BS_GRID", 64))
const BOX   = geti("BS_BOX", 24.0)
const NB    = SMOKE ? 5 : Int(geti("BS_NB", 101))
const BMIN  = geti("BS_BMIN", 0.0)     # µG
const BMAX  = geti("BS_BMAX", 100.0)   # µG
const EPS   = geti("BS_PIN_EPS", 1e-3) # fixed transverse pin b_x
const ITP   = SMOKE ? 150 : Int(geti("BS_ITP", 2000))
const LB_A  = SMOKE ? 40  : Int(geti("BS_LBFGS_ANCHOR", 400))
const LB_C  = SMOKE ? 30  : Int(geti("BS_LBFGS_CELL", 120))
# grad-norm early-stop target (driver.jl:187 breaks when |∇E| < tol). 1e-5 is
# 4 orders below the un-pinned Goldstone floor (~0.05) and stops BEFORE the
# near-convergence linesearch thrash (~1e-6 at 64³). Cells self-size: high-B
# converge in few steps, soft low-B run up to the n_steps cap.
const TOL   = geti("BS_TOL", 1e-5)
# Re-polish mode: re-solve ONLY already-cached frames whose |∇E| exceeds RP_THRESH
# (the soft low-B cells the fixed-pin main run leaves loose). BS_RP_RAMP set ⇒ use
# the ε-ladder pin continuation (pin_transverse_field + epsilon_ramp, the PR#54
# method that reaches ~1e-5 on the soft manifold); empty ⇒ just a higher-cap LBFGS
# at the fixed pin. Warm-starts from each frame's own same-B cached ψ. Resumable:
# a re-polished frame drops below RP_THRESH so a re-run skips it.
const REPOLISH  = get(ENV, "BS_REPOLISH", "") == "1"
const RP_THRESH = geti("BS_RP_THRESH", 1e-4)
const RP_LBFGS  = SMOKE ? 60 : Int(geti("BS_RP_LBFGS", 400))
const RP_RAMP   = let s = get(ENV, "BS_RP_RAMP", "")
    isempty(s) ? Float64[] : sort(parse.(Float64, split(s, ",")); rev=true)
end
const NEWT_A = get(ENV, "BS_NEWTON_ANCHOR", "1") == "1"
const SAVE_PSI = get(ENV, "BS_SAVE_PSI", "1") == "1"
const OUT   = get(ENV, "BS_OUT", "figs/eu_bscan_pinned")
mkpath(OUT)

const TRAPZ = geti("BS_TRAP_Z", 1.1818)   # ω_z/ω_⊥ aspect ratio (demag prediction axis)
const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET  = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, TRAPZ))
const ATOM = PRESET.atom
const SYS  = SpinSystem(ATOM.F)

# Scan direction. The anchor is always the FIRST cell, so the direction picks
# which spinodal the continuation walks toward — and therefore which branch this
# run produces.
#
#   down (default)  anchor at HIGH field, continue into the soft low-B manifold.
#                   Pairs with BS_ANCHOR_STATE=m_plus_F → the "dn" branch, which
#                   loses stability at the LOWER spinodal.
#   up              anchor at LOW field, continue upward. Pairs with
#                   BS_ANCHOR_STATE=flower → the "up" branch, which is stable at
#                   weak field and loses stability at the UPPER spinodal.
#
# Both branches at one κ are what a hysteresis loop is made of, so a first-order
# claim needs BOTH — the direction was hard-coded to `down` until 2026-07-29,
# which is why the library had no "up" branch at any κ ≥ 1.0.
const DIR = let d = lowercase(get(ENV, "BS_DIR", "down"))
    d in ("down", "up") || error("BS_DIR must be `down` or `up`, got `$d`")
    d
end
const B_UG = DIR == "down" ? collect(range(BMAX, BMIN; length=NB)) :
             collect(range(BMIN, BMAX; length=NB))

@printf("B-scan pinned continuation: grid=%d^3 box=%.1f κ=%.4f  B=%.1f→%.1f µG × %d pts (%s, anchor=%s)  pin b_x=%.1e  tol=%.0e  %s%s%s\n",
    NX, BOX, TRAPZ, first(B_UG), last(B_UG), NB, DIR,
    get(ENV, "BS_ANCHOR_STATE", "m_plus_F"),
    EPS, TOL, HAS_GPU ? "CUDA" : "CPU", SMOKE ? " [SMOKE]" : "",
    REPOLISH ? @sprintf(" [REPOLISH >%.0e cap=%d ramp=%s]", RP_THRESH, RP_LBFGS,
        isempty(RP_RAMP) ? "none" : join(RP_RAMP, ",")) : "")
flush(stdout)

# `make_workspace` deliberately defaults both image knobs OFF — it is the
# library primitive, and flipping it there would move every direct-call fixture
# (see its own comment). The YAML/DSL surface defaults them ON, and this script
# is production physics reached by direct call, so it opts in explicitly.
#
# It matters more here than almost anywhere else. The bare periodic kernel
# carries a 2-5 % dipolar field error that is FLAT in resolution, and its origin
# is the square lattice of periodic images breaking rotational symmetry — an
# ANISOTROPIC error. This scan's whole subject is how the trap aspect ratio κ
# controls the order of the transition, so an anisotropy-dependent DDI error is
# a direct confound on the axis being measured, not a uniform offset.
base_kw(p) = (; grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=PRESET.potential, zeeman=static_zeeman(; Bz=p, Bx=EPS, q=0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND,
    ddi_padding=true, ddi_trunc_radius=-1.0)

# density-weighted axial + transverse magnetisation (manifest scalars).
function frame_scalars(psi)
    dV = SpinorBEC.cell_volume(PRESET.grid)
    dens3 = dropdims(sum(abs2, psi; dims=4); dims=4)
    fx, fy, fz = _spin_expectation_fields(psi, PRESET.grid)
    ntot = sum(dens3) * dV
    (; fz_mean=sum(fz) * dV / ntot,
       fperp_mean=sum(sqrt.(fx .^ 2 .+ fy .^ 2)) * dV / ntot)
end

# z-midplane field extraction for the animation frames.
function dump_frame(dir, psi, energy, grad_norm, converged, last_step, p, b_ug)
    mkpath(dir)
    D = size(psi, 4)
    kz = size(psi, 3) ÷ 2 + 1
    dens3 = dropdims(sum(abs2, psi; dims=4); dims=4)
    fx, fy, fz = _spin_expectation_fields(psi, PRESET.grid)
    phase = angle.(@view psi[:, :, kz, D])          # dominant m=-F component
    writedlm(joinpath(dir, "density_xy.csv"), dens3[:, :, kz])
    writedlm(joinpath(dir, "fx_xy.csv"), fx[:, :, kz])
    writedlm(joinpath(dir, "fy_xy.csv"), fy[:, :, kz])
    writedlm(joinpath(dir, "fz_xy.csv"), fz[:, :, kz])
    writedlm(joinpath(dir, "fperp_xy.csv"),
        sqrt.(fx[:, :, kz] .^ 2 .+ fy[:, :, kz] .^ 2))
    writedlm(joinpath(dir, "phase_xy.csv"), phase)
    pops = component_populations(psi, PRESET.grid, SYS)
    writedlm(joinpath(dir, "populations.csv"),
        hcat(collect(pops.m_values), pops.populations))
    # psi.jld2 written LAST = the completion marker the resume path checks for.
    # Atomic (tmp+rename, same dir ⇒ same device, no EXDEV) so a SIGKILL mid-write
    # can't leave a corrupt jld2 that resume would EOFError on.
    if SAVE_PSI
        tmp = joinpath(dir, "psi.jld2.tmp")
        # Full load_state schema (t/step/zeeman_q/c_dict/c_lhy/dt/imaginary_time)
        # so `load_state(pf)` + make_workspace(psi_init=…) consume these directly,
        # PLUS reuse metadata (B_uG, pin_bx, E_total, grad_norm, converged, last_step).
        jldsave(tmp;
            psi=psi, t=0.0, step=0,
            grid_n_points=PRESET.grid.config.n_points,
            grid_box_size=PRESET.grid.config.box_size,
            atom_name=ATOM.name,
            c0=PRESET.interactions[0], c1=PRESET.interactions[1],
            c_lhy=PRESET.interactions.c_lhy, c_dict=PRESET.interactions.c,
            zeeman_p=p, zeeman_q=0.0, c_dd=PRESET.c_dd,
            dt=0.002, imaginary_time=true,
            B_uG=b_ug, pin_bx=EPS,
            E_total=energy, grad_norm=grad_norm,
            converged=converged, last_step=last_step)
        mv(tmp, joinpath(dir, "psi.jld2"); force=true)
    end
    nothing
end

# --- scan (RESUMABLE) --------------------------------------------------------
# Each completed frame writes psi.jld2 LAST. On (re)start we load any existing
# frame's ψ as the warm seed and skip its solve; the first frame WITHOUT a
# psi.jld2 is solved (anchored if no seed loaded yet, else warm-started from the
# last loaded ψ) and the scan continues. ⇒ timeout-safe + re-run a frame by
# deleting its dir + extend by adding points.
manifest = Vector{NTuple{6, Float64}}()   # frame, B_uG, E, grad_norm, Fz, Fperp
seed = nothing
for (i, b_ug) in enumerate(B_UG)
    global seed
    dir = joinpath(OUT, @sprintf("frame_%03d", i))
    pf = joinpath(dir, "psi.jld2")
    p = Units.bfield_to_p(b_ug * 1e-6, ATOM.g_F, PRESET.omega_ref)  # µG→Gauss→p

    # cached-frame gate: load any existing ψ; skip its solve UNLESS re-polishing a
    # frame that is still above RP_THRESH.
    cached = isfile(pf)
    gN_cached = NaN
    if cached
        gN_cached = jldopen(pf, "r") do f
            seed = Array{ComplexF64}(f["psi"]); f["grad_norm"]
        end
    end
    if cached && !(REPOLISH && gN_cached > RP_THRESH)   # resume: reuse converged ψ
        E = jldopen(pf, "r") do f; f["E_total"]; end
        sc = frame_scalars(seed)
        push!(manifest, (Float64(i), b_ug, E, gN_cached, sc.fz_mean, sc.fperp_mean))
        @printf("[frame %03d  B=%.2f µG] RESUME (cached ψ)  E=%.5f |gradE|=%.2e\n",
            i, b_ug, E, gN_cached)
        flush(stdout)
    else
        kw = base_kw(p)
        if REPOLISH && cached
            # re-polish the loose cached frame from its own same-B ψ (already loaded
            # into `seed`): ε-ladder pin continuation if RP_RAMP set, else higher-cap.
            @printf("[frame %03d  B=%.2f µG] REPOLISH (|∇E|=%.2e → cap=%d %s) …\n",
                i, b_ug, gN_cached, RP_LBFGS,
                isempty(RP_RAMP) ? "fixed pin" : "ε-ladder")
            flush(stdout)
            gl = isempty(RP_RAMP) ?
                find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=RP_LBFGS,
                    tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false) :
                find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=RP_LBFGS,
                    tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false,
                    pin=pin_transverse_field(; Bz=p, q=0.0), epsilon_ramp=RP_RAMP)
        elseif seed === nothing
            # anchor: symmetry-broken ITP seed. BS_ANCHOR_STATE picks the branch
            # (:m_plus_F for the downsweep, :flower for the upsweep → hysteresis loop).
            anchor_file = get(ENV, "BS_ANCHOR_FILE", "")
            psi0 = isempty(anchor_file) ?
                init_psi(PRESET.grid, SYS; state=Symbol(get(ENV, "BS_ANCHOR_STATE", "m_plus_F"))) :
                jldopen(anchor_file, "r") do f; Array{ComplexF64}(f["psi"]); end
            add_white_noise!(psi0, 0.02, 1, PRESET.grid)
            @printf("[frame %03d  B=%.2f µG] anchor ITP %d …\n", i, b_ug, ITP)
            flush(stdout)
            gs = find_ground_state(; kw..., psi_init=psi0, dt=0.002, n_steps=ITP,
                tol=1e-12, save_every=max(1, ITP ÷ 5), verbose=true)
            seed = Array{ComplexF64}(gs.workspace.state.psi)
            gl = find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=LB_A,
                tol=TOL, m_lbfgs=10, newton_polish=NEWT_A, verbose=true)
        else
            # warm cell: LBFGS from the neighbouring-B ψ, early-stop at |∇E|<TOL
            gl = find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=LB_C,
                tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false)
        end
        seed = Array{ComplexF64}(gl.workspace.state.psi)
        HAS_GPU && CUDA.synchronize()
        dump_frame(dir, seed, gl.energy, gl.grad_norm, gl.converged, gl.last_step, p, b_ug)
        sc = frame_scalars(seed)
        push!(manifest,
            (Float64(i), b_ug, gl.energy, gl.grad_norm, sc.fz_mean, sc.fperp_mean))
        @printf("[frame %03d  B=%.2f µG] E=%.5f |gradE|=%.2e (%d it%s)  Fz=%+.3f |F⊥|=%.3f\n",
            i, b_ug, gl.energy, gl.grad_norm, gl.last_step,
            gl.converged ? " ✓tol" : "", sc.fz_mean, sc.fperp_mean)
        flush(stdout)
    end
    # rewrite manifest each frame so a killed job leaves a usable partial
    open(joinpath(OUT, "frames.csv"), "w") do io
        writedlm(io, ["frame" "B_uG" "E_total" "grad_norm" "Fz_mean" "Fperp_mean"])
        writedlm(io, permutedims(reduce(hcat, collect.(manifest)), (2, 1)))
    end
end

@printf("ALLDONE  %d frames → %s\n", length(manifest), OUT)

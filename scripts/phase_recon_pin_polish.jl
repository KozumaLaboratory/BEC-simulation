# Pin-POLISH the discovered winners of a phase-recon run: load each saved seed_*.jld2
# (the un-pinned min-E basin per cell) and warm-continue it DOWN a bx=ε pin ladder
# with LBFGS+Newton, so the soft-manifold cells reach an isolated minimum (|∇E|≪
# 0.05 floor). No ITP, single seed ⇒ cheap — turns the bias-free reconnaissance
# winners into CONVERGED representatives for the validated fingerprint + clustering.
#
# Boundaries are already discovered by the un-pinned multi-seed pass; this only
# fills in convergence. The fingerprint is gauge-invariant ⇒ the ε bias washes out.
#
# Env: PP_DIR=figs/phase_recon_2d  PP_OUT=figs/phase_recon_2d_pin
#      PP_EPS=4e-3,1e-3,2.5e-4  PP_LBFGS=400  PP_BOX=24.0
#   julia --project=. scripts/phase_recon_pin_polish.jl

import CUDA
using SpinorBEC
using SpinorBEC: eu151_preset, find_ground_state_lbfgs, static_zeeman,
    InteractionParams, load_state, CUDABackend, CPUBackend
using JLD2: jldsave
using Printf
using Dates: now, format
include(joinpath(@__DIR__, "phase_fingerprint_lib.jl"))

clk() = format(now(), "HH:MM:SS")
const DIR   = get(ENV, "PP_DIR", "figs/phase_recon_2d")
const OUT   = get(ENV, "PP_OUT", DIR * "_pin")
const BOX   = parse(Float64, get(ENV, "PP_BOX", "24.0"))
const LBFGS = parse(Int, get(ENV, "PP_LBFGS", "400"))
# Newton polish reaches deeper |∇E| but each HvP on the ~D·N³ trapped Hessian is
# expensive and stalls on the soft manifold. Default OFF: rely on a longer warm
# ε-continuation (LBFGS only) — the approach that reached |∇E|~1e-5 in the arc.
const NEWTON = get(ENV, "PP_NEWTON", "0") == "1"
const EPS   = sort(parse.(Float64, split(get(ENV, "PP_EPS",
    "4e-3,2e-3,1e-3,5e-4,2.5e-4"), ",")); rev=true)
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
(!HAS_GPU) && @warn "CUDA not functional -> CPU run (slow)"

function parse_cell(fname)
    m = match(r"seed_L([0-9.]+)_B([0-9.]+)\.jld2", fname)
    m !== nothing && return (parse(Float64, m[1]), parse(Float64, m[2]))
    m = match(r"seed_B([0-9.]+)\.jld2", fname)
    m !== nothing && return (1.0, parse(Float64, m[1]))
    nothing
end

files = sort(filter(f -> startswith(f, "seed_") && endswith(f, ".jld2"), readdir(DIR)))
isempty(files) && error("no seed_*.jld2 in $DIR")
@printf("pin-polish %d cells from %s  ε=%s  LBFGS=%d/ε  %s\n",
    length(files), DIR, join(EPS, ","), LBFGS, HAS_GPU ? "CUDA" : "CPU")
flush(stdout)

rows = NamedTuple[]
for (n, f) in enumerate(files)
    cell = parse_cell(f); cell === nothing && continue
    lam, B = cell
    st = load_state(joinpath(DIR, f))
    psi = Array{ComplexF64}(st.psi)
    nx = size(psi, 1); F = (size(psi, 4) - 1) ÷ 2
    preset = eu151_preset(; n_pts=(nx, nx, nx), box=(BOX, BOX, BOX),
        trap_ratios=(1.0, 1.0, lam))
    p = st.zeeman_p
    inter = InteractionParams(Dict{Int, Float64}(0 => st.c0, 1 => st.c1))
    kw(eps) = (; grid=preset.grid, atom=preset.atom, interactions=inter,
        potential=preset.potential, zeeman=static_zeeman(; Bz=p, Bx=eps, q=0.0),
        enable_ddi=true, c_dd=st.c_dd, secular_ddi=false, backend=BACKEND)
    @printf("[%s] (%d/%d) λ=%.3f B=%.1f  start |∇|→ polishing…\n",
        clk(), n, length(files), lam, B); flush(stdout)
    local gl
    seed = psi
    for eps in EPS
        gl = find_ground_state_lbfgs(; kw(eps)..., psi_init=seed, n_steps=LBFGS,
            tol=1e-12, m_lbfgs=10, newton_polish=NEWTON, verbose=false)
        seed = Array{ComplexF64}(gl.workspace.state.psi)
    end
    HAS_GPU && CUDA.synchronize()
    pol = Array{ComplexF64}(gl.workspace.state.psi)
    ctx = fp_context(preset.grid; box=BOX, F=F)
    fp = fingerprint(ctx, pol)
    push!(rows, (; lam, B, E=gl.energy, grad=gl.grad_norm, fp))
    fcs = isnan(fp.fluxclosure) ? " N/A" : @sprintf("%.3f", fp.fluxclosure)
    @printf("  → E=%.5f |∇E|=%.2e  |F|=%.2f g=%.2f Jz=%+.2f flux=%s inert=%s\n",
        gl.energy, gl.grad_norm, fp.mF, fp.coh, fp.Jz, fcs, fp.inert)
    flush(stdout)
    jldsave(joinpath(OUT, f); psi=pol, t=0.0, step=0,
        grid_n_points=preset.grid.config.n_points, grid_box_size=preset.grid.config.box_size,
        atom_name=preset.atom.name, c0=st.c0, c1=st.c1, c_dd=st.c_dd,
        zeeman_p=p, zeeman_q=0.0)
end

# recon.csv-shaped table so phase_fingerprint_map.jl reads grad/E from the polished run
open(joinpath(OUT, "recon.csv"), "w") do io
    println(io, join(["lambda", "B", "seed", "E", "grad", "Fz", "Fperp", "phase"], "\t"))
    for r in rows
        println(io, join([r.lam, r.B, "pinpolish", r.E, r.grad, r.fp.Fz,
            "NA", r.fp.inert], "\t"))
    end
end
@printf("\nDONE → %s  (%d cells polished)\n", OUT, length(rows))

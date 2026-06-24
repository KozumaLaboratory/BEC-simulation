# Phase 1 — coarse, UNBIASED reconnaissance of a parameter range.
#
# At each parameter cell we run SEVERAL independent seeds FROM SCRATCH (no
# continuation) and take the lowest-energy one. This is the bias-free skeleton
# map: continuation is deliberately NOT used here (it would hide boundaries via
# hysteresis). Where the winning phase / order parameter changes between adjacent
# cells, a boundary lives in between — that is what later phases localise.
#
# Records per (cell, seed): E, |gradE|, ⟨F_z⟩, |F_perp|, m-populations, and the
# classify_phase label. Saves the lowest-E ψ per cell (→ continuation seeds).
#
# Env: PR_B=10,25,40,55,70   (µG)   PR_SEEDS=polar,m_plus_F,random1,random2
#      PR_GRID=32 PR_BOX=24 PR_ITP=3000 PR_LBFGS=300 PR_OUT=figs/phase_recon
#      PR_SMOKE=1  -> grid16, B=10,40, seeds polar,random1, itp200 lbfgs40
#   julia --project=. scripts/phase_recon.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem, spin_matrices,
    classify_phase, component_populations, cell_volume, CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave
using Printf

geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const SMOKE = get(ENV, "PR_SMOKE", "") == "1"
const NX    = SMOKE ? 16 : Int(geti("PR_GRID", 32))
const BOX   = geti("PR_BOX", 24.0)
const ITP   = SMOKE ? 200 : Int(geti("PR_ITP", 3000))
const LBFGS = SMOKE ? 40 : Int(geti("PR_LBFGS", 300))
const OUT   = get(ENV, "PR_OUT", "figs/phase_recon")
const BS    = parse.(Float64, split(get(ENV, "PR_B", SMOKE ? "10,40" : "10,25,40,55,70"), ","))
# trap aspect ratio λ = ω_z/ω_⊥ (oblate λ>1 / prolate λ<1). The DDI-geometry axis.
const LAMS  = parse.(Float64, split(get(ENV, "PR_LAMBDA", SMOKE ? "1.1818" : "1.1818"), ","))
const SEEDNAMES = split(get(ENV, "PR_SEEDS", SMOKE ? "polar,random1" : "polar,m_plus_F,random1,random2"), ",")
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, 1.1818))
const ATOM = PRESET.atom
const SYS  = SpinSystem(ATOM.F)
const F    = ATOM.F
const SM   = spin_matrices(F)
const DV   = cell_volume(PRESET.grid)

# seed name → an explicit initial ψ (random takes an Int seed, which can't go
# through find_ground_state's Float64-typed init_state_params).
function build_seed_psi(name)
    name == "polar" && return init_psi(PRESET.grid, SYS; state=:polar)
    name in ("m_plus_F", "ferro") && return init_psi(PRESET.grid, SYS; state=:m_plus_F)
    startswith(name, "random") &&
        return init_psi(PRESET.grid, SYS; state=:random, seed=parse(Int, name[7:end]))
    error("unknown seed $name")
end

# λ only changes the trap potential (grid / interactions / c_dd are λ-independent
# since ω_⊥ and ω_ref are fixed). Build the potential per λ.
potential_for(lam) = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, lam)).potential

base_kw(p, pot) = (; grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=pot, zeeman=ZeemanParams(p, 0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND)

function mean_fz(psi)
    fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, PRESET.grid)
    sum(fz) * DV
end
function mean_fperp(psi)
    fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, PRESET.grid)
    sum(sqrt.(fx .^ 2 .+ fy .^ 2)) * DV
end

@printf("phase recon: grid=%d^3  B=%s uG  λ=%s  seeds=%s  ITP=%d LBFGS=%d %s%s\n",
    NX, join(BS, ","), join(LAMS, ","), join(SEEDNAMES, ","),
    ITP, LBFGS, HAS_GPU ? "CUDA" : "CPU", SMOKE ? " [SMOKE]" : "")
flush(stdout)

rows = NamedTuple[]
for lam in LAMS
    pot = potential_for(lam)
    for B in BS
        p = Units.bfield_to_p(B * 1e-6, ATOM.g_F, PRESET.omega_ref)
        kw = base_kw(p, pot)
        best = nothing
        for sname in SEEDNAMES
            psi0 = Array{ComplexF64}(build_seed_psi(sname))
            gs = find_ground_state(; kw..., psi_init=psi0,
                dt=0.002, n_steps=ITP, tol=1e-12, save_every=max(1, ITP ÷ 5), verbose=false)
            gl = find_ground_state_lbfgs(; kw...,
                psi_init=Array{ComplexF64}(gs.workspace.state.psi),
                n_steps=LBFGS, tol=1e-12, m_lbfgs=10, verbose=false)
            psi = Array{ComplexF64}(gl.workspace.state.psi)
            cls = classify_phase(psi, F, PRESET.grid, SM)
            pops = component_populations(psi, PRESET.grid, SYS)
            fz = mean_fz(psi); fp = mean_fperp(psi)
            row = (; lam, B, seed=sname, E=gl.energy, grad=gl.grad_norm, Fz=fz, Fperp=fp,
                phase=String(cls.phase), pops=pops.populations)
            push!(rows, row)
            @printf("  λ=%.3f B=%5.1f  %-9s  E=%.5f |∇|=%.1e  Fz=%+.3f |F⊥|=%.4f  phase=%s\n",
                lam, B, sname, gl.energy, gl.grad_norm, fz, fp, String(cls.phase))
            flush(stdout)
            if best === nothing || gl.energy < best.E
                best = (; E=gl.energy, psi, lam, B, seed=sname, phase=String(cls.phase))
            end
        end
        # save the winning (lowest-E) ψ as a continuation seed for this cell
        jldsave(joinpath(OUT, @sprintf("seed_L%.3f_B%05.1f.jld2", lam, B));
            psi=best.psi, t=0.0, step=0,
            grid_n_points=PRESET.grid.config.n_points, grid_box_size=PRESET.grid.config.box_size,
            atom_name=ATOM.name, c0=PRESET.interactions[0], c1=PRESET.interactions[1],
            c_dd=PRESET.c_dd, zeeman_p=p, zeeman_q=0.0)
        @printf("  → λ=%.3f B=%.1f winner: %s  E=%.5f  phase=%s\n",
            lam, B, best.seed, best.E, best.phase)
        flush(stdout)
    end
end

# results table: one row per (λ, B, seed)
open(joinpath(OUT, "recon.csv"), "w") do io
    writedlm(io, ["lambda" "B" "seed" "E" "grad" "Fz" "Fperp" "phase"])
    for r in rows
        writedlm(io, [r.lam r.B r.seed r.E r.grad r.Fz r.Fperp r.phase])
    end
end
# populations table (λ, B, seed, then m=F..-F)
open(joinpath(OUT, "recon_pops.csv"), "w") do io
    writedlm(io, permutedims(vcat(["lambda", "B", "seed"], ["m$(F-i)" for i in 0:(2F)])))
    for r in rows
        writedlm(io, permutedims(vcat([r.lam, r.B, r.seed], r.pops)))
    end
end

println("\n================ winners (lowest-E per (λ,B)) ================")
for lam in LAMS, B in BS
    cell = filter(r -> r.lam == lam && r.B == B, rows)
    isempty(cell) && continue
    w = cell[argmin([r.E for r in cell])]
    @printf("λ=%.3f B=%5.1f  E=%.5f  Fz=%+.3f  |F⊥|=%.4f  phase=%-12s  (seed %s)\n",
        lam, B, w.E, w.Fz, w.Fperp, w.phase, w.seed)
end
println("DONE → ", OUT)

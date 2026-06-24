# Solve ONE pinned true-GS for the weak-field Eu+DDI degenerate problem, SAVE the
# wavefunction, and dump the fields needed for a density/spin/phase/energy figure.
#
# This is the figure companion to scripts/eu_pinning_extrapolation.jl — that
# driver only logs scalars and discards psi; here we persist psi (save_state) and
# the z-midplane slices so the broken-symmetry GS can actually be looked at.
#
# Env: TG_GRID=32 TG_BOX=24.0 TG_B_UG=10.0 TG_EPS=1e-3 TG_ITP=4000 TG_LBFGS=400
#      TG_OUT=figs/truegs  TG_SMOKE=1 (grid16, itp200, lbfgs60)
#   julia --project=. scripts/eu_truegs_figure_data.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem, static_zeeman,
    energy_decomposition, component_populations, spin_matrices, cell_volume,
    save_state, load_state, CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave
using Printf

geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const SMOKE = get(ENV, "TG_SMOKE", "") == "1"
const NX   = SMOKE ? 16 : Int(geti("TG_GRID", 32))
const BOX  = geti("TG_BOX", 24.0)
const B_UG = geti("TG_B_UG", 10.0)
# Warm continuation in the pin strength ε (descending): big ε converges to a
# STIFF clean minimum, then step down holding convergence. A single cold ε
# floors at ~1e-2; the continuation reaches ~1e-5 (see eu_pinning_extrapolation).
const EPS  = let d = SMOKE ? "4e-3,1e-3" : "4e-3,2e-3,1e-3,5e-4"
    sort(parse.(Float64, split(get(ENV, "TG_EPS", d), ",")); rev=true)
end
const ITP  = SMOKE ? 200 : Int(geti("TG_ITP", 4000))
const LBFGS = SMOKE ? 60 : Int(geti("TG_LBFGS", 600))
const SEED = get(ENV, "TG_SEED", "")   # jld2 to seed from (skips ITP — resolution-continuation)
const OUT  = get(ENV, "TG_OUT", "figs/truegs")
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, 1.1818))
const ATOM = PRESET.atom
const SYS  = SpinSystem(ATOM.F)
const P_ZEE = Units.bfield_to_p(B_UG * 1e-6, ATOM.g_F, PRESET.omega_ref)

@printf("true-GS figure data: grid=%d^3 box=%.1f B=%.1f uG eps(bx)=%s %s%s\n",
    NX, BOX, B_UG, join(EPS, ","), HAS_GPU ? "CUDA" : "CPU", SMOKE ? " [SMOKE]" : "")
flush(stdout)

base_kw(eps) = (; grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=PRESET.potential, zeeman=static_zeeman(; Bz=P_ZEE, Bx=eps, q=0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND)

# warm continuation in ε (descending): first ε from a symmetry-broken seed via
# ITP (avoids the :polar saddle), then LBFGS+Newton; each smaller ε warm-starts
# from the previous converged ψ to hold convergence down the continuation.
gl = let result = nothing, seed = nothing
    if !isempty(SEED)
        s = load_state(SEED)
        size(s.psi)[1:3] == (NX, NX, NX) ||
            error("seed grid $(size(s.psi)) ≠ target $(NX)^3 — upsample first")
        seed = Array{ComplexF64}(s.psi)
        @printf("seeded from %s (skipping ITP) — resolution-continuation polish\n", SEED)
    end
    for eps in EPS
        kw = base_kw(eps)
        if seed === nothing
            psi0 = init_psi(PRESET.grid, SYS; state=:m_plus_F)
            add_white_noise!(psi0, 0.02, 1, PRESET.grid)
            println("[eps $(eps)] ITP $(ITP) …"); flush(stdout)
            gs = find_ground_state(; kw..., psi_init=psi0, dt=0.002, n_steps=ITP,
                tol=1e-12, save_every=max(1, ITP ÷ 10), verbose=true)
            seed = Array{ComplexF64}(gs.workspace.state.psi)
        end
        println("[eps $(eps)] LBFGS $(LBFGS) + Newton polish …"); flush(stdout)
        result = find_ground_state_lbfgs(; kw..., psi_init=seed, n_steps=LBFGS,
            tol=1e-12, m_lbfgs=10, newton_polish=true, verbose=true)
        seed = Array{ComplexF64}(result.workspace.state.psi)
        @printf("[eps %.1e] E=%.6f |gradE|=%.3e\n", eps, result.energy, result.grad_norm)
        flush(stdout)
    end
    result
end

ws = gl.workspace
psi = Array{ComplexF64}(ws.state.psi)         # (nx,ny,nz,D)
HAS_GPU && CUDA.synchronize()

# --- persist the wavefunction (the snapshot) --------------------------------
# Save the HOST psi directly (save_state(ws) would serialize the GPU CuArray and
# its FFT/context handles → JLD2 reconstruct warnings on CPU load). Same schema
# load_state reads.
jldsave(joinpath(OUT, "truegs_state.jld2");
    psi=psi, t=0.0, step=0,
    grid_n_points=PRESET.grid.config.n_points,
    grid_box_size=PRESET.grid.config.box_size,
    atom_name=ATOM.name, c0=PRESET.interactions[0], c1=PRESET.interactions[1],
    c_dd=PRESET.c_dd, zeeman_p=P_ZEE, zeeman_q=0.0)

# --- fields ------------------------------------------------------------------
D = size(psi, 4)
F = (D - 1) ÷ 2
nz = size(psi, 3)
kz = nz ÷ 2 + 1                                # z-midplane
xs = collect(PRESET.grid.x[1])

dens3 = dropdims(sum(abs2, psi; dims=4); dims=4)            # (nx,ny,nz)
fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, PRESET.grid)
# dominant component for phase (ground state of +Bz, g_F>0 ⇒ m=-F ⇒ c=D)
cdom = D
phase = angle.(@view psi[:, :, kz, cdom])

dens_xy = dens3[:, :, kz]
fx_xy, fy_xy, fz_xy = fx[:, :, kz], fy[:, :, kz], fz[:, :, kz]
fperp_xy = sqrt.(fx_xy .^ 2 .+ fy_xy .^ 2)

pops = component_populations(psi, PRESET.grid, SYS)
edec = energy_decomposition(ws)

# --- dump for python viz -----------------------------------------------------
writedlm(joinpath(OUT, "x.csv"), xs)
writedlm(joinpath(OUT, "density_xy.csv"), dens_xy)
writedlm(joinpath(OUT, "fx_xy.csv"), fx_xy)
writedlm(joinpath(OUT, "fy_xy.csv"), fy_xy)
writedlm(joinpath(OUT, "fz_xy.csv"), fz_xy)
writedlm(joinpath(OUT, "fperp_xy.csv"), fperp_xy)
writedlm(joinpath(OUT, "phase_xy.csv"), phase)
writedlm(joinpath(OUT, "populations.csv"),
    hcat(collect(pops.m_values), pops.populations))

# energy decomposition + scalars as key,value text
open(joinpath(OUT, "meta.csv"), "w") do io
    writedlm(io, ["key" "value"])
    writedlm(io, ["grid" NX]); writedlm(io, ["box" BOX]); writedlm(io, ["B_uG" B_UG])
    writedlm(io, ["eps_bx" EPS[end]]); writedlm(io, ["E_total" gl.energy])
    writedlm(io, ["grad_norm" gl.grad_norm]); writedlm(io, ["F" F])
    for k in propertynames(edec)
        v = getfield(edec, k)
        v isa Number && writedlm(io, ["E_" * String(k) v])
    end
end

@printf("DONE  E=%.5f |gradE|=%.2e  → %s\n", gl.energy, gl.grad_norm, OUT)
for (m, p) in zip(pops.m_values, pops.populations)
    p > 1e-4 && @printf("   m=%+d  pop=%.4f\n", Int(m), p)
end

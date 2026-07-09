# scripts/edh_vs_flower/gs_trajectory.jl
# ============================================================================
# Ground-state from SCRATCH with full convergence TRAJECTORY logging, to verify
# (quantitatively + visually) that the 10 mG GS is correctly obtained.
#   random init  →  ITP (imaginary-time)  →  LBFGS (Sobolev) polish
# Records every RECORD_EVERY steps: energy, grad_norm (LBFGS), per-m populations,
# <Fz>, and z-midplane density / spin-z slices — enough for convergence curves
# AND an animation of the wavefunction settling into the GS.
# Matches the eu151_edh_phys mixin EXACTLY: Eu151, 64^3, box 18, 10 mG,
# c1_ratio=0 (c1=0), DDI on, no LHY.  Writes trajectory + final GS cache.
#
# Usage: julia --project=. scripts/edh_vs_flower/gs_trajectory.jl <out_traj.jld2> <out_gs.jld2>
import CUDA
using SpinorBEC
using SpinorBEC: Eu151, Units, make_grid, GridConfig, HarmonicTrap, ZeemanParams,
                 interaction_params_from_constraint, compute_c_dd_dimless,
                 find_ground_state, find_ground_state_lbfgs, total_energy,
                 spin_matrices, spin_density_vector, CUDABackend, CPUBackend
using JLD2, Printf, LinearAlgebra

const OUT_TRAJ = ARGS[1]
const OUT_GS   = ARGS[2]
_opt(flag,d)=(i=findfirst(==(flag),ARGS); (i===nothing||i==length(ARGS)) ? d : ARGS[i+1])
const BK = _opt("--backend","gpu")
const REC = parse(Int, _opt("--record_every","50"))
const ITP_STEPS = parse(Int, _opt("--itp_steps","20000"))
const LBFGS_STEPS = parse(Int, _opt("--lbfgs_steps","2000"))
const C1R = let v=_opt("--c1_ratio","0.0"); v=="1/36" ? 1/36 : parse(Float64,v) end  # Matsui/Buchachenko = 1/36
const NG = parse(Int, _opt("--n","64"))   # cubic grid points per axis (v6 uses 96)

# --- physics (eu151_edh_phys mixin) ---
const N=50_000; const NPTS=(NG,NG,NG); const BOX=(18.0,18.0,18.0)
const TRAP=(1.0,1.0,1.182); const OMEGA=691.15; const B_G=0.01   # 10 mG
atom = Eu151
a_ho = sqrt(Units.HBAR/(atom.mass*OMEGA))
c_total = 4π*(atom.a_s/a_ho)*N
inter = interaction_params_from_constraint(; c_total=c_total, c1_ratio=C1R, F=6)
c_dd = compute_c_dd_dimless(atom; N_atoms=N, omega_ref=OMEGA)
grid = make_grid(GridConfig(NPTS, BOX))
pot  = HarmonicTrap{3}(TRAP)
p = Units.bfield_to_p(B_G, atom.g_F, OMEGA)   # bfield_to_p(::Real) interprets arg as GAUSS
zee = ZeemanParams(p, 0.0)
backend = (BK=="gpu") ? CUDABackend() : CPUBackend()
sm = spin_matrices(6)
zc = NPTS[3] ÷ 2 + 1
yc = NPTS[2] ÷ 2 + 1
const C_M6 = 13   # c index for m=-6 (c=1→m=+6 … c=13→m=-6)
const C_M5 = 12
@printf("[gs_traj] c_total=%.4g c0=%.4g c1=%.4g c_dd=%.4g p=%.4g\n",
        c_total, inter.c[0], get(inter.c,1,0.0), c_dd, p)

# --- trajectory buffers ---
phase=String[]; steps=Int[]; Es=Float64[]; gns=Float64[]; Fzs=Float64[]
Fperps=Float64[]                                     # ∫|F_perp| / ∫n  (transverse spin)
pops=Vector{Float64}[]
# xy (z-mid) and xz (y-mid) slices: density, fx, fy, fz, and phase of m=-6 / m=-5
n_xy=Matrix{Float32}[]; fx_xy=Matrix{Float32}[]; fy_xy=Matrix{Float32}[]; fz_xy=Matrix{Float32}[]
a6_xy=Matrix{Float32}[]; a5_xy=Matrix{Float32}[]
n_xz=Matrix{Float32}[]; fx_xz=Matrix{Float32}[]; fz_xz=Matrix{Float32}[]; a6_xz=Matrix{Float32}[]

function record!(ph, step, psi, E, gn)
    pp = ComplexF64.(Array(psi))                     # (nx,ny,nz,13) spinor-last
    @assert size(pp)[end]==13
    dens = dropdims(sum(abs2, pp; dims=4); dims=4)    # (nx,ny,nz)
    ntot = sum(dens)
    popv = [sum(abs2, @view pp[:,:,:,c]) for c in 1:13] ./ ntot
    mvals = collect(6:-1:-6)
    Fz = sum(mvals .* popv)
    fx,fy,fz = spin_density_vector(pp, sm, 3)
    fperp = sum(sqrt.(fx.^2 .+ fy.^2)) / ntot         # density-weighted transverse spin proxy
    push!(phase,ph); push!(steps,step); push!(Es,E); push!(gns,gn); push!(Fzs,Fz); push!(Fperps,fperp)
    push!(pops, popv)
    # xy slice (z=mid)
    push!(n_xy,  Float32.(@view dens[:,:,zc]))
    push!(fx_xy, Float32.(@view fx[:,:,zc])); push!(fy_xy, Float32.(@view fy[:,:,zc])); push!(fz_xy, Float32.(@view fz[:,:,zc]))
    push!(a6_xy, Float32.(angle.(@view pp[:,:,zc,C_M6]))); push!(a5_xy, Float32.(angle.(@view pp[:,:,zc,C_M5])))
    # xz slice (y=mid)
    push!(n_xz,  Float32.(@view dens[:,yc,:]))
    push!(fx_xz, Float32.(@view fx[:,yc,:])); push!(fz_xz, Float32.(@view fz[:,yc,:]))
    push!(a6_xz, Float32.(angle.(@view pp[:,yc,:,C_M6])))
end

# --- ITP from random init ---
println("[gs_traj] === ITP (random init) ===")
itp_cb = function(ws, step, n_steps)
    (step==1 || step%REC==0) && record!("itp", step, ws.state.psi, total_energy(ws), NaN)
end
g_itp = find_ground_state(; grid=grid, atom=atom, interactions=inter, zeeman=zee,
    potential=pot, initial_state=:random, n_steps=ITP_STEPS, tol=1e-9, dt=0.005,
    enable_ddi=true, c_dd=c_dd, backend=backend, on_step=itp_cb, verbose=true)
@printf("[gs_traj] ITP done: E=%.6g\n", total_energy(g_itp.workspace))

# --- LBFGS polish ---
println("[gs_traj] === LBFGS (Sobolev 0.5) ===")
lbfgs_cb = function(step, E, gn, psi)
    record!("lbfgs", step, psi, E, gn)
end
g_lb = find_ground_state_lbfgs(; grid=grid, atom=atom, interactions=inter,
    zeeman=zee, potential=pot, psi_init=Array(g_itp.workspace.state.psi),
    n_steps=LBFGS_STEPS, tol=1e-9, m_lbfgs=10, sobolev_alpha=0.5,
    enable_ddi=true, c_dd=c_dd, secular_ddi=false, backend=backend, verbose=true,
    on_record=lbfgs_cb, record_every=10)
@printf("[gs_traj] LBFGS done: E=%.6g grad_norm=%.3e converged=%s\n",
        g_lb.energy, g_lb.grad_norm, g_lb.converged)

# --- save trajectory + final GS ---
nrec=length(steps)
popm = Matrix(permutedims(reduce(hcat, pops)))        # (nrec,13) plain Matrix (no Adjoint→h5py-readable)
st(v) = cat(v...; dims=3)                             # stack slices → (nx,n2,nrec)
jldsave(OUT_TRAJ; phase=phase, step=steps, energy=Es, grad_norm=gns, Fz=Fzs, Fperp=Fperps,
    populations=popm,
    n_xy=st(n_xy), fx_xy=st(fx_xy), fy_xy=st(fy_xy), fz_xy=st(fz_xy),
    arg6_xy=st(a6_xy), arg5_xy=st(a5_xy),
    n_xz=st(n_xz), fx_xz=st(fx_xz), fz_xz=st(fz_xz), arg6_xz=st(a6_xz),
    box=BOX[1], NX=NPTS[1], zc=zc, yc=yc, omega_ref=OMEGA, B_gauss=B_G, nrec=nrec)
psi_out = Array{ComplexF64}(g_lb.workspace.state.psi)
jldsave(OUT_GS; psi=psi_out, B_gauss=B_G, grid_n=collect(NPTS), grid_box=collect(BOX),
    n_atoms=N, c_dd=c_dd, F=6, E=g_lb.energy, grad_norm=g_lb.grad_norm,
    converged=g_lb.converged ? 1 : 0, method="gs_trajectory random->ITP->LBFGS sobolev0.5")
@printf("[gs_traj] wrote %s (%d records) and %s\n", OUT_TRAJ, nrec, OUT_GS)

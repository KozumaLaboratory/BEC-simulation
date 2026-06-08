#!/usr/bin/env julia
# scripts/m1_polar_afm_boundary.jl
#
# First (b) piece: classify the Ω=0 polar→AFM boundary (B≈2.6–5) ORDER,
# the two-diagnostic method WHERE IT WORKS (the gapped domain B=1 delineated).
# CPU-only, no GPU warm-up: load the converged neighbours (B=2.6 polar GS,
# B=5 AFM GS from the multistart sweep) and Newton-CG-CONTINUE each branch
# toward the other through the boundary. Three signals, read only at
# CONVERGED (gapped → stationary) points:
#   (1) E_polar(B) vs E_AFM(B) crossing            → Ω_thermo analogue (the GS
#       boundary; LEVEL CROSSING ⇒ 1st order if both gapped there).
#   (2) λ_min(B) of each branch → 0                 → 2nd-order softening.
#   (3) cross-branch fidelity |⟨ψ_polar|ψ_AFM⟩|²    → merge(→1, 2nd) vs distinct
#       (low, 1st). Fidelity needs NO stationarity, so it is valid even where
#       a branch has not fully converged.
# 1st order = polar survives as a distinct metastable minimum up to B=5
# (low fidelity, both gapped, energies cross). 2nd order = the polar branch
# merges into AFM (fidelity→1 and/or λ_min→0) at the boundary.

using SpinorBEC
using SpinorBEC: newton_cg_ground_state, trapped_bdg_lowest_eigenvalue,
    magnetization, orbital_angular_momentum, energy_gradient!
using JLD2
using Printf
using LinearAlgebra

const TW = eu151_preset()
const DIR = "runs/sprint5_M1_multistart_groundstate"
const GATE_TOL = 1e-4
const BGRID = haskey(ENV, "M1_BGRID") ?
    parse.(Float64, split(ENV["M1_BGRID"], ",")) :
    [2.6, 3.0, 3.5, 4.0, 4.5, 5.0]

zeeman_for(B) = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(B * TW.p_per_nT), ConstantWaveform(0.0),
)

function build_cpu_ws(B)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=0.0)
    make_workspace(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B), potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false, backend=CPUBackend(),
    )
end

load_psi(B) = JLD2.load(joinpath(DIR, @sprintf("cell_B%.1f_Om0.00.jld2", B)), "psi")

function continue_branch(label, B_start, march)
    @printf("\n── branch %s (start B=%.1f) ──\n", label, B_start)
    ψ = load_psi(B_start)
    out_by_B = Dict{Float64, NamedTuple}()
    for B in march
        ws = build_cpu_ws(B)
        out = newton_cg_ground_state(ws, ψ;
            tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
        conv = out.grad_norm < GATE_TOL
        λ = conv ? trapped_bdg_lowest_eigenvalue(ws, out.psi; niter=30)[1] : NaN
        N = real(sum(abs2, out.psi)) * SpinorBEC.cell_volume(ws.grid)
        Fz = magnetization(out.psi, ws.grid, ws.spin_matrices.system) / N
        Lz = orbital_angular_momentum(out.psi, ws.grid, ws.fft_plans)
        out_by_B[B] = (; E=out.energy, gn=out.grad_norm, conv, λ, Fz, Lz, psi=out.psi)
        @printf("  B=%.2f  E=%.8g  |∇E|=%.2e  ⟨Fz⟩=%+.4f ⟨Lz⟩=%+.4f  λ=%-8s %s\n",
            B, out.energy, out.grad_norm, Fz, Lz,
            isnan(λ) ? "(soft)" : @sprintf("%.4f", λ), conv ? "GAPPED" : "soft")
        flush(stdout)
        conv && (ψ = out.psi)
    end
    out_by_B
end

fidelity(a, b, dV) = abs(sum(conj.(a) .* b) * dV)^2 /
                     (real(sum(abs2, a)) * dV * real(sum(abs2, b)) * dV)

@printf("Ω=0 polar↔AFM boundary order — B∈%s (CPU continuation from saved GS)\n", BGRID)
polar = continue_branch(:polar, 2.6, sort(BGRID))          # up from 2.6
afm = continue_branch(:afm, 5.0, sort(BGRID; rev=true))    # down from 5.0

dV = SpinorBEC.cell_volume(TW.grid)
println("\n", "="^78)
@printf("%-6s %13s %13s %12s %8s %8s %10s\n",
    "B", "E_polar", "E_AFM", "ΔE=Ea−Ep", "λ_polar", "λ_AFM", "fidelity")
println("-"^78)
for B in sort(BGRID)
    p, a = polar[B], afm[B]
    fid = fidelity(p.psi, a.psi, dV)
    @printf("%-6.2f %13.6f %13.6f %+12.3e %8s %8s %10.4f\n",
        B, p.E, a.E, a.E - p.E,
        isnan(p.λ) ? "soft" : @sprintf("%.3f", p.λ),
        isnan(a.λ) ? "soft" : @sprintf("%.3f", a.λ), fid)
end
println("\nClassify: ΔE sign-flip = GS boundary. If branches stay DISTINCT there")
println("(fidelity ≪ 1, both λ GAPPED) ⇒ 1st order. If they MERGE (fidelity → 1)")
println("and/or λ_min → 0 ⇒ 2nd order (continuous).")

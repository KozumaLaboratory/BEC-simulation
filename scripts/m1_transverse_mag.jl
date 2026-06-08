#!/usr/bin/env julia
# scripts/m1_transverse_mag.jl
#
# The empirical (B)-prong of the polar↔AFM transition-vs-crossover question,
# WITHOUT the dead λ. The field is in-plane Bx, conjugate to the transverse
# magnetization ⟨F_x⟩. The codebase's "AFM" winner is the transverse-
# magnetized seed (⟨F_x⟩≠0); "polar" is m=0 (⟨F_x⟩=0). So ⟨F_x⟩ IS the
# order parameter that "distinguishes" them — and it is field-conjugate.
#
# A field conjugate to the order parameter turns a transition into a
# CROSSOVER (smooth response, nonzero at any Bx>0). Test: ⟨F_x⟩(Bx) along
# both continuation branches through the boundary. SMOOTH rise from ~0 with
# no jump, and the two branches merging, ⇒ crossover (empirically), the
# backstop to the symmetry argument. A discontinuity / sharp onset ⇒ a true
# transition. ⟨F_x⟩ needs NO eigensolve and NO stationarity for the
# qualitative trend (valid even on floored states), unlike λ_min.

using SpinorBEC
using SpinorBEC: newton_cg_ground_state, spin_density_vector
using JLD2
using Printf
using LinearAlgebra

const TW = eu151_preset()
const DIR = "runs/sprint5_M1_multistart_groundstate"
const BGRID = haskey(ENV, "M1_BGRID") ?
    parse.(Float64, split(ENV["M1_BGRID"], ",")) :
    [2.6, 2.8, 3.0, 3.3, 3.6, 4.0, 4.4, 4.7, 5.0]

zeeman_for(B) = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(B * TW.p_per_nT), ConstantWaveform(0.0),
)
function build_cpu_ws(B)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=0.0)
    make_workspace(; grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B), potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false, backend=CPUBackend())
end
load_psi(B) = JLD2.load(joinpath(DIR, @sprintf("cell_B%.1f_Om0.00.jld2", B)), "psi")

function mean_F(ψ, ws)
    fx, fy, fz = spin_density_vector(ψ, ws.spin_matrices, 3)
    Nrm = real(sum(abs2, ψ))
    (Fx=sum(fx) / Nrm, Fy=sum(fy) / Nrm, Fz=sum(fz) / Nrm)
end

function continue_branch(label, B_start, march)
    @printf("\n── branch %s (start B=%.1f) ──\n", label, B_start)
    ψ = load_psi(B_start)
    rows = NamedTuple[]
    for B in march
        ws = build_cpu_ws(B)
        out = newton_cg_ground_state(ws, ψ;
            tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
        F = mean_F(out.psi, ws)
        Fperp = sqrt(F.Fx^2 + F.Fy^2)
        push!(rows, (; label, B, F..., Fperp, gn=out.grad_norm))
        @printf("  B=%.2f  |∇E|=%.2e  ⟨Fx⟩=%+.4f ⟨Fy⟩=%+.4f ⟨Fz⟩=%+.4f  |⟨F⊥⟩|=%.4f\n",
            B, out.grad_norm, F.Fx, F.Fy, F.Fz, Fperp)
        flush(stdout)
        out.grad_norm < 1e-4 && (ψ = out.psi)   # continue from converged
    end
    rows
end

# Ground-state anchors at the saved grid (polished); shows GS ⟨Fx⟩ growth.
@printf("⟨F_x⟩(Bx) — in-plane field is conjugate to transverse magnetization\n")
@printf("\n== GS anchors (saved grid, polished) ==\n")
for B in [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]
    ws = build_cpu_ws(B)
    out = newton_cg_ground_state(ws, load_psi(B);
        tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
    F = mean_F(out.psi, ws)
    @printf("  B=%-6.1f |∇E|=%.2e  ⟨Fx⟩=%+.4f ⟨Fy⟩=%+.4f ⟨Fz⟩=%+.4f  |⟨F⊥⟩|=%.4f\n",
        B, out.grad_norm, F.Fx, F.Fy, F.Fz, sqrt(F.Fx^2 + F.Fy^2))
    flush(stdout)
end

polar = continue_branch(:polar, 2.6, sort(BGRID))
afm = continue_branch(:afm, 5.0, sort(BGRID; rev=true))

println("\n", "="^60)
@printf("%-6s %12s %12s %12s\n", "B", "Fx_polar", "Fx_afm", "ΔFx")
for B in sort(BGRID)
    p = polar[findfirst(r -> r.B == B, polar)]
    a = afm[findfirst(r -> r.B == B, afm)]
    @printf("%-6.2f %12.4f %12.4f %12.4f\n", B, p.Fx, a.Fx, a.Fx - p.Fx)
end
println("\nRead: ⟨Fx⟩ smooth 0→finite, both branches merging ⇒ crossover (smooth")
println("      field-conjugate response). Jump / sharp onset ⇒ true transition.")

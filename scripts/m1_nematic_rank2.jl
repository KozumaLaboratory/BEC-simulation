#!/usr/bin/env julia
# scripts/m1_nematic_rank2.jl
#
# Close the ONE honest-scope loose end of the polar↔AFM crossover proof:
# the conjugate-field argument rigorously handles the rank-1 discriminator
# ⟨F_x⟩ (forced smooth, field-conjugate), but a hypothetical hidden rank-2
# NEMATIC transition is NOT covered analytically (rank-2 ⟨Q⟩ is not
# conjugate to Bx, so it could be protected under residual C_2h(x) and
# onset at finite Bc, UNDER the smooth canting). Empirical test: the
# cloud-integrated rank-2 nematic tensor Q_ab and its biaxiality across the
# B-sweep. SMOOTH eigenvalues + biaxiality (no kink / jump / onset) ⇒ no
# hidden rank-2 feature ⇒ polar/AFM fully closed as a pure crossover.
#
# Global Q_ab = ⟨(F_aF_b+F_bF_a)/2⟩/N − F(F+1)/3 δ_ab (cloud-integrated;
# the aggregate rank-2 order parameter), eigenvalues l1≥l2≥l3, biaxiality
# β=(l2−l3)/(l1−l3). Polar (m=0) is uniaxial along z (β=0); canting tilts
# it toward x. A rank-2 transition would show as a non-analyticity in β(B).
# No eigensolve of the Hessian here — just observables on polished states.

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

function global_nematic(ψ, ws)
    sm = ws.spin_matrices
    F = sm.system.F
    Fm = (Matrix{ComplexF64}(sm.Fx), Matrix{ComplexF64}(sm.Fy), Matrix{ComplexF64}(sm.Fz))
    sp = Matrix{ComplexF64}[]
    for a in 1:3, b in a:3
        push!(sp, (Fm[a] * Fm[b] + Fm[b] * Fm[a]) / 2)
    end
    spatial = size(ψ)[1:(end - 1)]
    acc = zeros(Float64, 6)
    Ntot = 0.0
    @inbounds for I in CartesianIndices(spatial)
        s = @view ψ[I, :]
        Ntot += real(dot(s, s))
        for (idx, M) in enumerate(sp)
            acc[idx] += real(dot(s, M * s))
        end
    end
    Q = zeros(3, 3)
    idx = 0
    for a in 1:3
        for b in a:3
            idx += 1
            v = acc[idx] / Ntot - (a == b ? F * (F + 1) / 3 : 0.0)
            Q[a, b] = v
            Q[b, a] = v
        end
    end
    ev = eigvals(Symmetric(Q))          # ascending: ev[1]≤ev[2]≤ev[3]
    l1, l2, l3 = ev[3], ev[2], ev[1]
    β = (l2 - l3) / (l1 - l3 + eps(Float64))
    fx, _, _ = spin_density_vector(ψ, sm, 3)
    Fx = sum(fx) / Ntot
    (l1=l1, l2=l2, l3=l3, β=β, Fx=Fx)
end

function measure(B, ψ0)
    ws = build_cpu_ws(B)
    out = newton_cg_ground_state(ws, ψ0;
        tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
    q = global_nematic(out.psi, ws)
    (; B, gn=out.grad_norm, q.l1, q.l2, q.l3, q.β, q.Fx, psi=out.psi)
end

@printf("Global rank-2 nematic ⟨Q⟩ across the Bx sweep (hidden-transition check)\n\n")
@printf("== GS anchors (polished) ==\n")
@printf("%-7s %10s %9s %9s %9s %9s %9s\n", "B", "|∇E|", "l1", "l2", "l3", "biax_β", "⟨Fx⟩")
println("-"^70)
for B in [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]
    r = measure(B, load_psi(B))
    @printf("%-7.1f %10.2e %9.4f %9.4f %9.4f %9.4f %9.4f\n",
        r.B, r.gn, r.l1, r.l2, r.l3, r.β, r.Fx)
    flush(stdout)
end

function run_continuation()
    @printf("\n== polar branch continuation through the boundary (fine) ==\n")
    @printf("%-7s %10s %9s %9s %9s %9s %9s\n", "B", "|∇E|", "l1", "l2", "l3", "biax_β", "⟨Fx⟩")
    println("-"^70)
    ψ = load_psi(2.6)
    for B in sort(BGRID)
        r = measure(B, ψ)
        @printf("%-7.2f %10.2e %9.4f %9.4f %9.4f %9.4f %9.4f\n",
            r.B, r.gn, r.l1, r.l2, r.l3, r.β, r.Fx)
        flush(stdout)
        r.gn < 1e-4 && (ψ = r.psi)
    end
end
run_continuation()
println("\nRead: l1,l2,l3 and β SMOOTH in B (no kink/jump/onset) ⇒ no hidden rank-2")
println("      transition under the canting ⇒ polar/AFM is a pure crossover, fully closed.")

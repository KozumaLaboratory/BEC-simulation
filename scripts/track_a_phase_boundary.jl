#!/usr/bin/env julia
# scripts/track_a_phase_boundary.jl
#
# First Track-(a) deliverable: a REAL interaction-channel transition, located
# and order-classified with the λ-free suite — now that the tensor gradient is
# implemented (Newton-CG sees g_S). The conjugate-field pre-screen says B/Ω give
# crossovers (⟨F_x⟩/⟨L_z⟩ conjugate); the I_h/FM/cyclic phases differ by residual
# SYMMETRY (point group / σ_S fingerprint, NOT field-conjugate) ⇒ genuine
# transitions driven by the INTERACTIONS. Scan the rank-12 channel c12 (an
# I_h-load-bearing channel) across the cyclic↔I_h competition; at each value seed
# BOTH phases, Newton-CG to GS (the unlock), and read the λ-free signatures:
#   E_Ih(c12) vs E_cyc(c12) crossing  = the boundary (Ω_thermo analogue)
#   gated (Newton-CG converges) + DISTINCT (cross-branch fidelity ≪ 1) ⇒ 1st order
#   merge (fidelity→1) / a branch fails to converge (soft) ⇒ 2nd-order onset
# σ_S classification labels each branch. CPU (small grid); a GPU production scan
# is the follow-on.

using SpinorBEC
using SpinorBEC: newton_cg_ground_state, classify_polyhedral,
    canonical_polyhedral_spinor, SpinSystem
using LinearAlgebra, Printf

const NPT = parse(Int, get(ENV, "TA_NPT", "10"))
const C12S = haskey(ENV, "TA_C12") ? parse.(Float64, split(ENV["TA_C12"], ",")) :
    [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

gr = make_grid(GridConfig{3}((NPT, NPT, NPT), (8.0, 8.0, 8.0)))
sys = SpinSystem(6)
dV = cell_volume(gr)
env = sqrt.(dropdims(sum(abs2, init_psi(gr, sys; state=:polar); dims=4); dims=4))

function seed_from_spinor(ζ)
    ψ = zeros(ComplexF64, NPT, NPT, NPT, 13)
    for I in CartesianIndices((NPT, NPT, NPT))
        ψ[I, :] .= env[I] .* ζ
    end
    ψ ./= sqrt(real(sum(abs2, ψ)) * dV)
    ψ
end
ζ_ih = canonical_polyhedral_spinor(6)
ζ_cyc = (z = zeros(ComplexF64, 13); z[1] = 1 / sqrt(3);
    z[7] = cis(2π / 3) / sqrt(3); z[13] = cis(4π / 3) / sqrt(3); z)

function build_ws(c12)
    make_workspace(; grid=gr, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 12.0, 1 => 1.0, 6 => 2.0, 10 => 1.5, 12 => c12)),
        zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        psi_init=init_psi(gr, sys; state=:polar))
end

function relax(ws, ζ)
    out = newton_cg_ground_state(ws, seed_from_spinor(ζ);
        tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.05)
    ζc = vec(out.psi[NPT ÷ 2, NPT ÷ 2, NPT ÷ 2, :]); ζc ./= norm(ζc)
    (; E=out.energy, gn=out.grad_norm, psi=out.psi, cls=classify_polyhedral(ζc, 6).best)
end
fidelity(a, b) = abs(sum(conj.(a) .* b) * dV)^2 / (real(sum(abs2, a)) * dV * real(sum(abs2, b)) * dV)

@printf("Track (a): I_h ↔ cyclic boundary via c12 scan (%d³, Newton-CG on tensor)\n\n", NPT)
@printf("%-6s %13s %13s %12s %8s %8s %9s %8s\n",
    "c12", "E_Ih", "E_cyc", "ΔE=Ec−Ei", "cls_Ih", "cls_cyc", "fidelity", "winner")
println("-"^84)
for c12 in C12S
    ws = build_ws(c12)
    ri = relax(ws, ζ_ih)
    rc = relax(ws, ζ_cyc)
    fid = fidelity(ri.psi, rc.psi)
    win = ri.E < rc.E ? "I_h" : "cyclic"
    @printf("%-6.2f %13.6f %13.6f %+12.3e %8s %8s %9.4f %8s\n",
        c12, ri.E, rc.E, rc.E - ri.E, String(ri.cls), String(rc.cls), fid, win)
    flush(stdout)
end
println("\nRead: ΔE sign-flip = the boundary. Both gated + fidelity ≪ 1 there ⇒ 1st-order")
println("      (distinct symmetry phases cross); fidelity→1 / a branch goes soft ⇒ 2nd.")

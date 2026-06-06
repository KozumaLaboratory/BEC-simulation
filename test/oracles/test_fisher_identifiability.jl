# Fisher identifiability — the preflight instrument for the trust
# ledger's third column (docs/design/hamiltonian_layered_architecture.md
# §4.7, §5). Verifies, on a tiny static protocol:
#
#   1. linearity anchors — every parameter here enters its energy slot
#      linearly, so central FD is EXACT and ∂E_T/∂c = E_T/c is a free
#      identity (the §3 "checked, never declared" rule);
#   2. θ-valley — the FD-in-θ machinery certified by the same
#      valley_scan as the ψ-space bootstrap (:exact_floor for linear
#      parameters);
#   3. degenerate-protocol DETECTION — a protocol measuring only
#      E_total cannot identify 4 parameters: the report must say so
#      (null directions found, identifiable == false). This is the
#      failure class no code oracle sees: green suite + unidentifiable
#      protocol = confidently wrong posteriors;
#   4. rich-protocol verdict — per-slot energies identify all 4;
#   5. channel-space chain (the SBI shape, F=1): identifiability
#      transported to channel couplings (g₀, g₂) through the
#      T-CG-verified inverse map — J_chan = J_c · ∂(c₀,c₁)/∂(g₀,g₂).
#
# Observables are computed on the DUMB side (independence) for a FIXED
# reference state — the static cost regime. Dynamic protocols reuse
# the same machinery with f wrapping full forward runs (2·n_θ runs,
# TSUBAME-parallel); that wiring lands with the first real campaign.

using Test
using SpinorBEC
using SpinorBEC: fd_jacobian, fisher_information, identifiability_report
using SpinorBEC: dumb_energy_breakdown
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))

# θ = [c0, c1, c_dd, p]; ws rebuilt per evaluation (the FD-in-θ way);
# observables on a fixed reference state.
const GRID_F = make_grid(GridConfig{1}((8,), (6.0,)))
const PSI_F = let
    psi = init_psi(GRID_F, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
    psi ./ sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID_F))
end

function _ws_at(θ::AbstractVector{Float64})
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false, normalize_every=0)
    return make_workspace(;
        grid=GRID_F, atom=Rb87,
        interactions=InteractionParams(Dict(0 => θ[1], 1 => θ[2])),
        zeeman=ZeemanParams(θ[4], 0.0), potential=HarmonicTrap((1.0,)),
        sim_params=sp, enable_ddi=true, c_dd=θ[3], secular_ddi=false,
    )
end

function _slot_energies(θ)
    Ed = dumb_energy_breakdown(_ws_at(θ), PSI_F; ddi_secular=false)
    return [Ed.density_c0, Ed.spin_c1, Ed.ddi, Ed.zeeman_z]
end

_total_energy_only(θ) = [sum(_slot_energies(θ))]

const θ0 = [0.5, 0.1, 0.05, 0.3]

@testset "Fisher identifiability (preflight instrument)" begin
    @testset "linearity anchors: ∂E_slot/∂c = E_slot/c, FD exact" begin
        J = fd_jacobian(_slot_energies, θ0)
        E = _slot_energies(θ0)
        for (i, j) in ((1, 1), (2, 2), (3, 3), (4, 4))
            @test isapprox(J[i, j], E[i] / θ0[j]; rtol=1e-9)
        end
        # cross-terms vanish: each slot energy depends only on its own
        # coefficient (fixed state, linear entry)
        for i in 1:4, j in 1:4
            i == j && continue
            @test abs(J[i, j]) < 1e-9 * max(abs(J[i, i]), 1.0)
        end
    end

    @testset "θ-valley: FD-in-θ certified (linear ⇒ exact floor)" begin
        E_c1 = θ -> _slot_energies(θ)[2]
        ref = _slot_energies(θ0)[2] / θ0[2]   # exact ∂E_c1/∂c1
        v = valley_scan(; hs=[10.0^k for k in -1.0:-1.0:-6.0]) do h
            θp = copy(θ0); θm = copy(θ0)
            θp[2] += h * θ0[2]
            θm[2] -= h * θ0[2]
            fd = (E_c1(θp) - E_c1(θm)) / (2h * θ0[2])
            abs(fd - ref) / abs(ref)
        end
        @test v.kind === :exact_floor   # linear in c1: central FD exact
    end

    @testset "degenerate protocol DETECTED (E_total only)" begin
        rep = identifiability_report(
            _total_energy_only, θ0;
            param_names=["c0", "c1", "c_dd", "p"],
        )
        @test rep.identifiable == false
        @test length(rep.null_directions) == 3   # rank 1 from 4 params
    end

    @testset "rich protocol identifies all 4 (per-slot energies)" begin
        rep = identifiability_report(
            _slot_energies, θ0;
            param_names=["c0", "c1", "c_dd", "p"],
        )
        @test rep.identifiable == true
        @test isempty(rep.null_directions)
        @test isfinite(rep.cond)
    end

    @testset "channel-space chain (F=1 SBI shape): J_g = J_c · ∂c/∂g" begin
        # T-CG-verified map: c0 = (g0 + 2g2)/3, c1 = (g2 − g0)/3.
        M = [1/3 2/3; -1/3 1/3]
        g0vec = [0.3, 0.6]   # (g0, g2)
        f_chan = g -> _slot_energies(
            [(g[1] + 2g[2]) / 3, (g[2] - g[1]) / 3, θ0[3], θ0[4]]
        )
        J_g = fd_jacobian(f_chan, g0vec)
        c_of_g = [(g0vec[1] + 2g0vec[2]) / 3, (g0vec[2] - g0vec[1]) / 3, θ0[3], θ0[4]]
        J_c = fd_jacobian(_slot_energies, c_of_g)
        @test isapprox(J_g, J_c[:, 1:2] * M; rtol=1e-7, atol=1e-10)
        # And the channel protocol is identifiable from the two contact
        # slots alone:
        rep = identifiability_report(
            g -> f_chan(g)[1:2], g0vec; param_names=["g0", "g2"]
        )
        @test rep.identifiable == true
    end
end

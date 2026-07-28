# `kind: rotating_basis` vs the standard spinor path: same physics, and the
# `Fz` they report is NOT the same quantity.
#
# Since the RotatingBasisWS engine was retired (2026-06-21) both paths drive a
# lab-frame TimeDependentZeeman B(t) through the standard split-step. What still
# differs:
#
#   * the propagator — rotating_basis calls `split_step_midpoint!`, the standard
#     dynamics loop calls plain `split_step!`;
#   * the REPORTING FRAME — the `:Fz` entry of `:rotating_basis_dynamics` is
#     Σ_m m·|ψ̃_m|² = ⟨F·B̂(t)⟩, the spin projected on the INSTANTANEOUS FIELD,
#     whereas the standard path's F_z is the lab-frame axial magnetisation.
#
# Both are pinned here. The second is the one that bites: for a field rotating
# in the xy-plane the two numbers differ by more than 4× in this fixture, so
# reading a rotating_basis `Fz` column as "axial magnetisation" (the Barnett
# observable) silently reports the wrong physics.

using Test
using SpinorBEC
using LinearAlgebra

const _P_ZEE = 8.0
const _THETA = π / 2       # field in the xy-plane ⇒ tilde-z ⊥ lab-z
const _OMEGA = 0.9
const _T_END = 1.2
const _DT = 0.002
const _F = 2

function _rb_run(c_dd)
    gs = Dict{String, Any}(
        "F" => _F,
        "grid" => Dict("n" => [16, 16, 16], "box" => [8.0, 8.0, 8.0]),
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
        "interactions" => Dict("c0" => 30.0, "c1" => -0.6, "c_dd" => c_dd),
        "B" => Dict("p" => _P_ZEE, "q" => 0.0),
        "B_direction" => Dict("theta" => _THETA, "phi" => 0.0),
        "n_steps" => 250, "dt" => 0.01, "init_m_idx" => 1, "init_sigma" => 1.3,
    )
    psi_gs, grid, atom, _, gsr = SpinorBEC._run_step(
        SpinorBEC.RotatingBasisGroundStateStep(gs), nothing, nothing, nothing, nothing;
        verbose=false)
    dyn = Dict{String, Any}(
        "duration" => _T_END, "dt" => _DT, "save_every" => 50,
        "B_direction" => Dict("theta" => _THETA, "phi" => Dict("rate" => _OMEGA)),
        "save" => Dict("psi" => true),
    )
    _, _, _, _, dr = SpinorBEC._run_step(
        SpinorBEC.RotatingBasisDynamicsStep(dyn), psi_gs, grid, atom, nothing;
        verbose=false, pipeline_results=gsr)
    (gsr, grid, dr[:rotating_basis_dynamics])
end

# The standard path, driven from the identical lab state under the identical
# field. `Bx = A·sin(Ωt + π/2) = A·cos(Ωt)`, `By = A·sin(Ωt)` reproduces exactly
# the B̂ = (cos Ωt, sin Ωt, 0) that θ=π/2, φ(t)=Ωt gives on the rotating path.
function _standard_run(gsr, grid, c_dd, n_steps, save_every)
    prev = gsr[:rotating_basis_gs]
    sm = prev.sm;
    D = 2_F + 1;
    ND = 3
    psi_lab = Array{ComplexF64}(undef, size(prev.psi_tilde)...)
    copyto!(psi_lab, prev.psi_tilde)
    SpinorBEC._apply_UB!(psi_lab, sm, _THETA, 0.0, ND)

    zee = TimeDependentZeeman(
        ConstantWaveform(_P_ZEE * cos(_THETA)),
        ConstantWaveform(prev.q),
        SinusoidalWaveform(; amplitude=_P_ZEE * sin(_THETA), frequency=_OMEGA / 2π, phase=π/2),
        SinusoidalWaveform(; amplitude=_P_ZEE * sin(_THETA), frequency=_OMEGA / 2π, phase=0.0),
    )
    ws = make_workspace(; grid,
        atom=AtomSpecies("RB", 1.66e-25, _F, 0.0, 0.0, 0.0),
        interactions=InteractionParams(Dict(0 => prev.c0, 1 => prev.c1);
            c_lhy=prev.gamma_lhy),
        zeeman=zee, potential=NoPotential(),
        sim_params=SimParams(; dt=_DT, n_steps, imaginary_time=false, save_every),
        psi_init=psi_lab, enable_ddi=SpinorBEC.is_active(c_dd), c_dd=Float64(c_dd))
    copyto!(ws.potential_values, prev.V_trap)

    dV = prod(grid.dx)
    per_m = Vector{Vector{Float64}}();
    lab_Fz = Float64[];
    ts = Float64[]
    scratch = similar(ws.state.psi)
    for step in 1:n_steps
        split_step!(ws)
        step % save_every == 0 || continue
        t = step * _DT
        _, _, fz = spin_density_vector(Array(ws.state.psi), sm, ND)
        push!(lab_Fz, sum(fz) * dV);
        push!(ts, t)
        copyto!(scratch, ws.state.psi)
        SpinorBEC._apply_UB!(scratch, sm, _THETA, _OMEGA * t, ND; inverse=true)
        pm = [sum(abs2, selectdim(scratch, ND + 1, c)) * dV for c in 1:D]
        push!(per_m, pm ./ sum(pm))
    end
    (ts, per_m, lab_Fz)
end

@testset "rotating_basis ⇄ standard path: same physics, different reported Fz" begin
    for c_dd in (0.0, 12.0)
        gsr, grid, rb = _rb_run(c_dd)
        n_steps = round(Int, _T_END / _DT)
        ts, pm_std, labFz_std = _standard_run(gsr, grid, c_dd, n_steps, 50)

        sm = gsr[:rotating_basis_gs].sm
        dV = prod(grid.dx)
        snaps = rb[:psi_snapshots]

        @testset "c_dd = $c_dd" begin
            worst_pm = 0.0
            worst_fz = 0.0
            for (i, t) in enumerate(rb[:times])
                j = findfirst(x -> isapprox(x, t; atol=1e-9), ts)
                j === nothing && continue
                worst_pm = max(worst_pm,
                    maximum(abs.(rb[:per_m_history][i] .- pm_std[j])))
                # rotating_basis stores ψ̃; rotate back to lab for a like-for-like
                # comparison of the axial magnetisation.
                psi = copy(snaps[i])
                SpinorBEC._apply_UB!(psi, sm, _THETA, _OMEGA * t, 3)
                _, _, fz = spin_density_vector(psi, sm, 3)
                worst_fz = max(worst_fz, abs(sum(fz) * dV - labFz_std[j]))
            end
            # Two converged integrators of the same H under the same field. The
            # residual is propagator order (midpoint vs plain Strang), not a
            # Hamiltonian difference — a term-level drift would land ≫ 1e-4, the
            # scale at which the retired engine's inertial-term bug showed up.
            @test worst_pm < 1e-6
            @test worst_fz < 1e-6

            # The trap the frame difference sets: `:Fz` is ⟨F·B̂(t)⟩, not lab ⟨F_z⟩.
            # With B̂ in the xy-plane these are different projections and must NOT
            # be conflated. If this assertion ever starts failing because the two
            # converged, re-check that :Fz is still the tilde-frame quantity
            # before relaxing it.
            psi_end = copy(snaps[end])
            SpinorBEC._apply_UB!(psi_end, sm, _THETA, _OMEGA * rb[:times][end], 3)
            _, _, fz_end = spin_density_vector(psi_end, sm, 3)
            lab_Fz_end = sum(fz_end) * dV
            @test abs(rb[:Fz][end] - lab_Fz_end) > 1.0
        end
    end
end

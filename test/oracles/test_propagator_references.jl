# Propagator references: dt-valleys per term + Strang order slope.
#
# Completes the dumb reference's propagator coverage (arch doc §2).
# Two limit-class oracles (NEVER tight-tol — split-step legitimately
# differs from any reference by its truncation order; only the
# CONVERGENCE is identity-grade):
#
# 1. Per-term dt-valley: for each slot with a non-nil production
#    apply_step!, the step residual
#
#        ‖(step(ψ, dt) − ψ)/(−i·dt) − g_dumb(ψ)‖ / ‖g_dumb‖
#
#    must descend with slope ≈ +1 (Taylor truncation; frozen-field vs
#    self-consistent differences are also O(dt)) into a floor.
#    A plateau = the propagator face generates a DIFFERENT operator
#    than the variational gradient — the sign/coefficient bug class on
#    the face where both 2026-06 sign bugs lived.
#
# 2. Strang order slope: production split-step core vs the dumb RK4
#    reference trajectory — endpoint error slope ≈ 2 in dt. Catches
#    fwd/bwd V-chain asymmetry (order collapse), missing terms
#    (plateau), and dt-accounting bugs, end-to-end.
#
# State choice per slot: the smooth coherent fixture state by default
# (spectrally compact — keeps FFT-shear paths clean); the singlet slot
# uses a generic random state (coherent states are exactly
# singlet-free — see test_master_oracle.jl).
#
# Singlet (tensor) note: this is the first time the singlet PROPAGATOR
# face is checked against the variational RHS. A plateau here is a
# semantics finding about the production pair step, not necessarily a
# harness bug — derive before patching either side.

using Test
using SpinorBEC
using SpinorBEC: HamTerm, apply_step!, build_h_terms_registry
using SpinorBEC: dumb_rhs_breakdown, dumb_rk4_evolve
using SpinorBEC: KineticTerm, TrapTerm, LinearZeemanZTerm, TransverseZeemanTerm,
    DensityC0Term, SpinC1Term, DDITerm, LHYTerm, TensorTerm, RamanTerm,
    LightShiftTerm, CoriolisTerm, MagneticGradientTerm
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))
include(joinpath(@__DIR__, "..", "helpers", "oracle_fixtures.jl"))

# Down to 1e-8: terms with a large spectral radius (kinetic — k²/2 up
# to ~33 on the 3D fixture) have residual ≈ (dt/2)·⟨H²⟩/⟨H⟩ and need
# small dt to descend below HEALTHY_MIN; the roundoff floor
# eps·‖ψ‖/(dt·‖g‖) stays ≲ 1e-9 even at dt = 1e-8.
const DT_LIST = [10.0^k for k in -1.0:-0.5:-8.0]
const DT_HEALTHY_MIN = 1e-5

# Slope band, set from the measured full-band log-log fit (2026-06-07,
# over fixtures A / B / DDI / spin-rotating-frame). The order itself is
# NOT inferred from the slope: every per-term step is the SAME
# first-order exp(−i·dt·H) substep, so each term is order 1 BY
# CONSTRUCTION (the splitting scheme), and the slope is merely a
# CONSISTENCY CHECK of that — never the justification. The single-term
# residual is r(dt) = (dt/2)·‖H²ψ‖/‖Hψ‖ + O(dt²); the *fitted* slope
# over the band is not a clean 1.0 because the dt² admixture's weight
# grows when the operator's leading coefficient is small, so it is
# (term × fixture)-dependent. (For lhy/spin_c1 the full band cannot
# separate that admixture from a true order-2 — a gray zone — which is
# exactly why order is read from the scheme, not the slope.) Measured:
#   stiff/large-coefficient → slope ≈ 1.0  (kinetic 1.00, trap 1.00,
#     fixture-A zeeman_z 0.98, transverse 1.00, density_c0 1.00, ddi
#     1.00, raman 1.00, light_shift 1.00, coriolis 1.00, mg 0.99)
#   small-coefficient / soft mean-field → higher  (spin_c1 1.51, lhy
#     1.84, and RF zeeman_z 1.46 because p_eff = p − ω_R = 0.1 is small)
# So a per-term band is the wrong model (zeeman_z is 0.98 OR 1.46 by
# fixture). One band bracketing the measured max (1.84) + margin; this
# is tighter than the prior over-cautious 2.6, justified by the data.
# A sign / missing-operator bug does NOT shift the slope — it PLATEAUS
# (kind ≠ :valley), caught by the `kind` assertion; the band guards
# order-of-accuracy drift only.
const DT_SLOPE_BAND = (0.7, 2.2)

"""Per-term step residual at one dt (RT). Copies ψ so the caller's
state is untouched; syncs the kinetic phase cache when needed (the
dt-through-cache ritual — protocol tension #4, arch doc App. A)."""
function step_residual(term::HamTerm, ws, ψ, g, dt)
    ψc = copy(ψ)
    if term isa KineticTerm
        SpinorBEC._update_batched_kinetic_phase!(
            ws.batched_kinetic, ws.grid.k_squared, dt
        )
        apply_step!(term, ψc, 0.0, false, ws)
    else
        apply_step!(term, ψc, dt, false, ws)
    end
    num = sqrt(sum(abs2, (ψc .- ψ) ./ (-im * dt) .- g))
    return num / sqrt(sum(abs2, g))
end

function dt_valley_for(slot, term, ws, ψ; ddi_secular=nothing)
    G = dumb_rhs_breakdown(ws, ψ; ddi_secular)
    g = G[slot]
    nrm = sqrt(sum(abs2, g))
    @test nrm > 1e-8   # slot active AND state non-degenerate
    v = valley_scan(
        dt -> step_residual(term, ws, ψ, g, dt);
        hs=DT_LIST, floor_tol=1e-12, healthy_min=DT_HEALTHY_MIN,
    )
    @test v.kind in (:valley, :exact_floor)
    if v.kind === :valley && !isnan(v.slope)
        @test DT_SLOPE_BAND[1] < v.slope < DT_SLOPE_BAND[2]
    end
    return v
end

_registry_term(ws, ::Type{T}) where {T} = begin
    out = nothing
    for t in build_h_terms_registry(ws)
        t isa T && (out = t)
    end
    out
end

@testset "propagator references — per-term dt-valleys + Strang slope" begin
    @testset "fixture A slots (3D, no DDI)" begin
        ws, psi = oracle_full_ws(; ddi=false)
        for (slot, T) in (
            (:kinetic, KineticTerm), (:trap, TrapTerm),
            (:zeeman_z, LinearZeemanZTerm),
            (:zeeman_transverse, TransverseZeemanTerm),
            (:density_c0, DensityC0Term), (:spin_c1, SpinC1Term),
            (:lhy, LHYTerm), (:coriolis, CoriolisTerm),
        )
            @testset "$slot" begin
                dt_valley_for(slot, _registry_term(ws, T), ws, psi)
            end
        end
    end

    @testset "spin-rotating-frame dt-valleys (defect-5 gate, ω_R ≠ 0, t ≠ 0)" begin
        # Term-face ↔ dumb consistency under the RF model: the registry
        # bakes (p − ω_R, rotated bx/by) into the term structs, the
        # dumb side applies the same model independently.
        ws, psi = omega_R_ws()
        for (slot, T) in (
            (:zeeman_z, LinearZeemanZTerm),
            (:zeeman_transverse, TransverseZeemanTerm),
        )
            @testset "$slot" begin
                dt_valley_for(slot, _registry_term(ws, T), ws, psi)
            end
        end
    end

    @testset "split_step! ≡ dumb RHS in the spin rotating frame (defect-5 end-to-end)" begin
        # THE defect-5 gate: the PRODUCTION propagator applies the RF
        # Hamiltonian via zeeman_diagonal(z, sm, ω_R) and the rotated
        # transverse step; pre-fix the registry/dumb faces were
        # lab-frame, so this one-step residual plateaued at the frame
        # mismatch (~3e-2 here) instead of O(dt) (~4e-4 at dt = 1e-4).
        ws, psi = omega_R_ws()
        n_comp = ws.spin_matrices.system.n_components
        dt = 1e-4
        g = SpinorBEC.dumb_rhs_total(ws, Array(psi))
        copyto!(ws.state.psi, psi)
        SpinorBEC._strang_core!(ws, dt, n_comp)
        deriv = (Array(ws.state.psi) .- Array(psi)) ./ (-im * dt)
        rel = sqrt(sum(abs2, deriv .- g)) / sqrt(sum(abs2, g))
        @test rel < 5e-3
        copyto!(ws.state.psi, psi)
    end

    @testset "ddi dt-valley (3D, secular + full kernels)" begin
        for secular in (true, false)
            ws, psi = oracle_full_ws(; secular)
            @testset "secular=$secular" begin
                dt_valley_for(
                    :ddi, _registry_term(ws, DDITerm), ws, psi; ddi_secular=secular
                )
            end
        end
    end

    @testset "fixture B slots (1D aux)" begin
        rng = MersenneTwister(41)
        ws, psi = aux_ws()
        for (slot, T) in (
            (:raman, RamanTerm), (:light_shift, LightShiftTerm),
            (:magnetic_gradient, MagneticGradientTerm),
        )
            @testset "$slot" begin
                dt_valley_for(slot, _registry_term(ws, T), ws, psi)
            end
        end
        @testset "tensor (singlet pair — first variational check of the face)" begin
            ψr = rand_offmanifold_state(ws; rng)
            dt_valley_for(:tensor, _registry_term(ws, TensorTerm), ws, ψr)
        end
    end

    @testset "Strang order slope vs dumb RK4 (3D, no DDI)" begin
        ws, psi = oracle_full_ws(; ddi=false)
        dV = SpinorBEC.cell_volume(ws.grid)
        n_comp = ws.spin_matrices.system.n_components
        T_total = 0.02
        ψref = dumb_rk4_evolve(ws, psi, T_total, 200)   # RK4 global error O(dt⁴) ≪ Strang's

        dts = [2e-3, 1e-3, 5e-4]
        errs = Float64[]
        for dt in dts
            copyto!(ws.state.psi, psi)
            nsteps = round(Int, T_total / dt)
            for _ in 1:nsteps
                SpinorBEC._strang_core!(ws, dt, n_comp)
            end
            push!(errs, sqrt(sum(abs2, ws.state.psi .- ψref) * dV))
        end
        copyto!(ws.state.psi, psi)   # restore fixture state

        # global order 2: log-log slope of endpoint error vs dt
        xs = log10.(dts)
        ys = log10.(errs)
        x̄ = sum(xs) / length(xs)
        ȳ = sum(ys) / length(ys)
        slope = sum((xs .- x̄) .* (ys .- ȳ)) / sum(abs2, xs .- x̄)
        @test 1.6 < slope < 2.4
        @test errs[end] < 1e-5      # absolute sanity at the smallest dt
        @test errs[1] > errs[end]   # actually converging, not noise
    end

    @testset "Strang order slope WITH secular DDI vs dumb RK4 (3D)" begin
        # DDI sits innermost in the V sandwich and has its own history
        # of placement bugs (the *_ddi_strang_save_every regression
        # family). End-to-end order 2 with DDI active gates the
        # placement, the kernel, and the dt accounting together.
        ws, psi = oracle_full_ws()
        dV = SpinorBEC.cell_volume(ws.grid)
        n_comp = ws.spin_matrices.system.n_components
        T_total = 0.02
        ψref = dumb_rk4_evolve(ws, psi, T_total, 100; ddi_secular=true)

        dts = [2e-3, 1e-3, 5e-4]
        errs = Float64[]
        for dt in dts
            copyto!(ws.state.psi, psi)
            nsteps = round(Int, T_total / dt)
            for _ in 1:nsteps
                SpinorBEC._strang_core!(ws, dt, n_comp)
            end
            push!(errs, sqrt(sum(abs2, ws.state.psi .- ψref) * dV))
        end
        copyto!(ws.state.psi, psi)

        xs = log10.(dts)
        ys = log10.(errs)
        x̄ = sum(xs) / length(xs)
        ȳ = sum(ys) / length(ys)
        slope = sum((xs .- x̄) .* (ys .- ȳ)) / sum(abs2, xs .- x̄)
        @test 1.6 < slope < 2.4
        @test errs[end] < 1e-5
        @test errs[1] > errs[end]
    end
end

# Consolidated term property suite — docs/design/term_oracle_bootstrap.md.
#
# Week-1 item 1: step0 (FD trust bootstrap, ε-scaling valley, §3) on one
# representative per energy-nonlinearity class, plus a harness canary
# proving the valley detects a planted bug:
#
#   KineticTerm      — quadratic E: central FD exact ⇒ :exact_floor
#   LinearZeemanZ    — quadratic E with nontrivial spin structure
#   DensityC0Term    — quartic E: genuine truncation valley, slope ≈ +2
#
# The Pairing class (singlet c2) has no step0 pair — its gradient face
# is KNOWN-LIMIT nil — and enters at step2 via second-variation
# symmetry (§5). LHY joins at week-1 item 3, where the known defects
# trip (that is the gate working, not a detour).
#
# Growth path (§10–§11): step1 across the registry, step2 by operator
# class, symmetry declarations (§6), canary mutants (§7), collapse gate
# (§9), meta_completeness (§8). This file absorbs
# test_operator_trinity_per_term / four_step_chain /
# test_term_consistency / test_magnetic_gradient_gap as each property
# lands — every absorbed property deletes its old statement in the same
# commit.

using Test
using SpinorBEC
using SpinorBEC: HamTerm, apply_operator!, energy_contribution, apply_step!
using SpinorBEC: KineticTerm, LinearZeemanZTerm, DensityC0Term,
    LHYTerm, TensorTerm, RamanTerm
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))
include(joinpath(@__DIR__, "..", "helpers", "oracle_fixtures.jl"))

const VALLEY_MIN = 1e-7        # §3 primary oracle: valley floor reached
const SLOPE_BAND = (1.5, 2.5)  # §3 diagnostic: central-difference order ≈ 2

"""Run the §3 valley for one registry-built term against its own
canonical projection. Returns the `fd_valley` NamedTuple plus (δ, ref)
for reuse by harness canaries."""
function step0_valley(term::HamTerm, ws, psi; rng)
    dV = SpinorBEC.cell_volume(ws.grid)
    g = similar(psi)
    fill!(g, 0)
    apply_operator!(g, term, ws, psi)
    δ, ref = aligned_direction(g, dV, psi; rng)
    E = ψ -> energy_contribution(term, ψ, ws)
    v = fd_valley(E, psi, δ, ref)
    return v, δ, ref
end

@testset "term properties — step0 FD trust bootstrap (§3)" begin
    rng = MersenneTwister(2026)
    ws, psi = oracle_full_ws()

    @testset "KineticTerm (quadratic ⇒ exact floor)" begin
        v, _, _ = step0_valley(registry_term(ws, KineticTerm), ws, psi; rng)
        @test v.kind in (:exact_floor, :valley)
        @test v.min_err < VALLEY_MIN
        v.kind === :valley && @test SLOPE_BAND[1] < v.slope < SLOPE_BAND[2]
    end

    @testset "LinearZeemanZTerm (quadratic, spin-diagonal)" begin
        v, _, _ = step0_valley(registry_term(ws, LinearZeemanZTerm), ws, psi; rng)
        @test v.kind in (:exact_floor, :valley)
        @test v.min_err < VALLEY_MIN
        v.kind === :valley && @test SLOPE_BAND[1] < v.slope < SLOPE_BAND[2]
    end

    @testset "DensityC0Term (quartic ⇒ truncation valley, slope ≈ +2)" begin
        v, _, _ = step0_valley(registry_term(ws, DensityC0Term), ws, psi; rng)
        @test v.kind === :valley
        @test v.min_err < VALLEY_MIN
        @test SLOPE_BAND[1] < v.slope < SLOPE_BAND[2]
    end

    @testset "harness canary: valley detects a planted factor-2 plateau" begin
        # Coherent-mutation surrogate (§7 table, row `coefficient ×2`):
        # feed the valley a reference twice the true projection. A
        # healthy harness must classify this as :plateau at rel ≈ 0.5 —
        # a harness that still reports a valley is a no-op oracle.
        term = registry_term(ws, DensityC0Term)
        dV = SpinorBEC.cell_volume(ws.grid)
        g = similar(psi)
        fill!(g, 0)
        apply_operator!(g, term, ws, psi)
        δ, ref = aligned_direction(g, dV, psi; rng)
        E = ψ -> energy_contribution(term, ψ, ws)
        v = fd_valley(E, psi, δ, 2 * ref)
        @test v.kind === :plateau
        @test v.min_err > 0.3   # plateau height ≈ |1 − 1/2| = 0.5
    end

    @testset "harness canary: sign flip ⇒ plateau at ≈ 2" begin
        term = registry_term(ws, KineticTerm)
        dV = SpinorBEC.cell_volume(ws.grid)
        g = similar(psi)
        fill!(g, 0)
        apply_operator!(g, term, ws, psi)
        δ, ref = aligned_direction(g, dV, psi; rng)
        E = ψ -> energy_contribution(term, ψ, ws)
        v = fd_valley(E, psi, δ, -ref)
        @test v.kind === :plateau
        @test v.min_err > 1.0   # plateau height ≈ |1 − (−1)| = 2
    end
end

@testset "canonical pin — driver ×2 and dV clause (§1, week-1 item 2)" begin
    # The LBFGS driver contract (energy_gradient.jl:67-69): the returned
    # grad is 2·g (Wirtinger ×2), making δE = Re⟨grad, δψ⟩·dV in the
    # standard real inner product. The FD valley measures dE
    # independently: a driver that forgot the ×2 plateaus at 2, a
    # double-applied ×2 plateaus at 0.5. The ×2 is pinned HERE, at the
    # driver — never inside a term face.
    @testset "driver ×2 (energy_gradient!)" begin
        rng = MersenneTwister(7)
        ws, psi = oracle_full_ws()
        dV = SpinorBEC.cell_volume(ws.grid)
        grad = similar(psi)
        SpinorBEC.energy_gradient!(grad, psi, ws)
        δ, _ = aligned_direction(grad, dV, psi; rng)
        # Driver convention prediction (×1 on grad — the 2 lives inside):
        ref_driver = dV * real(sum(conj.(grad) .* δ))
        Efull = ψ -> begin
            copyto!(ws.state.psi, ψ)
            SpinorBEC.energy_decomposition(ws).total
        end
        v = fd_valley(Efull, psi, δ, ref_driver)
        @test v.kind in (:valley, :exact_floor)
        @test v.min_err < VALLEY_MIN
        copyto!(ws.state.psi, psi)   # restore fixture state
    end

    # The dV clause (§1) must be exercised on grids with dV on BOTH
    # sides of 1 — a dropped dV, or a dV in the wrong power, cannot
    # pass both (plateau at dV ratio ≈ 0.296 / 3.375 respectively).
    # Guards against a future "simplification" to a unit-dV fixture
    # silently weakening every valley in this file.
    @testset "dV ≠ 1, both sides (DensityC0 valley)" begin
        rng = MersenneTwister(13)
        for (box, side) in ((4.0, :below), (9.0, :above))
            ws, psi = oracle_full_ws(; box)
            dV = SpinorBEC.cell_volume(ws.grid)
            side === :below && @test dV < 0.5
            side === :above && @test dV > 2.0
            term = registry_term(ws, DensityC0Term)
            g = similar(psi)
            fill!(g, 0)
            apply_operator!(g, term, ws, psi)
            δ, ref = aligned_direction(g, dV, psi; rng)
            E = ψ -> energy_contribution(term, ψ, ws)
            v = fd_valley(E, psi, δ, ref)
            @test v.kind === :valley
            @test v.min_err < VALLEY_MIN
        end
    end
end

@testset "defect regressions — propagator faces + Raman energy (App. A 1-3)" begin
    # Defect 1: LHYTerm.apply_step! used to call `apply_lhy_step!`,
    # defined nowhere (UndefVarError on first call). Now a real phase
    # sharing `_lhy_V` with the production fused diagonal.
    @testset "LHYTerm.apply_step! — exists, unitary (RT), matches operator" begin
        ws, psi = oracle_full_ws()    # scalar c_lhy = 0.3 active
        dt = 1e-4
        ψ = copy(psi)
        apply_step!(LHYTerm(), ψ, dt, false, ws)
        @test sum(abs2, ψ) ≈ sum(abs2, psi) rtol = 1e-12  # diagonal phase ⇒ exact norm
        @test maximum(abs, ψ .- psi) > 1e-10              # actually acted
        # Small-dt consistency with the operator face (scalar LHY:
        # V = c_lhy·n^{3/2}, operator = V·ψ): (ψ' − ψ)/(−i·dt) ≈ H·ψ.
        g = similar(psi)
        fill!(g, 0)
        apply_operator!(g, LHYTerm(), ws, psi)
        deriv = (ψ .- psi) ./ (-im * dt)
        @test isapprox(deriv, g; rtol=1e-3)
    end

    # Defect 2: TensorTerm.apply_step! called a stale singlet signature
    # and a nonexistent `apply_tensor_step!`. Now delegates to the real
    # kernels. c2 singlet is independent at F=1 (KU); a polar state has
    # a guaranteed singlet amplitude (A₀₀ ∝ ψ₀²).
    @testset "TensorTerm.apply_step! — exists, unitary (RT, c2 active)" begin
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true, normalize_every=1)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.5, 1 => 0.1, 2 => 0.2)),
            zeeman=ZeemanParams(0.1, 0.0), potential=HarmonicTrap((1.0,)),
            sim_params=sp,
        )
        psi = init_psi(grid, SpinSystem(1); state=:polar)
        psi ./= sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
        ψ = copy(psi)
        apply_step!(TensorTerm(), ψ, 1e-3, false, ws)
        @test sum(abs2, ψ) ≈ sum(abs2, psi) rtol = 1e-10  # unitary pair mixing
        @test maximum(abs, ψ .- psi) > 1e-12              # actually acted
    end

    # Defect 3: RamanTerm.energy_contribution passed raw ws.raman into
    # `_raman_energy(::RamanCoupling)` — MethodError for
    # TimeDependentRaman (reachable: post-B1 the registry is the only
    # CPU energy path). Now resolved via raman_at at ws.state.t.
    @testset "RamanTerm energy resolves TimeDependentRaman" begin
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false, normalize_every=0)
        td = TimeDependentRaman{1}(ConstantWaveform(0.4), ConstantWaveform(0.1), (0.7,))
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0,)),
            sim_params=sp, raman=td,
        )
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
        E_td = energy_contribution(RamanTerm(), psi, ws)   # used to throw
        @test isfinite(E_td)
        # Must equal the energy under the statically-resolved coupling:
        ws_static = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0,)),
            sim_params=sp, raman=SpinorBEC.raman_at(td, ws.state.t),
        )
        E_static = energy_contribution(RamanTerm(), psi, ws_static)
        @test E_td ≈ E_static rtol = 1e-14
        @test abs(E_td) > 1e-12   # nonzero coupling on a coherent state
    end
end

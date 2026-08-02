# Master oracle: dumb reference vs production registry, per term.
#
# The mechanism behind architectural commitment #3 (zero silent sign
# drift via day-0 gated redundancy): every slot of
# H_TERMS_CANONICAL_ORDER is compared — energy and RHS — between the
# production faces (energy_contribution / apply_operator!) and the
# independent dumb statements (src/validation/dumb_reference.jl), at
# identity-class tolerance on the same discrete mathematics.
#
# Gap discipline (arch doc §4 KNOWN-LIMIT row):
# - DUMB_DEFERRED_SLOTS — dumb statement deferred to its own unit;
#   explicitly skipped, never silently. Empty since the DDI unit landed.
# - PRODUCTION_RHS_GAPS — production apply_operator! declared-nil; the
#   oracle asserts BOTH sides of the gap (production ≡ 0 AND dumb ≠ 0
#   when active), so the gap closing or widening is a test event either
#   way. EMPTY since 2026-07-31: :tensor left when its gradient face was
#   implemented (2026-06-09) and :raman when its was (2026-07-31), so
#   every slot's RHS is now compared against the dumb statement.
# - Slot coverage is not KIND coverage. The `lhy` slot's dumb statement
#   implements the scalar form only; see the declaration testset below.
#
# Set-equivalence meta-test: the dumb breakdown covers exactly the
# canonical slot list — a term added to the registry without a dumb
# statement (or vice versa) is a red, not a silent hole.

using Test
using SpinorBEC
using SpinorBEC:
    HamTerm, apply_operator!, energy_contribution,
    H_TERMS_CANONICAL_ORDER, build_h_terms_registry
using SpinorBEC:
    dumb_energy_breakdown, dumb_rhs_breakdown, DUMB_DEFERRED_SLOTS,
    dumb_lhy_coefficient
using SpinorBEC: ScalarLHY, IcosahedralLHY
using SpinorBEC: KineticTerm, TrapTerm, ZeemanTerm,
    DensityC0Term, SpinC1Term, DDITerm, LHYTerm, TensorTerm, RamanTerm,
    LightShiftTerm, CoriolisTerm, MagneticGradientTerm, SpatialZeemanTerm, LossTerm
using Random

include(joinpath(@__DIR__, "..", "helpers", "fd_gradient.jl"))
include(joinpath(@__DIR__, "..", "helpers", "oracle_fixtures.jl"))

const SLOT_TERM = (;
    kinetic=KineticTerm, trap=TrapTerm, zeeman=ZeemanTerm,
    density_c0=DensityC0Term,
    spin_c1=SpinC1Term, ddi=DDITerm, lhy=LHYTerm, tensor=TensorTerm,
    raman=RamanTerm, light_shift=LightShiftTerm, coriolis=CoriolisTerm,
    magnetic_gradient=MagneticGradientTerm, spatial_zeeman=SpatialZeemanTerm,
    loss=LossTerm,
)

const PRODUCTION_RHS_GAPS = ()  # :tensor 2026-06-09, :raman 2026-07-31

"""Source-faithful sign mutant: a copy of `term` with every numeric
field negated. The registry term carries its coefficients in struct
fields (`_diag_coef(term,m) = -term.p·m + term.q·m²`, `term.c0`,
`term.c1`, …), so the mutant runs the REAL production faces with a
flipped coefficient — for these linear terms negating all fields gives
exactly −energy and −Hψ. Returns `nothing` for coefficient-less terms
(Kinetic/DDI/LHY/…, whose coefficient lives in `ws`) or all-zero
fields (negation would be a no-op)."""
function _sign_mutant(term)
    T = typeof(term)
    fns = fieldnames(T)
    isempty(fns) && return nothing
    vals = map(f -> getfield(term, f), fns)
    all(v -> v isa Number, vals) || return nothing
    any(v -> abs(v) > 1e-14, vals) || return nothing
    T(map(-, vals)...)
end

const E_RTOL = 1e-10
const E_ATOL = 1e-12
const G_RTOL = 1e-10
const G_ATOL = 1e-11

# `aux_ws` (the MG/light-shift/Raman/c2 fixture) lives in
# test/helpers/oracle_fixtures.jl — shared with the propagator
# reference suite.

function compare_all_slots(ws, ψ, label; ddi_secular=nothing)
    Ed = dumb_energy_breakdown(ws, ψ; ddi_secular)
    Gd = dumb_rhs_breakdown(ws, ψ; ddi_secular)
    registry = build_h_terms_registry(ws)
    for slot in H_TERMS_CANONICAL_ORDER
        slot in DUMB_DEFERRED_SLOTS && continue
        T = getfield(SLOT_TERM, slot)
        term = nothing
        for t in registry
            t isa T && (term = t)
        end
        @testset "$label / $slot" begin
            @test term !== nothing
            # energy face
            Ef = energy_contribution(term, ψ, ws)
            @test isapprox(Ed[slot], Ef; rtol=E_RTOL, atol=E_ATOL)
            # RHS face
            g = similar(ψ)
            fill!(g, 0)
            apply_operator!(g, term, ws, ψ)
            if slot in PRODUCTION_RHS_GAPS
                @test sqrt(sum(abs2, g)) < 1e-12          # production declared-nil
                dumb_active = sqrt(sum(abs2, Gd[slot])) > 1e-10
                if abs(Ed[slot]) > 1e-12
                    @test dumb_active                      # dumb side sees the gap
                end
            else
                @test isapprox(g, Gd[slot]; rtol=G_RTOL, atol=G_ATOL)
            end
        end
    end
end

@testset "master oracle — dumb vs production, per term" begin
    @testset "set-equivalence meta-test" begin
        ws, psi = aux_ws()
        Ed = dumb_energy_breakdown(ws, psi)
        Gd = dumb_rhs_breakdown(ws, psi)
        @test Tuple(keys(Ed)) == H_TERMS_CANONICAL_ORDER
        @test Tuple(keys(Gd)) == H_TERMS_CANONICAL_ORDER
        @test DUMB_DEFERRED_SLOTS == ()   # every SLOT has a dumb arm
    end

    # Slot coverage is not kind coverage, and this is the meta-test whose job is
    # to stop that confusion. `LHYTerm` is one slot with ten interchangeable
    # tables behind it; the dumb statement implements the SCALAR form only and
    # raises on every `TabulatedLHY`. So `DUMB_DEFERRED_SLOTS == ()` says each
    # slot has a dumb arm — it does NOT say each LHY kind does, and the kinds
    # Eu F=6 production actually uses are exactly the ones it does not.
    #
    # Asserting the limitation is what keeps it declared rather than assumed.
    # The typed kinds are covered, by independent statements living elsewhere:
    #   oracles/test_lhy_full_bdg_closed_form_parity.jl — analytic closed form
    #       vs numerical BdG quadrature (polar F=1,2,6; FM F=6; scalar limit)
    #   oracles/test_lhy_magnitude_si_anchor.jl — SI magnitude, not self
    #   oracles/test_lhy_mode_face_coverage.jl — every schema kind × 3 faces
    # Extending `dumb_lhy_coefficient` to a table turns this red, which is the
    # prompt to widen the comparison and this declaration in the same commit.
    @testset "dumb LHY arm is scalar-only, by declaration" begin
        table = IcosahedralLHY([0.5, 1.0, 1.5], [1.0, 2.0, 3.0])
        @test_throws ErrorException dumb_lhy_coefficient((; lhy=table))
        @test dumb_lhy_coefficient((; lhy=ScalarLHY(0.7))) == 0.7
        @test dumb_lhy_coefficient((; lhy=nothing,
            interactions=(; c_lhy=0.3))) == 0.3
    end

    @testset "fixture A (3D, full incl. secular DDI)" begin
        rng = MersenneTwister(2026)
        ws, psi = oracle_full_ws()
        compare_all_slots(ws, psi, "A:coherent"; ddi_secular=true)
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "A:random"; ddi_secular=true)
    end

    @testset "fixture A′ (3D, FULL DDI kernel)" begin
        rng = MersenneTwister(2027)
        ws, psi = oracle_full_ws(; secular=false)
        compare_all_slots(ws, psi, "A′:coherent"; ddi_secular=false)
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "A′:random"; ddi_secular=false)
    end

    @testset "fixture B (1D, aux): mg/light_shift/raman/c2-singlet" begin
        rng = MersenneTwister(7)
        ws, psi = aux_ws()
        compare_all_slots(ws, psi, "B:coherent")
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "B:random")
    end

    @testset "fixture R (1D, spin rotating frame ω_R ≠ 0, t ≠ 0)" begin
        # App. A defect-5 gate: registry faces and the dumb statement
        # both apply the RF model (p → p − ω_R; (bx,by) rotated at t)
        # INDEPENDENTLY — identity here means the production registry
        # presents the same effective Hamiltonian the propagator runs.
        rng = MersenneTwister(17)
        ws, psi = omega_R_ws()
        compare_all_slots(ws, psi, "R:coherent")
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "R:random")
    end

    @testset "fixture SZ (1D, arbitrary B(r) active)" begin
        # Activates SpatialZeemanTerm with a non-trivial varying field so the
        # dumb-vs-production comparison of the :spatial_zeeman slot is
        # non-trivial (every other slot is inactive ⇒ 0 = 0).
        rng = MersenneTwister(31)
        grid = make_grid(GridConfig{1}((12,), (6.0,)))
        sys = SpinSystem(1)
        field = spatial_zeeman_field(grid;
            bz=(x,) -> 0.4 + 0.15x,
            bx=(x,) -> 0.2 - 0.1x,
            by=(x,) -> 0.05x^2,
            q=(x,) -> 0.03 + 0.02x^2)
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict{Int, Float64}()),
            potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
            spatial_zeeman=field)
        psi = init_psi(grid, sys; state=:m_plus_F)
        compare_all_slots(ws, psi, "SZ:coherent")
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "SZ:random")
    end

    @testset "fixture SZ+ (spatial B(r) coexisting with c0 + c1)" begin
        # Gates the spatial Zeeman term INTERACTING with contact terms in the
        # registry composition — the prior fixture SZ runs spatial alone (every
        # other slot 0 = 0). Here density_c0, spin_c1 AND spatial_zeeman are all
        # non-trivial, so a spatial-vs-contact cross-corruption reds the per-slot
        # dumb-vs-production comparison.
        rng = MersenneTwister(37)
        grid = make_grid(GridConfig{1}((12,), (6.0,)))
        sys = SpinSystem(1)
        field = spatial_zeeman_field(grid;
            bz=(x,) -> 0.3 + 0.1x, bx=(x,) -> 0.15 - 0.05x, q=(x,) -> 0.02x^2)
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.5, 1 => -0.3)),
            potential=HarmonicTrap((1.0,)),
            sim_params=SimParams(; dt=0.01, n_steps=1),
            spatial_zeeman=field)
        psi = init_psi(grid, sys; state=:spin_coherent, init_theta=π / 4)
        compare_all_slots(ws, psi, "SZ+:coherent")
        ψr = rand_offmanifold_state(ws; rng)
        compare_all_slots(ws, ψr, "SZ+:random")
    end

    # Hermiticity of the LINEAR production faces: ⟨φ|Hχ⟩ = ⟨Hφ|χ⟩ on
    # random pairs (frozen-field ambiguity does not exist for linear
    # terms). Absorbed from the retired 4-step chain, whose blanket
    # version was conceptually wrong for mean-field terms (it compared
    # H[ψ]ψ against H[φ]φ — different frozen fields) and whose step0
    # monotone heuristic was roundoff-fragile for exactly-quadratic
    # energies. Mean-field/pairing Hermitian structure = second-
    # variation symmetry on the dumb side (bootstrap doc §5),
    # registry-wide mutant canaries = §7 — both still-open items.
    @testset "linear-face Hermiticity (production apply_operator!)" begin
        rng = MersenneTwister(53)
        ws, _ = aux_ws()
        φ = rand_offmanifold_state(ws; rng)
        χ = rand_offmanifold_state(ws; rng)
        registry = build_h_terms_registry(ws)
        for slot in (:kinetic, :trap, :zeeman,
            :light_shift, :magnetic_gradient)
            T = getfield(SLOT_TERM, slot)
            term = nothing
            for t in registry
                t isa T && (term = t)
            end
            Hχ = zero(χ)
            apply_operator!(Hχ, term, ws, χ)
            Hφ = zero(φ)
            apply_operator!(Hφ, term, ws, φ)
            a = sum(conj.(φ) .* Hχ)
            c = sum(conj.(Hφ) .* χ)
            scale = max(abs(a), abs(c), 1e-30)
            @testset "$slot" begin
                @test abs(a - c) / scale < 1e-10
            end
        end
    end

    # Dumb-internal variational identity: the dumb energy and dumb RHS
    # of one slot must satisfy dE/dh = 2·dV·Re⟨g, δ⟩ — the FD valley,
    # run against the DUMB side only. Notably includes the PAIRING term
    # (conjugate-linear RHS), which production cannot check (its RHS is
    # a declared gap).
    #
    # State choice: GENERIC (random off-manifold), not the coherent
    # fixture state — spin-coherent states are exactly singlet-free
    # (F=1: 2ψ₊ψ₋ − ψ₀² ≡ 0), so the pairing slot's g and dE/dh both
    # degenerate to roundoff there and the valley measures 0/0. The
    # signal precondition below turns that degeneracy into a loud
    # failure instead of a misleading plateau.
    @testset "dumb-internal FD valley (incl. pairing)" begin
        rng = MersenneTwister(31)
        ws, _ = aux_ws()
        dV = SpinorBEC.cell_volume(ws.grid)
        ψv = rand_offmanifold_state(ws; rng)
        for slot in (:density_c0, :raman, :tensor)
            Gd = dumb_rhs_breakdown(ws, ψv)
            g = Gd[slot]
            @testset "$slot" begin
                @test sqrt(sum(abs2, g)) > 1e-8   # slot active AND state non-degenerate
                δ, ref = aligned_direction(g, dV, ψv; rng)
                E = ψ -> dumb_energy_breakdown(ws, ψ)[slot]
                v = fd_valley(E, ψv, δ, ref)
                @test v.kind in (:valley, :exact_floor)
                @test v.min_err < 1e-7
            end
        end
    end

    # SELF-CANARY: the beam's own canary. The set-equivalence + per-term
    # comparisons above only prove "dumb == production TODAY". They do
    # NOT, by themselves, prove the comparison would turn RED if a term's
    # sign drifted — a verifier's airtight-ness requirement. Here we
    # demonstrate the teeth, per ACTIVE term, two ways:
    #
    #   (1) source-faithful construction mutant: build a term with every
    #       coefficient negated (running the REAL production faces) — the
    #       SAME isapprox(dumb, production; rtol) the oracle uses must
    #       REJECT it. Covers every coefficient-bearing term.
    #   (2) value-perturbation: for EVERY active slot (incl. the
    #       coefficient-less terms whose coefficient lives in ws), the
    #       oracle comparison must reject −production and 2·production.
    #
    # Completeness: ≥1 source-faithful mutant must actually run (so the
    # faithful path is exercised, not skipped), and every coefficient-
    # bearing term active in a fixture must be mutant-canaried — a new
    # such term with no teeth is a red here, not a silent hole.
    @testset "self-canary: the master-oracle comparison has teeth" begin
        for (mkws, label, secular) in (
            (oracle_full_ws, "A", true), (aux_ws, "B", nothing)
        )
            ws, ψ = mkws()
            Ed = dumb_energy_breakdown(ws, ψ; ddi_secular=secular)
            Gd = dumb_rhs_breakdown(ws, ψ; ddi_secular=secular)
            registry = build_h_terms_registry(ws)
            mutant_checked = Symbol[]
            for slot in H_TERMS_CANONICAL_ORDER
                slot in DUMB_DEFERRED_SLOTS && continue
                T = getfield(SLOT_TERM, slot)
                term = nothing
                for t in registry
                    t isa T && (term = t)
                end
                term === nothing && continue
                Ef = energy_contribution(term, ψ, ws)
                g = zero(ψ)
                apply_operator!(g, term, ws, ψ)
                gnorm = sqrt(sum(abs2, g))
                (abs(Ef) > 1e-8 || gnorm > 1e-8) || continue   # active in this fixture
                @testset "$label / $slot teeth" begin
                    # (2) value-perturbation: flip + factor-2 rejected
                    if abs(Ef) > 1e-8
                        @test !isapprox(Ed[slot], -Ef; rtol=E_RTOL, atol=E_ATOL)
                        @test !isapprox(Ed[slot], 2 * Ef; rtol=E_RTOL, atol=E_ATOL)
                    end
                    if !(slot in PRODUCTION_RHS_GAPS) && gnorm > 1e-8
                        @test !isapprox(Gd[slot], -g; rtol=G_RTOL, atol=G_ATOL)
                        @test !isapprox(Gd[slot], 2 .* g; rtol=G_RTOL, atol=G_ATOL)
                    end
                    # (1) source-faithful construction mutant. CoriolisTerm
                    # binds Ω to ws (apply_operator! asserts term.Ω ==
                    # ws's Ω, since the Coriolis cache is ws-bound), so a
                    # flipped-Ω mutant is rejected by design — it gets
                    # teeth from the value-perturbation block above.
                    # (Authoring this canary surfaced a real single-source
                    # defect: SpinC1Term's gradient face read ws.interactions[1]
                    # instead of term.c1 — now fixed, so the c1 mutant flips.)
                    mut = term isa CoriolisTerm ? nothing : _sign_mutant(term)
                    if mut !== nothing
                        push!(mutant_checked, slot)
                        if abs(Ed[slot]) > 1e-8
                            Ef_m = energy_contribution(mut, ψ, ws)
                            @test !isapprox(Ed[slot], Ef_m; rtol=E_RTOL, atol=E_ATOL)
                        end
                        if !(slot in PRODUCTION_RHS_GAPS) && gnorm > 1e-8
                            gm = zero(ψ)
                            apply_operator!(gm, mut, ws, ψ)
                            @test !isapprox(Gd[slot], gm; rtol=G_RTOL, atol=G_ATOL)
                        end
                    end
                end
            end
            # CLASS guard, not instance. The source-faithful mutant
            # (flip term.<coeff> ⇒ energy AND RHS must respond) is what
            # caught SpinC1's single-source violation (gradient read
            # ws.interactions[1], bypassing term.c1). For this to close
            # the CLASS — not just SpinC1 — every active term carrying a
            # numeric coefficient field must receive that check. The
            # H_TERMS_CANONICAL_ORDER loop + `_sign_mutant` does so
            # structurally (and the set-equivalence meta-test guarantees
            # a new term is in the loop); we pin the load-bearing members
            # by name so a regression that silently drops one reds here.
            # CoriolisTerm is exempt (it binds Ω to ws by assertion —
            # single effective source). Fieldless terms (DDI/LHY/Tensor/
            # Raman/LightShift/MG/Loss) read one ws source — no parallel
            # source to drift to, so no violation is possible to guard.
            @testset "$label canary completeness (class guard)" begin
                @test !isempty(mutant_checked)
                expected = (:zeeman, :density_c0, :spin_c1)
                for slot in expected
                    @test slot in mutant_checked
                end
            end
        end
    end
end

using Test
using SpinorBEC
using SpinorBEC: HamTerm, build_h_terms_registry, build_gradient_context,
    build_energy_context, apply_operator!, energy_contribution,
    energy_operator_ratio, operator_and_energy_via_registry!,
    energy_decomposition, _realdot, H_TERMS_CANONICAL_ORDER, make_light_shift

# `energy_operator_ratio(term)` asserts that
#
#     energy_contribution(term, ψ, ws) == r · Re⟨ψ, H_term·ψ⟩ · dV
#
# and `operator_and_energy_via_registry!` uses it to get the total energy out of
# the pass that builds `H·ψ`, instead of the CPU L-BFGS iteration running the
# whole term registry a second time (12.80 ms against 6.11 for the gradient
# alone at 24³ D=13, in a ~30 ms iteration).
#
# That makes `r` a SECOND statement of each term's energy, competing with
# `energy_contribution` — precisely the duplication this architecture exists to
# forbid when it is ungated. So it is gated here, per term, from its first
# commit: a wrong `r` is a wrong energy in every L-BFGS line search on the CPU,
# and nothing else would notice, because the propagator does not use it.

# The first version of this fixture lit up FIVE terms — kinetic, trap, zeeman,
# c0, c1 — and the coverage guard was written as a count, which I then lowered
# from 6 to 5 when it failed instead of widening the fixture. The terms it never
# touched included LHY, and a wrong LHY ratio moved the total energy by 0.93 %,
# which a cache-hit verdict check in `test_gs_admission_axes.jl` caught instead
# of this file. A per-term gate whose fixture activates a third of the terms is
# a per-term gate for a third of the terms.
function _ws_all_terms()
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Na23,
        interactions=InteractionParams(Dict(0 => 20.0, 1 => -0.6)),
        zeeman=ZeemanParams(0.35, 0.12),
        potential=HarmonicTrap((1.0, 1.1, 0.9)),
        # The rotating frame lives in SimParams, not in make_workspace — that
        # is where CoriolisTerm reads it from.
        sim_params=SimParams(; dt=0.005, n_steps=1, rotating_frame_omega=0.3),
        enable_ddi=true, c_dd=1.5,
        spinor_lhy=:polar_contact,
        light_shift=make_light_shift(; F=1, alpha_vector=0.12, alpha_tensor=0.2,
            profile=[
                exp(-(x^2 + y^2 + z^2) / 8) for x in range(-3, 3; length=8),
                y in range(-3, 3; length=8), z in range(-3, 3; length=8)
            ]),
    )
    # A state with structure in every component, so no term is accidentally
    # evaluated at zero — a ratio checked against 0 == 0 is checked against
    # nothing.
    psi = ws.state.psi
    for I in CartesianIndices(size(psi)[1:3]), c in 1:size(psi, 4)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        psi[I, c] = exp(-(x^2 + y^2 + z^2) / 4) * cis(0.3c + 0.2x) * (1 + 0.1c)
    end
    SpinorBEC._normalize_psi!(psi, grid, size(psi, 4), 3)
    ws
end

@testset "energy_operator_ratio" begin
    ws = _ws_all_terms()
    psi = ws.state.psi
    dV = cell_volume(ws.grid)
    registry = build_h_terms_registry(ws)

    @testset "every active term's ratio reproduces its own energy" begin
        gctx = build_gradient_context(psi, ws)
        ectx = build_energy_context(psi, ws)
        scratch = similar(psi)
        n_checked = 0
        checked = Symbol[]
        for term in registry
            r = energy_operator_ratio(term)
            E_own = energy_contribution(term, psi, ws, ectx)
            if isnan(r)
                # Declared non-derivable. Allowed, but it must be a term that
                # genuinely carries no energy — otherwise the fallback is
                # hiding a missing declaration.
                @test E_own == 0.0
                continue
            end
            fill!(scratch, zero(eltype(scratch)))
            apply_operator!(scratch, term, ws, psi, gctx)
            E_derived = r * _realdot(psi, scratch) * dV
            # Terms that are switched off contribute zero both ways; they are
            # counted separately so the summary below cannot be all zeros.
            if abs(E_own) > 1.0e-12
                push!(checked, nameof(typeof(term)))
                n_checked += 1
                ok = isapprox(E_derived, E_own; rtol=1.0e-10)
                ok || @info("ratio does not reproduce this term's energy",
                    term=nameof(typeof(term)), ratio=r, derived=E_derived,
                    own=E_own, implied_ratio=E_own / (E_derived / r))
                @test ok
            else
                @test abs(E_derived) < 1.0e-12
            end
        end
        # Guard against the loop passing vacuously — but NAME what it covered
        # rather than asserting a count. The first version demanded six and got
        # five, which said nothing about which term was missing; a count is the
        # wrong instrument for a coverage claim.
        @info "terms whose ratio was actually exercised" checked
        # By NAME, and the list is the fixture's job description. LHY, the
        # light shift and Coriolis are here because their absence is what let a
        # wrong ratio through.
        for required in (:KineticTerm, :TrapTerm, :ZeemanTerm, :DensityC0Term,
            :SpinC1Term, :DDITerm, :LHYTerm, :LightShiftTerm, :CoriolisTerm)
            @test required in checked
        end
    end

    @testset "the registry total matches energy_decomposition" begin
        grad = similar(psi)
        _, E = operator_and_energy_via_registry!(grad, ws, dV)
        E_ref = energy_decomposition(ws).total
        @test abs(E_ref) > 1.0e-6                      # not vacuous
        # Not bit-identical by construction: different summation order, and
        # `_realdot`'s blocked reduction rather than each term's own. Bound it
        # by what consumes the number — the Armijo test, whose own floor on
        # this solver is ~1e-7 relative.
        @test isapprox(E, E_ref; rtol=1.0e-9)
    end

    @testset "a wrong ratio is caught" begin
        # Canary. Without it, a gate comparing two expressions of the same
        # quantity can pass because both are broken the same way, or because
        # the comparison itself is degenerate.
        gctx = build_gradient_context(psi, ws)
        ectx = build_energy_context(psi, ws)
        scratch = similar(psi)
        caught = false
        for term in registry
            r = energy_operator_ratio(term)
            isnan(r) && continue
            E_own = energy_contribution(term, psi, ws, ectx)
            abs(E_own) > 1.0e-12 || continue
            fill!(scratch, zero(eltype(scratch)))
            apply_operator!(scratch, term, ws, psi, gctx)
            wrong = (r == 1.0 ? 0.5 : 1.0) * _realdot(psi, scratch) * dV
            isapprox(wrong, E_own; rtol=1.0e-10) || (caught = true)
        end
        @test caught
    end

    @testset "every canonical term declares a ratio" begin
        # Adding a term and forgetting the declaration costs only speed, not
        # correctness — but silently, and it would never be noticed. Name the
        # exemptions so each is a deliberate act. Keyed on the TYPE, since the
        # registry is a tuple of instances and there is no name accessor.
        exempt = Set([:LossTerm])
        missing_decl = Symbol[]
        for term in registry
            isnan(energy_operator_ratio(term)) || continue
            nm = nameof(typeof(term))
            nm in exempt || push!(missing_decl, nm)
        end
        if !isempty(missing_decl)
            @info "terms with no `energy_operator_ratio`" missing_decl
        end
        @test isempty(missing_decl)
        # The registry really was populated — an empty one passes everything.
        @test length(registry) >= length(H_TERMS_CANONICAL_ORDER) - 2
    end
end

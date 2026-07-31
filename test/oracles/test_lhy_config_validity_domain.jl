# Meta-gate: every committed run config sits inside its LHY mode's validity domain.
#
# The closed forms have domains, and the domains are narrower than the schema
# enum. `IcosahedralLHY` is `c₀^(5/2) + 3|λ_spin|^(5/2)`; the absolute value made
# it symmetric under `c₁ → −c₁` and returned a real energy where the
# spin-Goldstone branch is dynamically unstable, so it now returns NaN at
# `λ_spin < 0` — which for these parameters means `c₁ < 0`.
#
# `runs/eu_k3_lhy*` use `c1_ratio = -0.005`. Their `icosa` cells had therefore
# been measured OUTSIDE the domain, and that reached a committed
# `factorial_2x4.json`, a committed figure, and two documented claims before
# anyone noticed (PR #207). Nothing caught it: the schema validates that `kind`
# is a known string, and `_tabulate_lhy` throws at BUILD time — which only fires
# when a run is actually launched, long after the config is reviewed and merged.
#
# So this gate takes the configs that are already in the tree and evaluates each
# one's closed form at ITS OWN (F, c₀, c₁). It is not a restatement of the domain
# rules; it calls the same functions a run would and fails on the same NaN.
#
# Scope: the cheap closed forms only. `full_bdg` and `spatial` solve a BdG
# problem per density node, which is minutes per config — they are also the
# general-purpose paths with no ansatz to violate, so they are the ANSWER to a
# domain failure rather than a source of one.

using Test
using YAML
using SpinorBEC
using SpinorBEC: _parse_gs_interactions, resolve_atom, _c0c1_to_gS,
    epsilon_LHY_F6_Ih, lhy_energy_polar, lhy_energy_fm, build_fm_lhy_coefs

const _RUNS = joinpath(@__DIR__, "..", "..", "runs")

# kind => (F restriction, energy at n=1 from a g_dict). `nothing` for F means any.
const _CLOSED_FORMS = Dict{String, Any}(
    "icosahedral" => (6, (F, g) -> epsilon_LHY_F6_Ih(1.0, g)),
    "polar_contact" => (nothing, (F, g) -> lhy_energy_polar(1.0, F, g)),
    "fm_contact" => (nothing, (F, g) -> lhy_energy_fm(1.0, build_fm_lhy_coefs(F, g))),
)

"""Every `(path, kind, F, c₀, c₁)` a committed config asks for, closed forms only."""
function _lhy_cells()
    out = Tuple{String, String, Int, Float64, Float64}[]
    isdir(_RUNS) || return out
    for f in sort(
        collect(
            Iterators.filter(p -> endswith(p, ".yaml") || endswith(p, ".yml"),
                (root * "/" * n for (root, _, ns) in walkdir(_RUNS) for n in ns)),
        ),
    )
        cfg = try
            YAML.load_file(f)
        catch
            continue
        end
        cfg isa Dict || continue
        pipe = get(cfg, "pipeline", nothing)
        pipe isa Vector || continue
        for step in pipe
            step isa Dict || continue
            for (_, blk) in step
                blk isa Dict || continue
                l = get(blk, "lhy", nothing)
                l isa Dict || continue
                kind = String(get(l, "kind", "none"))
                haskey(_CLOSED_FORMS, kind) || continue
                atom_name = get(blk, "atom", nothing)
                inter = get(blk, "interactions", nothing)
                (atom_name === nothing || !(inter isa Dict)) && continue
                atom = try
                    resolve_atom(Symbol(atom_name))
                catch
                    continue
                end
                ip = try
                    _parse_gs_interactions(
                        Dict{String, Any}(string(k) => v for (k, v) in inter), atom)
                catch
                    continue
                end
                push!(out, (relpath(f, _RUNS), kind, atom.F, ip[0], ip[1]))
            end
        end
    end
    out
end

@testset "committed configs stay inside their LHY mode's validity domain" begin
    cells = _lhy_cells()

    @testset "the sweep found configs to check" begin
        # A silent zero here would make the whole file vacuous — the exact
        # failure shape it exists to catch.
        @test !isempty(cells)
    end

    @testset "the domain guard is live (canary)" begin
        # If `epsilon_LHY_F6_Ih` stops rejecting c₁ < 0, every assertion below
        # passes for the wrong reason. Pin the guard itself.
        g_bad = _c0c1_to_gS(6, 3270.05, -16.35)     # eu_k3_lhy's own numbers
        @test isnan(epsilon_LHY_F6_Ih(1.0, g_bad))
        g_ok = _c0c1_to_gS(6, 3270.05, +16.35)
        @test isfinite(epsilon_LHY_F6_Ih(1.0, g_ok))
    end

    for (path, kind, F, c0, c1) in cells
        @testset "$path [$kind]" begin
            F_req, energy_at_1 = _CLOSED_FORMS[kind]
            if F_req !== nothing && F != F_req
                # The builder throws for this; a config asking for it is a bug
                # whatever the couplings are.
                @test F == F_req
                continue
            end
            g = _c0c1_to_gS(F, c0, c1)
            e = energy_at_1(F, g)
            # NaN is how the closed forms say "outside my domain". A run would
            # die at table-build time with an ArgumentError; this says so now.
            @test isfinite(e)
            # STRICTLY positive, not `>= 0`. A closed form can also leave its
            # domain by returning zero, and `isfinite(0.0) && 0.0 >= 0` passes
            # both assertions above — so the config would look gated while its
            # LHY term was simply absent, which is precisely the failure mode six
            # separate paths have already produced by dropping `ws.lhy`.
            # `lhy_energy_fm` did exactly this until 2026-07-30: its
            # `kappa < 1e-12 && return 0.0` swallowed NEGATIVE g_{2F} alongside
            # negligible ones. These configs all have active couplings, so a zero
            # here is a defect and never the physical answer.
            @test e > 0.0
        end
    end

    @testset "a silent zero fails too (canary)" begin
        # The assertion above is load-bearing only if zero is actually reachable.
        # F=6: g_{2F} = c₀ + 36 c₁, so c₁/c₀ < −1/36 drives the FM stiffness
        # negative. Before the fix that returned 0.0 and sailed through
        # `isfinite` and `>= 0`; it now declines with NaN.
        g_neg = _c0c1_to_gS(6, 10.0, -0.5)          # g_12 = −8.0
        @test build_fm_lhy_coefs(6, g_neg).delta_F < 0
        @test isnan(lhy_energy_fm(1.0, build_fm_lhy_coefs(6, g_neg)))
        # ...and the healthy side still answers.
        g_ok = _c0c1_to_gS(6, 10.0, -0.05)          # g_12 = +8.2
        @test lhy_energy_fm(1.0, build_fm_lhy_coefs(6, g_ok)) > 0
    end
end

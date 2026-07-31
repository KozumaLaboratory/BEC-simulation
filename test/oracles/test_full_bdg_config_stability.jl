using Test
using YAML
using SpinorBEC
using SpinorBEC: _parse_gs_interactions, resolve_atom, _extract_spinor,
    _lhy_zeeman_params, _to_zeeman_field, lhy_mean_field_max_growth,
    compute_c_dd_dimless, compute_quadratic_zeeman

# `full_bdg` has no ansatz to violate, so the closed-form domain gate
# (test_lhy_config_validity_domain.jl) has nothing to check for it. It has a
# different validity condition instead: the uniform mean field it linearises
# around must be dynamically stable. Where it is not, the zero-point sum drops
# the complex branches while the counterterms still subtract all D of them, so
# ε_LHY is scheme-dependent — the table still builds and still returns finite
# numbers, which is why nothing noticed.
#
# That condition needs the spinor and the density, so it is not a property of the
# YAML text. It became checkable when #214 made `max Im ω` a return value instead
# of a `maxlog`-limited warning — a warning is not something a caller can ask for,
# and #214's own account is of a log filter eating it.
#
# Direction matters, and this gate asserts BOTH:
#
#   * a config NOT on the list must be stable. A new `full_bdg` request in an
#     unstable regime then fails at review rather than at table build, which is
#     where it fails today: long after merge, on a machine, mid-campaign.
#   * a config ON the list must STILL be unstable. Without this the list decays
#     into a permanent exemption that protects nothing — if an entry becomes
#     stable, that is news and the entry has to be re-justified, not kept.
#
# It found ten entries on its first execution, in three groups — five comparator
# arms from #218, the texture campaign and its smoke twin, and three movie configs
# from #164 that nobody had connected to this at all. Each carries its reason
# below; the groups differ in KIND, not just in provenance:
#
#   * the #218 arms are unstable and kept ON PURPOSE, as the measurement of how
#     much the scheme dependence is worth (V_LHY 0.59327 vs 0.553422 against their
#     `fm_dipolar` siblings, a 7 % spread);
#   * the texture campaign is unstable and already marked do-not-run-as-is — the
#     gate reaching that verdict independently is the point of having it;
#   * the movie configs are unstable and that is not a defect. Their observable is
#     the excitation itself, and a texture exists *because* the uniform state is
#     unstable, so a uniform-mean-field BdG reference is the wrong reference for one
#     by construction (that framing is #214's). The scheme dependence is a caveat
#     on any ENERGY they quote, not on a vortex count.

# path (relative to runs/) => the reason it is allowed to be unstable.
const _KNOWN_UNSTABLE = Dict(
    "eu_k3_lhy/LHY_full_bdg.yaml" => "comparator for LHY_fm_dipolar.yaml (#218); instability is dipolar, eps_dd = 0.5402",
    "eu_k3_lhy_control/LHY_full_bdg_K0.yaml" => "comparator for LHY_fm_dipolar_K0.yaml (#218)",
    "eu_lhy_longtime/LHY_full_bdg_50ms.yaml" => "comparator for LHY_fm_dipolar_50ms.yaml (#218)",
    "eu_lhy_longtime/LHY_full_bdg_100ms.yaml" => "comparator for LHY_fm_dipolar_100ms.yaml (#218)",
    "eu_lhy_longtime/LHY_full_bdg_200ms.yaml" => "comparator for LHY_fm_dipolar_200ms.yaml (#218)",

    # The texture campaign. Already documented do-not-run-as-is; the gate reaching
    # the same verdict independently is the point of having it.
    "eu_gs_phase_c1_B_kappa/config_texture_bscan_lhy_full_bdg.yaml" =>
        "texture campaign: comparing five distinct textures needs one functional, " *
        "and full_bdg is the only one covering all five — see " *
        "docs/validation/full_bdg_scheme_dependence_eu_f6.md",
    "eu_gs_phase_c1_B_kappa/config_texture_bscan_lhy_smoke.yaml" => "smoke twin of config_texture_bscan_lhy_full_bdg.yaml",

    # The movie configs (#164). Here the instability is not a defect to route
    # around: the observable is the EXCITATION — where vortices come from, how the
    # density reacts — and a texture exists *because* the uniform state is
    # unstable, so a uniform-mean-field BdG reference is the wrong reference for it
    # by construction (the framing is #214's). eps_LHY's scheme dependence remains
    # a caveat on any ENERGY these quote; it is not one on the vortex count.
    "eu_gs_phase_c1_B_kappa/config_texture_quench_movie.yaml" => "movie config (#164): observable is the quench response, not eps_LHY",
    "eu_gs_phase_c1_B_kappa/config_texture_quench_movie_smoke.yaml" => "smoke twin of config_texture_quench_movie.yaml",
    "eu_gs_phase_c1_B_kappa/config_texture_stir_movie.yaml" =>
        "movie config (#164): observable is vortex nucleation under a rotating " *
        "b_perp, not eps_LHY",
)

const _RUNS = abspath(joinpath(@__DIR__, "..", "..", "runs"))
# Small enough that a BdG solve per config is seconds. The growth rate is a
# property of the peak spinor and the density, not of the resolution, so a coarse
# grid asks the same question as the production one.
const _N = (8, 8, 8)
const _BOX = (10.0, 10.0, 10.0)

"""Every committed config whose ground_state asks for `full_bdg`, with what it needs."""
function _full_bdg_configs()
    out = NamedTuple[]
    isdir(_RUNS) || return out
    files = sort([
        root * "/" * n for (root, _, ns) in walkdir(_RUNS) for n in ns
        if endswith(n, ".yaml") || endswith(n, ".yml")
    ])
    for f in files
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
            for (kindname, blk) in step
                kindname == "ground_state" || continue
                blk isa Dict || continue
                lhy = get(blk, "lhy", nothing)
                (lhy isa Dict && String(get(lhy, "kind", "")) == "full_bdg") || continue
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
                state = Symbol(get(blk, "initial_state", "polar"))
                ddi = get(blk, "ddi", nothing)
                ddi_on = ddi isa Dict ? Bool(get(ddi, "enabled", true)) : ddi === true
                push!(
                    out,
                    (path=relpath(f, _RUNS), atom=atom, ip=ip,
                        state=state, ddi_on=ddi_on, inter=inter),
                )
            end
        end
    end
    out
end

"""`max Im ω` for one config, through the SAME spinor extraction the run uses."""
function _growth(c)
    grid = make_grid(GridConfig(_N, _BOX))
    # `_extract_spinor` — not a hand-built spinor. For a texture the representative
    # is the peak-density one, and picking it differently here would check a
    # different state than `_build_spinor_lhy` does.
    psi = init_psi(grid, SpinSystem(c.atom.F); state=c.state)
    spinor = _extract_spinor(psi)
    om = Float64(get(c.inter, "omega_ref", 0.0))
    c_dd = if (c.ddi_on && om > 0)
        compute_c_dd_dimless(c.atom; N_atoms=Int(get(c.inter, "N_atoms", 1)),
            omega_ref=om)
    else
        0.0
    end
    lhy_mean_field_max_growth(; F=c.atom.F, spinor, interactions=c.ip,
        zeeman=_lhy_zeeman_params(_to_zeeman_field(ZeemanParams(), nothing)),
        c_dd=c_dd)
end

@testset "every committed full_bdg config is either stable or listed" begin
    cfgs = _full_bdg_configs()

    # A silent empty sweep is the failure shape this file exists to catch.
    @test !isempty(cfgs)

    seen = String[]
    for c in cfgs
        g = try
            _growth(c)
        catch err
            @info "full_bdg stability probe threw; treating as unknown" c.path err
            NaN
        end
        isnan(g) && continue
        push!(seen, c.path)
        listed = haskey(_KNOWN_UNSTABLE, c.path)
        if listed
            # Direction 2: a listed entry must still be unstable, else it is stale.
            g > 0 || @info """`$(c.path)` is now STABLE (max Im ω = 0) but is still \
listed as known-unstable. That is news: drop the entry, and if it was kept as a \
scheme-dependence comparator (#218) then the comparison it was for no longer \
exists.""" reason = _KNOWN_UNSTABLE[c.path]
            @test g > 0
        else
            g == 0 || @info """`$(c.path)` asks for `full_bdg` where the uniform mean \
field is dynamically UNSTABLE (max Im ω = $(round(g; sigdigits=4))). The table will \
build and return finite numbers, but ε_LHY is scheme-dependent there — the complex \
branches are dropped from the zero-point sum while all D counterterms are still \
subtracted. Either move to a `*_dipolar` closed form whose ansatz matches the state, \
or add it to `_KNOWN_UNSTABLE` with the reason it is a deliberate comparator. \
See docs/validation/full_bdg_scheme_dependence_eu_f6.md.""" state = c.state
            @test g == 0
        end
    end

    # The list must not name configs that no longer exist — a stale path silently
    # exempts nothing and hides that the entry was never re-checked.
    stale = setdiff(keys(_KNOWN_UNSTABLE), seen)
    isempty(stale) || @info "`_KNOWN_UNSTABLE` names configs the sweep did not reach" stale
    @test isempty(stale)
end

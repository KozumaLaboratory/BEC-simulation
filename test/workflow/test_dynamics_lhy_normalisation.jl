using Test
using SpinorBEC

# The `dynamics:` step used to reach `make_workspace` with an unresolved `lhy:`
# block, because `_resolve_lhy_block!` runs inside `_resolve_derived_params!`
# and only `run_step_ground_state.jl` calls that. Two consequences, opposite in
# direction, both silent:
#
#   * scalar / quasi_2d: `interactions.c_lhy` stayed 0 — the dynamics phase ran
#     with NO LHY while `lhy: {kind: scalar}` sat in the YAML. Because the term
#     was absent rather than wrong, energy conservation looked perfect.
#   * tabulated closed forms: `lhy_opts` was missing, so `LHYTableOpts()` gave
#     `n_atoms = 1`. That is the unit conversion (n is normalised to ∫|ψ|²dV = 1
#     while c₀ already carries N), so the table came out exactly `N_atoms` times
#     too strong — in the propagator as well as the energy. At Eu F=6 / N=30000
#     that put 97 % of the total energy into the LHY term.
#
# Both halves are pinned here against the *ground_state* resolution of the same
# block, which is the reference: the two phases must normalise identically.

const _ATOM = SpinorBEC.ATOM_REGISTRY[:Eu151]
const _N_ATOMS = 30_000
const _OMEGA_REF = 628.3

_inter() = Dict{String, Any}("N_atoms" => _N_ATOMS, "omega_ref" => _OMEGA_REF)

# The scalar auto-derive is gated on DDI being active (`c_dd_val > 0`), so the
# dynamics step passes the inherited `c_dd` and the test must too.
const _C_DD = compute_c_dd_dimless(_ATOM; N_atoms=_N_ATOMS, omega_ref=_OMEGA_REF)

function _dyn_block(kind::String)
    Dict{String, Any}(
        "duration" => 1.0, "dt" => 0.01,
        "interactions" => _inter(),
        "lhy" => Dict{String, Any}("kind" => kind),
    )
end

# Ground-state resolution of the same `lhy:` block — the reference both phases
# must agree with.
function _gs_resolved(kind::String)
    p = Dict{String, Any}(
        "interactions" => _inter(),
        "ddi" => Dict{String, Any}("enabled" => true),
        "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
        "lhy" => Dict{String, Any}("kind" => kind),
    )
    SpinorBEC._resolve_derived_params!(p, _ATOM; verbose=false)
    p
end

@testset "dynamics `lhy:` normalises the same way ground_state does" begin
    @testset "tabulated: n_atoms is the atom number, not 1" begin
        for kind in ("polar_contact", "icosahedral", "fm_contact")
            p = _dyn_block(kind)
            @test SpinorBEC._resolve_dyn_lhy!(p, _ATOM, _C_DD)
            @test haskey(p, "lhy_opts")
            opts = p["lhy_opts"]::SpinorBEC.LHYTableOpts

            # The regression: the fallback `LHYTableOpts()` supplies 1 here, and
            # `n_atoms` scales the table as 1/n_atoms, so 1 is exactly an
            # N_atoms-fold over-strength.
            @test opts.n_atoms == _N_ATOMS
            @test opts.n_atoms != SpinorBEC.LHYTableOpts().n_atoms

            # ... and it agrees with what the ground_state step would have built.
            @test opts.n_atoms == (_gs_resolved(kind)["lhy_opts"]::SpinorBEC.LHYTableOpts).n_atoms
        end
    end

    @testset "scalar: c_lhy reaches the dynamics interactions" begin
        p = _dyn_block("scalar")
        @test SpinorBEC._resolve_dyn_lhy!(p, _ATOM, _C_DD)
        c_lhy = Float64(get(p["interactions"], "c_lhy", 0.0))

        # The regression: this was 0, so the dynamics ran with no LHY while the
        # YAML said `kind: scalar`.
        @test c_lhy > 0.0

        gs = _gs_resolved("scalar")
        @test c_lhy ≈ Float64(gs["interactions"]["c_lhy"]) rtol = 1e-12

        # And it survives the re-parse that actually feeds `make_workspace` —
        # `_parse_gs_interactions` is what reads the key, which is why the
        # resolution has to happen before it.
        ip = SpinorBEC._parse_gs_interactions(p["interactions"], _ATOM)
        @test ip.c_lhy ≈ c_lhy rtol = 1e-12
    end

    @testset "table strength actually changes by N_atoms" begin
        # Guard the *consequence*, not just the field: a reviewer changing how
        # `n_atoms` threads through should see this fail, not only the ==.
        g = SpinorBEC.c_to_g(_ATOM.F,
            SpinorBEC._parse_gs_interactions(_inter(), _ATOM))
        tbl_right = SpinorBEC.compute_spinor_lhy_polar_contact(;
            F=_ATOM.F, g_dict=g, n_max=0.02, n_points=200, n_atoms=_N_ATOMS)
        tbl_wrong = SpinorBEC.compute_spinor_lhy_polar_contact(;
            F=_ATOM.F, g_dict=g, n_max=0.02, n_points=200, n_atoms=1)
        n = 0.005
        @test SpinorBEC._lhy_V(n, tbl_wrong) ≈
            _N_ATOMS * SpinorBEC._lhy_V(n, tbl_right) rtol = 1e-8
    end

    @testset "no `lhy:` block is a no-op, and c_total form is reported" begin
        p = Dict{String, Any}("duration" => 1.0, "dt" => 0.01,
            "interactions" => _inter())
        @test SpinorBEC._resolve_dyn_lhy!(p, _ATOM, _C_DD)
        @test !haskey(p, "lhy_opts")

        # `c_total` carries no atom number, so the block cannot be normalised.
        # It must report false (the caller warns) rather than fall back to 1.
        p_ct = Dict{String, Any}("duration" => 1.0, "dt" => 0.01,
            "interactions" => Dict{String, Any}("c_total" => 100.0),
            "lhy" => Dict{String, Any}("kind" => "polar_contact"))
        @test !SpinorBEC._resolve_dyn_lhy!(p_ct, _ATOM, _C_DD)
        @test !haskey(p_ct, "lhy_opts")
    end
end

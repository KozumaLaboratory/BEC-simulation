# `DDISpec.trunc_radius` is three-valued, and the three are DIFFERENT PHYSICS.
#
#   nothing  auto — derive the radius from the box at build time
#   0.0      off  — the bare periodic kernel, no real-space truncation
#   r > 0    that explicit radius
#
# The bare kernel carries a 2-5 % dipolar field error against free space that is
# FLAT in resolution (1.91e-2 at 32³, 48³ and 64³ alike), so collapsing auto and
# off is not a rounding decision — it silently changes the answer of every run,
# and no amount of grid refinement reveals it.
#
# `Float64` alone cannot hold the three: the YAML layer spells them `-1.0` /
# `NaN` / `r`, and `-1.0` is a sentinel inside the value domain while `NaN`
# breaks reflexivity (`m != m`, `hash` diverging from `==`). `Union{Nothing,
# Float64}` puts the auto arm OUTSIDE the numeric domain, where it cannot
# collide.
#
# The corpus cannot gate any of this: `git grep trunc_radius -- '*.yaml'` returns
# ZERO files across 429 committed configs, so every one takes the ABSENT path and
# a wrong auto↔off mapping would flip 100 % of production to the bare kernel with
# every corpus-derived gate still green. The fixtures below are therefore
# synthetic by necessity, and each carries its own positive control.

using Test
using SpinorBEC
using SpinorBEC: Model, Stage, stage, artifact_id, GridSpec, InteractionSpec, DDISpec,
    DDI_TRUNC_RADIUS_DEFAULT, ddi_trunc_radius_kwarg, ddi_trunc_radius_from_kwarg,
    to_toml, model_from_toml, model_toml_dict, resolve_atom, with, _speceq, _enc,
    _parse_ddi_trunc_radius, make_grid, GridConfig, make_ddi_params, OPTIONAL_FLOAT_NOTHING

dtr_model(tr) = Model(;
    grid=GridSpec(; ndim=3, n_points=(8, 8, 8), box=(6.0, 6.0, 6.0)),
    atom=resolve_atom(:Eu151),
    interactions=InteractionSpec(; n_atoms=1000, omega_ref=691.15, c0=10.0, c1=-0.3),
    ddi=DDISpec(; c_dd=0.4, trunc_radius=tr))

dtr_stage(tr) = stage(:relax; model=dtr_model(tr), method=:itp,
    params=(dt=1.0e-3, n_steps=100))

@testset "ddi.trunc_radius: auto / off / explicit are three distinct states" begin
    @testset "the field is a closed two-member union of concrete types" begin
        # PINNED, not read back from the struct: this is the decision the union
        # encodes, and changing it must cost a deliberate edit here. The shape
        # gate (`test_model_shape.jl`) does NOT cover this — `Nothing` is a
        # fieldless concrete type, so its walk terminates on that arm whether or
        # not `Nothing` is in `SCALAR_LEAF_KINDS`, and deleting that entry
        # leaves it fully green (measured).
        FT = fieldtype(DDISpec, :trunc_radius)
        @test FT isa Union
        @test Set(Base.uniontypes(FT)) == Set([Nothing, Float64])
        @test all(isconcretetype, Base.uniontypes(FT))
    end

    @testset "the three are distinct VALUES" begin
        a, o, e = dtr_model(nothing), dtr_model(0.0), dtr_model(4.0)
        @test a.ddi.trunc_radius === nothing
        @test o.ddi.trunc_radius === 0.0
        @test e.ddi.trunc_radius === 4.0
        @test !_speceq(a.ddi, o.ddi)
        @test !_speceq(a.ddi, e.ddi)
        @test !_speceq(o.ddi, e.ddi)
        @test a != o && a != e && o != e
        @test hash(a) != hash(o)
        @test hash(a) != hash(e)
        @test hash(o) != hash(e)
        # ... and each equals itself, which a NaN sentinel would not.
        for m in (a, o, e)
            @test m == m
            @test hash(m) == hash(m)
        end
    end

    @testset "the three are distinct artifact_ids" begin
        # One assertion each, per the brief. This is the physics collision the
        # union exists to prevent: three runs that differ only here differ in
        # their dipolar field, so they must not share a store slot.
        ia = artifact_id(dtr_stage(nothing))
        io = artifact_id(dtr_stage(0.0))
        ie = artifact_id(dtr_stage(4.0))
        @test ia != io
        @test ia != ie
        @test io != ie
        # Determinism, so the inequalities above are not three coin flips.
        @test artifact_id(dtr_stage(nothing)) == ia
        @test artifact_id(dtr_stage(0.0)) == io
        @test artifact_id(dtr_stage(4.0)) == ie
    end

    @testset "the three are distinct SERIALISED forms, and all three round-trip" begin
        sa, so, se = to_toml(dtr_model(nothing)), to_toml(dtr_model(0.0)), to_toml(dtr_model(4.0))
        @test sa != so && sa != se && so != se
        for (m, s) in ((dtr_model(nothing), sa), (dtr_model(0.0), so), (dtr_model(4.0), se))
            back = model_from_toml(s)
            @test back == m
            @test back.ddi.trunc_radius === m.ddi.trunc_radius
            @test to_toml(back) == s
        end
        # The auto arm is spelled outside the numeric domain, so it cannot
        # collide with a radius no matter which radius is chosen.
        @test model_toml_dict(dtr_model(nothing))["ddi"]["trunc_radius"] ==
            OPTIONAL_FLOAT_NOTHING
        @test model_toml_dict(dtr_model(0.0))["ddi"]["trunc_radius"] === 0.0
        @test OPTIONAL_FLOAT_NOTHING isa AbstractString
    end

    @testset "the serialised vocabulary is closed" begin
        d = model_toml_dict(dtr_model(nothing))
        for bad in ("box_half", "none", "off", "", "AUTO")
            d2 = deepcopy(d)
            d2["ddi"]["trunc_radius"] = bad
            @test_throws ArgumentError SpinorBEC.model_from_toml_dict(d2)
        end
        d3 = deepcopy(d)
        d3["ddi"]["trunc_radius"] = Dict{String, Any}("times" => [0.0], "values" => [1.0])
        @test_throws ArgumentError SpinorBEC.model_from_toml_dict(d3)
        # And `_enc(nothing)` stays refused: `Nothing` is fieldless, so the
        # generic struct arm would launder it into `{}` and past
        # `_canonical_bytes!`, which is the enforcement invariant 1 rests on.
        @test_throws ArgumentError _enc(nothing)
    end

    @testset "the constructor admits the three and refuses the YAML spellings" begin
        @test DDISpec(; c_dd=0.4).trunc_radius === nothing           # library default = auto
        @test DDISpec(; c_dd=0.4, trunc_radius=0.0).trunc_radius === 0.0
        @test DDISpec(; c_dd=0.4, trunc_radius=4.0).trunc_radius === 4.0
        # `-1.0` is the YAML auto sentinel and `NaN` the YAML off sentinel;
        # neither is a model value, and both used to reach here. 364 of the
        # committed configs resolve to `-1.0`.
        @test DDI_TRUNC_RADIUS_DEFAULT == -1.0
        @test_throws ArgumentError DDISpec(; c_dd=0.4, trunc_radius=-1.0)
        @test_throws ArgumentError DDISpec(; c_dd=0.4, trunc_radius=NaN)
        @test_throws ArgumentError DDISpec(; c_dd=0.4, trunc_radius=Inf)
        # An INACTIVE ddi has exactly one representation, and auto is not it: a
        # kernel that does not exist is not truncated and has no box to derive a
        # radius from.
        @test DDISpec().trunc_radius === 0.0
        @test DDISpec(; c_dd=0.0, trunc_radius=nothing) == DDISpec()
        @test DDISpec(; c_dd=0.0, trunc_radius=4.0) == DDISpec()
        # `with` re-runs the constructor, so it cannot produce a refused value.
        @test with(DDISpec(; c_dd=0.4), trunc_radius=2.0).trunc_radius === 2.0
        @test with(DDISpec(; c_dd=0.4, trunc_radius=2.0), trunc_radius=nothing).trunc_radius ===
            nothing
    end

    @testset "the ONE conversion to the make_workspace vocabulary" begin
        # Non-identity in BOTH directions. `make_workspace` reads `<= 0` as auto
        # and `NaN` as off, so passing a model's `0.0` through unchanged would
        # turn every untruncated run into an auto-truncated one, silently.
        @test ddi_trunc_radius_kwarg(DDISpec(; c_dd=0.4, trunc_radius=nothing)) == -1.0
        @test isnan(ddi_trunc_radius_kwarg(DDISpec(; c_dd=0.4, trunc_radius=0.0)))
        @test ddi_trunc_radius_kwarg(DDISpec(; c_dd=0.4, trunc_radius=4.0)) == 4.0
        # ... and it must NOT be the identity on 0.0, which is the whole hazard.
        @test ddi_trunc_radius_kwarg(DDISpec(; c_dd=0.4, trunc_radius=0.0)) != 0.0

        # The inverse, over the whole Float64 the YAML layer can produce. The
        # three YAML spellings are pinned as literals rather than read back from
        # `_parse_ddi_trunc_radius`, so editing that function moves one side
        # only.
        @test _parse_ddi_trunc_radius(nothing) == -1.0
        @test _parse_ddi_trunc_radius("auto") == -1.0
        @test _parse_ddi_trunc_radius("box_half") == -1.0
        @test isnan(_parse_ddi_trunc_radius("none"))
        @test isnan(_parse_ddi_trunc_radius("off"))
        @test _parse_ddi_trunc_radius(4.0) == 4.0

        @test ddi_trunc_radius_from_kwarg(-1.0) === nothing
        @test ddi_trunc_radius_from_kwarg(0.0) === nothing      # make_workspace: <=0 is auto
        @test ddi_trunc_radius_from_kwarg(NaN) === 0.0
        @test ddi_trunc_radius_from_kwarg(4.0) === 4.0

        # Round trip through the pair for the three model states.
        for tr in (nothing, 0.0, 4.0)
            @test ddi_trunc_radius_from_kwarg(
                ddi_trunc_radius_kwarg(DDISpec(; c_dd=0.4, trunc_radius=tr))) === tr
        end
    end

    @testset "auto and off build DIFFERENT kernels" begin
        # The physics anchor. `DDIParams` carries no radius — only `C_dd`, the
        # six Q tensors and `box_size` — so the only way to see the difference
        # is in the kernel itself. Without this, every assertion above is about
        # bookkeeping.
        grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
        atom = resolve_atom(:Eu151)
        box = ntuple(d -> grid.config.n_points[d] * grid.dx[d], 3)
        auto_r = SpinorBEC.auto_ddi_trunc_radius(box)
        @test auto_r > 0

        p_off = make_ddi_params(grid, atom; c_dd=1.0, trunc_radius=nothing)
        p_auto = make_ddi_params(grid, atom; c_dd=1.0, trunc_radius=auto_r)
        p_expl = make_ddi_params(grid, atom; c_dd=1.0, trunc_radius=0.6 * auto_r)

        @test p_off.Q_zz != p_auto.Q_zz
        @test p_auto.Q_zz != p_expl.Q_zz
        @test p_off.Q_zz != p_expl.Q_zz

        # The off kernel is the bare `k̂_z² − 1/3` with `Q(k=0) = 0` — that is
        # what "no real-space truncation" means, and it is exactly what the auto
        # kernel is NOT. `Q` lives on the rfft half-grid, whose first axis is
        # `rfftfreq`, i.e. the magnitudes of `grid.k[1][1:n÷2+1]`.
        rk = size(p_off.Q_zz)
        @test rk == (9, 16, 16)
        kx = abs.(grid.k[1][1:rk[1]])
        ky, kz = grid.k[2], grid.k[3]
        worst_off = 0.0
        worst_auto = 0.0
        for i in 1:rk[1], j in 1:rk[2], l in 1:rk[3]
            k2 = kx[i]^2 + ky[j]^2 + kz[l]^2
            k2 == 0 && continue
            bare = kz[l]^2 / k2 - 1 / 3
            worst_off = max(worst_off, abs(p_off.Q_zz[i, j, l] - bare))
            worst_auto = max(worst_auto, abs(p_auto.Q_zz[i, j, l] - bare))
        end
        @test worst_off < 1e-12
        # The positive control: the truncated kernel is a DIFFERENT function, so
        # the assertion above is a real constraint and not a tautology.
        @test worst_auto > 1e-3
        @test p_off.Q_zz[1, 1, 1] == 0.0
    end
end

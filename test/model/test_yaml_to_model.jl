# `yaml_to_model` — cutover step 1b.
#
# Three claims, one testset each:
#
# 1. A config resolves to a `Model` that survives the TOML round trip unchanged.
#    Losslessness here is not a property of the codec alone: `yaml_to_model` is
#    the first producer of models the codec never saw, and what it produces (Eu
#    F=6, auto DDI truncation, derived c₀/c₁, lab-Gauss Zeeman) is not the
#    hand-written corpus in `test_model_toml_roundtrip.jl`.
#
# 2. Slots a ground-state step cannot set take their inactive value, and WHICH
#    those are is derived from `GS_SCHEMA` against a partition pinned here — so
#    a schema key added without deciding where it goes is red, rather than
#    silently dropped from every model.
#
# 3. It fails loudly and by name. A model that substituted a default for a
#    number the config never gave would be a wrong answer wearing a content id,
#    and the store is shared, so every gap throws with the config path in it.
#
# The numeric pins below are LITERAL. Deriving them from the resolver and then
# checking the resolver against them is the circular shape that went green twice
# in this campaign: editing the declaration would move both sides together.

using Test
using SpinorBEC
using SpinorBEC: yaml_to_model, resolve_gs, gs_model, GSResolved,
    Model, GridSpec, InteractionSpec, DDISpec, LHYSpec, PotentialSpec, HarmonicSpec,
    BeamSpec, ZeemanSpec, RamanSpec, LightShiftSpec, GradientSpec, FrameSpec,
    GeometrySpec, ReservoirSpec, LossParams, n_terms,
    to_toml, model_from_toml, model_toml_dict, slots, REQUIRED_SLOTS,
    GS_SCHEMA, GS_KEYS_DROPPED_PHYSICS,
    _light_shift_spec, _parse_light_shift, evaluate_potential, make_grid, GridConfig,
    PlugBeam, LaguerreGaussBeam, HarmonicTrap, QuarticPotential, NoPotential,
    CompositePotential, MagneticGradient, OpticalLatticePotential,
    RingPotential, BoxPotential, GravityPotential, DoubleWellPotential,
    TimeDependentTrap, ConstantWaveform, Waveform, AbstractPotential, CPUBackend,
    DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF

const YTM_DIR = mktempdir()

# The reference config. Every pin below was read off a run of this exact block.
const YTM_BASE = """
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [8, 8, 8], box: [6.0, 6.0, 6.0]}
      interactions: {N_atoms: 1000, omega_ref: 691.15, c1_ratio: -0.01}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      B: {Bz: 0.01}
      ddi: {secular: true}
      method: itp
      n_steps: 20
      dt: 0.002
      tol: 1.0e-8
      backend: cpu
"""

function ytm_write(name::AbstractString, body::AbstractString)
    p = joinpath(YTM_DIR, name)
    write(p, body)
    p
end

"Run `f` with the dealias globals saved and restored — `_run_yaml_prepare` sets them and leaves them set."
function with_dealias_restored(f)
    e, k = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]
    try
        f()
    finally
        DEALIAS_2_3_ENABLED[] = e
        DEALIAS_K_CUTOFF[] = k
    end
end

ytm_model(path; kw...) = with_dealias_restored(() -> yaml_to_model(path; kw...))

function ytm_why(path; kw...)
    try
        ytm_model(path; kw...)
        return nothing
    catch err
        return err isa ArgumentError ? err.msg : sprint(showerror, err)
    end
end

# Exercise the potential walk on a bare `AbstractPotential`, the way `gs_model`
# does, without building a whole `GSResolved`.
function ytm_pot(pot, duration::Float64=1.0)
    acc = SpinorBEC._PotAcc()
    SpinorBEC._accumulate_potential!(acc, pot, duration)
    (
        PotentialSpec(; harmonic=acc.harmonic, lattice=acc.lattice, ring=acc.ring,
            box=acc.box, gravity=acc.gravity, double_well=acc.double_well,
            beam=acc.beam, dipole_trap=acc.dipole_trap), acc.gradient)
end

@testset "yaml_to_model" begin
    base_path = ytm_write("base.yaml", YTM_BASE)

    @testset "resolves, and the pinned physics is what arrives" begin
        m = ytm_model(base_path)
        @test m isa Model

        @test m.grid.ndim == 3
        @test m.grid.n_points == (8, 8, 8)
        @test m.grid.box == (6.0, 6.0, 6.0)
        @test m.grid.dealias_two_thirds == false
        @test m.grid.dealias_k_cut == 0.0

        @test m.atom.name == "151Eu"
        @test m.atom.F == 6

        # c₀/c₁ come from N_atoms + omega_ref + c1_ratio through
        # `interaction_params_from_constraint`; the numbers are pinned, not
        # recomputed here.
        @test m.interactions.n_atoms == 1000
        @test m.interactions.omega_ref == 691.15
        @test m.interactions.c0 ≈ 146.47702987921934 atol = 1e-10
        @test m.interactions.c1 ≈ -1.4647702987921936 atol = 1e-12
        @test isempty(m.interactions.c_extra_ranks)

        @test length(m.potential.harmonic) == 1
        @test m.potential.harmonic[1].omega == (1.0, 1.0, 2.0)
        @test m.potential.harmonic[1].lambda == (0.0, 0.0, 0.0)

        # 0.01 G through `Units.bfield_to_p`, and q auto-derived from |B|². The
        # sign is the whole Kawaguchi-Ueda convention: +Bz on g_F>0 Eu gives a
        # NEGATIVE p.
        @test m.zeeman.p ≈ -147.9552357253949 atol = 1e-9
        @test m.zeeman.q ≈ 0.001292251453530959 atol = 1e-15
        @test m.zeeman.bx == 0.0
        @test m.zeeman.by == 0.0
        @test m.zeeman.spatial_kind === :uniform

        # c_dd auto-derived from atom + N + ω_ref; padding and truncation take
        # the YAML-surface defaults (padded, auto radius).
        @test m.ddi.c_dd ≈ 4.220427701805867 atol = 1e-12
        @test m.ddi.secular == true
        @test m.ddi.padded == true
        @test m.ddi.pad_factor == (2.0, 2.0, 2.0)
        @test m.ddi.trunc_radius === nothing        # auto
        @test m.ddi.quasi_2d == false

        @test m.lhy.kind === :none
    end

    @testset "TOML round trip is lossless for a resolved model" begin
        m = ytm_model(base_path)
        s = to_toml(m)
        back = model_from_toml(s)
        @test back == m
        @test to_toml(back) == s
        @test model_toml_dict(back) == model_toml_dict(m)
        # The auto arm really did go through the codec, rather than the model
        # happening to hold a number.
        @test model_toml_dict(m)["ddi"]["trunc_radius"] == "auto"
        @test back.ddi.trunc_radius === nothing
    end

    @testset "the three ddi.trunc_radius states survive YAML -> Model" begin
        # End-to-end version of `test_ddi_trunc_radius_three_states.jl`. That
        # file gates the value layer; this one gates the RESOLUTION, which is
        # where the auto↔off collision would actually be introduced — and no
        # committed config writes `trunc_radius` at all, so nothing else in the
        # tree exercises the `none` and explicit arms.
        auto = ytm_model(base_path)                                    # key absent
        off = ytm_model(
            ytm_write("tr_none.yaml",
                replace(
                    YTM_BASE, "ddi: {secular: true}" => "ddi: {secular: true, trunc_radius: none}"
                )),
        )
        expl = ytm_model(
            ytm_write("tr_expl.yaml",
                replace(
                    YTM_BASE, "ddi: {secular: true}" => "ddi: {secular: true, trunc_radius: 2.5}"
                )),
        )
        @test auto.ddi.trunc_radius === nothing
        @test off.ddi.trunc_radius === 0.0
        @test expl.ddi.trunc_radius === 2.5
        @test auto.ddi != off.ddi
        @test auto.ddi != expl.ddi
        @test off.ddi != expl.ddi
        # ... and everything else about the three is identical, so the
        # inequalities above are about this field alone.
        for f in setdiff(collect(fieldnames(DDISpec)), [:trunc_radius])
            @test getfield(auto.ddi, f) == getfield(off.ddi, f)
            @test getfield(auto.ddi, f) == getfield(expl.ddi, f)
        end
        @test to_toml(auto) != to_toml(off) != to_toml(expl)
    end

    @testset "the dealias block reaches GridSpec" begin
        # It is popped into module `Ref`s before any step dict exists, so a
        # resolver taking only the step params CANNOT see it — and 75 committed
        # configs set it. Dealiasing is an exact spectral projector: two runs
        # that differ in it differ in their answer.
        p = ytm_write("dealias.yaml", "dealias: {enabled: true, k_cut: 16.0}\n" * YTM_BASE)
        m = ytm_model(p)
        @test m.grid.dealias_two_thirds == true
        @test m.grid.dealias_k_cut == 16.0
        m0 = ytm_model(base_path)
        @test m.grid != m0.grid
        @test to_toml(m) != to_toml(m0)
    end

    # ------------------------------------------------------------------
    # Claim 2: the inactive slots are inactive BY DERIVATION.
    # ------------------------------------------------------------------
    @testset "slots a ground_state step cannot set are inactive" begin
        # Where every GS_SCHEMA key goes. Written out, not computed: this is the
        # decision, and adding a key without making it is what must be red.
        to_model = Set([
            "atom", "grid", "interactions", "ddi", "B", "potential", "lhy",
            "light_shift", "rotating_frame_omega", "dtype",
        ])
        to_stage_or_initial = Set([
            "kind", "species_A", "species_B", "F", "gauge_fix", "init_m_idx",
            "init_sigma", "method", "dt", "n_steps", "tol", "tol_drho", "m_lbfgs",
            "newton_polish", "residual_polish", "initial_state", "backend",
            "target_magnetization", "temperature_ratio", "init_state_params",
            "seed_from", "pin", "cache", "noise_seed",
        ])
        dropped = Set(GS_KEYS_DROPPED_PHYSICS)

        unclassified = setdiff(Set(keys(GS_SCHEMA)),
            union(to_model, to_stage_or_initial, dropped))
        stale = setdiff(union(to_model, to_stage_or_initial, dropped), Set(keys(GS_SCHEMA)))
        isempty(unclassified) || println("  GS_SCHEMA keys with no classification: ",
            sort!(collect(unclassified)))
        isempty(stale) || println("  classified keys not in GS_SCHEMA: ", sort!(collect(stale)))
        @test isempty(unclassified)
        @test isempty(stale)
        # The refusal list is the one part of the partition the SOURCE carries;
        # pinned here so moving a key out of it costs a deliberate edit.
        # `a_s`, `ddi_pad` and `B_magnitude_gauss` joined 2026-08-18 with
        # `kind: scalar_egpe`: declared in GS_SCHEMA, read only by that path,
        # and therefore SILENTLY IGNORED on a spinor ground_state — `a_s` most
        # sharply, since the run would fall back to the registry value.
        @test Set(GS_KEYS_DROPPED_PHYSICS) == Set(["quasi_2d", "l_z", "raman",
            "B_direction", "a_s", "ddi_pad", "B_magnitude_gauss"])

        # Nothing in `to_model` names raman / geometry / reservoir / loss /
        # magnetic_gradient, so a ground-state model must hold their inactive
        # values — asserted on a real config rather than argued.
        m = ytm_model(base_path)
        # `_speceq`, not `==`: `LossParams` is a reused foundation type with
        # `Vector` fields, so the default `==` is `===` (object identity) and
        # would report two all-zero loss blocks as different.
        for (f, T) in ((:raman, RamanSpec), (:geometry, GeometrySpec),
            (:reservoir, ReservoirSpec), (:loss, LossParams),
            (:magnetic_gradient, GradientSpec), (:light_shift, LightShiftSpec))
            @test getfield(m, f) isa T
            @test SpinorBEC._speceq(getfield(m, f), T())
        end
        # ... and being inactive, they are absent from the serialised form.
        d = model_toml_dict(m)
        for f in (:raman, :geometry, :reservoir, :loss, :magnetic_gradient, :light_shift)
            @test !haskey(d, String(f))
        end
        @test all(f -> haskey(d, String(f)), REQUIRED_SLOTS)
        @test length(slots(Model)) == 14
    end

    # ------------------------------------------------------------------
    # Claim 3: it fails loudly, by name, and never half-fills a model.
    # ------------------------------------------------------------------
    @testset "no N_atoms" begin
        # `omega_ref` stays, because a Gauss-valued `B:` needs it to convert —
        # dropping both would fail earlier, for the other reason, and the
        # assertion below would be about a message this gap never produces.
        # 16 committed configs are exactly this shape (bare c0/c1, no N).
        p = ytm_write(
            "no_n.yaml",
            replace(YTM_BASE,
                "interactions: {N_atoms: 1000, omega_ref: 691.15, c1_ratio: -0.01}" => "interactions: {c0: 10.0, c1: -0.3, omega_ref: 691.15}",
            ),
        )
        msg = ytm_why(p)
        @test msg !== nothing
        @test occursin("N_atoms", msg)
        @test occursin(basename(p), msg)          # names the config
    end

    @testset "no omega_ref" begin
        # Dimensionless `B: {p: …}`, so the missing `omega_ref` is not caught by
        # the Gauss converter first.
        p = ytm_write(
            "no_w.yaml",
            replace(
                replace(YTM_BASE,
                    "interactions: {N_atoms: 1000, omega_ref: 691.15, c1_ratio: -0.01}" => "interactions: {c_total: 100.0, c1_ratio: -0.01, N_atoms: 1000}",
                ),
                "B: {Bz: 0.01}" => "B: {p: -147.0, q: 0.001}"),
        )
        msg = ytm_why(p)
        @test msg !== nothing
        @test occursin("omega_ref", msg)
    end

    @testset "tabulated LHY with no explicit n_max takes it from the seed" begin
        # CHANGED 2026-08-19. This arm asserted that such a config is REFUSED,
        # and `LHYSpec` still refuses a non-positive `n_max` — but the resolver
        # no longer hands it one. `_resolve_lhy_n_max` pins it to the DECLARED
        # seed, which is what makes it a function of the config rather than of
        # whichever ψ `make_workspace` happens to hold.
        #
        # Measured before the change (Eu F=6 `fm_dipolar`, 16³): the fresh solve
        # built the table from the seed at `n_max = 0.4466` and the CACHE-HIT
        # path from the converged state at `0.7471`, 1.67× wider, for one config.
        # `V_LHY` agreed to 4e-5 where both covered — a resolution difference,
        # not a different functional, and still two tables where there should be
        # one. 23 committed configs were in this state and none had a Model.
        p = ytm_write(
            "lhy.yaml",
            replace(YTM_BASE,
                "      method: itp" => "      lhy: {kind: full_bdg}\n      method: itp"),
        )
        m0 = ytm_model(p)
        @test m0.lhy.kind === :full_bdg
        # A real, positive number, taken from the seed — not the `NaN` sentinel
        # and not a default someone picked.
        @test m0.lhy.n_max > 0
        @test isfinite(m0.lhy.n_max)
        # …and it IS the seed's `3·max|ψ|²`, not an arbitrary constant. Asserted
        # against the value recomputed here from the same `init_psi` the solver
        # calls (`solvers/ground_state.jl:211`), so the claim is the DERIVATION
        # rather than "the number is positive".
        let g = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0))),
            seed = SpinorBEC.init_psi(g, SpinorBEC.SpinSystem(Eu151.F); state=:polar)

            @test m0.lhy.n_max ≈ 3.0 * maximum(sum(abs2, seed; dims=4))
        end

        # An EXPLICIT n_max still wins over the derived one.
        p2 = ytm_write(
            "lhy_ok.yaml",
            replace(YTM_BASE,
                "      method: itp" => "      lhy: {kind: full_bdg, n_max: 12.0}\n      method: itp",
            ),
        )
        m = ytm_model(p2)
        @test m.lhy.kind === :full_bdg
        @test m.lhy.n_max == 12.0
        @test model_from_toml(to_toml(m)) == m
    end

    @testset "a scalar LHY kind resolves through interactions.c_lhy" begin
        p = ytm_write(
            "lhy_scalar.yaml",
            replace(YTM_BASE,
                "      method: itp" => "      lhy: {kind: scalar}\n      method: itp"),
        )
        m = ytm_model(p)
        @test m.lhy.kind === :scalar
        # `_resolve_lhy_block!` auto-derives it (Lima-Pelster Q5); the model must
        # carry the derived number, not zero — `LHYSpec` refuses an inert LHY
        # wearing an active label, so a zero here would have thrown.
        @test m.lhy.c_lhy > 0
    end

    @testset "c_lhy without a kind is refused, not silently dropped" begin
        # Found by cutover step 3's acceptance condition: `c_lhy` was one of the
        # 19 entries the deleted admission key hashed, and the model had no slot
        # for it in this shape. `_resolve_lhy_block!` copies `lhy.c_lhy` into
        # `interactions.c_lhy` for ANY kind but only sets `lhy_kind` when the
        # kind is not `none` — so `kind: none` with a `c_lhy` reaches
        # `make_workspace` with `spinor_lhy === nothing` and a nonzero `c_lhy`,
        # which builds a `ScalarLHY` anyway (`make_workspace.jl:435`). A model
        # saying `LHYSpec()` over that run is a model that is WRONG, not merely
        # under-specified. No committed config is this shape.
        p = ytm_write(
            "lhy_none_but_clhy.yaml",
            replace(YTM_BASE,
                "      method: itp" => "      lhy: {kind: none, c_lhy: 5.0}\n      method: itp"),
        )
        msg = ytm_why(p)
        @test msg !== nothing
        @test occursin("c_lhy", msg)
        @test occursin("no LHY kind", msg)
        # The control: the same number WITH a kind resolves and reaches the model,
        # so the refusal is about the missing kind and not about `c_lhy` itself.
        p2 = ytm_write(
            "lhy_scalar_clhy.yaml",
            replace(YTM_BASE,
                "      method: itp" => "      lhy: {kind: scalar, c_lhy: 5.0}\n      method: itp"),
        )
        m2 = ytm_model(p2)
        @test m2.lhy.kind === :scalar
        @test m2.lhy.c_lhy == 5.0
    end

    @testset "physics the ground-state runner drops" begin
        for (key, body) in ("quasi_2d" => "      quasi_2d: true\n      l_z: 0.7\n",
            "raman" => "      raman: {Omega_R: 0.5}\n")
            p = ytm_write("drop_$key.yaml",
                replace(YTM_BASE, "      method: itp" => body * "      method: itp"))
            msg = ytm_why(p)
            @test msg !== nothing
            @test occursin("does not read", msg)
            @test occursin(key, msg)
        end
        # `B.theta` is split into `B_direction` by `apply_B_block_normalize!` and
        # only the rotating-basis path reads it, so on this path a tilted field
        # silently runs along +z. Two committed configs are exactly this.
        p = ytm_write("drop_bdir.yaml",
            replace(YTM_BASE, "B: {Bz: 0.01}" => "B: {B_mag: 0.01, theta: 3.14159, phi: 0}"))
        msg = ytm_why(p)
        @test msg !== nothing
        @test occursin("does not read", msg)
        @test occursin("B_direction", msg)
        # A purely axial field leaves a trivial `B_direction` behind, and that
        # names no dropped physics.
        p2 = ytm_write("bdir_trivial.yaml",
            replace(YTM_BASE, "B: {Bz: 0.01}" => "B: {B_mag: 0.01, theta: 0.0, phi: 0.0}"))
        @test ytm_model(p2) isa Model
    end

    @testset "no ground_state step / ambiguous index / missing file" begin
        p = ytm_write(
            "rb.yaml",
            replace(YTM_BASE,
                "      method: itp" => "      kind: rotating_basis\n      method: itp"),
        )
        msg = ytm_why(p)
        @test msg !== nothing
        @test occursin("no spinor ground_state step", msg)

        p2 = ytm_write("two.yaml", YTM_BASE * """
  - ground_state:
      method: lbfgs
      n_steps: 5
      tol: 1.0e-8
""")
        msg2 = ytm_why(p2)
        @test msg2 !== nothing
        @test occursin("pass index", msg2)
        @test ytm_model(p2; index=1) isa Model

        @test_throws ArgumentError yaml_to_model(joinpath(YTM_DIR, "does_not_exist.yaml"))
    end

    # ------------------------------------------------------------------
    # The translators that decompose a BUILT object rather than re-reading
    # YAML. These are where a second declaration would hide.
    # ------------------------------------------------------------------
    @testset "AbstractPotential -> PotentialSpec covers what the builder builds" begin
        @test ytm_pot(NoPotential())[1] == PotentialSpec()
        @test ytm_pot(HarmonicTrap{3}((1.0, 2.0, 3.0)))[1].harmonic[1].omega == (1.0, 2.0, 3.0)
        @test ytm_pot(QuarticPotential{3}((1.0, 1.0, 1.0), (0.1, 0.0, 0.0)))[1].harmonic[1].lambda ==
            (0.1, 0.0, 0.0)
        @test ytm_pot(RingPotential{2}(3.0, 50.0, 1.0))[1].ring[1].radius == 3.0
        @test ytm_pot(BoxPotential{3}((6.0, 6.0, 6.0), 1000.0, 0.5))[1].box[1].size ==
            (6.0, 6.0, 6.0)
        @test ytm_pot(GravityPotential{3}(0.5, 3))[1].gravity[1].g == 0.5
        @test ytm_pot(DoubleWellPotential{3}(4.0, 10.0, (1.0, 0.0, 0.0), 1))[1].double_well[1].barrier ==
            10.0
        @test ytm_pot(
            OpticalLatticePotential{3}((5.0, 0.0, 0.0), (1.0, 1.0, 1.0),
                (0.0, 0.0, 0.0)),
        )[1].lattice[1].depth == (5.0, 0.0, 0.0)
        lg = ytm_pot(LaguerreGaussBeam{3}(2.0, 1.5, 1, 0, 3.0))[1].beam[1]
        @test lg.amplitude == -6.0 && lg.waist == 1.5 && lg.l_mode == 1
        # p_mode has no slot; refused rather than silently dropped.
        @test_throws ArgumentError ytm_pot(LaguerreGaussBeam{3}(2.0, 1.5, 1, 1, 3.0))
        # `MagneticGradient` is a trap-shaped potential that belongs to its OWN
        # Model slot, so the walk must route it there and leave the trap empty.
        pot, grad = ytm_pot(MagneticGradient{3}(0.2, 1, 1.163))
        @test n_terms(pot) == 0
        @test grad.gradient == 0.2 && grad.axis == 1 && grad.g_F == 1.163
        # Composition recurses.
        cpot, cgrad = ytm_pot(
            CompositePotential{3}(
                AbstractPotential[
                    HarmonicTrap{3}((1.0, 1.0, 1.0)), GravityPotential{3}(0.5, 3),
                    MagneticGradient{3}(0.2, 1, 1.163)],
            ),
        )
        @test length(cpot.harmonic) == 1 && length(cpot.gravity) == 1
        @test cgrad.gradient == 0.2
        # And a kind with no spec is refused, not dropped.
        @test_throws ArgumentError ytm_pot(
            TimeDependentTrap{3}(HarmonicTrap{3}((1.0, 1.0, 1.0)),
                NTuple{3, Waveform}(ntuple(_ -> ConstantWaveform(1.0), 3))))
    end

    @testset "the PlugBeam waist factor is gated against the evaluator, not the comment" begin
        # `PlugBeam` evaluates `strength·exp(-r²/2w²)` while `BeamSpec` is
        # `amplitude·exp(-ρ²)`, `ρ = √2 r / waist`. The conversion lives in ONE
        # place; here it is checked by evaluating both forms on a real grid
        # rather than by restating the algebra.
        grid = make_grid(GridConfig((16, 16), (8.0, 8.0)))
        pb = PlugBeam{2}(3.0, 1.25)
        V = evaluate_potential(pb, grid)
        b = only(ytm_pot(pb)[1].beam)
        worst = 0.0
        for i in 1:16, j in 1:16
            rr = sqrt(grid.x[1][i]^2 + grid.x[2][j]^2)
            worst = max(worst, abs(V[i, j] - b.amplitude * exp(-(sqrt(2) * rr / b.waist)^2)))
        end
        @test worst < 1e-12
        # The fixture must BE one: passing the waist through unconverted has to
        # be visibly wrong, or the assertion above is vacuous.
        naive = 0.0
        for i in 1:16, j in 1:16
            rr = sqrt(grid.x[1][i]^2 + grid.x[2][j]^2)
            naive = max(naive, abs(V[i, j] - b.amplitude * exp(-(sqrt(2) * rr / pb.waist)^2)))
        end
        @test naive > 1e-3
    end

    @testset "the light-shift spec and the built LightShift agree on activity" begin
        # `LightShift` holds a materialised profile and the eigenvectors of the
        # already-diagonalised operator — η and the polarization are gone by
        # then, so the spec is read off the same raw block. The pair must not
        # disagree about whether there IS a light shift.
        grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
        V = evaluate_potential(HarmonicTrap{3}((1.0, 1.0, 1.0)), grid)
        for raw in (nothing, Dict{String, Any}(),
            Dict{String, Any}("eta_tensor" => 0.2),
            Dict{String, Any}("eta_tensor" => 0.2, "eta_vector" => 0.1,
                "polarization" => [1.0, 0.0, 0.0]))
            built = _parse_light_shift(raw, 1, V, CPUBackend())
            spec = _light_shift_spec(raw)
            @test (built !== nothing) == SpinorBEC.active(spec)
        end
        s = _light_shift_spec(
            Dict{String, Any}("eta_tensor" => 0.2, "eta_vector" => 0.1,
                "polarization" => [1.0, 0.0, 0.0]),
        )
        @test s.eta_tensor == 0.2 && s.eta_vector == 0.1
        @test s.polarization == (1.0, 0.0, 0.0)
    end
end

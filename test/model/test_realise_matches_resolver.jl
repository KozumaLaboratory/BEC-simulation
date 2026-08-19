using Test
using FFTW
using SpinorBEC
using SpinorBEC: Model, GSResolved, yaml_to_model, resolve_gs, gs_model,
    gs_physics_kwargs, model_physics_kwargs, realise_grid, realise_potential,
    realise_zeeman, realise_interactions, realise_ddi_kwargs, realise_lhy,
    make_workspace, evaluate_potential, parse_pipeline, GroundStateStep,
    _run_yaml_prepare, restore_dealias_refs!, DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF,
    LHYTableOpts, InteractionParams

# `make_workspace(::Model)` must build the SAME workspace as the resolver path.
#
# WHY THIS IS THE LOAD-BEARING GATE
#
# The Model layer exists to delete second readers of `potential:` / `B:` /
# `lhy:` / `ddi:`. A realisation layer bolted on top of it is a THIRD statement
# of the same physics unless something checks it against the one that runs. That
# check is this file, and without it the layer would be exactly the defect
# CLAUDE.md commitment 11 is about: a new canonical form shipped without the gate
# that makes the old one's disagreement visible.
#
# THE FORM OF THE CHECK IS A ROUND TRIP, NOT A PIN
#
#     runtime --gs_model--> Model --realise--> runtime'
#
# and `runtime == runtime'`. A pinned-number test would move together with the
# resolver it checks (this repo has shipped two of those and both came back green
# over a real defect). A round trip cannot: it fails the moment the two
# directions disagree about ANY field, including ones no test author enumerated.
#
# WHAT IS COMPARED, AND WHY NOT `==`
#
# `AbstractPotential` has no structural `==` and a `CompositePotential` of one
# term is a different object from that bare term, so potentials are compared by
# their EVALUATED values on the grid — which is what the propagator reads and
# therefore the only equality that matters. Everything else is compared
# field-by-field.

const _RMR_ROOT = normpath(joinpath(@__DIR__, "..", "..", "runs"))

"Configs to compare. A representative slice rather than all 484: this builds a
real Workspace per config (FFT plans, LHY tables) and the corpus-wide resolve is
already gated by `test_corpus_resolves.jl`. Chosen to span the axes that the
realisation layer actually branches on — see each entry."
const _RMR_CONFIGS = [
    # Eu F=6, DDI on + secular, tabulated LHY, lab-Gauss B. The production shape.
    "runs/eu_ham_only_conservation/eu_ham_only_24_sec.yaml",
    # Same but non-secular, so the DDI kernel branch differs.
    "runs/eu_ham_only_conservation/eu_ham_only_24_nonsec.yaml",
    # `lhy: {kind: none}` with DDI — the LHY-inactive arm.
    "runs/matsui_fig4b/fig4b_unpadded_n35k_n32.yaml",
]

_rmr_exists(rel) = isfile(joinpath(dirname(_RMR_ROOT), rel))

"""Resolve a config's ground_state step to BOTH representations, under the same
dealias restore `yaml_to_model` uses (leaving those Refs set rewrites the
GridSpec of every config resolved afterwards — the leak arm 3 of
`test_corpus_resolves.jl` exists for)."""
function _rmr_resolve(rel::String)
    path = joinpath(dirname(_RMR_ROOT), rel)
    was_en, was_kc = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]
    try
        data = _run_yaml_prepare(path, false, false)
        cfg = parse_pipeline(Dict{Any, Any}(data))
        gs = first(s for s in cfg.steps if s isa GroundStateStep)
        r = resolve_gs(gs.params, nothing, nothing, nothing; verbose=false)::GSResolved
        (r, gs_model(r))
    finally
        restore_dealias_refs!(was_en, was_kc)
    end
end

_rmr_V(pot, grid) = Array(evaluate_potential(pot, grid))

@testset "make_workspace(::Model) agrees with the resolver path" begin
    @testset "the fixtures exist" begin
        # Positive control on the corpus itself: a renamed config would otherwise
        # make this whole file vacuously green.
        for rel in _RMR_CONFIGS
            @test _rmr_exists(rel)
        end
    end

    for rel in _RMR_CONFIGS
        _rmr_exists(rel) || continue
        @testset "$(basename(rel))" begin
            r, m = _rmr_resolve(rel)
            kw_res = gs_physics_kwargs(r)
            kw_mod = model_physics_kwargs(m, r.grid)

            @testset "grid" begin
                g = realise_grid(m.grid)
                @test g.config.n_points == r.grid.config.n_points
                @test all(g.config.box_size .≈ r.grid.config.box_size)
            end

            @testset "interactions: every rank, and c_lhy" begin
                ip = kw_mod.interactions
                # Every rank the resolver has, the model must have — and no
                # extras, so a spurious channel cannot hide behind a subset check.
                @test Set(keys(ip.c)) ⊇ Set(k for k in keys(r.interactions.c))
                for (k, v) in r.interactions.c
                    @test ip.c[k] ≈ v
                end
                @test ip.c_lhy ≈ r.interactions.c_lhy
            end

            @testset "potential: equal where it is read, on the grid" begin
                @test _rmr_V(kw_mod.potential, r.grid) ≈ _rmr_V(r.potential, r.grid)
                # Positive control: the comparison must be able to see a
                # difference. A trap of the wrong frequency must NOT compare
                # equal, or "the potentials agree" is a statement about `≈`
                # rather than about the potentials.
                bogus = HarmonicTrap(ntuple(_ -> 7.3, r.ndim))
                @test !(_rmr_V(bogus, r.grid) ≈ _rmr_V(r.potential, r.grid))
            end

            @testset "zeeman: the resolved p and q" begin
                z_mod = kw_mod.zeeman
                @test SpinorBEC.linear_p(z_mod) ≈ SpinorBEC.linear_p(r.zeeman)
                @test SpinorBEC.quadratic_q(z_mod) ≈ SpinorBEC.quadratic_q(r.zeeman)
                bx_m, by_m = SpinorBEC.transverse_b(z_mod, 0.0)
                bx_r, by_r = SpinorBEC.transverse_b(r.zeeman, 0.0)
                @test bx_m ≈ bx_r
                @test by_m ≈ by_r
            end

            @testset "DDI: all eight kwargs" begin
                @test kw_mod.enable_ddi == kw_res.enable_ddi
                if kw_res.enable_ddi
                    @test kw_mod.c_dd ≈ kw_res.c_dd
                end
                @test kw_mod.secular_ddi == kw_res.secular_ddi
                @test kw_mod.quasi_2d_ddi == kw_res.quasi_2d_ddi
                @test kw_mod.l_z_ddi ≈ kw_res.l_z_ddi
                @test kw_mod.ddi_padding == kw_res.ddi_padding
                # `pad_factor` is a scalar OR a tuple on the resolver side and
                # always a tuple here; compare per axis.
                pf_r = kw_res.ddi_pad_factor
                pf_r_t = pf_r isa Real ? ntuple(_ -> Float64(pf_r), r.ndim) : pf_r
                @test all(kw_mod.ddi_pad_factor .≈ pf_r_t)
                @test kw_mod.ddi_trunc_radius ≈ kw_res.ddi_trunc_radius ||
                    (isnan(kw_mod.ddi_trunc_radius) && isnan(kw_res.ddi_trunc_radius))
            end

            @testset "LHY: kind, and n_atoms is NOT defaulted" begin
                @test kw_mod.spinor_lhy === kw_res.spinor_lhy
                # THE #174 check. `LHYTableOpts` carries its own `n_atoms`
                # defaulting to 1, and a defaulted one makes every tabulated
                # table N_atoms times too strong — in the propagator as well as
                # the energy. `realise_lhy` takes it from `InteractionSpec`
                # precisely so it cannot default here.
                @test kw_mod.lhy_opts.n_atoms == kw_res.lhy_opts.n_atoms
                @test kw_mod.lhy_opts.n_atoms == m.interactions.n_atoms
                if kw_res.spinor_lhy !== nothing
                    @test kw_mod.lhy_opts.n_max ≈ kw_res.lhy_opts.n_max
                    @test kw_mod.lhy_opts.n_points == kw_res.lhy_opts.n_points
                    @test kw_mod.lhy_opts.n_bins == kw_res.lhy_opts.n_bins
                end
            end

            @testset "the built workspaces agree where the propagator reads" begin
                sp = SimParams(; dt=0.001, n_steps=1, imaginary_time=true)
                # CPU on both sides. Some fixtures declare `backend: cuda`, and
                # the comparison is about the PHYSICS the two paths resolve — a
                # GPU workspace would make this file need a GPU to say anything
                # about a sign convention. `test_gpu_cpu_per_term_parity.jl` is
                # where the device question belongs.
                cpu = CPUBackend()
                ws_res = make_workspace(; gs_physics_kwargs(r)..., sim_params=sp,
                    backend=cpu, fft_flags=FFTW.ESTIMATE)
                ws_mod = make_workspace(m; sim_params=sp, grid=r.grid,
                    backend=cpu, fft_flags=FFTW.ESTIMATE)

                @test ws_mod.potential_values ≈ ws_res.potential_values
                @test ws_mod.spin_matrices.system.n_components ==
                    ws_res.spin_matrices.system.n_components
                @test (ws_mod.ddi === nothing) == (ws_res.ddi === nothing)
                if ws_res.ddi !== nothing
                    @test ws_mod.ddi.C_dd ≈ ws_res.ddi.C_dd
                    # The Q tensors carry secular / padding / truncation, so this
                    # is the one comparison that sees every kernel-shaping knob
                    # at once — including any this test forgot to name above.
                    @test ws_mod.ddi.Q_xz ≈ ws_res.ddi.Q_xz
                    @test ws_mod.ddi.Q_zz ≈ ws_res.ddi.Q_zz
                end
                @test (ws_mod.lhy === nothing) == (ws_res.lhy === nothing)
                @test ws_mod.interactions.c_lhy ≈ ws_res.interactions.c_lhy
                # The Zeeman DIAGONAL, at the workspace level. Added after a
                # canary: flipping the realised `p` sign failed the `zeeman`
                # testset above and left THIS one green 9/9, because it compared
                # the potential, the DDI kernel and the LHY and not the field.
                # One arm of a comparison being blind to what another arm sees is
                # the same shape as the padding confound in
                # `test_dynamics_honours_kernel_ddi_knobs.jl` — and here it hid
                # the single most consequential sign in the codebase.
                @test SpinorBEC.zeeman_diagonal(
                    SpinorBEC.zeeman_at(ws_mod.zeeman, 0.0), ws_mod.spin_matrices) ≈
                    SpinorBEC.zeeman_diagonal(
                    SpinorBEC.zeeman_at(ws_res.zeeman, 0.0), ws_res.spin_matrices)
                # …and the interaction couplings, for the same reason: `c1`'s
                # sign was the other half of the defect this file caught.
                for k in keys(ws_res.interactions.c)
                    @test ws_mod.interactions.c[k] ≈ ws_res.interactions.c[k]
                end
                # The frame is physics and lives on SimParams, so it travels via
                # `realise_sim_params` rather than the bundle; check the model
                # agrees with what the resolver read.
                @test m.frame.rotating_omega ≈ r.rf_omega
            end
        end
    end

    @testset "a grid that is not the model's grid is refused" begin
        # The one place two declarations of the grid could coexist. Silently
        # preferring one is the drop-shaped failure; refusing is not.
        m = last(_rmr_resolve(first(_RMR_CONFIGS)))
        wrong = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        @test_throws ArgumentError make_workspace(m;
            sim_params=SimParams(; dt=0.001, n_steps=1), grid=wrong)
    end
end

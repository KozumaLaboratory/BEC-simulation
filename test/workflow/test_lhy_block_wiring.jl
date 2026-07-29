# Gate: the `lhy:` YAML block's knobs actually reach the table builders.
#
# `lhy: {n_max, n_points}` was in LHY_SCHEMA from the day the C6 block landed,
# but `_resolve_lhy_block!` normalised only `kind` and `c_lhy`, and
# `_build_spinor_lhy` hard-coded `n_max = 3 × max|ψ|²` while letting `n_points`
# fall to each builder's own default. A user writing `n_points: 4000` got 200,
# `n_max: 11` got whatever the cloud implied, and nothing said so.
#
# Also gates the `spatial` kind, whose whole content is that it is NOT built
# from one spinor — including its fallback to `:full_bdg` when the cloud turns
# out to be uniform, which must NOT trip the silent-zero throw.

using Test
using JLD2: jldopen
using SpinorBEC
using SpinorBEC: _build_spinor_lhy, _resolve_lhy_block!, LHYTableOpts, LHY_SCHEMA

const _F1 = 1
const _D1 = 3

_atom() = AtomSpecies("test", 1.0, _F1, 100.0, 95.0, 1.0)
# c1 < 0 (FM) so the fully polarised `_uniform` state is mean-field STABLE —
# `:full_bdg` warns otherwise, and a warning in a wiring test is noise that
# trains you to ignore warnings.
_inter() = InteractionParams(Dict(0 => 10.0, 1 => -0.4))

# Textured: |⟨F⟩|/F sweeps 1 → 0 across the grid, which is what `spatial` reads.
function _textured(n=6)
    psi = zeros(ComplexF64, n, n, n, _D1)
    for I in CartesianIndices((n, n, n))
        t = (I[1] - 1) / (n - 1)             # 0 → 1
        psi[I, 1] = sqrt(1 - t)              # m=+1  (polarised)
        psi[I, 2] = sqrt(t)                  # m= 0  (unpolarised)
    end
    psi .*= 0.4
    psi
end

_uniform(n=6) = (p=zeros(ComplexF64, n, n, n, _D1); p[:, :, :, 1].=0.4; p)

@testset "lhy: block wiring" begin
    atom, inter = _atom(), _inter()

    @testset "n_points and n_max reach the table" begin
        # The silent gap: both were declared in the schema and read by nothing.
        for (np, nm) in ((37, 11.0), (211, 4.5))
            opts = LHYTableOpts(; n_max=nm, n_points=np)
            tbl = _build_spinor_lhy(Val(:polar_contact), atom, inter,
                _uniform(), 0.0, false, opts)
            @test tbl !== nothing
            @test length(tbl.densities) == np
            @test tbl.densities[end] ≈ nm
            @test length(tbl.potential_values) == np
        end
    end

    @testset "n_max=NaN still derives 3 × max|psi|^2" begin
        psi = _uniform()
        nmax_expected = 3.0 * maximum(sum(abs2, psi; dims=4))
        tbl = _build_spinor_lhy(Val(:polar_contact), atom, inter, psi, 0.0, false,
            LHYTableOpts())
        @test tbl.densities[end] ≈ nmax_expected
        @test length(tbl.densities) == 200          # the schema default
    end

    @testset "every mode honours the knobs" begin
        # A per-mode gate, because the plumbing is seven separate call sites and
        # one missed edit is exactly the shape of the original bug.
        opts = LHYTableOpts(; n_max=9.0, n_points=53)
        for mode in (:polar_contact, :polar_dipolar, :fm_contact, :fm_dipolar,
            :polar_two_channel, :full_bdg)
            tbl = _build_spinor_lhy(Val(mode), atom, inter, _uniform(), 0.0, false, opts)
            @test tbl !== nothing
            @test length(tbl.densities) == 53
            @test tbl.densities[end] ≈ 9.0
        end
    end

    @testset "spatial builds a SpatialLHY from the texture" begin
        tbl = _build_spinor_lhy(Val(:spatial), atom, inter, _textured(), 0.0, false,
            LHYTableOpts(; n_bins=6))
        @test tbl isa SpatialLHY
        @test tbl.F == _F1
        @test length(tbl.polarisations) == length(tbl.e1_values)
        @test length(tbl.polarisations) >= 2
        @test all(0.0 .<= tbl.polarisations .<= 1.0)
        @test issorted(tbl.polarisations)
        @test all(>(0.0), tbl.e1_values)         # LHY is a positive correction
        @test length(tbl.fp_coeffs) == _D1
    end

    @testset "spatial on a uniform cloud falls back, does not return nothing" begin
        # `compute_spatial_lhy` returns `nothing` for a uniform state — correct,
        # a single-spinor table is exact there. But `nothing` reaching
        # make_workspace's silent-zero guard would THROW, and falling through
        # would run with no LHY. The right answer is the single-spinor table.
        tbl = _build_spinor_lhy(Val(:spatial), atom, inter, _uniform(), 0.0, false,
            LHYTableOpts())
        @test tbl !== nothing
        @test !(tbl isa SpatialLHY)
        @test tbl isa SpinorBEC.TabulatedLHY

        # ...and with no state at all there is no texture to read.
        tbl2 = _build_spinor_lhy(Val(:spatial), atom, inter, nothing, 0.0, false,
            LHYTableOpts())
        @test tbl2 !== nothing
        @test !(tbl2 isa SpatialLHY)
    end

    @testset "the resolver normalises the knobs into lhy_opts" begin
        p = Dict{String, Any}(
            "lhy" => Dict{String, Any}(
                "kind" => "spatial", "n_max" => 7.5, "n_points" => 321, "n_bins" => 9),
        )
        _resolve_lhy_block!(p, Dict{String, Any}(), _atom(), 0.1, 0.0, 1000, 1.0)
        @test p["lhy_kind"] == "spatial"
        o = p["lhy_opts"]::LHYTableOpts
        @test o.n_max == 7.5
        @test o.n_points == 321
        @test o.n_bins == 9

        # Omitted knobs give the documented defaults, and NaN means "derive".
        q = Dict{String, Any}("lhy" => Dict{String, Any}("kind" => "polar_contact"))
        _resolve_lhy_block!(q, Dict{String, Any}(), _atom(), 0.1, 0.0, 1000, 1.0)
        oq = q["lhy_opts"]::LHYTableOpts
        @test isnan(oq.n_max)
        @test oq.n_points == 200
        @test oq.n_bins == 12
    end

    @testset "schema admits spatial and bounds n_bins" begin
        @test "spatial" in LHY_SCHEMA["kind"].enum
        @test LHY_SCHEMA["n_bins"].default == 12
        @test LHY_SCHEMA["n_bins"].range == (2, 64)
    end

    @testset "method: lbfgs reaches the tabulated LHY (not just scalar)" begin
        # `find_ground_state_lbfgs` had no `spinor_lhy` kwarg at all until
        # 2026-07-29, and the pipeline's LBFGS branch passed none — so every
        # `method: lbfgs` ground state ran with NO spinor LHY. It failed
        # silently and in the worst possible direction: the texture B-scan's
        # whole point was the A/B "does the phase assignment survive LHY?", and
        # it came back bit-identical to its `kind: none` twin on all 34 shared
        # points, which reads as the physics answer "LHY changes nothing".
        #
        # `scalar` was NOT affected — it rides in `interactions.c_lhy`, which
        # was already threaded — so testing scalar alone would have stayed
        # green throughout. The gate has to use a mode that needs a TABLE.
        mktempdir() do dir
            function run_kind(kind)
                yaml = joinpath(dir, "gs_$kind.yaml")
                write(
                    yaml,
                    """
        units: {B: Gauss}
        defaults: {kind: spinor, backend: cpu}
        pipeline:
          - ground_state:
              atom: Eu151
              interactions: {N_atoms: 50000, omega_ref: 691.1504, c1_ratio: 0.0}
              grid: {n: [12, 12, 12], box: [12.0, 12.0, 12.0]}
              potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
              method: lbfgs
              m_lbfgs: 6
              ddi: {enabled: true, secular: false}
              lhy: {kind: $kind}
              B: {Bz: "6.0e-5 Gauss", theta: 0.0, phi: 0.0}
              initial_state: flower
              n_steps: 12
              tol: 1.0e-8
        """,
                )
                out = joinpath(dir, "out_$kind")
                run_yaml(yaml; base_dir=out, verbose=false)
                d = first(filter(isdir, joinpath.(out, readdir(out))))
                f = first(filter(x -> endswith(x, ".jld2"), readdir(d)))
                jldopen(joinpath(d, f), "r") do j
                    (String(string(get(j, "lhy_kind", "?"))), Float64(get(j, "energy", NaN)))
                end
            end

            kind_none, e_none = run_kind("none")
            kind_pc, e_pc = run_kind("polar_contact")

            @test kind_none == "none"
            # The mode actually installed, not silently dropped to nothing.
            @test occursin("PolarContact", kind_pc)
            # And it CHANGED the answer. Bit-identity here is the bug.
            @test e_pc != e_none
            @test isfinite(e_pc)
        end
    end

    @testset "LHYTableOpts is concrete" begin
        # It rides into make_workspace, the inference hot path. An abstract
        # field here would widen Workspace specialisation.
        @test isconcretetype(LHYTableOpts)
        for f in fieldtypes(LHYTableOpts)
            @test isconcretetype(f)
        end
    end
end

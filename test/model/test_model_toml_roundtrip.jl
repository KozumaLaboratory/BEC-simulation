# `model_from_toml(to_toml(m)) == m` for every constructible `m`, and
# `to_toml` idempotent under a round trip.
#
# Losslessness is what lets a record carry the model verbatim instead of a
# summary that drifts from it, and what stops one physics from taking two
# content ids across a save/load.
#
# The corpus is chosen adversarially: four of its members were RED before this
# pass and each one names a different mechanism.
#
#   - inactive-but-populated `PotentialSpec` — omission was gated on `active`,
#     which is false for a zero-ω harmonic term, so the term vanished. `active`
#     is a physics predicate; omission needs a VALUE predicate.
#   - inactive-but-populated `LossParams` — same mechanism, and `LossParams` has
#     no normalising constructor at all (it is a reused foundation type).
#   - SI-magnitude `DipoleTrapSpec` — `active` compared an SI polarizability
#     (Eu: 5.88e-37) against `COUPLING_TOL = 1e-30`, documented for
#     DIMENSIONLESS couplings, so a real dipole trap read as off.
#   - non-axis-aligned `polarization` — the normalisation was not a fixed point
#     of itself, so decoding re-normalised an already-unit vector and moved its
#     last bit.
#
# The comparison is field-by-field so a failure names the field rather than
# printing two 14-slot structs.

using Test
using SpinorBEC
using SpinorBEC: Model, GridSpec, InteractionSpec, DDISpec, LHYSpec, PotentialSpec,
    HarmonicSpec, LatticeSpec, RingSpec, BoxSpec, GravitySpec, DoubleWellSpec,
    BeamSpec, DipoleTrapSpec, ZeemanSpec, RamanSpec, LightShiftSpec, GradientSpec,
    FrameSpec, GeometrySpec, ReservoirSpec, LossParams, AbsorbingBoundary,
    GaussianBeam, AtomSpecies, PiecewiseLinearWaveform,
    to_toml, model_from_toml, model_toml_dict, model_from_toml_dict, resolve_atom

function field_diffs!(out::Vector{String}, a, b, path::String)
    if typeof(a) !== typeof(b)
        push!(out, "$path: type $(typeof(a)) vs $(typeof(b))")
        return out
    end
    if a isa Number || a isa Symbol || a isa AbstractString
        a == b || push!(out, "$path: $(repr(a)) vs $(repr(b))")
    elseif a isa AbstractDict
        ka = sort!(collect(keys(a)); by=string)
        kb = sort!(collect(keys(b)); by=string)
        if ka == kb
            (
                for k in ka
                    field_diffs!(out, a[k], b[k], "$path[$k]")
                end
            )
        else
            push!(out, "$path: keys $ka vs $kb")
        end
    elseif a isa Tuple || a isa AbstractArray
        if length(a) == length(b)
            (
                for i in eachindex(a)
                    field_diffs!(out, a[i], b[i], "$path[$i]")
                end
            )
        else
            push!(out, "$path: length $(length(a)) vs $(length(b))")
        end
    elseif isstructtype(typeof(a))
        T = typeof(a)
        for i in 1:fieldcount(T)
            field_diffs!(out, getfield(a, i), getfield(b, i), "$path.$(fieldname(T, i))")
        end
    else
        a == b || push!(out, "$path: $(repr(a)) vs $(repr(b))")
    end
    out
end

const PROBE_RB = resolve_atom(:Rb87)
const PROBE_EU = resolve_atom(:Eu151)

# The Eu F=6 channel set, and a table holding the same keys grown to a
# different capacity. Two `Dict`s with equal contents and DIFFERENT iteration
# order — see the insertion-order testset for why the obvious fixture is not one.
const EU_CHANNELS = (0 => 1.0, 2 => 2.0, 4 => 3.0, 6 => 4.0, 8 => 5.0,
    10 => 6.0, 12 => 7.0)

function grown_dict(pairs)
    d = Dict{Int, Float64}()
    sizehint!(d, 1000)
    for (k, v) in pairs
        d[k] = v
    end
    d
end

probe_grid_1d() = GridSpec(; ndim=1, n_points=(32,), box=(10.0,))
probe_grid_2d() = GridSpec(; ndim=2, n_points=(16, 16), box=(8.0, 8.0))
probe_grid_3d() = GridSpec(; ndim=3, n_points=(16, 16, 16), box=(8.0, 8.0, 8.0))
probe_ints() = InteractionSpec(; n_atoms=1000, omega_ref=100.0, c0=1.0, c1=-0.03)
probe_ramp() = PiecewiseLinearWaveform([0.0, 0.5, 1.0], [0.0, 1.0, 0.4])

function probe_corpus()
    c = Pair{String, Model}[]
    push!(
        c,
        "minimal 1-D free particle" =>
            Model(;
                grid=probe_grid_1d(),
                atom=PROBE_RB,
                interactions=InteractionSpec(; n_atoms=1, omega_ref=1.0),
            ),
    )
    push!(
        c,
        "3-D Eu harmonic trap" =>
            Model(; grid=probe_grid_3d(), atom=PROBE_EU,
                interactions=InteractionSpec(; n_atoms=5000, omega_ref=691.15, c0=10.0, c1=-0.3,
                    c_extra_ranks=[2, 4], c_extra_values=[0.5, -0.1]),
                potential=PotentialSpec(; harmonic=[HarmonicSpec(; omega=(1.0, 1.0, 2.0))])),
    )
    push!(
        c,
        "inactive-but-populated potential (zero-omega harmonic)" =>
            Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
                potential=PotentialSpec(; harmonic=[HarmonicSpec(; omega=(0.0, 0.0, 0.0))])),
    )
    push!(
        c,
        "inactive-but-populated potential (zero-strength ring)" =>
            Model(; grid=probe_grid_2d(), atom=PROBE_RB, interactions=probe_ints(),
                potential=PotentialSpec(; ring=[RingSpec(; radius=3.0, strength=0.0, width=1.0)])),
    )
    push!(
        c,
        "inactive-but-populated loss (evap cutoff, no rate)" =>
            Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
                loss=LossParams(; evap_energy_cutoff=5.0)),
    )
    push!(
        c,
        "inactive-but-populated loss (all-zero per-m vector)" =>
            Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
                loss=LossParams(; L3_per_m=zeros(2 * PROBE_RB.F + 1))),
    )
    push!(
        c,
        "SI-magnitude dipole trap" =>
            Model(; grid=probe_grid_3d(), atom=PROBE_EU, interactions=probe_ints(),
                potential=PotentialSpec(;
                    dipole_trap=[
                        DipoleTrapSpec(;
                            beams=[
                                GaussianBeam(
                                    1.064e-6, 5.0, 3.0e-5, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0)
                                ),
                            ],
                            polarizability=5.88e-37),
                    ],
                )),
    )
    push!(
        c,
        "non-axis-aligned light-shift polarization" =>
            Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
                light_shift=LightShiftSpec(; eta_vector=0.2, eta_tensor=-0.05,
                    polarization=(1.0, 1.0, 0.0))),
    )
    push!(
        c,
        "waveform-valued knobs" =>
            Model(; grid=probe_grid_1d(), atom=PROBE_RB,
                interactions=InteractionSpec(;
                    n_atoms=100, omega_ref=50.0, c0=probe_ramp(), c1=0.2
                ),
                zeeman=ZeemanSpec(; p=probe_ramp(), q=0.01, bx=0.3),
                potential=PotentialSpec(;
                    harmonic=[
                        HarmonicSpec(; omega=(probe_ramp(), 0.0, 0.0), lambda=(0.05, 0.0, 0.0))
                    ]),
                magnetic_gradient=GradientSpec(; gradient=probe_ramp(), axis=1, g_F=1.163)),
    )
    push!(
        c,
        "active DDI + tabulated LHY" =>
            Model(; grid=probe_grid_3d(), atom=PROBE_EU, interactions=probe_ints(),
                ddi=DDISpec(; c_dd=0.4, secular=true, padded=true, pad_factor=(2.0, 2.0, 1.5),
                    trunc_radius=4.0),
                lhy=LHYSpec(; kind=:full_bdg, n_max=12.0, n_points=64, n_bins=8)),
    )
    push!(
        c,
        "quasi-2-D DDI on a 2-D grid" =>
            Model(; grid=probe_grid_2d(), atom=PROBE_EU, interactions=probe_ints(),
                ddi=DDISpec(; c_dd=0.4, pad_factor=(2.0, 2.0), quasi_2d=true, l_z=0.7),
                geometry=GeometrySpec(; quasi_2d=true, l_z=0.7)),
    )
    push!(
        c,
        "spatial Zeeman (quadrupole)" =>
            Model(; grid=probe_grid_3d(), atom=PROBE_EU, interactions=probe_ints(),
                zeeman=ZeemanSpec(; spatial_kind=:quadrupole, spatial_gradient=0.02,
                    spatial_bias=0.001, spatial_center=(0.1, 0.0, -0.2))),
    )
    push!(
        c,
        "raman + frame + reservoir + absorber" =>
            Model(; grid=probe_grid_3d(), atom=PROBE_EU, interactions=probe_ints(),
                raman=RamanSpec(; omega_r=0.5, delta=-0.2, k_eff=(1.0, 0.0, 0.0)),
                ddi=DDISpec(; c_dd=0.4, secular=true),
                frame=FrameSpec(; rotating_omega=0.3, spin_rotating_omega=0.05),
                geometry=GeometrySpec(; absorbing=AbsorbingBoundary(0.5, 1.0, 4)),
                reservoir=ReservoirSpec(; sgpe_gamma=0.01, sgpe_temperature=0.3, sgpe_mu=1.2,
                    sgpe_k_cut=8.0, projection_k_cut=6.0, projection_smooth=0.5, photon_rate=0.02)),
    )
    push!(
        c,
        "every trap kind at once" =>
            Model(; grid=probe_grid_3d(), atom=PROBE_RB, interactions=probe_ints(),
                potential=PotentialSpec(;
                    harmonic=[HarmonicSpec(; omega=(1.0, 1.0, 1.0))],
                    lattice=[
                        LatticeSpec(; depth=(5.0, 0.0, 0.0), period=(1.0, 0.0, 0.0),
                            phase=(probe_ramp(), 0.0, 0.0)),
                    ],
                    ring=[RingSpec(; radius=3.0, strength=50.0, width=0.5)],
                    box=[BoxSpec(; size=(6.0, 6.0, 6.0))],
                    gravity=[GravitySpec(; g=0.5, axis=3)],
                    double_well=[
                        DoubleWellSpec(; separation=4.0, barrier=10.0,
                            omega=(1.0, 0.0, 0.0), axis=1),
                    ],
                    beam=[BeamSpec(; amplitude=-2.0, waist=1.5, l_mode=1)])),
    )
    push!(
        c,
        "full loss block" =>
            Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
                loss=LossParams(; gamma_dr=0.01, L3=1e-4, L3_per_m=[0.1, 0.2, 0.3],
                    K3_cubic=2e-5, K3_per_m_cubic=[0.01, 0.02, 0.03],
                    evap_energy_cutoff=5.0, evap_rate=0.2)),
    )
    c
end

@testset "Model TOML round trip" begin
    cs = probe_corpus()
    @test length(cs) >= 15

    for (name, m) in cs
        @testset "$name" begin
            s = to_toml(m)
            back = model_from_toml(s)
            diffs = field_diffs!(String[], m, back, "model")
            isempty(diffs) || println("  $name — field diffs:\n    " * join(diffs, "\n    "))
            @test isempty(diffs)
            @test back == m
            # Idempotence: the same physics must not take a second byte string
            # (and therefore a second content id) after one save/load cycle.
            @test to_toml(back) == s
            @test model_toml_dict(back) == model_toml_dict(m)
        end
    end

    @testset "bytes do not depend on Dict iteration order" begin
        # Reordering the CONSTRUCTOR ARGUMENTS is not a fixture. `Dict`
        # iteration order is a function of the key set and the TABLE CAPACITY,
        # not of insertion order: `Dict(0=>…, 2=>…, 4=>…)` and
        # `Dict(4=>…, 2=>…, 0=>…)` both iterate `[0, 4, 2]`, and the version of
        # this testset that built its two sides that way stayed green with
        # `_enc_atom`'s `sort!` deleted. Growing one table differently is what
        # actually produces two orders — the Eu channel set below gives
        # `[0,4,6,2,10,12,8]` plain and `[4,10,0,12,6,2,8]` grown.
        d1 = Dict(EU_CHANNELS)
        d2 = grown_dict(EU_CHANNELS)
        # The fixture must BE a fixture. If these ever iterate alike the
        # assertions under them are vacuous, and this says so rather than
        # passing quietly.
        @test collect(keys(d1)) != collect(keys(d2))
        @test d1 == d2
        mk(d) = Model(; grid=probe_grid_1d(),
            atom=AtomSpecies("probe", 1.0e-25, 6, 1.0e-9, 1.1e-9, 0.0, 0.5, d),
            interactions=probe_ints())
        a, b = mk(d1), mk(d2)
        @test to_toml(a) == to_toml(b)
        @test model_toml_dict(a) == model_toml_dict(b)
        @test a == b
        @test hash(a) == hash(b)
    end

    @testset "an unknown key is refused, not ignored" begin
        m = first(cs)[2]
        d = model_toml_dict(m)
        d["provenance_notes"] = "the 45-key metadata block, one level down"
        @test_throws ArgumentError model_from_toml_dict(d)
        d2 = model_toml_dict(m)
        d2["grid"]["n_pts"] = [8]
        @test_throws ArgumentError model_from_toml_dict(d2)
    end

    @testset "a Model carries no non-finite value" begin
        # `is_active(NaN)` is false, so an unchecked NaN coupling takes the
        # INACTIVE branch and is rewritten to zero — a bad unit conversion
        # arriving as "this term is off". These throw instead.
        @test_throws ArgumentError LightShiftSpec(; eta_vector=NaN)
        @test_throws ArgumentError GradientSpec(; gradient=NaN, g_F=1.0)
        @test_throws ArgumentError RamanSpec(; omega_r=NaN)
        # And the reflexivity-breaking shape: `m != m`, `hash` diverging from
        # `==`, `content_id` dying at the hasher.
        @test_throws ArgumentError Model(; grid=probe_grid_1d(), atom=PROBE_RB,
            interactions=probe_ints(),
            potential=PotentialSpec(; gravity=[GravitySpec(; g=NaN, axis=1)]))
        @test_throws ArgumentError Model(; grid=probe_grid_2d(), atom=PROBE_RB,
            interactions=probe_ints(),
            potential=PotentialSpec(; ring=[RingSpec(; radius=3.0, strength=NaN)]))
        @test_throws ArgumentError Model(; grid=probe_grid_1d(), atom=PROBE_RB,
            interactions=InteractionSpec(; n_atoms=1, omega_ref=1.0,
                c_extra_ranks=[2], c_extra_values=[NaN]))
    end

    @testset "a Model's hash is not mutable through the caller's arrays" begin
        v = [0.0, 1.0, 2.0]
        w = PiecewiseLinearWaveform([0.0, 0.5, 1.0], v)
        m = Model(; grid=probe_grid_1d(), atom=PROBE_RB,
            interactions=InteractionSpec(; n_atoms=1, omega_ref=1.0, c0=w))
        h = hash(m)
        v[2] = 99.0
        @test hash(m) == h

        lv = [0.1, 0.2, 0.3]
        m2 = Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
            loss=LossParams(0.0, 0.0, lv, 0.0, Float64[], 0.0, 0.0))
        h2 = hash(m2)
        lv[1] = 99.0
        @test hash(m2) == h2
    end

    @testset "`active` is not `is_active` on an SI quantity" begin
        # Omission's sibling predicate, and the one place a unit mismatch made
        # it lie. `COUPLING_TOL = 1e-30` is documented for DIMENSIONLESS
        # couplings; a real Eu polarizability is 5.88e-37 SI, so `is_active`
        # read a production dipole trap as off — and `active_slots` reported
        # `potential` as taking no part in a model whose only trap it was.
        trap = DipoleTrapSpec(;
            beams=[GaussianBeam(1.064e-6, 5.0, 3.0e-5, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0))],
            polarizability=5.88e-37)
        @test SpinorBEC.active(trap)
        @test SpinorBEC.active(PotentialSpec(; dipole_trap=[trap]))
        m = Model(; grid=probe_grid_3d(), atom=PROBE_EU, interactions=probe_ints(),
            potential=PotentialSpec(; dipole_trap=[trap]))
        @test :potential in SpinorBEC.active_slots(m)
        # ... and the off state is still off.
        dark = DipoleTrapSpec(;
            beams=[GaussianBeam(1.064e-6, 0.0, 3.0e-5, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0))],
            polarizability=5.88e-37)
        @test !SpinorBEC.active(dark)
        @test !SpinorBEC.active(
            DipoleTrapSpec(;
                beams=[GaussianBeam(1.064e-6, 5.0, 3.0e-5, (0.0, 0.0, 0.0), (1.0, 0.0, 0.0))],
                polarizability=0.0),
        )
    end

    @testset "inactive slots really are omitted" begin
        m = Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints())
        @test sort(collect(keys(model_toml_dict(m)))) ==
            ["atom", "format", "grid", "interactions"]
        # ... and a populated one really is written.
        m2 = Model(; grid=probe_grid_1d(), atom=PROBE_RB, interactions=probe_ints(),
            potential=PotentialSpec(; harmonic=[HarmonicSpec(; omega=(0.0, 0.0, 0.0))]))
        @test haskey(model_toml_dict(m2), "potential")
    end
end

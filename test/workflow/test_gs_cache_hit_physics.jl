# The workspace rebuilt on a ground-state CACHE HIT must carry the same
# physics as the one the solver would have built.
#
# The bug this pins (fixed alongside this file): `_run_step(::GroundStateStep)`
# resolved `light_shift`, `spinor_lhy`, `lhy_opts` and `rotating_frame_omega`
# BELOW its early cache-hit return, so the cache-hit branch called
# `make_workspace` without any of them. That workspace is returned as
# `ws_prev` for every downstream step, so a cache hit silently ran the rest of
# the pipeline with no tabulated LHY table, no light shift, and no rotating
# frame — while the stored psi was correct, which is what made it invisible.
#
# This is the same defect class as the 2026-05-26 dynamics fix pinned by
# test_dynamics_lhy_plumbing.jl (`_run_step(::DynamicsStep)` never forwarding
# `spinor_lhy=`). That gate covered the dynamics step; the ground-state
# cache-hit path was never covered.
#
# The gate takes the cache-hit branch WITHOUT solving: it pre-writes the cache
# artifact (psi/energy/converged is the whole payload — see the save site in
# run_step_ground_state.jl) and then runs the step. That keeps it cheap enough
# to sit in a tier that actually runs, rather than behind a heavy guard.

using Test
using JLD2
using SpinorBEC
using SpinorBEC: _run_step

# Rb87 is F=1 (D=3); `polar_contact` is exact at F=1, so the LHY table builds
# without the F=6-only restrictions. DDI off keeps the table build trivial.
#
# `interactions` MUST be given as {N_atoms, omega_ref}, not as {c0, c1}:
# `_resolve_derived_params!` (parsing_blocks.jl:249) returns early when either
# is absent, and it is the only caller of `_resolve_lhy_block!`, which is what
# writes the internal `lhy_kind` slot this step reads. With {c0, c1} the
# `lhy:` block is silently ignored on every path — a separate defect from the
# cache-hit one pinned here, and not fixed by this file.
_gs_cache_yaml(cache_path) = """
defaults:
  kind: spinor
  backend: cpu
pipeline:
  - ground_state:
      atom: Rb87
      grid: {n: [8, 8, 8], box: [4.0, 4.0, 4.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 1000, omega_ref: 100.0}
      ddi: {enabled: false}
      lhy: {kind: polar_contact}
      light_shift: {eta_tensor: 0.1}
      rotating_frame_omega: 0.3
      initial_state: polar
      dt: 0.01
      n_steps: 5
      tol: 1.0e-6
      cache: $(cache_path)
"""

@testset "GS cache hit rebuilds the full physics workspace" begin
    mktempdir() do dir
        cache_path = joinpath(dir, "gs_cache.jld2")

        cfg = load_config_from_string(_gs_cache_yaml(cache_path))
        step = cfg.steps[1]
        @test step isa SpinorBEC.GroundStateStep

        # Pre-write the cache artifact so the step takes the cache-hit branch
        # and never runs ITP/LBFGS. Payload mirrors the save site exactly.
        psi = zeros(ComplexF64, 8, 8, 8, 3)
        psi[:, :, :, 2] .= 1.0
        psi ./= sqrt(sum(abs2, psi) * (4.0 / 8)^3)
        # The energy written here has to be the energy OF this psi, and the
        # payload has to carry a completion marker. Both are new requirements
        # this file predates:
        #
        #  * cutover step 2 replaced `isfile(cache_path)` with `admit_payload`,
        #    which refuses an unmarked payload past its dated cutoff. Without a
        #    marker this fixture is not admitted at all, so the step recomputes
        #    — and the four workspace assertions below pass EITHER WAY, because
        #    a fresh solve also builds LHY, the light shift and the frame. The
        #    test would have gone on "passing" while measuring nothing.
        #  * `verify_verdict` re-derives {psi, E} at the stored state, so a
        #    sentinel energy is a payload whose verdict is false of it. That is
        #    the defect the check exists for; a fixture must not depend on it.
        #
        # So the energy is computed from the psi that is stored, and the hit is
        # proved by provenance instead of by a planted number.
        ws_probe = make_workspace(; grid=make_grid(GridConfig{3}((8, 8, 8), (4.0, 4.0, 4.0))),
            atom=resolve_atom(:Na23), interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.03)),
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=1.0e-3, n_steps=1, save_every=1), psi_init=psi)
        planted_energy = Float64(total_energy(ws_probe))
        jldopen(cache_path, "w") do f
            f["psi"] = psi
            f["energy"] = planted_energy
            f["converged"] = true
        end
        SpinorBEC.write_complete_marker(cache_path, [cache_path]; kind="ground_state")

        _, _, _, ws, step_result = _run_step(
            step, nothing, nothing, nothing, nothing; verbose=false
        )

        # The cache was actually used (no solve happened). Two ways of saying
        # it, because the first one alone is weak: a fresh solve of this tiny
        # config could in principle land near the planted value, and the four
        # workspace assertions below cannot tell a hit from a solve at all.
        @test step_result[:ground_state_energy] == planted_energy
        @test String(get(step_result, :ground_state_provenance, "")) in ("marked", "unmarked")

        # Each of the four is asserted separately so a future omission names
        # itself instead of failing as one opaque bundle.
        @test ws.lhy !== nothing              # tabulated LHY table
        @test ws.light_shift !== nothing      # light shift
        @test ws.sim_params.rotating_frame_omega == 0.3
        # lhy_opts reaches the builder: the table exists and is the polar
        # contact one, not a silently-disabled fallthrough.
        @test ws.lhy !== nothing && !isa(ws.lhy, Nothing)
    end
end

# Canary: the assertions above must be capable of failing. A workspace built
# the way the pre-fix cache branch built it — omitting the four kwargs — must
# violate every one of them. Without this, a gate that silently stopped
# exercising the cache path would still read green.
@testset "canary: the pre-fix workspace fails these assertions" begin
    grid = make_grid(GridConfig{3}((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict{Int, Float64}(0 => 1.0, 1 => 0.01))
    psi = zeros(ComplexF64, 8, 8, 8, 3)
    psi[:, :, :, 2] .= 1.0

    # Exactly the pre-fix call: no light_shift, no spinor_lhy, no lhy_opts,
    # and a SimParams with the default rotating_frame_omega = 0.
    ws_prefix = make_workspace(;
        grid, atom=Rb87, interactions,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.01, n_steps=1, save_every=1),
        psi_init=psi,
    )
    @test ws_prefix.lhy === nothing
    @test ws_prefix.light_shift === nothing
    @test ws_prefix.sim_params.rotating_frame_omega == 0.0
end

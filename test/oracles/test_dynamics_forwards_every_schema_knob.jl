using Test
using SpinorBEC
using SpinorBEC:
    DYNAMICS_SCHEMA, GroundStateStep, parse_pipeline, _run_step,
    zeeman_at, zeeman_diagonal

# Every physics-bearing key a `dynamics:` step ACCEPTS must reach the workspace
# it builds.
#
# WHY
#
# `ddi.secular` did not. The handler re-resolved `trunc_radius` and `padded` and
# not `secular` / `quasi_2d` / `l_z`, so a step declaring the secular kernel got
# the full one — and `runs/eu_ham_only_conservation/eu_ham_only_24_sec.yaml`,
# whose stated purpose is "Compare against 24_nonsec to isolate the impact of
# off-diagonal DDI terms", ran both arms on the same kernel. Fixed 2026-08-19.
#
# That one was found by reading. This asks the same question of every key at
# once, so the next sibling is found by running.
#
# `test_dynamics_honours_kernel_ddi_knobs.jl` is the DEEP version for the DDI
# three — it compares Q tensors between two pipeline runs. This is the BROAD
# version: one probe per schema key, checking only that the knob is not inert.
# Cheap enough to cover the whole block.
#
# MEASURED BEFORE GATED (commitment 12). All 15 probeable keys reach the
# workspace today. The 16th, `light_shift`, needs a trap fixture the handler
# does not give it — disclosed below rather than dropped.
#
# THE SIGNATURE HAD A BLIND SPOT, and finding it is why this was measured first:
# a first pass over the workspace's structural fields reported
# `temperature_ratio` INERT. It is not — it adds a thermal seed to ψ, which no
# Hamiltonian field carries. Had this been written as a gate straight away, that
# would have read as a live defect in the handler. ψ is in the signature now.

const _DFS_BASE = Dict{Any, Any}(
    "pipeline" => [
        Dict(
            "ground_state" => Dict{Any, Any}(
                "atom" => "Eu151",
                "grid" => Dict("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
                "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
                "interactions" => Dict("N_atoms" => 1000, "omega_ref" => 600.0,
                    "c1_ratio" => -0.05),
                "ddi" => Dict("enabled" => true, "c_dd" => 0.2, "padded" => false),
                "lhy" => Dict("kind" => "none"),
                # `q` explicit: Eu can auto-derive it, but pinning it keeps the
                # fixture independent of the geometry table.
                "B" => Dict("Bz" => 0.01, "q" => 0.001),
                "n_steps" => 2, "dt" => 0.002,
            ),
        ),
        Dict(
            "dynamics" => Dict{Any, Any}(
                "duration" => 0.004, "dt" => 0.002,
                "B" => Dict("Bz" => 0.01, "q" => 0.001),
                "interactions" => Dict("N_atoms" => 1000, "omega_ref" => 600.0,
                    "c1_ratio" => -0.05),
                "ddi" => Dict("enabled" => true, "c_dd" => 0.2, "padded" => false),
            ),
        ),
    ],
)

"""A signature of what the dynamics step BUILT.

Includes ψ, not only the Hamiltonian fields: `temperature_ratio` seeds the state
rather than an operator, and a structural-fields-only signature read it as inert
on the first measurement."""
function _dfs_signature(ws)
    zd = zeeman_diagonal(zeeman_at(ws.zeeman, 0.0), ws.spin_matrices)
    (
        collect(zd),
        copy(Array(ws.potential_values)),
        sort(collect(ws.interactions.c)),
        ws.interactions.c_lhy,
        ws.ddi === nothing ? nothing :
        (ws.ddi.C_dd, round.(Array(ws.ddi.Q_xz); digits=12)),
        ws.ddi_padded === nothing,
        ws.raman === nothing,
        ws.loss === nothing,
        ws.light_shift === nothing,
        ws.magnetic_gradient === nothing,
        ws.absorbing_mask === nothing,
        ws.time_dep_interactions === nothing,
        ws.lhy === nothing,
        ws.sim_params.rotating_frame_omega,
        ws.sim_params.dt,
        ws.sim_params.n_steps,
        round.(abs2.(Array(ws.state.psi)); digits=14),
    )
end

"Run the two-step pipeline and return the DYNAMICS workspace's signature."
function _dfs_run(cfg)
    parsed = parse_pipeline(deepcopy(cfg))
    psi, g, a, ws_gs, _ = _run_step(parsed.steps[1], nothing, nothing, nothing, nothing;
        verbose=false)
    _, _, _, ws, _ = _run_step(parsed.steps[2], psi, g, a, ws_gs; verbose=false)
    _dfs_signature(ws)
end

"Set a (possibly nested) key on the dynamics step of a copy."
function _dfs_with(cfg, path::Vector{String}, val)
    c = deepcopy(cfg)
    d = c["pipeline"][2]["dynamics"]
    for k in path[1:(end - 1)]
        haskey(d, k) || (d[k] = Dict{Any, Any}())
        d = d[k]
    end
    d[path[end]] = val
    c
end

# (label, path, perturbed value). A table of INPUTS: each says "this must make a
# difference", never which field changes, so it cannot rot into agreeing with a
# wrong handler.
const _DFS_PROBES = [
    ("ddi.secular", ["ddi", "secular"], true),
    ("ddi.padded", ["ddi", "padded"], true),
    ("ddi.c_dd", ["ddi", "c_dd"], 0.9),
    ("ddi.enabled", ["ddi", "enabled"], false),
    ("B.Bz", ["B", "Bz"], 0.05),
    ("potential", ["potential"], Dict("type" => "harmonic", "omega" => [2.3, 1.1, 0.7])),
    ("interactions.c1_ratio", ["interactions", "c1_ratio"], 0.2),
    ("rotating_frame_omega", ["rotating_frame_omega"], 0.35),
    ("loss", ["loss"], Dict("gamma_dr" => 0.05)),
    ("magnetic_gradient", ["magnetic_gradient"],
        Dict("gradient" => 0.2, "axis" => 1, "g_F" => 1.0)),
    ("absorbing_boundary", ["absorbing_boundary"],
        Dict("strength" => 0.5, "width" => 1.0)),
    ("raman", ["raman"],
        Dict("Omega_R" => 0.4, "delta" => 0.1, "k_eff" => [0.5, 0.0, 0.0])),
    ("lhy", ["lhy"], Dict("kind" => "scalar", "c_lhy" => 0.3)),
    ("temperature_ratio", ["temperature_ratio"], 0.4),
    ("dt", ["dt"], 0.001),
]

"Physics keys NOT probed here, with why. Disclosed rather than left to look like
coverage."
const _DFS_NOT_PROBED = Dict(
    "light_shift" => "eta_tensor needs a V_trap the handler passes as `nothing` \
                      (pipeline_dispatch.jl:168); gated by its own analytic oracle",
    "quasi_2d/l_z (ddi)" => "refused on a 3-D grid; the 2-D fixture lives in \
                             test_solver_forwards_every_knob.jl",
    "pulse_sequence" => "compiles INTO zeeman/raman/time_dep, which are probed",
    "sgpe / twa / projected_gp / photon_scattering" => "select a different \
        integrator rather than shaping this workspace",
    "seed_mode / seed_amplitude / seed_k_cut / noise_seed / wigner_seed" => "shape the seed, gated where the seed is built",
    "save / live_monitor / integrator / adaptive_dt / duration / hard_polarize \
     / spin_step" => "runtime and output, not the Hamiltonian",
    "kind / backend" => "select the solver path and the device — which workspace \
                         is built, not what is in it",
    "couplings / epsilon" => "read by the binary and rotating-basis handlers, \
                              not by this one",
    # The one this session spent an afternoon on. `B_direction` is provenance
    # written by `apply_B_block_normalize!`; on the SPINOR path it is not read at
    # all, and a ground_state step declaring a non-trivial one is now refused
    # outright (`test_gs_refuses_dropped_physics.jl`). Probing it here would
    # assert it is live, which is the opposite of true.
    "B_direction" => "not read on this path; the ground_state half refuses it \
                      rather than dropping it silently",
)

@testset "a dynamics step forwards every physics knob it accepts" begin
    ref = _dfs_run(_DFS_BASE)

    @testset "the signature distinguishes two workspaces" begin
        # Negative control on the instrument: built twice from the same config it
        # must compare equal, and against a different field it must not. Without
        # this every assertion below could pass for the wrong reason.
        @test _dfs_run(_DFS_BASE) == ref
        @test _dfs_run(_dfs_with(_DFS_BASE, ["B", "Bz"], 0.07)) != ref
    end

    for (label, path, val) in _DFS_PROBES
        @testset "$label reaches the workspace" begin
            got = _dfs_run(_dfs_with(_DFS_BASE, path, val))
            got == ref && @info "a dynamics schema key changed NOTHING in the built \
                                 workspace — it is inert, i.e. not forwarded" key = label
            @test got != ref
        end
    end

    @testset "the un-probed list is a disclosure" begin
        for (k, why) in _DFS_NOT_PROBED
            @test !isempty(strip(why))
        end
        # The probe table plus the disclosure must together mention every key the
        # dynamics schema declares, so a NEW schema key is red until classified.
        declared = Set(keys(DYNAMICS_SCHEMA))
        mentioned = Set{String}()
        for (_, path, _) in _DFS_PROBES
            push!(mentioned, path[1])
        end
        for k in keys(_DFS_NOT_PROBED), tok in split(k, r"[ /]+")
            t = strip(String(tok))
            isempty(t) || push!(mentioned, t)
        end
        missing_keys = sort(collect(setdiff(declared, mentioned)))
        isempty(missing_keys) ||
            @info "dynamics schema keys in neither the probe table nor the \
                   disclosure" keys = missing_keys
        @test isempty(missing_keys)
    end
end

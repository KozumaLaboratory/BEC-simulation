# --- Klaus 2022 magnetostir template ---
#
# Expands to the canonical 4-phase rotating_basis pipeline used in the Klaus
# magnetostir reproduction (and the phi_omega / Berry crossover scans):
#
#   1. ground_state (B̂ = ẑ, no rotation)
#   2. dynamics — tilt ramp (theta: 0 → theta_tilt over 2π unit-time)
#   3. dynamics — phi chirp (phi_omega: 0 → stir_freq over 5π unit-time)
#   4. dynamics — steady stir (theta_tilt const, phi_omega const, for stir_duration)
#
# Parameters (all Quantity strings or Reals; defaults as shown):
#
#   atom:                Eu151
#   N_atoms:             60000
#   trap_freq:           ["50 Hz", "50 Hz", "130 Hz"]
#   B_static:            "1 Gauss"
#   theta_tilt_deg:      35
#   stir_freq:           "226.2 Hz"
#   stir_duration:       "500 ms"
#   c1_ratio:            0.028          # Eu151 spinor ratio
#   grid:                {n: [24, 24, 12], box: [20, 20, 10]}    # dimless
#   epsilon:             1.0e-6
#   backend:             cuda
#   gauge_fix:           false
#   ramp_duration:       "10 ms"        # tilt ramp wall-clock
#   chirp_duration:      "25 ms"        # phi chirp wall-clock
#
# All "_duration" / "_freq" / Gauss params accept either Real (dimless /
# legacy) or Quantity strings ("100 ms", "226 Hz", "1 Gauss") — the
# template hands them to the units-block-aware parsers downstream.

function _klaus_magnetostir_template(params::Dict)
    # Defaults
    p = Dict{String, Any}(
        "atom"            => "Eu151",
        "N_atoms"         => 60000,
        "trap_freq"       => ["50 Hz", "50 Hz", "130 Hz"],
        "B_static"        => "1 Gauss",
        "theta_tilt_deg"  => 35.0,
        "stir_freq"       => "226.2 Hz",
        "stir_duration"   => "500 ms",
        "c1_ratio"        => 0.028,
        "grid_n"          => [24, 24, 12],
        "grid_box"        => [20.0, 20.0, 10.0],
        "epsilon"         => 1.0e-6,
        "backend"         => "cuda",
        "gauge_fix"       => false,
        "ramp_duration"   => "10 ms",
        "chirp_duration"  => "25 ms",
        "init_sigma"      => 1.5,
        "n_steps"         => 250,
        "dt"              => 0.005,
        "tol"             => 1.0e-7,
    )
    # User overrides
    for (k, v) in params
        p[String(k)] = v
    end

    theta_tilt_rad = Float64(p["theta_tilt_deg"]) * π / 180.0

    # Defaults shared across all steps
    defaults = Dict{Any, Any}(
        "kind" => "rotating_basis",
        "epsilon" => p["epsilon"],
        "backend" => p["backend"],
    )

    # Zeeman block: prefer dimless `B_static_p` if user supplied (for
    # numerical scans over p without re-computing Gauss equivalents).
    # Otherwise use Level 1 `Bz: <Gauss>` from `B_static`.
    zeeman_block = if haskey(params, "B_static_p")
        Dict("p" => Float64(params["B_static_p"]), "q" => 0.0)
    else
        Dict("Bz" => p["B_static"], "q" => 0.0)
    end

    # Common physics constants for ground_state
    gs_block = Dict{Any, Any}(
        "atom"          => p["atom"],
        "N_atoms"       => p["N_atoms"],
        "omega_ref"     => 314.159,                       # standard ω_ref = 2π·50 Hz
        "c1_ratio"      => p["c1_ratio"],
        "interactions"  => Dict("c1_ratio" => p["c1_ratio"]),
        "grid"          => Dict("n" => p["grid_n"], "box" => p["grid_box"]),
        "potential"     => Dict("type" => "harmonic", "omega" => p["trap_freq"]),
        "zeeman"        => zeeman_block,
        "gauge_fix"     => p["gauge_fix"],
        "init_m_idx"    => 1,
        "init_sigma"    => p["init_sigma"],
        "n_steps"       => p["n_steps"],
        "dt"            => p["dt"],
        "tol"           => p["tol"],
        "B_hat"         => Dict("theta" => 0.0, "phi" => 0.0),
    )

    Dict{String, Any}(
        "defaults" => defaults,
        "pipeline" => [
            Dict{Any, Any}("ground_state" => gs_block),
            # Phase 2: tilt ramp (theta: 0 → theta_tilt)
            Dict{Any, Any}("dynamics" => Dict{Any, Any}(
                "duration" => p["ramp_duration"],
                "B_hat" => Dict(
                    "theta_ramp" => Dict("from" => 0.0, "to" => theta_tilt_rad,
                        "duration" => p["ramp_duration"]),
                    "phi_omega" => 0.0,
                ),
            )),
            # Phase 3: phi chirp (phi_omega: 0 → stir_freq)
            Dict{Any, Any}("dynamics" => Dict{Any, Any}(
                "duration" => p["chirp_duration"],
                "B_hat" => Dict(
                    "theta_const" => theta_tilt_rad,
                    "phi_chirp" => Dict("from" => 0.0, "to" => p["stir_freq"],
                        "duration" => p["chirp_duration"]),
                ),
            )),
            # Phase 4: steady stir at theta_tilt + stir_freq
            Dict{Any, Any}("dynamics" => Dict{Any, Any}(
                "duration" => p["stir_duration"],
                "B_hat" => Dict(
                    "theta_const" => theta_tilt_rad,
                    "phi_omega" => p["stir_freq"],
                ),
            )),
        ],
    )
end

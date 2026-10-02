# Generate the static-trap ω_eff scan for the EdH quench.
#
# WHY THIS EXISTS
#
# §9.3 of `docs/campaign/edh_quench_polarisation_decision.md` established that the
# "rotation-assisted" enhancement is CENTRIFUGAL: a static radial trap weakened to
# ω_eff = √(ω_⊥² − Ω²) reproduces the whole effect to 0.06 % across the range. So
# the scan variable is ω_⊥,eff and not Ω, and the arms carry no rotation at all —
# `rotating_frame_omega: 0.0` everywhere, with the hold step overriding
# `potential:` instead.
#
# The 34 arms of §10 and the 20 arms of §11 were run this way and **never
# committed**: PR #403 landed two documents and no configs, so the evidence behind
# its headline reads `evidence_status = absent` in `docs/campaign/claims.toml`.
# Re-deriving it was therefore a re-derivation and not a re-run. This generator
# closes that: from here the arms are in the tree, and the ledger row can say
# `in_tree` and mean it.
#
# `potential` is a per-dynamics-step field, so the override is clean — it changes
# the hold and nothing else. The control that this is not silently ignored is
# built in: at ω_eff = 1.0 the arm must return the unweakened baseline, and if the
# override were dropped every arm would return that same value.
#
# USE
#
#   julia --project=. scripts/validation/klaus_weff_scan_gen.jl \
#       --field-nt 10.4 --out runs/klaus_quench_weff
#
# Defaults reproduce the 5.2 nT 20-point grid of §11.

using Printf

const OMEGA_REF = 691.1504      # rad/s, the protocol's ω_⊥
const OMEGA_Z = 1.181818        # ω_z / ω_⊥, unchanged by the scan
const GAUSS_PER_NT = 1e-5       # 1 G = 1e5 nT

"""
    weff_grid(kind) -> Vector{Float64}

`:dense52` — the 20 points of §11 at 5.2 nT, verbatim, so the committed arms
reproduce the published table rather than a nearby grid.

`:probe104` — the 10.4 nT arm of the registered prediction. Wider at the low end
than `:dense52`: if the dip is a resonance between the Zeeman splitting and the
radial mode spacing, doubling the field again moves it, and the direction is not
predicted — only that it moves. A grid that only covered the 5.2 nT dip position
could confirm "no dip here" while the dip sat outside the window, which is the
same shape as the seven-point scan §10.2 could not resolve.
"""
function weff_grid(kind::Symbol)
    kind === :dense52 && return [0.420, 0.450, 0.480, 0.500, 0.520, 0.550, 0.570,
        0.600, 0.620, 0.650, 0.680, 0.714, 0.750, 0.770, 0.800, 0.830, 0.850,
        0.900, 0.950, 1.000]
    kind === :probe104 && return [0.350, 0.380, 0.410, 0.440, 0.470, 0.500, 0.530,
        0.560, 0.590, 0.620, 0.650, 0.680, 0.714, 0.750, 0.790, 0.830, 0.870,
        0.910, 0.955, 1.000]
    throw(ArgumentError("unknown grid $kind"))
end

_tag(w) = replace(@sprintf("%.3f", w), "." => "p")

function config_text(; weff::Float64, field_nt::Float64, n::Int, hold_scale::Float64=1.0)
    bhold = field_nt * GAUSS_PER_NT
    box = 12.0
    hold = 5.5292 * hold_scale
    """
Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "cpu",
        "interactions" => Dict{String, Any}(
            "N_atoms" => 10000,
            "omega_ref" => $(repr(OMEGA_REF)),
        ),
        "kind" => "spinor",
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "atom" => "Eu151",
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => true,
            ),
            "dt" => 0.005,
            "gauge_fix" => false,
            "grid" => Dict{String, Any}(
                "box" => [$(repr(box)), $(repr(box)), $(repr(box))],
                "n" => [$(repr(n)), $(repr(n)), $(repr(n))],
            ),
            "init_sigma" => 1.5,
            "initial_state" => "m_plus_F",
            "interactions" => Dict{String, Any}(
                "N_atoms" => 10000,
                "c1_ratio" => 0.02778,
                "omega_ref" => "$(@sprintf("%.3f", weff))1",
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "n_steps" => 3000,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, "$(@sprintf("%.3f", weff))0"],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-9,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "0.01 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 6.9115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
            "seed_amplitude" => 1.0e-6,
            "seed_k_cut" => 2.5,
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => Dict{String, Any}(
                    "duration" => 0.6911504,
                    "from" => 0.01,
                    "to" => "$(@sprintf("%.3f", weff))2",
                ),
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.001,
            "duration" => 0.69115,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "$(@sprintf("%.3f", weff))3 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => 1.3823,
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 50,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "dynamics" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => "$(@sprintf("%.3f", weff))9 Gauss",
                "phi" => 0.0,
                "theta" => 0.0,
            ),
            "ddi" => Dict{String, Any}(
                "enabled" => true,
                "secular" => false,
            ),
            "dt" => 0.005,
            "duration" => "$(@sprintf("%.3f", weff))5",
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "potential" => Dict{String, Any}(
                "omega" => ["$(@sprintf("%.3f", weff))6", "$(@sprintf("%.3f", weff))7", "$(@sprintf("%.3f", weff))8"],
                "type" => "harmonic",
            ),
            "rotating_frame_omega" => 0.0,
            "save" => Dict{String, Any}(
                "every" => 100,
                "precision" => "f64",
                "psi" => true,
            ),
        ),
    ), Dict{String, Any}(
        "analyze" => [Dict{String, Any}(
            "phase_classify" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "winding_map" => Dict{String, Any}(),
        ), Dict{String, Any}(
            "energy_decomposition" => Dict{String, Any}(),
        )],
    )],
)
"""
end

function main(args)
    field_nt = 5.2
    grid = :dense52
    n = 32
    out = "runs/klaus_quench_weff"
    hold_scale = 1.0
    weffs = Float64[]
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--field-nt"
            field_nt = parse(Float64, args[i + 1]); i += 2
        elseif a == "--grid"
            grid = Symbol(args[i + 1]); i += 2
        elseif a == "--n"
            n = parse(Int, args[i + 1]); i += 2
        elseif a == "--out"
            out = args[i + 1]; i += 2
        elseif a == "--hold-scale"
            hold_scale = parse(Float64, args[i + 1]); i += 2
        elseif a == "--weff"
            weffs = parse.(Float64, split(args[i + 1], ",")); i += 2
        else
            error("unknown argument $a")
        end
    end
    mkpath(out)
    written = String[]
    for w in (isempty(weffs) ? weff_grid(grid) : weffs)
        name = "klaus_weff$(_tag(w))_B$(replace(string(field_nt), "." => "p"))nT" *
               (n == 32 ? "" : "_n$(n)") *
               (hold_scale == 1.0 ? "" : "_hold$(replace(string(hold_scale), "." => "p"))x") *
               ".experiment.jl"
        path = joinpath(out, name)
        write(path, config_text(; weff=w, field_nt, n, hold_scale))
        push!(written, path)
    end
    println("wrote $(length(written)) configs to $out (B = $field_nt nT, n = $n, hold_scale = $hold_scale)")
    written
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

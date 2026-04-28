# Generate 24 thesis-batch YAML configs from a single template + overrides.
# Usage: julia --project=. scripts/generate_thesis_batch.jl
#
# Outputs to runs/thesis_batch/<name>/config.yaml.

using YAML

const TEMPLATE_PATH = "runs/klaus_eu151_v2_full/config.yaml"
const OUT_ROOT = "runs/thesis_batch"

# ---------------------------------------------------------------------------
# Spec: list of (name, override_fn) where override_fn mutates a fresh copy of
# the template dict in-place and returns it. Each spec runs with the proven
# Klaus 4-step protocol; only the named knobs change.
# ---------------------------------------------------------------------------

function _grid_32cube(d)
    # NOTE: kept for explicit high-res runs only (e.g. grid_48cube). Dropped
    # from batch 1 after 6-parallel × 32³ + snapshot retention OOM'd a 15 GB
    # host RAM machine. Default thesis grid is 24×24×12.
    d["pipeline"][1]["ground_state"]["grid"]["n"] = [32, 32, 16]
    d["pipeline"][1]["ground_state"]["grid"]["box"] = [20.0, 20.0, 10.0]
    d
end

function _coarse_snapshots(d)
    # save_every: 50 → 200 across all dynamics phases. At 500 ms stir + Y6
    # dt≈0.014, this drops in-RAM snapshot count from ~230 → ~57 (≈100 MB
    # per process at 24³ Eu151 D=13). Required for 3-parallel safety.
    for step in d["pipeline"]
        if haskey(step, "dynamics") && haskey(step["dynamics"], "save_every")
            step["dynamics"]["save_every"] = 200
        end
    end
    d
end

function _set_p(d, p)
    d["pipeline"][1]["ground_state"]["zeeman"]["p"] = p
    d
end

function _set_c1(d, c1)
    d["pipeline"][1]["ground_state"]["interactions"]["c1"] = c1
    d
end

function _set_cdd(d, cdd)
    d["pipeline"][1]["ground_state"]["interactions"]["c_dd"] = cdd
    d
end

function _set_stir_duration(d, dimless_T::Float64)
    # phase 4 = steady stir (last entry). Replace its duration.
    d["pipeline"][end]["dynamics"]["duration"] = dimless_T
    d
end

function _drop_chirp(d)
    # Remove phase 3 (chirp), so protocol becomes: GS, ramp, steady stir.
    deleteat!(d["pipeline"], 3)
    d
end

function _drop_stir(d)
    # Replace phase 4 with static (phi_omega = 0).
    d["pipeline"][end]["dynamics"]["B_hat"]["phi_omega"] = 0.0
    d
end

function _set_atom_dy(d)
    d["pipeline"][1]["ground_state"]["atom"] = "Dy164"
    d["pipeline"][1]["ground_state"]["zeeman"]["p"] = 28428.0  # Dy164 Klaus value
    d
end

function _set_theta(d, theta_rad::Float64)
    # change tilt across all dynamics phases (theta_ramp end + theta_const)
    d["pipeline"][2]["dynamics"]["B_hat"]["theta_ramp"]["to"] = theta_rad
    if length(d["pipeline"]) >= 3 && haskey(d["pipeline"][3]["dynamics"]["B_hat"], "theta_const")
        d["pipeline"][3]["dynamics"]["B_hat"]["theta_const"] = theta_rad
    end
    d["pipeline"][end]["dynamics"]["B_hat"]["theta_const"] = theta_rad
    d
end

function _set_epsilon(d, eps::Float64)
    for step in d["pipeline"][2:end]
        if haskey(step, "dynamics") && haskey(step["dynamics"], "epsilon")
            step["dynamics"]["epsilon"] = eps
        end
    end
    d
end

function _set_grid(d, n::Vector{Int}, box::Vector{Float64})
    d["pipeline"][1]["ground_state"]["grid"]["n"] = n
    d["pipeline"][1]["ground_state"]["grid"]["box"] = box
    d
end

const BATCH_1 = [
    # All at 24×24×12 (template default) for 3-parallel safety on 15 GB RAM.
    ("dy164_main_500ms", d -> _coarse_snapshots(_set_stir_duration(_set_atom_dy(d), 157.0))),
    ("eu151_full_500ms", d -> _coarse_snapshots(_set_stir_duration(d, 157.0))),
    ("eu151_no_ddi_500ms", d -> _coarse_snapshots(_set_stir_duration(_set_cdd(d, 0.0), 157.0))),
    ("eu151_no_stir_500ms", d -> _coarse_snapshots(_set_stir_duration(_drop_stir(d), 157.0))),
    (
        "eu151_baseline_500ms",
        d -> _coarse_snapshots(_set_stir_duration(_drop_stir(_set_cdd(d, 0.0)), 157.0)),
    ),
    ("eu151_no_chirp_500ms", d -> _coarse_snapshots(_set_stir_duration(_drop_chirp(d), 157.0))),
]

const BATCH_2 = [
    ("p_30", d -> _coarse_snapshots(_set_stir_duration(_set_p(d, 30.0), 157.0))),
    ("p_100", d -> _coarse_snapshots(_set_stir_duration(_set_p(d, 100.0), 157.0))),
    ("p_300", d -> _coarse_snapshots(_set_stir_duration(_set_p(d, 300.0), 157.0))),
    ("p_1000", d -> _coarse_snapshots(_set_stir_duration(_set_p(d, 1000.0), 157.0))),
    ("p_3000", d -> _coarse_snapshots(_set_stir_duration(_set_p(d, 3000.0), 157.0))),
    ("p_10000", d -> _coarse_snapshots(_set_stir_duration(_set_p(d, 10000.0), 157.0))),
]

const BATCH_3 = [
    ("c1_FM_strong", d -> _coarse_snapshots(_set_stir_duration(_set_c1(d, -200.0), 157.0))),  # ~ -0.05 c0
    ("c1_FM_weak", d -> _coarse_snapshots(_set_stir_duration(_set_c1(d, -20.0), 157.0))),
    ("c1_AFM_strong", d -> _coarse_snapshots(_set_stir_duration(_set_c1(d, 200.0), 157.0))),
    ("c1_AFM_weak", d -> _coarse_snapshots(_set_stir_duration(_set_c1(d, 20.0), 157.0))),
    ("cdd_half", d -> _coarse_snapshots(_set_stir_duration(_set_cdd(d, 85.4), 157.0))),  # 170.7/2
    ("cdd_2x", d -> _coarse_snapshots(_set_stir_duration(_set_cdd(d, 341.4), 157.0))),
]

const BATCH_4 = [
    ("duration_1500ms", d -> _coarse_snapshots(_set_stir_duration(d, 471.0))),  # 1.5 s
    ("duration_2000ms", d -> _coarse_snapshots(_set_stir_duration(d, 628.0))),  # 2.0 s (Klaus full)
    # grid_48cube: ONLY high-res run; runs solo in batch 4 to avoid OOM.
    (
        "grid_48cube",
        d -> _coarse_snapshots(
            _set_stir_duration(_set_grid(d, [48, 48, 24], [20.0, 20.0, 10.0]), 62.83)
        ),
    ),
    ("epsilon_1e6", d -> _coarse_snapshots(_set_stir_duration(_set_epsilon(d, 1.0e-6), 62.83))),
    ("theta_25deg", d -> _coarse_snapshots(_set_stir_duration(_set_theta(d, 0.436), 157.0))),  # 25°
    ("theta_45deg", d -> _coarse_snapshots(_set_stir_duration(_set_theta(d, 0.785), 157.0))),  # 45°
]

const ALL_BATCHES = [BATCH_1, BATCH_2, BATCH_3, BATCH_4]

# ---------------------------------------------------------------------------

function _deepcopy_dict(d)
    YAML.load(YAML.write(d))
end

function main()
    template = YAML.load_file(TEMPLATE_PATH)
    isdir(OUT_ROOT) || mkpath(OUT_ROOT)

    n_total = 0
    for (i, batch) in enumerate(ALL_BATCHES)
        for (name, override_fn) in batch
            d = _deepcopy_dict(template)
            d = override_fn(d)
            outdir = joinpath(OUT_ROOT, name)
            isdir(outdir) || mkpath(outdir)
            outfile = joinpath(outdir, "config.yaml")
            open(outfile, "w") do io
                YAML.write(io, d)
            end
            println("  batch $i: $name → $outfile")
            n_total += 1
        end
    end
    println("Generated $n_total configs.")
end

main()

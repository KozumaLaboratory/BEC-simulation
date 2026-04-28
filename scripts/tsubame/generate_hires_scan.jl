# Generate high-resolution Dy164 / Eu151 scan configs for TSUBAME deployment.
#
# Default: 48×48×24 grid, ε=1e-6, full Klaus 4-step protocol with longer
# steady stir than the local 12h batch.
#
#   Dy164: F=8 D=17, p=28428 (Klaus paper bias B_z=0.819 G + 35° tilt)
#   Eu151: F=6 D=13, p=26700 (same protocol on Eu spinor)
#
# Each config descends from runs/klaus_eu151_v2_full as the baseline; only
# named knobs change. Outputs to runs/tsubame_scan/<name>/config.yaml.

using YAML

const TEMPLATE_PATH = "runs/klaus_eu151_v2_full/config.yaml"
const OUT_ROOT = "runs/tsubame_scan"

function _deepcopy_dict(d)
    YAML.load(YAML.write(d))
end

function _set_grid(d, n, box)
    d["pipeline"][1]["ground_state"]["grid"]["n"] = n
    d["pipeline"][1]["ground_state"]["grid"]["box"] = box
    d
end

function _set_eps(d, eps)
    for step in d["pipeline"][2:end]
        if haskey(step, "dynamics") && haskey(step["dynamics"], "epsilon")
            step["dynamics"]["epsilon"] = eps
        end
    end
    d
end

function _set_atom_dy(d)
    d["pipeline"][1]["ground_state"]["atom"] = "Dy164"
    d["pipeline"][1]["ground_state"]["zeeman"]["p"] = 28428.0
    d
end

function _set_stir(d, T)
    d["pipeline"][end]["dynamics"]["duration"] = T
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

# -------------------------------------------------------------------------
# Dy164 scan: Klaus reproduction at thesis-grade resolution
# -------------------------------------------------------------------------
const DY_SCAN = [
    # 48³ + 500ms stir + ε=1e-6 (Klaus paper-equivalent quality)
    ("dy164_klaus_500ms", d -> _set_stir(_set_eps(_set_grid(_set_atom_dy(d), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    # 48³ + 1000ms stir (full Klaus paper duration)
    ("dy164_klaus_1000ms", d -> _set_stir(_set_eps(_set_grid(_set_atom_dy(d), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 314.0)),
    # 64³ convergence check (just 200ms)
    ("dy164_klaus_64cube_200ms", d -> _set_stir(_set_eps(_set_grid(_set_atom_dy(d), [64, 64, 32], [20.0, 20.0, 10.0]), 1.0e-6), 62.83)),
]

# -------------------------------------------------------------------------
# Eu151 scan: spinor extension at thesis-grade resolution
# -------------------------------------------------------------------------
const EU_SCAN = [
    # 48³ baseline mirrors the Dy run
    ("eu151_full_500ms_48cube", d -> _set_stir(_set_eps(_set_grid(d, [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    # 48³ longer duration
    ("eu151_full_1000ms_48cube", d -> _set_stir(_set_eps(_set_grid(d, [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 314.0)),
    # 48³ no_ddi (Berry-only, c_dd=0) — mechanism comparison
    ("eu151_no_ddi_500ms_48cube", d -> _set_stir(_set_eps(_set_grid(_set_cdd(d, 0.0), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    # 48³ p-sweep at thesis resolution (3 points spanning the regime)
    ("eu151_p_300_48cube",   d -> _set_stir(_set_eps(_set_grid(_set_p(d, 300.0), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    ("eu151_p_3000_48cube",  d -> _set_stir(_set_eps(_set_grid(_set_p(d, 3000.0), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    # 48³ c1 sweep — FM and AFM, strong c1
    ("eu151_c1_FM_48cube",   d -> _set_stir(_set_eps(_set_grid(_set_c1(d, -200.0), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    ("eu151_c1_AFM_48cube",  d -> _set_stir(_set_eps(_set_grid(_set_c1(d, 200.0), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 157.0)),
    # 64³ convergence check
    ("eu151_full_64cube_200ms", d -> _set_stir(_set_eps(_set_grid(d, [64, 64, 32], [20.0, 20.0, 10.0]), 1.0e-6), 62.83)),
]

const ALL_SCANS = [("Dy164", DY_SCAN), ("Eu151", EU_SCAN)]

function main()
    template = YAML.load_file(TEMPLATE_PATH)
    isdir(OUT_ROOT) || mkpath(OUT_ROOT)

    n_total = 0
    for (atom_label, scan) in ALL_SCANS
        println("--- $atom_label scan ($(length(scan)) configs) ---")
        for (name, override_fn) in scan
            d = _deepcopy_dict(template)
            d = override_fn(d)
            outdir = joinpath(OUT_ROOT, name)
            isdir(outdir) || mkpath(outdir)
            outfile = joinpath(outdir, "config.yaml")
            open(outfile, "w") do io
                YAML.write(io, d)
            end
            grid_n = d["pipeline"][1]["ground_state"]["grid"]["n"]
            stir_T = d["pipeline"][end]["dynamics"]["duration"]
            println("  $name  grid=$grid_n  stir_T=$stir_T")
            n_total += 1
        end
    end
    println("\nGenerated $n_total configs under $OUT_ROOT/")
end

main()

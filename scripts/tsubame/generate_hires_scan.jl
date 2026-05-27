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

# Set the stir angular frequency (phi_omega) consistently across the chirp
# (phase 3) ramp end and the steady-stir (phase 4) plateau. The chirp ramps
# from 0 → ω; the steady-stir holds at ω.
function _set_phi_omega(d, omega)
    chirp = d["pipeline"][3]["dynamics"]["B_hat"]["phi_chirp"]
    chirp["to"] = omega
    d["pipeline"][end]["dynamics"]["B_hat"]["phi_omega"] = omega
    d
end

# -------------------------------------------------------------------------
# phi_omega scan — find the optimal stir frequency for Eu151 spinor
# extension of Klaus 2022. Klaus paper uses 226 Hz (= 4.524 dimless at
# ω_ref = 2π·50 Hz); we don't yet know whether that's the optimum for the
# F=6 spinor regime. All other knobs (p=26700, θ_const=35°, c1≈0) fixed.
#
# Scan in log-spaced points so the high-frequency tail is sampled cheaply.
# -------------------------------------------------------------------------
const PHI_OMEGA_POINTS = [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]

# Eu151 phi_omega scan at thesis resolution (48³, 1000 ms stir, ε=1e-6)
const EU_SCAN = [
    (
        "eu151_phi$(replace(string(ω), "." => "_"))_1000ms_48cube",
        d -> _set_phi_omega(
            _set_stir(_set_eps(_set_grid(d, [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 314.0),
            ω,
        ),
    ) for ω in PHI_OMEGA_POINTS
]

# Dy164 reference at the Klaus-paper phi_omega only — for direct
# comparison with the Eu scan.
const DY_SCAN = [
    (
    "dy164_klaus_1000ms",
    d -> _set_stir(
        _set_eps(_set_grid(_set_atom_dy(d), [48, 48, 24], [20.0, 20.0, 10.0]), 1.0e-6), 314.0
    ),
),
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

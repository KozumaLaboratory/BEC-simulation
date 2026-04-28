# Local PC phi_omega scan — Eu151, 24³ × 500ms × ε=1e-6.
# Sized for ~50 min/run × 3-parallel × 3 batches = ~2.5h total wall clock.
# Output: runs/phi_omega_scan/<name>/config.yaml.

using YAML

const TEMPLATE_PATH = "runs/klaus_eu151_v2_full/config.yaml"
const OUT_ROOT = "runs/phi_omega_scan"
const PHI_OMEGA_POINTS = [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]

_deepcopy_dict(d) = YAML.load(YAML.write(d))

function _set_eps(d, eps)
    for step in d["pipeline"][2:end]
        haskey(step, "dynamics") &&
            haskey(step["dynamics"], "epsilon") &&
            (step["dynamics"]["epsilon"] = eps)
    end
    d
end

function _set_stir(d, T_dim)
    d["pipeline"][end]["dynamics"]["duration"] = T_dim
    d
end

function _set_phi_omega(d, omega)
    d["pipeline"][3]["dynamics"]["B_hat"]["phi_chirp"]["to"] = omega
    d["pipeline"][end]["dynamics"]["B_hat"]["phi_omega"] = omega
    d
end

function main()
    template = YAML.load_file(TEMPLATE_PATH)
    isdir(OUT_ROOT) || mkpath(OUT_ROOT)
    for ω in PHI_OMEGA_POINTS
        d = _deepcopy_dict(template)
        d = _set_eps(d, 1.0e-6)
        d = _set_stir(d, 157.0)            # 500 ms
        d = _set_phi_omega(d, ω)
        # Grid stays at the template's 24×24×12 — ε=1e-6 is the only
        # numerical change from the original v2_full configs.
        name = "eu151_phi$(replace(string(ω), "." => "_"))_500ms"
        outdir = joinpath(OUT_ROOT, name)
        isdir(outdir) || mkpath(outdir)
        open(joinpath(outdir, "config.yaml"), "w") do io
            YAML.write(io, d)
        end
        println("  $name  (phi_omega = $ω)")
    end
    println("Generated $(length(PHI_OMEGA_POINTS)) configs under $OUT_ROOT/")
end

main()

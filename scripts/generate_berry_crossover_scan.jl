# Berry crossover scan — find where Berry connection actually drives
# m-population transfer in Eu151. Today's audit showed Klaus regime
# (p=26700) is fully adiabatic; the real spinor extension story is in
# the low-p (~mG B field) regime where p·F·dt < 1 and Berry coupling
# |Â| ≈ 4.5 dominates over the Larmor gap.
#
# Protocol: proven Klaus 4-step (tilt ramp → chirp → steady stir),
# 24×24×12, 500 ms stir, ε=1e-6 (everywhere, after the audit).
#
# Scan: p ∈ {10, 30, 100, 300, 1000, 3000} — six logarithmic points
# spanning the deeply Berry-driven (p < |Â|) through the adiabatic
# crossover. Combined with the existing phi_omega scan (fixed p=26700)
# this gives the full 2D phase diagram for the thesis figure.
#
# Output: runs/berry_crossover_scan/<name>/config.yaml.

using YAML

const TEMPLATE_PATH = "runs/klaus_eu151_v2_full/config.yaml"
const OUT_ROOT = "runs/berry_crossover_scan"
const P_POINTS = [10.0, 30.0, 100.0, 300.0, 1000.0, 3000.0]

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

function _set_p(d, p)
    d["pipeline"][1]["ground_state"]["zeeman"]["p"] = p
    d
end

function main()
    template = YAML.load_file(TEMPLATE_PATH)
    isdir(OUT_ROOT) || mkpath(OUT_ROOT)
    for p in P_POINTS
        d = _deepcopy_dict(template)
        d = _set_eps(d, 1.0e-6)
        d = _set_stir(d, 157.0)            # 500 ms
        d = _set_p(d, p)
        # Phi_omega kept at Klaus 4.524 — vary p only, since the audit
        # showed phi is secondary at high p; expect to be more sensitive
        # at low p where Berry rate matches the spin gap.
        name = "eu151_p$(replace(string(p), "." => "_"))_500ms"
        outdir = joinpath(OUT_ROOT, name)
        isdir(outdir) || mkpath(outdir)
        open(joinpath(outdir, "config.yaml"), "w") do io
            YAML.write(io, d)
        end
        b_g = 1.0 / 32600.0    # Eu151 dimless → Gauss
        println("  $name  (p=$p, B≈$(round(p * b_g * 1000; digits=2)) mG)")
    end
    println("Generated $(length(P_POINTS)) configs under $OUT_ROOT/")
end

main()

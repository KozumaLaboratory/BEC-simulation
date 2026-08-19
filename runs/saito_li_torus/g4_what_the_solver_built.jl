# What the SOLVER builds — not what the YAML says, and not what the run log prints.
#
# The run log's "Derived: c_total=… ε_dd=…" line recomputes c_total from the
# registry a_s unconditionally (parsing_blocks.jl:_resolve_derived_params!),
# so for any config that SUPPLIES c_total the printed value is not the one used.
# The smoke run printed c_total=1406.2 / ε_dd=0.5402 while `_parse_gs_interactions`
# honoured c_total=584.37 / ε_dd=1.3. Read the InteractionParams, not the banner.

using SpinorBEC
using Printf

paths = isempty(ARGS) ? ["runs/saito_li_torus/config.yaml"] : ARGS

for path in paths
    cfg = SpinorBEC.load_config(path)
    raw = getfield(cfg, :raw_data)
    println("="^72)
    println(path)
    println("="^72)
    for (i, step) in enumerate(raw["pipeline"])
        key = first(keys(step))
        p = step[key]
        atom = SpinorBEC.ATOM_REGISTRY[Symbol(get(p, "atom", "Eu151"))]
        SpinorBEC._resolve_derived_params!(p, atom; verbose=false)
        inter = get(p, "interactions", Dict())
        ddi = get(p, "ddi", Dict())

        ip = SpinorBEC._parse_gs_interactions(inter, atom)
        F = atom.F
        c0 = get(ip.c, 0, 0.0)
        c1 = get(ip.c, 1, 0.0)
        c_dd = ddi isa Dict ? Float64(get(ddi, "c_dd", NaN)) : NaN
        c_lhy = ip.c_lhy

        N = Int(get(inter, "N_atoms", 0))
        omega_ref = Float64(get(inter, "omega_ref", 1.0))
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
        c_total_eff = c0 + F^2 * c1
        eps_eff = c_total_eff > 0 ? c_dd * F^2 / (3 * c_total_eff) : NaN
        a_s_eff = c_total_eff * a_ho / (4pi * N)

        @printf("\n[step %d] %s   (what the Hamiltonian actually gets)\n", i, key)
        @printf("  c0            = %.4f\n", c0)
        @printf("  c1            = %.4f   (c1_ratio = %.4g)\n", c1, c0 == 0 ? NaN : c1 / c0)
        @printf("  c_total = c0 + F^2 c1 = %.4f\n", c_total_eff)
        @printf("  c_dd          = %.4f\n", c_dd)
        @printf("  c_lhy         = %.4f\n", c_lhy)
        @printf("  higher-rank c_k present: %s\n",
            join(sort([k for k in keys(ip.c) if k >= 2]), ", ") |> s -> isempty(s) ? "none" : s)
        println()
        @printf("  => eps_dd     = %.4f   (target 1.3000)\n", eps_eff)
        @printf("  => a_s        = %.2f a_0\n", a_s_eff / 5.29177210903e-11)
        c_lhy_consistent = SpinorBEC.scalar_lhy_coefficient(a_s_eff / a_ho, N; eps_dd=eps_eff)
        @printf("  => c_lhy consistent with (a_s, eps_dd) = %.3f  -> ratio %.4f\n",
            c_lhy_consistent, c_lhy / c_lhy_consistent)
    end
end

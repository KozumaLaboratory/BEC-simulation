# What the YAML ACTUALLY resolves to, for issue #336.
#
# The config's comments assert c_total=583 / c_dd=152 / eps_dd=1.3. Comments are
# not the resolver. `use:` layers a mixin and then the step's own keys, and the
# layering is SHALLOW (`templates_block.jl:_apply_step_mixins`) — a step-level
# `interactions:` REPLACES the mixin's wholesale rather than merging into it.
#
# Usage: julia --project=. runs/saito_li_torus/g2_resolved_coefficients.jl [config.yaml ...]

using SpinorBEC
using Printf

const A0 = 5.29177210903e-11

paths = isempty(ARGS) ? ["runs/saito_li_torus/config.yaml"] : ARGS

for path in paths
    println("="^72)
    println(path)
    println("="^72)
    cfg = SpinorBEC.load_config(path)
    raw = cfg isa Dict ? cfg : getfield(cfg, :raw_data)
    steps = raw["pipeline"]
    for (i, step) in enumerate(steps)
        key = first(keys(step))
        p = step[key]
        atom_pre = SpinorBEC.ATOM_REGISTRY[Symbol(get(p, "atom", "Eu151"))]
        SpinorBEC._resolve_derived_params!(p, atom_pre; verbose=false)
        inter = get(p, "interactions", Dict())
        ddi = get(p, "ddi", Dict())
        lhy = get(p, "lhy", Dict())
        grid = get(p, "grid", Dict())
        pot = get(p, "potential", Dict())

        atom_name = get(p, "atom", "?")
        atom = SpinorBEC.ATOM_REGISTRY[Symbol(atom_name)]
        N = Int(get(inter, "N_atoms", 0))
        omega_ref = Float64(get(inter, "omega_ref", 1.0))
        a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
        F = atom.F

        # Absent c_total is NOT a default — make_workspace derives it from the
        # registry a_s. Say which of the two happened; that distinction is the
        # whole bug here.
        c_total_given = haskey(inter, "c_total")
        c_total = c_total_given ? Float64(inter["c_total"]) :
                  SpinorBEC.compute_c_total(atom; N_atoms=N, omega_ref=omega_ref)
        c_dd = ddi isa Dict ? Float64(get(ddi, "c_dd", NaN)) : NaN
        c_lhy = Float64(get(inter, "c_lhy", get(lhy, "c_lhy", NaN)))

        @printf("\n[step %d] %s\n", i, key)
        @printf("  atom=%s F=%d  N=%d  omega_ref=%.2f  a_ho=%.5f um\n",
            atom_name, F, N, omega_ref, a_ho / 1e-6)
        @printf("  grid n=%s box=%s\n", get(grid, "n", "?"), get(grid, "box", "?"))
        @printf("  potential=%s\n", pot)
        @printf("  initial_state=%s  params=%s\n",
            get(p, "initial_state", "polar"), get(p, "init_state_params", Dict()))
        @printf("  method=%s  dt=%s  n_steps=%s  tol=%s\n",
            get(p, "method", "itp"), get(p, "dt", "?"),
            get(p, "n_steps", "?"), get(p, "tol", "?"))
        println()
        @printf("  RESOLVED c_total = %-10.3f  (%s)\n", c_total,
            c_total_given ? "from YAML" : "ABSENT in YAML -> derived from registry a_s")
        @printf("  RESOLVED c_dd    = %-10.3f\n", c_dd)
        @printf("  RESOLVED c_lhy   = %-10.3f  (lhy kind=%s)\n",
            c_lhy, get(lhy, "kind", "none"))
        if isfinite(c_total) && isfinite(c_dd) && c_total > 0
            eps_eff = c_dd * F^2 / (3 * c_total)
            a_s_eff = c_total * a_ho / (4pi * N)
            @printf("  => eps_dd (c_dd F^2 / 3 c_total) = %.4f\n", eps_eff)
            @printf("  => implied a_s                   = %.2f a_0\n", a_s_eff / A0)
            c_lhy_consistent = SpinorBEC.scalar_lhy_coefficient(
                a_s_eff / a_ho, N; eps_dd=eps_eff)
            @printf("  => c_lhy CONSISTENT with those   = %.3f\n", c_lhy_consistent)
            if isfinite(c_lhy) && c_lhy_consistent > 0
                @printf("  => resolved / consistent         = %.3f x\n",
                    c_lhy / c_lhy_consistent)
            end
            # box adequacy vs the paper's F=6 cloud edge (Fig 2a, digitised)
            if haskey(grid, "box")
                box = Float64(first(grid["box"]))
                half_um = box / 2 * a_ho / 1e-6
                @printf("  => box half-width = %.2f um   (Fig 2a cloud edge 1.41 um) -> %s\n",
                    half_um, half_um > 1.41 ? "OK" : "CLIPS THE DROPLET")
            end
        end
    end
    println()
end

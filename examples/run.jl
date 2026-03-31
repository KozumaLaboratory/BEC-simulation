using SpinorBEC
using JLD2

function output_path(yaml_path)
    dir = dirname(yaml_path)
    base = splitext(basename(yaml_path))[1]
    outdir = joinpath(dir, "output")
    mkpath(outdir)
    joinpath(outdir, base * ".jld2")
end

function _ramp_endpoints(v::ConstantValue)
    (v.value, v.value)
end
function _ramp_endpoints(v::LinearRamp)
    (v.from, v.to)
end

function run_and_save(yaml_path)
    println("Loading: $yaml_path")
    config = load_config(yaml_path)
    println("Running: $(config.name)")

    result = run_config(config)

    if haskey(result, :ground_state_energy)
        println("  Ground state: E=$(result.ground_state_energy), converged=$(result.ground_state_converged)")
    end

    if haskey(result, :phase_results)
        for (i, (name, sim)) in enumerate(zip(result.phase_names, result.phase_results))
            println("  Phase $i ($name): t=$(sim.times[1])→$(sim.times[end]), E=$(sim.energies[end])")
        end
    end

    out = output_path(yaml_path)
    sys = config.system
    ip = sys.interactions
    save_data = Dict{String,Any}(
        "config_name" => config.name,
        "grid_n_points" => collect(sys.grid_n_points),
        "grid_box_size" => collect(sys.grid_box_size),
        "atom_name" => string(sys.atom_name),
        "F" => resolve_atom(sys.atom_name).F,
        "c0" => ip.c0,
        "c1" => ip.c1,
        "c_lhy" => ip.c_lhy,
        "c_extra" => ip.c_extra,
        "ddi_enabled" => sys.ddi.enabled,
        "c_dd" => something(sys.ddi.c_dd, 0.0),
    )
    gs = config.ground_state
    save_data["gs_zeeman_p"] = gs.zeeman.p
    save_data["gs_zeeman_q"] = gs.zeeman.q
    if gs.potential.type == :harmonic
        save_data["trap_omega"] = Float64.(gs.potential.params["omega"])
    end
    if haskey(result, :ground_state_energy)
        save_data["ground_state_energy"] = result.ground_state_energy
        save_data["ground_state_converged"] = result.ground_state_converged
    end
    if haskey(result, :phase_results)
        save_data["phase_names"] = result.phase_names
        spec = config.spec
        for (i, sim) in enumerate(result.phase_results)
            save_data["phase_$(i)_times"] = sim.times
            save_data["phase_$(i)_energies"] = sim.energies
            save_data["phase_$(i)_norms"] = sim.norms
            save_data["phase_$(i)_magnetizations"] = sim.magnetizations
            save_data["phase_$(i)_psi_snapshots"] = sim.psi_snapshots
            if i <= length(spec.sequence)
                ph = spec.sequence[i]
                p0, p1 = _ramp_endpoints(ph.zeeman_p)
                q0, q1 = _ramp_endpoints(ph.zeeman_q)
                save_data["phase_$(i)_zeeman"] = [p0, p1, q0, q1]
                save_data["phase_$(i)_duration"] = ph.duration
            end
        end
    end
    if haskey(result, :psi)
        save_data["psi"] = result.psi
    end
    jldopen(out, "w") do f
        for (k, v) in save_data
            f[k] = v
        end
    end
    println("  Saved: $out")
    println()
end

path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "configs")

if isdir(path)
    yamls = sort(filter(f -> endswith(f, ".yaml"), readdir(path; join=true)))
    isempty(yamls) && error("No .yaml files found in $path")
    println("Found $(length(yamls)) YAML files in $path\n")
    for yaml in yamls
        run_and_save(yaml)
    end
else
    run_and_save(path)
end

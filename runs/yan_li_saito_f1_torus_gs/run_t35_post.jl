using JLD2, Statistics, Printf, LinearAlgebra

results_dir = "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs"
jld2_files = String[]
for (root, dirs, files) in walkdir(results_dir)
    for f in files
        endswith(f, ".jld2") && push!(jld2_files, joinpath(root, f))
    end
end
println("Found JLD2 files: ", length(jld2_files))
for f in jld2_files; println("  ", f); end
@assert length(jld2_files) >= 1 "No JLD2 produced — ITP failed silently"

# Use the most recently modified jld2 as the GS result
latest = jld2_files[argmax([mtime(f) for f in jld2_files])]
println("Using: ", latest)
jldopen(latest, "r") do f
    println("  keys: ", keys(f))
    for k in keys(f)
        v = f[k]
        if v isa AbstractArray
            println("    ", k, " :: ", typeof(v), " size=", size(v))
        else
            println("    ", k, " :: ", typeof(v), " value=", v)
        end
    end
end

# Extract psi (rotating-basis psi_tilde)
psi = nothing
psi_key_used = ""
jldopen(latest, "r") do f
    for candidate in ("psi", "psi_tilde", "ws.psi_tilde", "final_psi", "state", "psi_final")
        if haskey(f, candidate)
            global psi = f[candidate]
            global psi_key_used = candidate
            break
        end
    end
    # Check nested groups
    if psi === nothing
        for k in keys(f)
            v = f[k]
            if v isa AbstractArray && ndims(v) >= 3
                global psi = v
                global psi_key_used = k
                break
            end
        end
    end
end

if psi === nothing
    println("ERROR: Could not find psi key in JLD2. All keys listed above.")
    println("F1_VERDICT: INCONCLUSIVE (psi_key_unknown)")
    exit(1)
end
println("psi key used: ", psi_key_used, " shape=", size(psi))

# Density |psi|^2 summed over spinor components, then maximum
rho = dropdims(sum(abs2.(psi); dims=ndims(psi)); dims=ndims(psi))
n_max_dimless = maximum(rho)
@printf("n_max (dimless, psi_tilde normalization): %.6e\n", n_max_dimless)

# Convert to D0 units (paper normalization)
# Paper: D0 = 1/(a_s^3 * N^2)
# Paper uses a_s = 21 a0 for Eu151 F=1 effective (ε_dd = a_dd/a_s = 1.2)
# Our units: psi_tilde normalized s.t. integral |psi|^2 d^3x_dimless = 1
# physical density n_phys(r) = N * |psi_tilde(r)|^2 / a_ho^3
# n_phys_max = N * n_max_dimless / a_ho^3
# n_in_D0 = n_phys_max / D0 = n_phys_max * a_s^3 * N^2
#          = N * n_max_dimless / a_ho^3 * a_s^3 * N^2
#          = N^3 * n_max_dimless * (a_s/a_ho)^3

N_atoms = 15000.0
a_s_bohr = 21.0   # in Bohr radii (paper: a_s = 21 a0 for ε_dd=1.2)
a_bohr_si = 5.29177e-11  # m
a_s_si = a_s_bohr * a_bohr_si
omega_ref = 314.159  # rad/s
m_eu = 151.0 * 1.66054e-27  # kg (Eu-151)
hbar = 1.05457e-34  # J·s
a_ho = sqrt(hbar / (m_eu * omega_ref))

@printf("a_s_si = %.4e m = %.2f a0\n", a_s_si, a_s_bohr)
@printf("a_ho = %.4e m\n", a_ho)
@printf("a_s/a_ho = %.4f\n", a_s_si / a_ho)

# n_in_D0 = N^3 * n_max_dimless * (a_s/a_ho)^3
a_s_over_a_ho = a_s_si / a_ho
n_in_D0 = N_atoms^3 * n_max_dimless * a_s_over_a_ho^3
@printf("n_max in D0 units: %.1f\n", n_in_D0)
@printf("Paper target: ~13000 D0 (Fig 1c)\n")
deviation_pct = 100.0 * abs(n_in_D0 - 13000.0) / 13000.0
@printf("Deviation: %.1f%%\n", deviation_pct)

f1_verdict = if deviation_pct <= 10.0
    "PASS"
elseif deviation_pct <= 50.0
    "INCONCLUSIVE"
else
    "FALSIFIED"
end
println("F1_VERDICT: ", f1_verdict)
println("f1_n_max_in_D0: ", n_in_D0)
println("f1_deviation_pct: ", deviation_pct)

# F4: |E_LHY| / |E_ddi| ratio — extract energy components from JLD2 if available
E_kin = NaN; E_s = NaN; E_ddi = NaN; E_lhy = NaN
jldopen(latest, "r") do f
    haskey(f, "E_kin") && (global E_kin = f["E_kin"])
    haskey(f, "E_s") && (global E_s = f["E_s"])
    haskey(f, "E_ddi") && (global E_ddi = f["E_ddi"])
    haskey(f, "E_lhy") && (global E_lhy = f["E_lhy"])
    haskey(f, "E_LHY") && (global E_lhy = f["E_LHY"])
    haskey(f, "energy") && println("  has 'energy' key: ", f["energy"])
    # try nested energy keys
    for k in keys(f)
        v = f[k]
        if v isa Number
            println("  scalar key: ", k, " = ", v)
        end
    end
end
@printf("Energy decomposition: E_kin=%.6e E_s=%.6e E_ddi=%.6e E_lhy=%.6e\n", E_kin, E_s, E_ddi, E_lhy)
ratio = abs(E_lhy) / abs(E_ddi)
if isnan(ratio)
    println("F4_VERDICT: INCONCLUSIVE (energy_components_not_saved)")
else
    @printf("|E_LHY|/|E_ddi| = %.3f (target: [2, 20])\n", ratio)
    f4_verdict = if 2.0 <= ratio <= 20.0
        "PASS"
    elseif 0.5 <= ratio < 2.0 || 20.0 < ratio <= 50.0
        "INCONCLUSIVE"
    else
        "FALSIFIED"
    end
    println("F4_VERDICT: ", f4_verdict)
end

# Check norm and spin polarization
norm_val = sum(abs2.(psi)) * prod(size(psi)[1:end-1]) / prod(size(psi)[1:end-1])
# Proper integral: norm = sum(|psi|^2) * dV
# dV in dimless units = (box/n_pts)^3 = product of grid spacings
# We don't have grid info here, but norm should be 1 from normalize_rotating!
# Estimate: sum(|psi|^2) should equal 1/dV
norm_raw = sum(abs2.(psi))
println("norm_raw (sum |psi|^2): ", norm_raw, " (correct only if dV=1)")

println("=== POST_PROCESS_OK ===")

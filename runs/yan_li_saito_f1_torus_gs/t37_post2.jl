using JLD2, Statistics, Printf, LinearAlgebra
using SpinorBEC

results_dir = "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs"
jld2_files = String[]
for (root, _dirs, files) in walkdir(results_dir)
    for f in files
        endswith(f, ".jld2") && push!(jld2_files, joinpath(root, f))
    end
end
println("Found JLD2 files: ", length(jld2_files))
for f in jld2_files; println("  ", f); end
@assert length(jld2_files) >= 1 "No JLD2 produced"

latest = jld2_files[argmax([mtime(f) for f in jld2_files])]
println("Using: ", latest)

psi = nothing; energy = NaN; converged = nothing
box_size = nothing; n_points = nothing
jldopen(latest, "r") do f
    ks = keys(f)
    println("  JLD2 keys: ", ks)
    for k in ks
        println("  key=", k, " type=", typeof(f[k]))
    end
    energy_raw = f["energy"]
    println("  energy_raw type=", typeof(energy_raw), " val=", energy_raw)
    psi_raw = f["psi"]
    println("  psi_raw type=", typeof(psi_raw), " size=", size(psi_raw))
    psi = psi_raw
    energy = energy_raw
    haskey(f, "converged") && (converged = f["converged"])
    haskey(f, "grid_box_size") && (box_size = f["grid_box_size"])
    haskey(f, "grid_n_points") && (n_points = f["grid_n_points"])
end

println("psi type after read: ", typeof(psi))
println("psi size: ", size(psi))
println("psi is array: ", psi isa AbstractArray)

if !(psi isa AbstractArray)
    println("ERROR: psi is not an array — type reconstruction failed, trying alternate read")
    # Try reading without SpinorBEC custom types
    psi = nothing
    jldopen(latest, "r"; typemap=Dict("SpinorBEC.XXX" => Array)) do f
        psi = read(f, "psi")
    end
end

if psi === nothing
    println("FATAL: psi unreadable")
    exit(1)
end

@printf("psi shape: %s eltype: %s\n", string(size(psi)), string(eltype(psi)))
@printf("energy (mu): %.6e\n", energy)
println("converged: ", converged)
println("box_size: ", box_size, " n_points: ", n_points)

# Norm check
DV_dimless = if box_size !== nothing && n_points !== nothing
    prod(Float64.(box_size) ./ Float64.(n_points))
else
    (28.0/64.0)^3
end
norm_sq = sum(abs2.(psi)) * DV_dimless
@printf("norm_sq = %.6f\n", norm_sq)
norm_drift = abs(norm_sq - 1.0)
@printf("norm_drift = %.3e\n", norm_drift)

# Peak density
rho = dropdims(sum(abs2.(psi); dims=ndims(psi)); dims=ndims(psi))
n_max_dimless = maximum(rho)
@printf("n_max (dimless): %.6e\n", n_max_dimless)

# Convert to D_0 units
N = 15000.0
a_0_si = 5.29177e-11
a_s_si = 21.0 * a_0_si
omega_ref = 314.159
m_eu = 151.0 * 1.66054e-27
hbar = 1.05457e-34
a_ho = sqrt(hbar / (m_eu * omega_ref))
D_0 = 1.0 / (a_s_si^3 * N^2)
@printf("a_ho = %.3e m\n", a_ho)
@printf("a_s_si = %.3e m\n", a_s_si)
@printf("D_0  = %.3e m^-3\n", D_0)

n_phys_max = N * n_max_dimless / a_ho^3
n_in_D0 = n_phys_max / D_0
@printf("n_phys_max = %.3e m^-3\n", n_phys_max)
@printf("n_max in D_0 = %.1f\n", n_in_D0)
@printf("Paper target: ~13000 D_0\n")
f1_deviation_pct = 100.0 * abs(n_in_D0 - 13000.0) / 13000.0
@printf("F1 deviation = %.2f%%\n", f1_deviation_pct)

f1_pass = f1_deviation_pct <= 10.0
f1_inconclusive = !f1_pass && f1_deviation_pct <= 50.0
f1_falsified = f1_deviation_pct > 50.0
f1_verdict = f1_pass ? "PASS" : (f1_inconclusive ? "INCONCLUSIVE" : "FALSIFIED")
println("F1_VERDICT: ", f1_verdict)
println("F1_PASS: ", f1_pass)
println("F1_INCONCLUSIVE: ", f1_inconclusive)
println("F1_FALSIFIED: ", f1_falsified)

D_size = size(psi)[end]
m_populations = zeros(Float64, D_size)
for m_idx in 1:D_size
    m_populations[m_idx] = sum(abs2.(view(psi, :, :, :, m_idx))) * DV_dimless
end
println("m-populations: ", m_populations)
println("Sum: ", sum(m_populations))
pol_dominant = m_populations[1] > 0.95
println("m=+F dominant: ", pol_dominant)

println("F4_VERDICT: INCONCLUSIVE")
println("F4_REASON: rotating_basis_no_energy_decomposition")
println("=== POST_PROCESS_OK ===")

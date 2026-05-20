using JLD2

latest = "/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/point_001.jld2"
data = load(latest)

# Print all scalar values
for k in sort(collect(keys(data)))
    v = data[k]
    if !(v isa Array)
        println("$k = $v")
    end
end

# Particular interest: units
println("\n=== units ===")
println("units/a_ho_m = ", get(data, "units/a_ho_m", "missing"))
println("units/N_atoms = ", get(data, "units/N_atoms", "missing"))
println("units/omega_ref_hz = ", get(data, "units/omega_ref_hz", "missing"))
println("units/omega_ref_rad_s = ", get(data, "units/omega_ref_rad_s", "missing"))
println("units/atom = ", get(data, "units/atom", "missing"))
println("units/system = ", get(data, "units/system", "missing"))

# Psi normalization check with known a_ho
psi = data["psi"]
box_size = data["grid_box_size"]
n_points = data["grid_n_points"]
DV_dimless = prod(Float64.(box_size) ./ Float64.(n_points))
norm = sum(abs2.(psi)) * DV_dimless
println("\nnorm check: ", norm)

# n_max in dimless units
rho = dropdims(sum(abs2.(psi); dims=ndims(psi)); dims=ndims(psi))
n_max_dimless = maximum(rho)
println("n_max_dimless = ", n_max_dimless)

# Get actual a_ho from JLD2
a_ho_m = get(data, "units/a_ho_m", nothing)
N_atoms = get(data, "units/N_atoms", nothing)
println("\nFrom JLD2: a_ho_m = ", a_ho_m, " N_atoms = ", N_atoms)

if a_ho_m !== nothing && N_atoms !== nothing
    # ψ dimless is normalized: integral(|ψ|² dx³_dimless) = 1
    # Physical density: n_phys = N * |ψ|² / a_ho³
    n_phys_max = N_atoms * n_max_dimless / a_ho_m^3
    println("n_phys_max (m^-3) = ", n_phys_max)
    
    # Paper D_0 = 1/(a_s^3 * N^2)
    # Per paper: a_s = 21 a_0, N = 15000
    a_s_si = 21.0 * 5.29177e-11
    D_0_paper = 1.0 / (a_s_si^3 * N_atoms^2)
    println("D_0_paper (m^-3) = ", D_0_paper)
    println("n_max / D_0 = ", n_phys_max / D_0_paper)
end

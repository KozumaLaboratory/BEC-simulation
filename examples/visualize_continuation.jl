# Visualize Continuation Results
using Plots
using DelimitedFiles

# Data from continuation (manually extracted)
c_dd_values = [0.0, 1000.0, 2000.0, 4000.0, 6000.0, 7647.0]

energies = [10.0498, -431.183, -862.676, -713.873, -763.342, -860.659]

# Energy components: [kinetic, trap, density, spin, ddi, zeeman]
energy_components = [
    [0.1322, 7.312, 7.437, -2.677, 0.0, -2.154],      # c_dd=0
    [16.15, 6.41, 474.3, -170.7, -755.4, -1.917],      # c_dd=1000
    [19.3, 8.481, 353.7, -127.3, -1115.0, -1.63],      # c_dd=2000
    [30.16, 5.651, 288.1, -103.5, -934.3, 0.0309],     # c_dd=4000
    [31.66, 2.993, 303.7, -108.6, -993.2, 0.08027],    # c_dd=6000
    [31.92, 3.911, 297.3, -106.6, -1087.0, -0.04128],  # c_dd=7647
]

# Top 5 populations at each step (m, fraction)
populations = [
    # c_dd=0
    Dict(6=>0.6679, 5=>0.2719, 4=>0.0531, 3=>0.0065),
    # c_dd=1000
    Dict(6=>0.5921, 5=>0.153, 4=>0.1032, 3=>0.0653, 2=>0.0374),
    # c_dd=2000
    Dict(6=>0.4804, 5=>0.1613, 4=>0.0991, 3=>0.0605, 2=>0.0426),
    # c_dd=4000
    Dict(1=>0.0905, 0=>0.0897, 2=>0.0855, -6=>0.0845, -1=>0.0839),
    # c_dd=6000
    Dict(-6=>0.1131, 6=>0.0866, -1=>0.0865, 0=>0.0834, -2=>0.0819),
    # c_dd=7647
    Dict(-6=>0.1066, 6=>0.0902, 1=>0.0811, 0=>0.0798, 5=>0.0794),
]

# Create plots
gr()
default(fontfamily="sans-serif", linewidth=2, framestyle=:box,
        label=nothing, grid=true)

# Plot 1: Total Energy
p1 = plot(c_dd_values, energies,
    marker=:circle, markersize=8,
    xlabel="c_dd", ylabel="Total Energy",
    title="Energy vs DDI Strength",
    legend=false, color=:red, linewidth=3)
hline!([0], linestyle=:dash, color=:black, alpha=0.5)

# Plot 2: Energy Components
p2 = plot(xlabel="c_dd", ylabel="Energy Component",
    title="Energy Decomposition")
plot!(c_dd_values, [ec[1] for ec in energy_components],
    label="Kinetic", marker=:circle, color=1)
plot!(c_dd_values, [ec[2] for ec in energy_components],
    label="Trap", marker=:square, color=2)
plot!(c_dd_values, [ec[3] for ec in energy_components],
    label="Density", marker=:diamond, color=3)
plot!(c_dd_values, [ec[4] for ec in energy_components],
    label="Spin", marker=:utriangle, color=4)
plot!(c_dd_values, [ec[5] for ec in energy_components],
    label="DDI", marker=:star, color=5, linewidth=3)
hline!([0], linestyle=:dash, color=:black, alpha=0.3)

# Plot 3: Population evolution for selected m values
p3 = plot(xlabel="c_dd", ylabel="Population",
    title="Population Distribution Evolution",
    ylims=(0, 0.7))

# Track specific m values across steps
m_track = [6, 5, 0, -1, -6]
colors = [:red, :orange, :green, :blue, :purple]

for (i, m) in enumerate(m_track)
    pops = [get(populations[j], m, 0.0) for j in 1:6]
    plot!(c_dd_values, pops, label="m=$m",
        marker=:circle, color=colors[i], linewidth=2)
end

# Plot 4: Major vs Minor components
p4 = plot(xlabel="c_dd", ylabel="Population Entropy",
    title="Population Mixing")

# Calculate entropy-like measure: -Σ p log(p)
entropies = Float64[]
for pops_dict in populations
    # Get all 13 components (assume rest are ~0)
    all_pops = [get(pops_dict, m, 1e-10) for m in -6:6]
    entropy = -sum(p * log(max(p, 1e-10)) for p in all_pops if p > 1e-10)
    push!(entropies, entropy)
end

plot!(c_dd_values, entropies, marker=:circle, markersize=8,
    color=:purple, linewidth=3, legend=false)

# Combine all plots
final_plot = plot(p1, p2, p3, p4, layout=(2,2), size=(1200, 900),
    plot_title="Eu151 DDI Continuation Analysis",
    margin=5Plots.mm)

# Save
savefig(final_plot, "output/continuation_analysis.png")
println("Saved: output/continuation_analysis.png")

# Also create a focused plot on stability
p5 = plot(xlabel="c_dd", ylabel="Dominant Population",
    title="Most Populated State",
    legend=:topright)

max_pops = [maximum(values(pops_dict)) for pops_dict in populations]
plot!(c_dd_values, max_pops, marker=:circle, markersize=10,
    color=:red, linewidth=3, label="Max P(m)")
hline!([1/13], linestyle=:dash, color=:black,
    label="Uniform (1/13)", linewidth=2)

savefig(p5, "output/continuation_populations.png")
println("Saved: output/continuation_populations.png")

println("\nKey observations:")
println("  1. Energy turns negative at c_dd=1000")
println("  2. DDI energy dominates at high c_dd")
println("  3. Population transitions: polarized → mixed")
println("  4. Entropy increases with c_dd (more mixing)")
println("  5. Final state: moderately mixed, not uniform")

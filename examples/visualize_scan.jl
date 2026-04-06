using JLD2
using PlotlyJS

# 1. Load the data
filepath = "examples/output/eu151_phase_scan.jld2"
results = jldopen(filepath, "r") do f
    f["phase_scan_results"]
end

# 2. Extract data for plotting
params = [r.param for r in results]
energies = [r.energy for r in results]
spin_orders = [r.phase_info.spin_order for r in results]
nematic_orders = [r.phase_info.nematic_order for r in results]

# 3. Define traces for subplots
trace_energy = scatter(x=params, y=energies, name="Energy", xaxis="x1", yaxis="y1")
trace_spin_order = scatter(x=params, y=spin_orders, name="Spin Order", xaxis="x2", yaxis="y2")
trace_nematic_order = scatter(x=params, y=nematic_orders, name="Nematic Order", xaxis="x2", yaxis="y2")

# 4. Define the layout with a 2-row grid
layout = Layout(
    title_text="Eu151 Quasi-2D Phase Scan vs. c1_ratio",
    grid=attr(rows=2, columns=1, pattern="independent"),
    height=600,
    xaxis1=attr(title_text=""),
    yaxis1=attr(title_text="Energy"),
    xaxis2=attr(title_text="c1_ratio (param)"),
    yaxis2=attr(title_text="Order Parameter")
)

# 5. Combine traces and layout into a single plot
p = plot([trace_energy, trace_spin_order, trace_nematic_order], layout)

# 6. Save the plot to an HTML file
output_path = "eu151_phase_scan.html"
savefig(p, output_path)

println("Successfully generated plot: $(output_path)")

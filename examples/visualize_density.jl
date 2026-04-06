using JLD2
using PlotlyJS

# 1. Load data
filepath = "output/eu151_ground_state.jld2"
d = jldopen(filepath, "r")
psi = d["psi"]
box_size = d["grid_box_size"]
F = d["F"]
close(d)

# 2. Prepare grid and component info
(nx, ny, nc) = size(psi)
x_axis = range(-box_size[1]/2, stop=box_size[1]/2, length=nx)
y_axis = range(-box_size[2]/2, stop=box_size[2]/2, length=ny)
m_values = Int(F):-1:Int(-F)

# Find global max for consistent color scale
max_density = maximum(abs2, psi)

# 3. Define a trace for each component
traces = GenericTrace[]
for i in 1:nc
    density = abs2.(psi[:,:,i])
    trace = heatmap(
        x=x_axis,
        y=y_axis,
        z=density,
        colorscale="Viridis",
        zmin=0,
        zmax=max_density,
        name="m = $(m_values[i])",
        colorbar_title="Density",
        showscale=false # Disable individual color bars
    )
    push!(traces, trace)
end

# 4. Define the layout with a 3x5 grid
layout = Layout(
    title="Density Distribution per m-component (c1_ratio=0.001)",
    grid=attr(rows=3, columns=5, pattern="independent"),
    height=700,
    width=1400,
    # Add annotations for subplot titles
    annotations=[
        attr(
            text="m = $(m_values[i])",
            showarrow=false,
            xref="paper", yref="paper",
            x= ( ( (i-1) % 5 ) + 0.5 ) / 5, # Center x in subplot
            y= 1 - ( ( div(i-1, 5) ) + 0.25) / 3 # Top y in subplot
        )
        for i in 1:nc
    ]
)

# 5. Create the plot and save
p = plot(traces, layout)
output_path = "eu151_density_distribution.html"
savefig(p, output_path)

println("Successfully generated density distribution plot: $(output_path)")

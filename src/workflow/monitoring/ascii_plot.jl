# ASCII plotting for terminal visualization

"""
    plot_ascii(data::Vector{Float64}; width::Int=60, height::Int=8)

Create an ASCII plot of time series data.
"""
function plot_ascii(data::Vector{Float64}; width::Int=60, height::Int=8, title::String="")
    isempty(data) && return ""

    # Downsample if needed
    n = length(data)
    if n > width
        indices = round.(Int, range(1, n; length=width))
        data_plot = data[indices]
    else
        data_plot = data
        width = n
    end

    # Normalize to plot height
    min_val = minimum(data_plot)
    max_val = maximum(data_plot)
    range_val = max_val - min_val

    if range_val < 1e-10
        # Constant data
        lines = String[]
        push!(lines, title)
        push!(lines, "│" * " "^width)
        mid_line = "│" * "─"^width
        push!(lines, mid_line)
        push!(lines, "│" * " "^width)
        return join(lines, "\n")
    end

    # Normalize to [0, height-1]
    normalized = [(v - min_val) / range_val * (height - 1) for v in data_plot]

    # Build plot
    lines = String[]
    !isempty(title) && push!(lines, title)

    # Y-axis labels
    y_labels = range(max_val, min_val; length=height)

    for row in (height - 1):-1:0
        line_chars = Char[]

        # Y-axis label
        label = @sprintf("%.2f", y_labels[height - row])

        # Plot points
        for col in 1:width
            val = normalized[col]
            if abs(val - row) < 0.5
                push!(line_chars, '●')
            elseif row == 0 || row == height - 1
                push!(line_chars, '─')
            else
                # Check if line passes through
                if col > 1
                    prev_val = normalized[col - 1]
                    if (prev_val <= row <= val) || (val <= row <= prev_val)
                        push!(line_chars, '│')
                    else
                        push!(line_chars, ' ')
                    end
                else
                    push!(line_chars, ' ')
                end
            end
        end

        push!(lines, label * " ┤" * String(line_chars))
    end

    # X-axis
    push!(lines, " "^6 * "└" * "─"^width)
    push!(lines, " "^7 * "0" * " "^(width÷2-1) * @sprintf("%d", n) * " "^(width÷2))

    join(lines, "\n")
end

"""
    plot_sparkline(data::Vector{Float64}; width::Int=40)

Create a compact sparkline plot (single line).
"""
function plot_sparkline(data::Vector{Float64}; width::Int=40)
    isempty(data) && return ""

    # Downsample
    n = length(data)
    if n > width
        indices = round.(Int, range(1, n; length=width))
        data_plot = data[indices]
    else
        data_plot = data
    end

    # Normalize
    min_val = minimum(data_plot)
    max_val = maximum(data_plot)
    range_val = max_val - min_val

    if range_val < 1e-10
        return "─"^length(data_plot)
    end

    # Spark characters: ▁▂▃▄▅▆▇█
    sparks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']

    chars = Char[]
    for v in data_plot
        norm = (v - min_val) / range_val
        idx = clamp(round(Int, norm * (length(sparks) - 1)) + 1, 1, length(sparks))
        push!(chars, sparks[idx])
    end

    String(chars)
end

"""
    plot_histogram(data::Vector{Float64}; bins::Int=20, width::Int=40, height::Int=8)

Create an ASCII histogram.
"""
function plot_histogram(data::Vector{Float64}; bins::Int=20, width::Int=40, height::Int=8)
    isempty(data) && return ""

    # Compute histogram
    min_val = minimum(data)
    max_val = maximum(data)
    range_val = max_val - min_val

    if range_val < 1e-10
        return "All values equal: $(min_val)"
    end

    bin_width = range_val / bins
    counts = zeros(Int, bins)

    for v in data
        bin = clamp(floor(Int, (v - min_val) / bin_width) + 1, 1, bins)
        counts[bin] += 1
    end

    # Scale to height
    max_count = maximum(counts)
    scaled = [round(Int, c / max_count * height) for c in counts]

    # Build plot
    lines = String[]
    for row in height:-1:1
        chars = Char[]
        for bin in 1:bins
            if scaled[bin] >= row
                push!(chars, '▓')
            else
                push!(chars, ' ')
            end
        end
        count_at_height = sum(scaled .>= row)
        push!(lines, "│" * String(chars))
    end

    push!(lines, "└" * "─"^bins)

    join(lines, "\n")
end

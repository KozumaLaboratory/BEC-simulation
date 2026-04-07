# Mz-scan dashboard generator
#
# Reads all JLD2 files from output/eu151_mz_scan/ and builds a single HTML
# with per-Mz-point views: component populations, spin texture, density.
#
# Usage:
#   julia --project=. examples/mz_scan_dashboard.jl [output_dir]

using SpinorBEC
using JLD2
using JSON
using Printf

function build_mz_scan_dashboard(
    scan_dir::String = "output/eu151_mz_scan";
    F::Int = 6,
    box::Float64 = 24.0,
    output_html::String = "output/eu151_mz_scan_dashboard.html",
)
    files = sort(filter(f -> endswith(f, ".jld2"), readdir(scan_dir; join=true)))
    isempty(files) && error("No JLD2 files found in $scan_dir")

    D = 2F + 1
    points = NamedTuple[]

    for file in files
        d = load(file)
        psi = d["psi"]
        mz_target = d["mz_target"]
        mz_actual = d["mz_actual"]
        energy = d["energy"]
        phase = get(d, "phase", "unknown")

        n_pts = size(psi)[1:3]
        nx = n_pts[1]

        # Component populations (integrated)
        pops = [sum(abs2, psi[:, :, :, c]) for c in 1:D]

        # Total density column-integrated (sum over z)
        n_total = dropdims(sum(sum(abs2, psi; dims=4); dims=3); dims=(3, 4))

        # Spin expectation values at z midplane
        z_mid = nx ÷ 2 + 1
        psi_slice = psi[:, :, z_mid, :]

        fx = zeros(Float64, nx, nx)
        fy = zeros(Float64, nx, nx)
        fz = zeros(Float64, nx, nx)

        for i in 1:nx, j in 1:nx
            for c in 1:D
                m = F - (c - 1)
                fz[i, j] += m * abs2(psi_slice[i, j, c])
            end
            for c in 2:D
                m = F - (c - 1)
                fp_coef = sqrt(F * (F + 1) - m * (m + 1))
                z = conj(psi_slice[i, j, c - 1]) * psi_slice[i, j, c] * fp_coef
                fx[i, j] += real(z)
                fy[i, j] += imag(z)
            end
        end

        # Component slices (xy plane at z_mid)
        comp_densities_2d = [abs2.(psi_slice[:, :, c]) for c in 1:D]

        # Column density of each component (sum along z)
        comp_columns = [dropdims(sum(abs2, psi[:, :, :, c]; dims=3); dims=3) for c in 1:D]

        push!(points, (
            mz_target = mz_target,
            mz_actual = mz_actual,
            energy = energy,
            phase = phase,
            populations = pops,
            n_column = n_total,
            fx = fx,
            fy = fy,
            fz = fz,
            comp_slices = comp_densities_2d,
            comp_columns = comp_columns,
            nx = nx,
            box = box,
        ))
    end

    # Build JSON payload
    data = Dict(
        "F" => F,
        "D" => D,
        "box" => box,
        "m_values" => [F - (c - 1) for c in 1:D],
        "points" => [Dict(
            "mz_target" => p.mz_target,
            "mz_actual" => p.mz_actual,
            "energy" => p.energy,
            "phase" => p.phase,
            "populations" => p.populations,
            "n_column" => p.n_column,
            "fx" => p.fx,
            "fy" => p.fy,
            "fz" => p.fz,
            "comp_slices" => p.comp_slices,
            "comp_columns" => p.comp_columns,
            "nx" => p.nx,
        ) for p in points],
    )

    json_str = JSON.json(data)
    html = build_html(json_str)

    mkpath(dirname(output_html))
    write(output_html, html)
    println("Dashboard written to: $output_html")
    println("  Points: $(length(points))")
    println("  Open in browser to view.")
end

function build_html(json_data::String)
    return """
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Eu151 Mz-Scan Dashboard</title>
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<style>
  body { font-family: -apple-system, sans-serif; margin: 8px; background: #0f0f0f; color: #e0e0e0; }
  h1 { color: #fff; font-size: 16px; margin: 4px 0; }
  .controls { margin: 6px 0; padding: 6px 10px; background: #1a1a1a; border-radius: 4px; display: flex; align-items: center; gap: 15px; }
  .controls input[type=range] { width: 600px; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; margin-bottom: 6px; }
  .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px; margin-bottom: 6px; }
  .plot { background: #1a1a1a; border-radius: 4px; }
  .plot > div { padding: 0 !important; }
  .info { background: #1a1a1a; padding: 6px 10px; border-radius: 4px; margin-bottom: 6px; font-size: 13px; }
  .info span { display: inline-block; margin-right: 24px; }
  .info b { color: #7cc; }
</style>
</head>
<body>
<h1>Eu151 Mz-constrained scan — c_dd=7647 (ε_dd=1.09), LHY, p=0</h1>

<div class="controls">
  <label>Mz point: <span id="mz-label"></span></label>
  <input type="range" id="slider" min="0" max="0" step="1" value="0">
</div>

<div class="info">
  <span><b>Mz target:</b> <span id="info-mz-t"></span></span>
  <span><b>Mz actual:</b> <span id="info-mz-a"></span></span>
  <span><b>Energy:</b> <span id="info-E"></span></span>
  <span><b>Phase label:</b> <span id="info-ph"></span></span>
</div>

<div class="grid">
  <div class="plot" id="energy-curve"></div>
  <div class="plot" id="populations"></div>
</div>

<div class="grid-3">
  <div class="plot" id="n-column"></div>
  <div class="plot" id="fz-slice"></div>
  <div class="plot" id="fxy-quiver"></div>
</div>

<div class="plot" id="comp-columns"></div>

<script>
const DATA = $json_data;

const layoutBase = {
  paper_bgcolor: '#1a1a1a',
  plot_bgcolor: '#1a1a1a',
  font: { color: '#e0e0e0', size: 10 },
  margin: { t: 20, r: 4, b: 20, l: 32, pad: 0 },
  height: 260,
  title: { font: { size: 11 }, y: 0.98, yanchor: 'top', pad: { t: 2, b: 0 } },
};
const config = { displayModeBar: false, responsive: true };

// Energy curve (static)
const mz_targets = DATA.points.map(p => p.mz_target);
const energies = DATA.points.map(p => p.energy);
Plotly.newPlot('energy-curve', [{
  x: mz_targets, y: energies,
  mode: 'lines+markers', line: { color: '#7cc' }, marker: { size: 8 }
}], {
  ...layoutBase,
  title: 'Energy vs Mz',
  xaxis: { title: 'Mz/N' },
  yaxis: { title: 'E' },
}, config);

function update(idx) {
  const p = DATA.points[idx];
  document.getElementById('mz-label').innerText = 'Mz = ' + p.mz_target.toFixed(2);
  document.getElementById('info-mz-t').innerText = p.mz_target.toFixed(3);
  document.getElementById('info-mz-a').innerText = p.mz_actual.toFixed(3);
  document.getElementById('info-E').innerText = p.energy.toFixed(2);
  document.getElementById('info-ph').innerText = p.phase;

  // Populations bar chart
  Plotly.react('populations', [{
    x: DATA.m_values, y: p.populations,
    type: 'bar', marker: { color: '#e77' }
  }], {
    ...layoutBase,
    title: 'Populations',
    xaxis: { title: 'm', tickmode: 'array', tickvals: DATA.m_values },
    yaxis: { title: 'N_m/N', range: [0, 1.05] },
  }, config);

  const sqLayout = { ...layoutBase, height: 320, xaxis: { title: 'x', scaleanchor: 'y' }, yaxis: { title: 'y' } };

  // Column density n(x,y)
  Plotly.react('n-column', [{
    z: p.n_column, type: 'heatmap', colorscale: 'Viridis', showscale: false,
  }], { ...sqLayout, title: 'n(x,y)' }, config);

  // Fz slice
  const fz_max = Math.max(...p.fz.flat().map(Math.abs));
  Plotly.react('fz-slice', [{
    z: p.fz, type: 'heatmap', colorscale: 'RdBu', showscale: false,
    zmin: -fz_max, zmax: fz_max,
  }], { ...sqLayout, title: '⟨Fz⟩ @ z=0' }, config);

  // Fx,Fy transverse magnitude
  const fxy_mag = p.fx.map((row, i) => row.map((v, j) => Math.sqrt(v*v + p.fy[i][j]*p.fy[i][j])));
  Plotly.react('fxy-quiver', [{
    z: fxy_mag, type: 'heatmap', colorscale: 'Plasma', showscale: false,
  }], { ...sqLayout, title: '|⟨F⊥⟩|' }, config);

  // All component columns grid
  const nx = p.nx;
  const traces = [];
  const nc = DATA.D;
  const cols = Math.ceil(Math.sqrt(nc));
  const subplots = [];

  for (let c = 0; c < nc; c++) {
    const m = DATA.m_values[c];
    traces.push({
      z: p.comp_columns[c],
      type: 'heatmap',
      colorscale: 'Viridis',
      showscale: false,
      xaxis: 'x' + (c + 1),
      yaxis: 'y' + (c + 1),
      name: 'm=' + m,
    });
  }

  const layout = { ...layoutBase, height: 500, title: 'Component column densities', grid: { rows: Math.ceil(nc/cols), columns: cols, pattern: 'independent' }, annotations: [] };
  for (let c = 0; c < nc; c++) {
    const row = Math.floor(c / cols);
    const col = c % cols;
    layout.annotations.push({
      text: 'm=' + DATA.m_values[c],
      xref: 'x' + (c + 1) + ' domain', yref: 'y' + (c + 1) + ' domain',
      x: 0.5, y: 1.1, showarrow: false, font: { color: '#fff', size: 11 },
    });
  }
  Plotly.react('comp-columns', traces, layout, config);
}

const slider = document.getElementById('slider');
slider.max = DATA.points.length - 1;
slider.oninput = () => update(parseInt(slider.value));
update(0);
</script>
</body>
</html>
"""
end

if abspath(PROGRAM_FILE) == @__FILE__
    scan_dir = length(ARGS) >= 1 ? ARGS[1] : "output/eu151_mz_scan"
    build_mz_scan_dashboard(scan_dir)
end

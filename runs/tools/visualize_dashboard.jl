using JLD2, JSON, FFTW

# ============================================================
# General BEC dashboard — single-page visualization
# Dependencies: JLD2 + JSON + FFTW (no SpinorBEC)
# Usage: julia --project=. examples/demo/visualize_dashboard.jl path/to/file.jld2
# Output: single self-contained HTML with time slider
#   - 3D isosurface (Plotly) or 2D heatmap for density
#   - Per-component density grid
#   - Canvas for time-series graphs (population, energy, conservation)
# ============================================================

function load_data(path)
    d = load(path)
    n_pts = Tuple(d["grid_n_points"])
    L = Tuple(Float64.(d["grid_box_size"]))
    ndim = length(n_pts)
    dx = [L[i] / n_pts[i] for i in 1:ndim]
    axes = [range(-L[i]/2, L[i]/2, length=n_pts[i]) |> collect for i in 1:ndim]
    kvecs = [let dk = 2π / L[i]
        [n <= n_pts[i]÷2 ? n * dk : (n - n_pts[i]) * dk for n in 0:n_pts[i]-1]
    end for i in 1:ndim]
    n_phases = length(d["phase_names"])

    all_times = Float64[]
    all_psi = []
    all_zeeman_q = Float64[]

    for i in 1:n_phases
        times = d["phase_$(i)_times"]
        snaps = d["phase_$(i)_psi_snapshots"]
        zee = d["phase_$(i)_zeeman"]
        dur = d["phase_$(i)_duration"]
        t0 = isempty(all_times) ? 0.0 : all_times[end]
        for (j, t) in enumerate(times)
            push!(all_times, t)
            push!(all_psi, snaps[j])
            frac = dur > 0 ? clamp((t - t0) / dur, 0, 1) : 1.0
            push!(all_zeeman_q, zee[3] + (zee[4] - zee[3]) * frac)
        end
    end

    F = d["F"]
    nc = 2F + 1
    omega = get(d, "trap_omega", ones(ndim))
    c0 = d["c0"]
    c1 = d["c1"]
    gs_energy = get(d, "ground_state_energy", NaN)

    (; axes, kvecs, dx, L, n_pts, ndim, all_times, all_psi, all_zeeman_q,
     nc, F, c0, c1, omega, gs_energy,
     name=d["config_name"], atom=d["atom_name"])
end

# Compute scalar observables for a frame (no spatial data)
function compute_scalars(d, idx)
    psi = d.all_psi[idx]
    q = d.all_zeeman_q[idx]
    F = d.F; nc = d.nc; ndim = d.ndim
    n_pts = d.n_pts; dx = d.dx; dV = prod(dx)
    m_values = [F + 1 - c for c in 1:nc]

    pops = [sum(abs2, selectdim(psi, ndim+1, c)) * dV for c in 1:nc]
    norm = sum(pops)
    pop_frac = pops ./ max(norm, 1e-30)
    Mz = sum(m_values[c] * pop_frac[c] for c in 1:nc)

    # Kinetic energy
    k2 = if ndim == 3
        [d.kvecs[1][i]^2 + d.kvecs[2][j]^2 + d.kvecs[3][l]^2
         for i in 1:n_pts[1], j in 1:n_pts[2], l in 1:n_pts[3]]
    elseif ndim == 2
        [d.kvecs[1][i]^2 + d.kvecs[2][j]^2 for i in 1:n_pts[1], j in 1:n_pts[2]]
    else
        [d.kvecs[1][i]^2 for i in 1:n_pts[1]]
    end
    N_grid = prod(n_pts)
    E_kin = sum(c -> real(sum(k2 ./ 2 .* abs2.(fft(selectdim(psi, ndim+1, c))))) * dV / N_grid, 1:nc)

    trap_r2 = if ndim == 3
        [d.omega[1]^2*d.axes[1][i]^2 + d.omega[2]^2*d.axes[2][j]^2 + d.omega[3]^2*d.axes[3][l]^2
         for i in 1:n_pts[1], j in 1:n_pts[2], l in 1:n_pts[3]]
    elseif ndim == 2
        [d.omega[1]^2*d.axes[1][i]^2 + d.omega[2]^2*d.axes[2][j]^2 for i in 1:n_pts[1], j in 1:n_pts[2]]
    else
        [d.omega[1]^2*d.axes[1][i]^2 for i in 1:n_pts[1]]
    end
    n_total = dropdims(sum(abs2, psi; dims=ndim+1); dims=ndim+1)
    E_trap = sum(trap_r2 ./ 2 .* n_total) * dV
    E_density = d.c0 / 2 * sum(n_total .^ 2) * dV

    Fz_field = sum(m_values[c] .* abs2.(selectdim(psi, ndim+1, c)) for c in 1:nc)
    Fp_field = sum(c -> sqrt(F*(F+1) - m_values[c+1]*(m_values[c+1]+1)) .*
                   conj.(selectdim(psi, ndim+1, c)) .* selectdim(psi, ndim+1, c+1), 1:nc-1)
    F2_field = Fz_field .^ 2 .+ abs2.(Fp_field)
    E_spin = d.c1 / 2 * sum(F2_field) * dV
    E_zeeman = sum(q * m_values[c]^2 * pops[c] for c in 1:nc)

    Dict{String,Any}(
        "t" => d.all_times[idx],
        "pops" => collect(pop_frac),
        "norm" => norm, "Mz" => Mz,
        "E_kin" => E_kin, "E_trap" => E_trap,
        "E_density" => E_density, "E_spin" => E_spin,
        "E_zeeman" => E_zeeman,
        "E_total" => E_kin + E_trap + E_density + E_spin + E_zeeman,
    )
end

# Flatten 3D density array to column-major vector, rounded for compactness
function flatten_vals(arr; digits=4)
    round.(vec(arr); digits)
end

# Build x,y,z coordinate arrays (shared across all frames)
function build_coords(axes, n_pts)
    nx, ny, nz = n_pts
    x = Float64[]; y = Float64[]; z = Float64[]
    sizehint!(x, nx*ny*nz); sizehint!(y, nx*ny*nz); sizehint!(z, nx*ny*nz)
    for iz in 1:nz, iy in 1:ny, ix in 1:nx
        push!(x, round(axes[1][ix]; digits=3))
        push!(y, round(axes[2][iy]; digits=3))
        push!(z, round(axes[3][iz]; digits=3))
    end
    (; x, y, z)
end

# Compute spatial data for a single frame
function compute_3d_frame(d, idx)
    psi = d.all_psi[idx]
    nc = d.nc; ndim = d.ndim; n_pts = d.n_pts

    if ndim == 3
        n_total = dropdims(sum(abs2, psi; dims=4); dims=4)
        comps = [abs2.(psi[:,:,:,c]) for c in 1:nc]
        return Dict("total" => flatten_vals(n_total),
                     "comps" => [flatten_vals(c) for c in comps])
    elseif ndim == 2
        n_total = dropdims(sum(abs2, psi; dims=3); dims=3)
        comps_2d = [abs2.(psi[:,:,c]) for c in 1:nc]
        return Dict("total_2d" => flatten_vals(collect(n_total')),
                     "comps_2d" => [flatten_vals(collect(m')) for m in comps_2d],
                     "N" => [n_pts[1], n_pts[2]])
    end
    Dict()
end

function generate_html(d)
    nt = length(d.all_times)
    F = d.F; nc = d.nc; ndim = d.ndim; n_pts = d.n_pts

    println("  Computing $nt scalar frames...")
    scalars = [compute_scalars(d, i) for i in 1:nt]

    # Subsample for 3D spatial data (max ~12 frames for manageable HTML size)
    max_3d = 12
    step = max(1, (nt - 1) ÷ (max_3d - 1))
    spatial_indices = unique(vcat(collect(1:step:nt), nt))

    println("  Computing $(length(spatial_indices)) spatial frames...")
    spatial_list = [compute_3d_frame(d, i) for i in spatial_indices]

    data = Dict{String,Any}(
        "scalars" => scalars,
        "F" => F, "D" => nc, "ndim" => ndim,
        "spatial_indices" => spatial_indices .- 1,  # 0-indexed for JS
    )

    if ndim == 3
        data["coords"] = build_coords(d.axes, d.n_pts)
        data["spatial"] = spatial_list
    elseif ndim == 2
        data["axes"] = [round.(d.axes[1]; digits=3), round.(d.axes[2]; digits=3)]
        data["spatial"] = spatial_list
    end

    # Also store 1D profile data for all frames
    mid_y = n_pts[min(2, ndim)] ÷ 2 + 1
    mid_z = ndim >= 3 ? n_pts[3] ÷ 2 + 1 : 1
    profiles = Vector{Dict{String,Any}}()
    g_max_nx = 0.0
    for idx in 1:nt
        psi = d.all_psi[idx]
        comp_n_x = if ndim == 3
            [abs2.(psi[:, mid_y, mid_z, c]) for c in 1:nc]
        elseif ndim == 2
            [abs2.(psi[:, mid_y, c]) for c in 1:nc]
        else
            [abs2.(psi[:, c]) for c in 1:nc]
        end
        n_x = [sum(comp_n_x[c][i] for c in 1:nc) for i in 1:n_pts[1]]
        g_max_nx = max(g_max_nx, maximum(n_x))
        push!(profiles, Dict("n_x" => n_x, "comp_n_x" => [collect(v) for v in comp_n_x]))
    end
    data["profiles"] = profiles
    data["x_axis"] = d.axes[1]
    data["gmax_nx"] = g_max_nx

    data_json = JSON.json(data)

    n_cols = nc <= 3 ? nc : min(7, nc)

    sub_parts = ["$(d.atom) F=$F", "c₀=$(d.c0)", "c₁=$(d.c1)"]
    if ndim == 3
        push!(sub_parts, "$(n_pts[1])³")
    elseif ndim == 2
        push!(sub_parts, "$(n_pts[1])×$(n_pts[2])")
    end
    !isnan(d.gs_energy) && push!(sub_parts, "E_gs=$(round(d.gs_energy, digits=4))")
    sub_text = join(sub_parts, " | ")

    # HTML for 3D density: use Plotly divs
    density_html = if ndim == 3
        """<div class="section">
  <h2>Total Density (3D isosurface)</h2>
  <div id="plot-total-3d" style="height:450px;background:#12122a;border:1px solid #2a2a4a;border-radius:6px"></div>
</div>
<div class="section">
  <h2>Per-Component Density (3D)</h2>
  <div class="comp-grid-3d" id="comp-grid-3d"></div>
</div>"""
    else
        """<div class="section">
  <h2>Total Density</h2>
  <div id="plot-total-2d" style="height:400px;background:#12122a;border:1px solid #2a2a4a;border-radius:6px"></div>
</div>
<div class="section">
  <h2>Per-Component Density</h2>
  <div class="comp-grid-2d" id="comp-grid-2d"></div>
</div>"""
    end

    html = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$(d.name)</title>
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#0a0a1a;color:#e0e0e0;font-family:'Segoe UI',system-ui,sans-serif;padding:12px}
h1{text-align:center;font-size:1.3em;color:#88ccff;margin-bottom:2px}
.sub{text-align:center;font-size:.78em;color:#556;margin-bottom:12px}
.controls{text-align:center;margin-bottom:10px;display:flex;justify-content:center;align-items:center;gap:10px;flex-wrap:wrap;position:sticky;top:0;z-index:10;background:#0a0a1acc;backdrop-filter:blur(6px);padding:8px 0}
.controls button{background:#2a2a5a;color:#aac;border:1px solid #3a3a7a;border-radius:4px;padding:5px 12px;cursor:pointer;font-size:.82em}
.controls button:hover{background:#3a3a7a}
#slider{width:300px;accent-color:#4466aa}
#time-label{font-size:1.1em;color:#6cf;font-weight:bold;min-width:100px}
.stats{display:flex;gap:8px;flex-wrap:wrap;justify-content:center;margin-bottom:10px}
.stat{background:#1a1a3a;border:1px solid #2a2a5a;border-radius:5px;padding:6px 12px;text-align:center}
.stat .v{font-size:1.1em;color:#6cf;font-weight:bold}
.stat .l{font-size:.65em;color:#889;margin-top:1px}
.section{max-width:1200px;margin:0 auto 16px}
.section h2{font-size:.9em;color:#aac;margin-bottom:6px;border-left:3px solid #4466aa;padding-left:8px}
.pop-bar{display:flex;height:22px;border-radius:3px;overflow:hidden;margin:2px 0}
.pop-bar div{transition:width .3s}
.pop-legend{font-size:.68em;color:#889;margin-top:3px;display:flex;gap:6px;flex-wrap:wrap;justify-content:center}
.comp-grid-3d{display:grid;grid-template-columns:repeat($n_cols,1fr);gap:4px}
.comp-grid-3d>div{background:#0e0e20;border:1px solid #1a1a3a;border-radius:4px;min-height:260px}
.comp-grid-2d{display:grid;grid-template-columns:repeat($n_cols,1fr);gap:4px}
.comp-grid-2d>div{background:#0e0e20;border:1px solid #1a1a3a;border-radius:4px;min-height:250px}
.graph-panel{background:#12122a;border:1px solid #2a2a4a;border-radius:6px;padding:8px;margin-bottom:8px}
.graph-panel canvas{width:100%;height:220px}
.graph-panel .info{font-size:.68em;color:#556;text-align:center;margin-top:3px}
.row-2{display:grid;grid-template-columns:1fr 1fr;gap:8px}
</style>
</head>
<body>
<h1>$(d.name)</h1>
<div class="sub">$sub_text</div>

<div class="controls">
  <button id="btn-play" onclick="togglePlay()">▶ Play</button>
  <input id="slider" type="range" min="0" max="$(nt-1)" value="0" oninput="setFrame(+this.value)">
  <span id="time-label">t = 0.000</span>
  <button onclick="setFrame(0)">⏮</button>
  <button onclick="setFrame(DATA.scalars.length-1)">⏭</button>
</div>
<div class="stats" id="stats"></div>

<div class="section">
  <div class="pop-bar" id="pop-bar"></div>
  <div class="pop-legend" id="pop-legend"></div>
</div>

$density_html

<div class="section">
  <h2>1D Profiles n_m(x,0,0)</h2>
  <div class="graph-panel">
    <canvas id="c_profiles"></canvas>
    <div class="info">Solid = per-component | Dashed = total</div>
  </div>
</div>

<div class="section">
  <h2>Population &amp; Energy</h2>
  <div class="row-2">
    <div class="graph-panel"><canvas id="c_pops"></canvas></div>
    <div class="graph-panel"><canvas id="c_energy"></canvas></div>
  </div>
</div>

<div class="section">
  <h2>Conservation</h2>
  <div class="graph-panel">
    <canvas id="c_conservation"></canvas>
  </div>
</div>

<script>
const DATA = $data_json;
const D=DATA.D, F_val=DATA.F, NDIM=DATA.ndim;
const mLabels=[],mColors=[];
{
  const palette=['#e6194b','#f58231','#ffe119','#bfef45','#3cb44b','#42d4f4','#4363d8','#911eb4','#f032e6','#fabed4','#9A6324','#800000','#469990','#aaffc3','#dcbeff','#000075','#a9a9a9'];
  for(let c=0;c<D;c++){mLabels.push(F_val-c);mColors.push(palette[c%palette.length]);}
}
let currentIdx=0,playing=false,playTimer=null;
const plotlyLayout3d={
  paper_bgcolor:'#0e0e20',plot_bgcolor:'#0e0e20',
  font:{color:'#aac',size:10},
  margin:{l:0,r:0,t:30,b:0},
  scene:{
    xaxis:{title:'x',color:'#556',gridcolor:'#1a1a3a'},
    yaxis:{title:'y',color:'#556',gridcolor:'#1a1a3a'},
    zaxis:{title:'z',color:'#556',gridcolor:'#1a1a3a'},
    bgcolor:'#0e0e20',
    aspectmode:'data',
  }
};

// Find nearest spatial frame index
function nearestSpatial(idx){
  const si=DATA.spatial_indices;
  let best=0;
  for(let i=1;i<si.length;i++){if(Math.abs(si[i]-idx)<Math.abs(si[best]-idx))best=i;}
  return best;
}

// 3D isosurface rendering
function render3dTotal(spatialIdx){
  if(NDIM!==3)return;
  const sf=DATA.spatial[spatialIdx];
  const vals=sf.total;
  const mx=Math.max(...vals);
  const levels=[mx*0.05, mx*0.2, mx*0.5, mx*0.8];
  const trace={
    type:'isosurface',
    x:DATA.coords.x, y:DATA.coords.y, z:DATA.coords.z,
    value:vals,
    isomin:levels[0], isomax:levels[3],
    surface:{count:4},
    caps:{x:{show:false},y:{show:false},z:{show:false}},
    colorscale:'Inferno',
    opacity:0.6,
    showscale:true,
    colorbar:{title:'n',len:0.6},
  };
  const t=DATA.scalars[DATA.spatial_indices[spatialIdx]].t;
  const layout=Object.assign({},plotlyLayout3d,{title:{text:'Total density  t='+t.toFixed(3),font:{size:12,color:'#88ccff'}}});
  Plotly.react('plot-total-3d',[trace],layout,{responsive:true});
}

function render3dComponents(spatialIdx){
  if(NDIM!==3)return;
  const sf=DATA.spatial[spatialIdx];
  for(let c=0;c<D;c++){
    const divId='comp3d_'+c;
    const el=document.getElementById(divId);
    if(!el)continue;
    const vals=sf.comps[c];
    const mx=Math.max(...vals);
    if(mx<1e-15){Plotly.react(divId,[],Object.assign({},plotlyLayout3d,{title:{text:'m='+(mLabels[c]>=0?'+':'')+mLabels[c],font:{size:11,color:mColors[c]}}}),{responsive:true});continue;}
    const trace={
      type:'isosurface',
      x:DATA.coords.x, y:DATA.coords.y, z:DATA.coords.z,
      value:vals,
      isomin:mx*0.05, isomax:mx*0.9,
      surface:{count:3},
      caps:{x:{show:false},y:{show:false},z:{show:false}},
      colorscale:[[0,'#000'],[0.5,mColors[c]],[1,'#fff']],
      opacity:0.5,
      showscale:false,
    };
    const layout=Object.assign({},plotlyLayout3d,{title:{text:'m='+(mLabels[c]>=0?'+':'')+mLabels[c],font:{size:11,color:mColors[c]}}});
    Plotly.react(divId,[trace],layout,{responsive:true});
  }
}

// 2D heatmap rendering
function render2dTotal(spatialIdx){
  if(NDIM!==2)return;
  const sf=DATA.spatial[spatialIdx];
  const Nx=sf.N[0],Ny=sf.N[1];
  const z=[];for(let j=0;j<Ny;j++){const row=[];for(let i=0;i<Nx;i++)row.push(sf.total_2d[j*Nx+i]);z.push(row);}
  const trace={type:'heatmap',x:DATA.axes[0],y:DATA.axes[1],z:z,colorscale:'Inferno',colorbar:{title:'n'}};
  const t=DATA.scalars[DATA.spatial_indices[spatialIdx]].t;
  Plotly.react('plot-total-2d',[trace],{
    paper_bgcolor:'#12122a',plot_bgcolor:'#12122a',font:{color:'#aac',size:10},
    title:{text:'Total density  t='+t.toFixed(3),font:{size:12,color:'#88ccff'}},
    xaxis:{title:'x'},yaxis:{title:'y',scaleanchor:'x'},margin:{l:50,r:10,t:40,b:40},
  },{responsive:true});
}

function render2dComponents(spatialIdx){
  if(NDIM!==2)return;
  const sf=DATA.spatial[spatialIdx];
  const Nx=sf.N[0],Ny=sf.N[1];
  for(let c=0;c<D;c++){
    const divId='comp2d_'+c;
    const el=document.getElementById(divId);if(!el)continue;
    const flat=sf.comps_2d[c];
    const z=[];for(let j=0;j<Ny;j++){const row=[];for(let i=0;i<Nx;i++)row.push(flat[j*Nx+i]);z.push(row);}
    const trace={type:'heatmap',x:DATA.axes[0],y:DATA.axes[1],z:z,colorscale:'Inferno',showscale:false};
    Plotly.react(divId,[trace],{
      paper_bgcolor:'#0e0e20',plot_bgcolor:'#0e0e20',font:{color:'#aac',size:9},
      title:{text:'m='+(mLabels[c]>=0?'+':'')+mLabels[c],font:{size:11,color:mColors[c]}},
      xaxis:{title:''},yaxis:{title:'',scaleanchor:'x'},margin:{l:30,r:5,t:30,b:20},
    },{responsive:true});
  }
}

function initCompGrid(){
  if(NDIM===3){
    const g=document.getElementById('comp-grid-3d');if(!g)return;
    g.innerHTML='';
    for(let c=0;c<D;c++){
      const div=document.createElement('div');
      div.id='comp3d_'+c;
      g.appendChild(div);
    }
  }else if(NDIM===2){
    const g=document.getElementById('comp-grid-2d');if(!g)return;
    g.innerHTML='';
    for(let c=0;c<D;c++){
      const div=document.createElement('div');
      div.id='comp2d_'+c;
      div.style.minHeight='220px';
      g.appendChild(div);
    }
  }
}

// Canvas graph helpers
function drawGraph(canvasId,series,allFrames,currentIdx,opts){
  const canvas=document.getElementById(canvasId);if(!canvas)return;
  const rect=canvas.parentElement.getBoundingClientRect();
  const dpr=window.devicePixelRatio||1;
  const W=rect.width-16,H=220;
  canvas.style.width=W+'px';canvas.style.height=H+'px';
  canvas.width=W*dpr;canvas.height=H*dpr;
  const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);
  const p={l:60,r:12,t:20,b:30},pw=W-p.l-p.r,ph=H-p.t-p.b;
  ctx.fillStyle='#12122a';ctx.fillRect(0,0,W,H);
  const times=allFrames.map(f=>f.t);
  const tMin=times[0],tMax=times[times.length-1];
  let yMin=opts.yMin!=null?opts.yMin:Infinity,yMax=opts.yMax!=null?opts.yMax:-Infinity;
  if(yMin===Infinity||yMax===-Infinity){
    for(const s of series){const vals=allFrames.map(f=>s.key?f[s.key]:s.fn(f));
      yMin=Math.min(yMin,...vals);yMax=Math.max(yMax,...vals);}
    const pad=(yMax-yMin)*0.1||1;yMin-=pad;yMax+=pad;
  }
  ctx.strokeStyle='#1a1a3a';ctx.lineWidth=0.5;
  for(let i=0;i<=4;i++){const y=p.t+ph-(i/4)*ph;ctx.beginPath();ctx.moveTo(p.l,y);ctx.lineTo(p.l+pw,y);ctx.stroke();}
  ctx.strokeStyle='#333';ctx.lineWidth=1;ctx.beginPath();
  ctx.moveTo(p.l,p.t);ctx.lineTo(p.l,p.t+ph);ctx.lineTo(p.l+pw,p.t+ph);ctx.stroke();
  ctx.fillStyle='#778';ctx.font='9px sans-serif';ctx.textAlign='center';
  for(let i=0;i<=5;i++){const t=tMin+(tMax-tMin)*i/5;ctx.fillText(t.toFixed(2),p.l+(i/5)*pw,p.t+ph+14);}
  ctx.textAlign='right';ctx.textBaseline='middle';
  for(let i=0;i<=4;i++){const v=yMin+(yMax-yMin)*i/4;ctx.fillText(v.toPrecision(3),p.l-4,p.t+ph-(i/4)*ph);}
  if(opts.title){ctx.fillStyle='#aac';ctx.font='11px sans-serif';ctx.textAlign='left';ctx.fillText(opts.title,p.l+4,p.t+12);}
  for(const s of series){
    const vals=allFrames.map(f=>s.key?f[s.key]:s.fn(f));
    ctx.strokeStyle=s.color||'#fff';ctx.lineWidth=s.width||1.2;
    if(s.dash){ctx.setLineDash(s.dash);}else{ctx.setLineDash([]);}
    ctx.beginPath();
    for(let i=0;i<times.length;i++){
      const x=p.l+((times[i]-tMin)/(tMax-tMin))*pw;
      const y=p.t+ph-((vals[i]-yMin)/(yMax-yMin))*ph;
      i===0?ctx.moveTo(x,y):ctx.lineTo(x,y);
    }ctx.stroke();ctx.setLineDash([]);
  }
  const cx=p.l+((times[currentIdx]-tMin)/(tMax-tMin))*pw;
  ctx.strokeStyle='#ffffff55';ctx.lineWidth=1;ctx.setLineDash([3,3]);
  ctx.beginPath();ctx.moveTo(cx,p.t);ctx.lineTo(cx,p.t+ph);ctx.stroke();ctx.setLineDash([]);
  ctx.font='9px sans-serif';ctx.textAlign='left';
  let lx=p.l+pw-series.length*72;if(lx<p.l)lx=p.l;
  for(const s of series){ctx.fillStyle=s.color||'#fff';ctx.fillRect(lx,p.t+2,12,2);ctx.fillText(s.label||'',lx+15,p.t+6);lx+=72;}
}

function drawProfiles(frame){
  const canvas=document.getElementById('c_profiles');if(!canvas)return;
  const rect=canvas.parentElement.getBoundingClientRect();
  const dpr=window.devicePixelRatio||1;
  const W=rect.width-16,H=220;
  canvas.style.width=W+'px';canvas.style.height=H+'px';
  canvas.width=W*dpr;canvas.height=H*dpr;
  const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);
  const p={l:55,r:12,t:12,b:28},pw=W-p.l-p.r,ph=H-p.t-p.b;
  const x=DATA.x_axis,allMax=DATA.gmax_nx*1.1;
  const xMin=x[0],xMax=x[x.length-1];
  ctx.fillStyle='#12122a';ctx.fillRect(0,0,W,H);
  ctx.strokeStyle='#1a1a3a';ctx.lineWidth=.5;
  for(let i=0;i<=4;i++){const y=p.t+ph-(i/4)*ph;ctx.beginPath();ctx.moveTo(p.l,y);ctx.lineTo(p.l+pw,y);ctx.stroke();}
  ctx.strokeStyle='#333';ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(p.l,p.t);ctx.lineTo(p.l,p.t+ph);ctx.lineTo(p.l+pw,p.t+ph);ctx.stroke();
  ctx.fillStyle='#778';ctx.font='9px sans-serif';ctx.textAlign='center';
  for(let v=Math.ceil(xMin);v<=Math.floor(xMax);v+=2)ctx.fillText(v,p.l+((v-xMin)/(xMax-xMin))*pw,p.t+ph+12);
  ctx.textAlign='right';ctx.textBaseline='middle';
  for(let i=0;i<=4;i++)ctx.fillText(((i/4)*allMax).toExponential(1),p.l-4,p.t+ph-(i/4)*ph);
  ctx.strokeStyle='#ffffff88';ctx.lineWidth=1.5;ctx.setLineDash([4,3]);ctx.beginPath();
  for(let i=0;i<x.length;i++){
    const xp=p.l+((x[i]-xMin)/(xMax-xMin))*pw,yp=p.t+ph-(frame.n_x[i]/allMax)*ph;
    i===0?ctx.moveTo(xp,yp):ctx.lineTo(xp,yp);
  }ctx.stroke();ctx.setLineDash([]);
  for(let c=0;c<D;c++){
    const vals=frame.comp_n_x[c];
    ctx.strokeStyle=mColors[c];ctx.lineWidth=1.2;ctx.beginPath();
    for(let i=0;i<x.length;i++){
      const xp=p.l+((x[i]-xMin)/(xMax-xMin))*pw,yp=p.t+ph-(vals[i]/allMax)*ph;
      i===0?ctx.moveTo(xp,yp):ctx.lineTo(xp,yp);
    }ctx.stroke();
  }
}

function updatePopBar(frame){
  const bar=document.getElementById('pop-bar'),leg=document.getElementById('pop-legend');
  bar.innerHTML='';leg.innerHTML='';
  for(let c=0;c<D;c++){
    const d=document.createElement('div');
    d.style.width=(frame.pops[c]*100)+'%';d.style.background=mColors[c];
    d.title='m='+(mLabels[c]>=0?'+':'')+mLabels[c]+': '+(frame.pops[c]*100).toFixed(1)+'%';
    bar.appendChild(d);
  }
  for(let c=0;c<D;c++){
    if(frame.pops[c]>0.005){
      const s=document.createElement('span');
      s.innerHTML='<span style="color:'+mColors[c]+'">■</span>m='+(mLabels[c]>=0?'+':'')+mLabels[c]+':'+(frame.pops[c]*100).toFixed(1)+'%';
      leg.appendChild(s);
    }
  }
}

let lastSpatialIdx=-1;
function render(idx){
  currentIdx=idx;
  const frame=DATA.scalars[idx];
  document.getElementById('slider').value=idx;
  document.getElementById('time-label').textContent='t = '+frame.t.toFixed(3)+' ω⁻¹';
  document.getElementById('stats').innerHTML=[
    {v:frame.t.toFixed(3),l:'Time [ω⁻¹]'},
    {v:frame.Mz.toFixed(3),l:'⟨Fz⟩'},
    {v:frame.norm.toFixed(4),l:'Norm'},
    {v:frame.E_total.toFixed(4),l:'E_total'},
  ].map(s=>'<div class="stat"><div class="v">'+s.v+'</div><div class="l">'+s.l+'</div></div>').join('');
  updatePopBar(frame);

  // Spatial (3D/2D) — only update when nearest spatial frame changes
  const si=nearestSpatial(idx);
  if(si!==lastSpatialIdx){
    lastSpatialIdx=si;
    if(NDIM===3){render3dTotal(si);render3dComponents(si);}
    else if(NDIM===2){render2dTotal(si);render2dComponents(si);}
  }

  // 1D profiles
  drawProfiles(DATA.profiles[idx]);

  // Time-series graphs
  drawGraph('c_pops',
    mLabels.map((m,c)=>({fn:f=>f.pops[c],color:mColors[c],label:'m='+(m>=0?'+':'')+m})),
    DATA.scalars,idx,{yMin:0,yMax:1.05,title:'Population fractions'});
  drawGraph('c_energy',[
    {key:'E_kin',color:'#4363d8',label:'Kinetic'},
    {key:'E_trap',color:'#f58231',label:'Trap'},
    {key:'E_density',color:'#3cb44b',label:'c₀'},
    {key:'E_spin',color:'#e6194b',label:'c₁'},
    {key:'E_zeeman',color:'#911eb4',label:'Zeeman'},
    {key:'E_total',color:'#ffffff',label:'Total',width:2},
  ],DATA.scalars,idx,{title:'Energy decomposition'});
  const f0=DATA.scalars[0];
  drawGraph('c_conservation',[
    {fn:f=>(f.norm-f0.norm)/f0.norm,color:'#42d4f4',label:'δN/N'},
    {fn:f=>(f.E_total-f0.E_total)/Math.abs(f0.E_total),color:'#f58231',label:'δE/E'},
    {fn:f=>f.Mz-f0.Mz,color:'#3cb44b',label:'δMz'},
  ],DATA.scalars,idx,{title:'Conservation'});
}

function setFrame(i){render(i);}
function togglePlay(){
  playing=!playing;
  document.getElementById('btn-play').textContent=playing?'⏸ Pause':'▶ Play';
  if(playing){
    playTimer=setInterval(()=>{
      currentIdx=(currentIdx+1)%DATA.scalars.length;
      render(currentIdx);
    },120);
  }else{clearInterval(playTimer);}
}

initCompGrid();
render(0);
</script>
</body>
</html>"""
    html
end

# --- Main ---
path = length(ARGS) >= 1 ? ARGS[1] : joinpath(@__DIR__, "output", "li7_spin_dynamics.jld2")
println("Loading data: $path")
d = load_data(path)
html = generate_html(d)
base = splitext(basename(path))[1]
outpath = joinpath(dirname(path), base * "_dashboard.html")
write(outpath, html)
println("Done: $outpath ($(round(filesize(outpath)/1024/1024, digits=1)) MB)")

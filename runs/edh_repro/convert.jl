# GLUE: Julia JLD2 (48^3) -> Eu-Fortran .hdr/.bin frames for analysis/standard.py.
using JLD2
src = "runs/edh_repro/point_001.jld2"
outdir = ARGS[1]; prefix = ARGS[2]
mkpath(outdir)
f = jldopen(src, "r")
g = f["dynamics"]["psi_snapshots_streamed"]
times = f["dynamics"]["times"]; u = f["units"]
a_ho_um = u["a_ho_m"]*1e6; omega_ref = 691.1504
nx,ny,nz,D = 48,48,48,13; Fq=6; box=16.0; dx=box/nx
man = open(joinpath(outdir, "$(prefix)_frames.txt"), "w"); println(man, "# idx time tag")
nfr=0
for k in 1:2000
  key = "frame_"*lpad(k,5,'0'); haskey(g,key) || continue
  psi = g[key]; tag = key; base = joinpath(outdir, "$(prefix)_$(tag)")
  open(base*".bin","w") do io; write(io, ComplexF64.(psi)); end   # promote f32->f64 for our reader
  open(base*".hdr","w") do io
    println(io,"shape_nx_ny_nz_D    $nx   $ny   $nz   $D"); println(io,"F   $Fq")
    println(io,"spacing_dx_dy_dz   $dx  $dx  $dx"); println(io,"box_Lx_Ly_Lz   $box   $box   $box")
    println(io,"a_ho_um   $a_ho_um"); println(io,"omega_ref   $omega_ref")
  end
  tt = k<=length(times) ? times[k] : (k-1)*0.1; println(man,"$k  $tt  $tag"); global nfr+=1
end
close(man); close(f); println("converted $nfr frames -> $outdir")

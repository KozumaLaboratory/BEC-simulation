# GLUE (new file, no SpinorBEC.jl source touched): convert Julia JLD2 psi snapshots
# to the Eu-Fortran .hdr/.bin frame format so analysis/standard.py reads them
# identically to a Fortran run.  Julia (nx,ny,nz,D) column-major bytes == numpy
# reshape((D,nz,ny,nx)); components already m=+6..-6, matching Fortran.
using JLD2
src = "runs/cmp_fortran_10mG_32/point_001.jld2"
outdir = ARGS[1]           # e.g. /home/6/ue06186/work/KozumaLab/Eu-Fortran/runs/cmp_julia_10mG_32/datas
prefix = ARGS[2]           # e.g. cmp_julia_10mG_32
mkpath(outdir)
f = jldopen(src, "r")
g = f["dynamics"]["psi_snapshots_streamed"]
times = f["dynamics"]["times"]
u = f["units"]
a_ho_um = u["a_ho_m"] * 1e6
omega_ref = 691.15
nx, ny, nz, D = 32, 32, 32, 13
F = 6; box = 18.0; dx = box/nx
man = open(joinpath(dirname(outdir), "$(prefix)_frames.txt"), "w")
# read_frames expects: prefix_frames.txt in the SAME dir as prefix (datas/), lines "idx time tag"
close(man); man = open(joinpath(outdir, "$(prefix)_frames.txt"), "w")
println(man, "# idx  time  tag")
nfr = 0
for k in 1:1000
    key = "frame_" * lpad(k, 5, '0')
    haskey(g, key) || continue
    psi = g[key]                       # (32,32,32,13) ComplexF64
    tag = "frame_" * lpad(k, 5, '0')
    base = joinpath(outdir, "$(prefix)_$(tag)")
    open(base * ".bin", "w") do io; write(io, psi); end   # col-major == numpy (D,nz,ny,nx)
    open(base * ".hdr", "w") do io
        println(io, "shape_nx_ny_nz_D    $nx   $ny   $nz   $D")
        println(io, "F   $F")
        println(io, "spacing_dx_dy_dz   $dx  $dx  $dx")
        println(io, "box_Lx_Ly_Lz   $box   $box   $box")
        println(io, "a_ho_um   $a_ho_um")
        println(io, "omega_ref   $omega_ref")
    end
    tt = k <= length(times) ? times[k] : (k-1)*0.1
    println(man, "$k  $tt  $tag")
    global nfr += 1
end
close(man); close(f)
println("converted $nfr frames -> $outdir  (prefix $prefix)")

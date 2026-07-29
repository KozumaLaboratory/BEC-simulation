# Stern-Gerlach + time-of-flight observation of a saved spinor state.
#
# The in-situ spin texture (eu_truegs_texture.jl) and the SG+TOF image are the
# two complementary ways the lab observes a spinor BEC: the texture shows the
# orientation field in place; SG+TOF separates the 2F+1 magnetic sublevels in
# space so each population m is measured independently.
#
# Far-field model: per component, |ψ̃_m(k)|² (single FFT) is mapped to position
# r = k·t_tof and displaced by the Stern-Gerlach ballistic shift
#     d_m = m · gradient · t_tof² / 2
# along the separation axis, then column-integrated along the imaging axis.
#
# Two facts make the built-in `simulate_tof` unusable for "measure all 2F+1":
#   1. it applies the SG shift along `imaging_axis` and then integrates out that
#      SAME axis — a circular shift is invariant under full-axis summation, so
#      the separation cancels. Here the separation axis (x) and the imaging line
#      of sight (z) are kept distinct.
#   2. on the native grid the SG shift wraps (circshift) once d_m exceeds the
#      half-box, so 2F+1 clouds cannot fit. Here each component is placed on a
#      wide non-wrapping canvas by linear interpolation.
#
# The gradient required for clean separation is derived from the measured cloud
# width: spacing Δx = KSEP × RMS ⇒ gradient = 2Δx / t_tof². Default KSEP=8 puts
# adjacent clouds 8 RMS apart (resolved & individually integrable).
#
# Env: SG_IN=<state.jld2>  SG_OUT=figs/sg_tof  SG_T_TOF=10.0  SG_KSEP=8.0
#   julia --project=. scripts/eu_sg_tof.jl
# Then: python scripts/viz_sg_tof.py   (reads SG_OUT)

using SpinorBEC
using SpinorBEC: eu151_preset, SpinSystem, load_state
using FFTW
using DelimitedFiles: writedlm
using Printf

const IN = get(ENV, "SG_IN", "figs/sg_tof/state.jld2")
const OUT = get(ENV, "SG_OUT", "figs/sg_tof")
const T_TOF = parse(Float64, get(ENV, "SG_T_TOF", "10.0"))
const KSEP = parse(Float64, get(ENV, "SG_KSEP", "8.0"))   # spacing = KSEP × cloud RMS
const PAD = parse(Int, get(ENV, "SG_PAD", "4"))          # real-space zero-pad → k interp
const SEP_AXIS = 1   # Stern-Gerlach separation direction (x)
const LOS_AXIS = 3   # imaging line of sight, integrated out (z)
mkpath(OUT)

st = load_state(IN)
psi = st.psi
npts = st.grid_n_points
box = st.grid_box_size
D = size(psi, 4)
F = (D - 1) ÷ 2
@printf("loaded %s  grid=%s box=%s  D=%d  F=%d\n", IN, npts, box, D, F)

PRESET = eu151_preset(; n_pts=Tuple(npts), box=Tuple(float.(box)),
    trap_ratios=(1.0, 1.0, 1.1818))
grid = PRESET.grid
sys = SpinSystem(F)
NX, NY, NZ = npts

# real-space zero-padding interpolates the far-field: in-plane axes (sep,
# transverse) padded by PAD → k-grid PAD× finer & smoother. LOS axis is
# integrated out, so it stays at native resolution (cost).
NXp = NX * PAD
NYp = NY * PAD
dk_sep = grid.dk[SEP_AXIS] / PAD

# far-field position grid along the separation axis (centered): p = k · t_tof
ks = ((0:(NXp - 1)) .- NXp ÷ 2) .* dk_sep
ps = ks .* T_TOF
dp = dk_sep * T_TOF

# per-component far-field: 2D (sep, transverse) image + 1D sep profile, centered
img2d = Vector{Matrix{Float64}}(undef, D)
prof1d = Vector{Vector{Float64}}(undef, D)
pops = Float64[]
ms = Int[]
padded = zeros(ComplexF64, NXp, NYp, NZ)
for c in 1:D
    m = sys.m_values[c]
    fill!(padded, 0)
    @views padded[1:NX, 1:NY, 1:NZ] .= psi[:, :, :, c]   # corner pad (|ψ̃|² phase-invariant)
    nk = fftshift(abs2.(fft(padded)))
    col = dropdims(sum(nk; dims=LOS_AXIS); dims=LOS_AXIS)   # (sep, transverse)
    img2d[c] = col
    prof1d[c] = dropdims(sum(col; dims=2); dims=2)
    push!(ms, m)
    push!(pops, sum(col))
end
tot_pop = sum(pops)

# cloud RMS width (position units) from the dominant component → required gradient
cdom = argmax(pops)
w = prof1d[cdom]
pbar = sum(w .* ps) / sum(w)
rms = sqrt(sum(w .* (ps .- pbar) .^ 2) / sum(w))
spacing = KSEP * rms
grad_needed = 2 * spacing / T_TOF^2
@printf("\n cloud RMS width = %.2f  ⇒ spacing Δx = %.2f (=%.1f×RMS)\n", rms, spacing, KSEP)
@printf(" gradient for clean separation = %.4f  (t_tof=%.1f)\n", grad_needed, T_TOF)

# wide non-wrapping canvas; place each component at offset m·Δx (linear interp)
xlo = -(F * spacing + 4 * rms)
xhi = (F * spacing + 4 * rms)
NXC = max(256, ceil(Int, (xhi - xlo) / dp))
xc = range(xlo, xhi; length=NXC)
dxc = xc[2] - xc[1]
canvas2d = zeros(Float64, NXC, NYp)
profiles = zeros(Float64, NXC, D)
for c in 1:D
    off = ms[c] * spacing
    for i in 1:NXp
        g = (ps[i] + off - xlo) / dxc + 1
        b = floor(Int, g)
        fr = g - b
        (1 <= b <= NXC) || continue
        @views canvas2d[b, :] .+= (1 - fr) .* img2d[c][i, :]
        profiles[b, c] += (1 - fr) * prof1d[c][i]
        if b + 1 <= NXC
            @views canvas2d[b + 1, :] .+= fr .* img2d[c][i, :]
            profiles[b + 1, c] += fr * prof1d[c][i]
        end
    end
end

println("\n m   pop%    center_x")
for c in 1:D
    @printf("%+3d  %5.1f   %+8.2f\n", ms[c], 100 * pops[c] / tot_pop, ms[c] * spacing)
end
@printf("\n adjacent-cloud gap / width = %.1f  ⇒ %s\n",
    spacing / rms, spacing > 4 * rms ? "RESOLVED (each measurable)" : "OVERLAP")

writedlm(joinpath(OUT, "combined.csv"), canvas2d, ',')
writedlm(joinpath(OUT, "xaxis.csv"), collect(xc), ',')
writedlm(joinpath(OUT, "profiles_perm.csv"), hcat(collect(xc), profiles), ',')
writedlm(joinpath(OUT, "m_values.csv"), reshape(collect(ms), 1, :), ',')
writedlm(joinpath(OUT, "populations.csv"),
    hcat(collect(ms), pops, pops ./ tot_pop), ',')
@printf(" wrote %s/{combined,xaxis,profiles_perm,m_values,populations}.csv\n", OUT)
println(" DONE")

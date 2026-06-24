# Detailed spin-texture analysis of a saved weak-field Eu+DDI true-GS state.
# Loads the wavefunction persisted by eu_truegs_figure_data.jl and characterises
# the SHAPE of the transverse-spin texture: orientation field (azimuth Φ, polar
# Θ), spin-length |F|/(F·n), transverse winding ℓ(r), radial profiles, an xz
# cross-section (3D structure), and the monopole/skyrmion charge.
#
# Env: TX_IN=figs/truegs/truegs_state.jld2  TX_OUT=figs/truegs  TX_SMOOTH=1
#   julia --project=. scripts/eu_truegs_texture.jl

using SpinorBEC
using SpinorBEC: eu151_preset, SpinSystem, load_state, monopole_charge_3d,
    total_monopole_charge
using DelimitedFiles: writedlm
using Printf

const IN  = get(ENV, "TX_IN", "figs/truegs/truegs_state.jld2")
const OUT = get(ENV, "TX_OUT", "figs/truegs")
const SMOOTH = get(ENV, "TX_SMOOTH", "1") == "1"
mkpath(OUT)

st = load_state(IN)
psi = st.psi                                    # (nx,ny,nz,D)
npts = st.grid_n_points
box = st.grid_box_size
NX = npts[1]
@printf("texture: loaded %s  grid=%s box=%s\n", IN, npts, box)

PRESET = eu151_preset(; n_pts=Tuple(npts),
    box=Tuple(float.(box)), trap_ratios=(1.0, 1.0, 1.1818))
grid = PRESET.grid
D = size(psi, 4); F = (D - 1) ÷ 2

# --- raw spin fields + density ----------------------------------------------
fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, grid)
dens = dropdims(sum(abs2, psi; dims=4); dims=4)
if SMOOTH
    fx = SpinorBEC._box_smooth_3d(fx); fy = SpinorBEC._box_smooth_3d(fy)
    fz = SpinorBEC._box_smooth_3d(fz)
end

fperp = sqrt.(fx .^ 2 .+ fy .^ 2)
fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
# spin-length fraction: 1 ⇒ fully ferromagnetic (|F|=F), 0 ⇒ unmagnetised
spinlen = fmag ./ max.(F .* dens, eps())
azim = atan.(fy, fx)                            # Φ ∈ (-π,π]
polar = acos.(clamp.(fz ./ max.(fmag, eps()), -1, 1))   # Θ ∈ [0,π]

kz = NX ÷ 2 + 1                                 # z-midplane
ky = NX ÷ 2 + 1                                 # y-midplane (for xz section)
xs = collect(grid.x[1])

# --- transverse winding ℓ(r): ∮ dΦ / 2π on concentric circles (z-midplane) ---
cx = (NX + 1) / 2; cy = (NX + 1) / 2
dx = xs[2] - xs[1]
nrings = NX ÷ 2 - 1
ring_r = Float64[]; ring_wind = Float64[]; ring_fperp = Float64[]; ring_fz = Float64[]
for ir in 2:nrings
    r = ir * dx
    nth = max(16, 4 * ir)
    Φprev = NaN; tot = 0.0; fp = 0.0; fzr = 0.0; cnt = 0
    for it in 0:nth
        θ = 2π * it / nth
        gx = cx + (r / dx) * cos(θ); gy = cy + (r / dx) * sin(θ)
        i = clamp(round(Int, gx), 1, NX); j = clamp(round(Int, gy), 1, NX)
        Φ = azim[i, j, kz]
        if it > 0
            dΦ = Φ - Φprev
            dΦ -= 2π * round(dΦ / (2π))          # unwrap to (-π,π]
            tot += dΦ
        end
        Φprev = Φ
        if it < nth
            fp += fperp[i, j, kz]; fzr += fz[i, j, kz]; cnt += 1
        end
    end
    push!(ring_r, r); push!(ring_wind, tot / (2π))
    push!(ring_fperp, fp / cnt); push!(ring_fz, fzr / cnt)
end

# --- monopole / skyrmion charge of the unit spin field ----------------------
mono = monopole_charge_3d(psi, grid; smooth=SMOOTH)
qtot = total_monopole_charge(mono, grid)

# --- dumps -------------------------------------------------------------------
writedlm(joinpath(OUT, "tx_x.csv"), xs)
writedlm(joinpath(OUT, "tx_azim_xy.csv"), azim[:, :, kz])
writedlm(joinpath(OUT, "tx_polar_xy.csv"), polar[:, :, kz])
writedlm(joinpath(OUT, "tx_spinlen_xy.csv"), spinlen[:, :, kz])
writedlm(joinpath(OUT, "tx_fperp_xy.csv"), fperp[:, :, kz])
writedlm(joinpath(OUT, "tx_fx_xy.csv"), fx[:, :, kz])
writedlm(joinpath(OUT, "tx_fy_xy.csv"), fy[:, :, kz])
writedlm(joinpath(OUT, "tx_fz_xy.csv"), fz[:, :, kz])
# xz cross-section (3D structure): index [i, ky, k]
writedlm(joinpath(OUT, "tx_fx_xz.csv"), fx[:, ky, :])
writedlm(joinpath(OUT, "tx_fz_xz.csv"), fz[:, ky, :])
writedlm(joinpath(OUT, "tx_fperp_xz.csv"), fperp[:, ky, :])
writedlm(joinpath(OUT, "tx_spinlen_xz.csv"), spinlen[:, ky, :])
writedlm(joinpath(OUT, "tx_rings.csv"),
    hcat(ring_r, ring_wind, ring_fperp, ring_fz))

open(joinpath(OUT, "tx_meta.csv"), "w") do io
    writedlm(io, ["key" "value"])
    writedlm(io, ["grid" NX]); writedlm(io, ["F" F]); writedlm(io, ["smooth" SMOOTH])
    writedlm(io, ["total_monopole_charge" qtot])
    writedlm(io, ["mean_spinlen_core" spinlen[NX÷2+1, NX÷2+1, kz]])
    writedlm(io, ["max_fperp" maximum(fperp)])
    writedlm(io, ["outer_winding" isempty(ring_wind) ? 0.0 : ring_wind[end]])
end

@printf("DONE → %s\n", OUT)
@printf("  total monopole/skyrmion charge = %.3f\n", qtot)
@printf("  core spin-length |F|/(F·n)     = %.3f\n", spinlen[NX÷2+1, NX÷2+1, kz])
@printf("  transverse winding ℓ(r):\n")
for (r, w) in zip(ring_r, ring_wind)
    @printf("    r=%.2f  ℓ=%+.2f\n", r, w)
end

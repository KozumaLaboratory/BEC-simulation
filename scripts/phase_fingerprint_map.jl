# Apply the VALIDATED phase fingerprint to every saved cell of a phase-recon run
# (the seed_*.jld2 winners from phase_recon.jl) and emit a numeric feature matrix.
# This is the "correct phase diagram" layer: classify_phase gave a coarse magnetic
# label per cell; here every cell gets the full gauge-invariant invariant vector
# (σ_S, |F|/F, coherence g, Jz, chirality, flux-closure, S(k), inert class), so
# the map reflects the real spinor texture and the matrix feeds clustering.
#
# Pure post-processing — NO GPU, NO re-solving. Convergence quality (E, |∇E|) is
# joined from recon.csv so under-converged weak-field cells are flagged, not hidden.
#
# Env: FM_DIR=figs/phase_recon_2d  FM_BOX=24.0  FM_OUT=<DIR>/fp_features.csv
#   julia --project=. scripts/phase_fingerprint_map.jl

import SpinorBEC
using SpinorBEC: load_state
using DelimitedFiles: writedlm, readdlm
using Printf
include(joinpath(@__DIR__, "phase_fingerprint_lib.jl"))

const DIR = get(ENV, "FM_DIR", "figs/phase_recon_2d")
const BOX = parse(Float64, get(ENV, "FM_BOX", "24.0"))
const OUT = get(ENV, "FM_OUT", joinpath(DIR, "fp_features.csv"))

# parse (λ, B) from seed filename: seed_L0.500_B015.0.jld2  or  seed_B060.0.jld2
function parse_cell(fname)
    m = match(r"seed_L([0-9.]+)_B([0-9.]+)\.jld2", fname)
    m !== nothing && return (parse(Float64, m[1]), parse(Float64, m[2]))
    m = match(r"seed_B([0-9.]+)\.jld2", fname)
    m !== nothing && return (1.0, parse(Float64, m[1]))
    nothing
end

# winning (lowest-E) row per (λ,B) from recon.csv → (E, grad, phase_old)
function load_conv(dir)
    path = joinpath(dir, "recon.csv")
    conv = Dict{Tuple{Float64, Float64}, NamedTuple}()
    isfile(path) || return conv
    data = readdlm(path, '\t'; header=true)[1]
    ncol = size(data, 2)
    has_lam = ncol >= 8
    for r in 1:size(data, 1)
        lam = has_lam ? Float64(data[r, 1]) : 1.0
        off = has_lam ? 0 : -1
        B = Float64(data[r, 2+off]); E = Float64(data[r, 4+off])
        grad = Float64(data[r, 5+off]); phase = String(data[r, 8+off])
        k = (round(lam; digits=3), round(B; digits=1))
        if !haskey(conv, k) || E < conv[k].E
            conv[k] = (; E, grad, phase)
        end
    end
    conv
end

files = sort(filter(f -> startswith(f, "seed_") && endswith(f, ".jld2"), readdir(DIR)))
isempty(files) && error("no seed_*.jld2 in $DIR")
conv = load_conv(DIR)

rows = NamedTuple[]
for f in files
    cell = parse_cell(f); cell === nothing && continue
    lam, B = cell
    st = load_state(joinpath(DIR, f))
    psi = Array{ComplexF64}(st.psi)
    nx = size(psi, 1); F = (size(psi, 4) - 1) ÷ 2
    grid = SpinorBEC.eu151_preset(; n_pts=(nx, nx, nx), box=(BOX, BOX, BOX),
        trap_ratios=(1.0, 1.0, 1.0)).grid
    ctx = fp_context(grid; box=BOX, F=F)
    fp = fingerprint(ctx, psi)
    cv = get(conv, (round(lam; digits=3), round(B; digits=1)),
        (; E=NaN, grad=NaN, phase="?"))
    net_wind = sum(w -> w == "·" ? 0 : parse(Int, w), fp.winding)
    push!(rows, (; lam, B, cv.E, cv.grad, fp.mF, fp.coh, fp.Lz, fp.Fz, fp.Jz,
        fp.chirality, fp.fluxclosure, fp.spin_mod, fp.kspin, fp.dens_mod, fp.kdens,
        sigma=fp.sigma, net_wind, fp.inert, fp.inert_score, phase_old=cv.phase))
    fcs = isnan(fp.fluxclosure) ? "  N/A" : @sprintf("%.3f", fp.fluxclosure)
    @printf("λ=%.3f B=%5.1f  E=%9.4f |∇|=%.1e  |F|=%.2f g=%.2f Jz=%+.2f χ=%+.1e flux=%s  wind=%+d  inert=%-6s old=%s\n",
        lam, B, cv.E, cv.grad, fp.mF, fp.coh, fp.Jz, fp.chirality, fcs,
        net_wind, fp.inert, cv.phase)
end

# numeric feature matrix (one row per cell) → CSV for clustering + viz
F = (size(load_state(joinpath(DIR, files[1])).psi, 4) - 1) ÷ 2
sig_hdr = ["sigma$S" for S in 0:2:(2F)]
hdr = vcat(["lambda", "B", "E", "grad", "mF", "coh", "Lz", "Fz", "Jz", "chirality",
    "fluxclosure", "spin_mod", "kspin", "dens_mod", "kdens"], sig_hdr,
    ["net_wind", "inert", "inert_score", "phase_old"])
open(OUT, "w") do io
    writedlm(io, permutedims(hdr))
    for r in rows
        sigvals = [r.sigma[S] for S in 0:2:(2F)]
        writedlm(io, permutedims(vcat(
            [r.lam, r.B, r.E, r.grad, r.mF, r.coh, r.Lz, r.Fz, r.Jz, r.chirality,
             r.fluxclosure, r.spin_mod, r.kspin, r.dens_mod, r.kdens], sigvals,
            [r.net_wind, r.inert, r.inert_score, r.phase_old])))
    end
end
@printf("\nDONE → %s  (%d cells)\n", OUT, length(rows))

# Spatial spin-texture classifier for DDI spinor ground states.
#
# In the DDI-dominated regime the relevant order is the SPATIAL spin texture, not
# the uniform-spinor inert label (polar/cyclic/…). This computes a texture
# fingerprint and assigns a structure label:
#   uniform / splayed / vortex / skyrmion / helix(SDW) / density-modulated
# The inert σ_S/Majorana label (via classify_polyhedral) is reported as a
# secondary LOCAL-order descriptor.
#
# Env: TC_IN=figs/truegs_conv/truegs_state.jld2
#   julia --project=. scripts/eu_texture_classify.jl

import SpinorBEC
using SpinorBEC: load_state, eu151_preset, monopole_charge_3d, total_monopole_charge,
    classify_polyhedral
using FFTW: fft, fftfreq
using LinearAlgebra: norm
using Printf

const IN = get(ENV, "TC_IN", "figs/truegs_conv/truegs_state.jld2")
st = load_state(IN)
psi = Array{ComplexF64}(st.psi)
NX = size(psi, 1); D = size(psi, 4); F = (D - 1) ÷ 2
box = st.grid_box_size
PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=Tuple(float.(box)), trap_ratios=(1.0, 1.0, 1.1818))
grid = PRESET.grid
dx = box[1] / NX

dens = dropdims(sum(abs2, psi; dims=4); dims=4)
fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, grid)
fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
thr = 0.05 * maximum(dens)
mask = dens .> thr

# --- 1. spin coherence |⟨n̂⟩| (density-weighted) ------------------------------
function spin_coherence(dens, fx, fy, fz, fmag, mask)
    wsum = 0.0; nx = 0.0; ny = 0.0; nz = 0.0
    @inbounds for I in CartesianIndices(dens)
        (mask[I] && fmag[I] > 1e-12) || continue
        w = dens[I]; wsum += w
        nx += w * fx[I] / fmag[I]; ny += w * fy[I] / fmag[I]; nz += w * fz[I] / fmag[I]
    end
    wsum > 0 ? norm((nx, ny, nz)) / wsum : 0.0
end
coherence = spin_coherence(dens, fx, fy, fz, fmag, mask)

# --- 2. transverse winding ℓ (bulk, z-midplane rings) ------------------------
kz = NX ÷ 2 + 1; cx = (NX + 1) / 2; cy = (NX + 1) / 2
azim = atan.(fy, fx)
function ring_winding(r)
    nth = max(24, round(Int, 8r / dx)); Φp = NaN; tot = 0.0
    for it in 0:nth
        θ = 2π * it / nth
        i = clamp(round(Int, cx + (r / dx) * cos(θ)), 1, NX)
        j = clamp(round(Int, cy + (r / dx) * sin(θ)), 1, NX)
        Φ = azim[i, j, kz]
        if it > 0
            dΦ = Φ - Φp; dΦ -= 2π * round(dΦ / 2π); tot += dΦ
        end
        Φp = Φ
    end
    tot / 2π
end
rmax = (NX ÷ 2 - 2) * dx
wind_bulk = round(ring_winding(0.5 * rmax))     # representative bulk radius

# --- 3. skyrmion / monopole charge -------------------------------------------
Q = total_monopole_charge(monopole_charge_3d(psi, grid; smooth=true), grid)

# --- 4. spin structure factor: dominant modulation wavevector ----------------
# S(k) = Σ_α |FFT(f_α)|². Envelope sits at |k| ~ 1/R_TF; a genuine helix/SDW
# peaks at |k| ≫ 1/R_TF. Report the prominence of the dominant k≠0 shell.
Sk = abs.(fft(fx)) .^ 2 .+ abs.(fft(fy)) .^ 2 .+ abs.(fft(fz)) .^ 2
kf = 2π .* fftfreq(NX, 1 / dx)
kgrid = [sqrt(kf[i]^2 + kf[j]^2 + kf[l]^2) for i in 1:NX, j in 1:NX, l in 1:NX]
# cloud size estimate (density rms radius) → envelope k-scale
rms = sqrt(sum(dens[I] * sum(abs2, Tuple(I) .- (NX + 1) / 2) for I in CartesianIndices(dens)) /
           sum(dens)) * dx
k_env = 1 / max(rms, dx)
beyond = kgrid .> 3 * k_env                       # well beyond the envelope
peak_beyond = any(beyond) ? maximum(Sk[beyond]) : 0.0
kstar = any(beyond) && peak_beyond > 0 ? kgrid[argmax(Sk .* beyond)] : 0.0
# fraction of spin spectral power in a sharp peak beyond the envelope (a helix
# concentrates power at one k*; a smooth splay does not). Normalise by total
# power, not S0 (S0→0 for low magnetisation inflates the ratio spuriously).
spin_mod = sum(Sk) > 0 ? peak_beyond / sum(Sk) : 0.0

# --- 5. Fz splay: does Fz flip sign across the cloud (density-weighted)? ------
pos = sum(dens[I] for I in CartesianIndices(dens) if mask[I] && fz[I] > 0; init=0.0)
neg = sum(dens[I] for I in CartesianIndices(dens) if mask[I] && fz[I] < 0; init=0.0)
fz_splay = (pos + neg) > 0 ? 2 * min(pos, neg) / (pos + neg) : 0.0  # 0 uniform-sign … 1 balanced flip

# --- 6. density modulation: dominant n(r) peak beyond envelope ---------------
nk = abs.(fft(dens .- sum(dens) / length(dens))) .^ 2
dens_mod = nk[1, 1, 1] > 0 && any(beyond) ? maximum(nk[beyond]) / maximum(nk) : 0.0

# --- label heuristic ---------------------------------------------------------
# coherence FIRST: a near-uniform spin direction is a single-domain state, and
# its winding/structure-factor are transverse-noise artifacts (|F⊥|≈0). Only a
# genuinely textured state (coherence < 0.9) gets a texture sub-label.
label = if coherence > 0.9
    "uniform"
elseif abs(wind_bulk) >= 0.5
    "vortex(ℓ=$(Int(wind_bulk)))"
elseif abs(Q) >= 0.5
    "skyrmion(Q≈$(round(Q; digits=2)))"
elseif spin_mod >= 0.15
    "helix/SDW(k*≈$(round(kstar; digits=2)))"
elseif dens_mod >= 0.1
    "density-modulated"
else
    "splayed/textured"
end

# secondary: local inert order at peak density
pk = argmax(dens); z = ComplexF64[psi[pk, c] for c in 1:D]; z ./= norm(z)
loc = classify_polyhedral(z, F)

@printf("texture classify: %s  grid=%d^3 F=%d\n", IN, NX, F)
@printf("  R_rms=%.2f  k_env≈%.2f\n", rms, k_env)
@printf("  [1] spin coherence |⟨n̂⟩| = %.3f   (1 uniform … 0 disordered)\n", coherence)
@printf("  [2] transverse winding ℓ = %+d\n", Int(wind_bulk))
@printf("  [3] skyrmion charge Q    = %+.3f\n", Q)
@printf("  [4] spin modulation      = %.3f  (k*=%.2f)  (>0.1 ⇒ helix/SDW)\n", spin_mod, kstar)
@printf("  [5] Fz splay             = %.3f  (0 uniform-sign … 1 balanced ±z flip)\n", fz_splay)
@printf("  [6] density modulation   = %.3f  (>0.1 ⇒ supersolid-like)\n", dens_mod)
@printf("  ──► STRUCTURE LABEL: %s\n", label)
@printf("  (local inert order at peak: %s, score %.3f)\n", loc.best, loc.score)

# Complete gauge/frame-invariant phase fingerprint for an F=6 dipolar spinor.
# A single invariant VECTOR per state, spanning the layers that separate the many
# expected phases:
#   A local order : {σ_S} (S=0..2F), |⟨F⟩|/F            — polar/cyclic/biaxial/polyhedral/FM
#   B uniformity  : spinor coherence g=⟨|⟨ζ_ref|ζ(r)⟩|²⟩ — uniform ↔ textured (multipole-complete)
#   C topology    : winding vector, Jz=⟨L_z+F_z⟩, skyrmion Q, chirality, flux-closure ∇·F
#   D modulation  : spin / density structure-factor peaks  — helix-SDW / supersolid
#
# Validate by running on KNOWN states (imprints + inert candidates) and checking
# each parameter recovers the known structure — keep only the parameters that do.
#
# Env: FP_STATE=polar|fm|cyclic|biaxial_nematic|fl_vortex|polar_core_vortex|chiral_spin_vortex|spin_helix
#      FP_IN=<jld2>   (classify a saved state instead of a named imprint)
#      FP_GRID=40 FP_BOX=24
#   julia --project=. scripts/phase_fingerprint.jl

import SpinorBEC
using SpinorBEC: eu151_preset, SpinSystem, init_psi, spin_matrices, cell_volume,
    polyhedral_fingerprint, classify_polyhedral, majorana_stars,
    winding_number_field, monopole_charge_3d, total_monopole_charge, load_state
using FFTW: fft, fftfreq
using LinearAlgebra: norm, dot
using Printf

const F  = 6
const NX = parse(Int, get(ENV, "FP_GRID", "40"))
const BOX = parse(Float64, get(ENV, "FP_BOX", "24.0"))
const PRESET = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, 1.0))
const GRID = PRESET.grid
const SYS = SpinSystem(F)
const SM = spin_matrices(F)
const DV = cell_volume(GRID)
const DX = BOX / NX
const D = 2F + 1

# ---------- state source ----------
function get_psi()
    if haskey(ENV, "FP_IN")
        st = load_state(ENV["FP_IN"])
        return Array{ComplexF64}(st.psi), basename(ENV["FP_IN"])
    end
    s = Symbol(get(ENV, "FP_STATE", "polar"))
    s === :fm && (s = :m_plus_F)                       # FM uniform
    kw = Dict{Symbol,Any}()
    s in (:fl_vortex, :polar_core_vortex, :chiral_spin_vortex) && (kw[:init_vortex_charge] = 1)
    s === :spin_helix && (kw[:helix_k] = (2π / BOX * 3, 0.0, 0.0))   # 3 periods across box
    Array{ComplexF64}(init_psi(GRID, SYS; state=s, kw...)), String(s)
end

# ---------- helpers ----------
spinor_at(psi, I) = ComplexF64[psi[I, c] for c in 1:D]

function spin_fields(psi)
    fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, GRID)
    fx, fy, fz
end

# B. spinor coherence (gauge-invariant, multipole-complete)
function spinor_coherence(psi, dens)
    pk = argmax(dens); zref = spinor_at(psi, pk); zref ./= norm(zref)
    num = 0.0; den = 0.0
    @inbounds for I in CartesianIndices(dens)
        dens[I] > 0.02 * maximum(dens) || continue
        z = spinor_at(psi, I); nz = norm(z); nz > 1e-12 || continue
        ov = abs2(dot(zref, z)) / nz^2
        num += dens[I] * ov; den += dens[I]
    end
    den > 0 ? num / den : 0.0
end

# C. ⟨L_z⟩ per atom (orbital angular momentum, central differences)
function mean_Lz(psi, dens)
    xs = collect(GRID.x[1]); ys = collect(GRID.x[2])
    Lz = 0.0; nrm = 0.0
    @inbounds for c in 1:D, k in 1:NX, j in 2:(NX-1), i in 2:(NX-1)
        ψ = psi[i, j, k, c]
        dψx = (psi[i+1, j, k, c] - psi[i-1, j, k, c]) / (2DX)
        dψy = (psi[i, j+1, k, c] - psi[i, j-1, k, c]) / (2DX)
        # L_z = -i (x ∂_y - y ∂_x)
        Lzψ = -im * (xs[i] * dψy - ys[j] * dψx)
        Lz += real(conj(ψ) * Lzψ)
        nrm += abs2(ψ)
    end
    nrm > 0 ? Lz / nrm : 0.0
end

mean_Fz(fz, dens) = sum(fz) * DV / (sum(dens) * DV)

# C. per-component net winding at z-midplane, gated on component population
# (winding in a near-empty component is phase noise, not a physical vortex).
function winding_vector(psi)
    kz = NX ÷ 2 + 1
    tot = sum(abs2, psi)
    map(1:D) do c
        pop = sum(abs2, view(psi, :, :, :, c)) / tot
        pop < 1e-3 ? "·" : string(sum(view(winding_number_field(psi, GRID; component=c), :, :, kz)))
    end
end

# C. scalar spin chirality + skyrmion density (z-midplane, density-weighted)
function chirality_and_Q2d(fx, fy, fz, dens)
    kz = NX ÷ 2 + 1
    fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    χ = 0.0; w = 0.0
    @inbounds for j in 2:(NX-1), i in 2:(NX-1)
        fmag[i, j, kz] > 1e-9 || continue
        n = [fx[i, j, kz], fy[i, j, kz], fz[i, j, kz]] ./ fmag[i, j, kz]
        nx = ([fx[i+1, j, kz], fy[i+1, j, kz], fz[i+1, j, kz]] ./ max(fmag[i+1, j, kz], 1e-12) .-
              [fx[i-1, j, kz], fy[i-1, j, kz], fz[i-1, j, kz]] ./ max(fmag[i-1, j, kz], 1e-12)) ./ (2DX)
        ny = ([fx[i, j+1, kz], fy[i, j+1, kz], fz[i, j+1, kz]] ./ max(fmag[i, j+1, kz], 1e-12) .-
              [fx[i, j-1, kz], fy[i, j-1, kz], fz[i, j-1, kz]] ./ max(fmag[i, j-1, kz], 1e-12)) ./ (2DX)
        cross = [nx[2]*ny[3]-nx[3]*ny[2], nx[3]*ny[1]-nx[1]*ny[3], nx[1]*ny[2]-nx[2]*ny[1]]
        χ += dens[i, j, kz] * dot(n, cross); w += dens[i, j, kz]
    end
    w > 0 ? χ / w : 0.0
end

# C. flux-closure: ‖∇·F‖ / ‖∇F‖   (Flower phase → ≈0). Gated on a magnetised
# voxel (|F|>thr): for polar/cyclic the spin density ≈0 and the ratio is noise.
function flux_closure_fraction(fx, fy, fz)
    fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    fthr = 0.05 * maximum(fmag)
    maximum(fmag) < 1e-8 && return NaN                 # unmagnetised ⇒ N/A
    divsq = 0.0; gradsq = 0.0
    @inbounds for k in 2:(NX-1), j in 2:(NX-1), i in 2:(NX-1)
        fmag[i, j, k] > fthr || continue
        dxFx = (fx[i+1, j, k] - fx[i-1, j, k]) / (2DX)
        dyFy = (fy[i, j+1, k] - fy[i, j-1, k]) / (2DX)
        dzFz = (fz[i, j, k+1] - fz[i, j, k-1]) / (2DX)
        divF = dxFx + dyFy + dzFz
        divsq += divF^2
        for (Fc, ax) in ((fx, 1), (fy, 2), (fz, 3))
            gradsq += ((Fc[i+1, j, k]-Fc[i-1, j, k])/(2DX))^2 +
                      ((Fc[i, j+1, k]-Fc[i, j-1, k])/(2DX))^2 +
                      ((Fc[i, j, k+1]-Fc[i, j, k-1])/(2DX))^2
        end
    end
    gradsq > 0 ? sqrt(divsq / gradsq) : 0.0
end

# D. structure-factor peak beyond the cloud envelope
function struct_peak(field, dens)
    rms = sqrt(sum(dens[I] * sum(abs2, Tuple(I) .- (NX+1)/2) for I in CartesianIndices(dens)) / sum(dens)) * DX
    kenv = 1 / max(rms, DX)
    kf = 2π .* fftfreq(NX, 1 / DX)
    kg = [sqrt(kf[i]^2 + kf[j]^2 + kf[l]^2) for i in 1:NX, j in 1:NX, l in 1:NX]
    S = abs.(fft(field)) .^ 2
    beyond = kg .> 3 * kenv
    tot = sum(S)
    (any(beyond) && tot > 1e-30) || return (0.0, 0.0)   # NaN guard (unmagnetised)
    pk = maximum(S[beyond]); frac = pk / tot
    (frac, kg[argmax(S .* beyond)])
end

# ---------- fingerprint ----------
psi, name = get_psi()
dens = dropdims(sum(abs2, psi; dims=4); dims=4)
fx, fy, fz = spin_fields(psi)
pk = argmax(dens); zbulk = spinor_at(psi, pk); zbulk ./= norm(zbulk)

sigma = polyhedral_fingerprint(zbulk, F)              # A
mF = sqrt(real(dot(zbulk, SM.Fx * zbulk))^2 + real(dot(zbulk, SM.Fy * zbulk))^2 +
          real(dot(zbulk, SM.Fz * zbulk))^2) / F
coh = spinor_coherence(psi, dens)                     # B
Lz = mean_Lz(psi, dens); Fz = mean_Fz(fz, dens); Jz = Lz + Fz   # C
wv = winding_vector(psi)
χ = chirality_and_Q2d(fx, fy, fz, dens)   # 2D skyrmion density (replaces dropped 3D Q)
fc = flux_closure_fraction(fx, fy, fz)
spin_mod, kspin = struct_peak(fx, dens)             # spin channel proxy (Fx)
dens_mod, kdens = struct_peak(ComplexF64.(dens .- sum(dens)/length(dens)), dens)
loc = classify_polyhedral(zbulk, F)

@printf("=== fingerprint: %s  (grid %d^3) ===\n", name, NX)
@printf("A local: |⟨F⟩|/F=%.3f  inert≈%s(%.3f)  σ_S=[%s]\n",
    mF, loc.best, loc.score, join([@sprintf("%d:%.3f", S, sigma[S]) for S in 0:2:(2F)], " "))
@printf("B unif : spinor coherence g=%.3f  (1 uniform … 0 textured)\n", coh)
fc_str = coh > 0.9 ? "N/A(uniform)" : (isnan(fc) ? "N/A(|F|≈0)" : @sprintf("%.3f", fc))
@printf("C topo : Jz=%.3f (Lz=%.3f+Fz=%.3f)  chirality=%+.3e  fluxclosure ‖∇·F‖/‖∇F‖=%s\n",
    Jz, Lz, Fz, χ, fc_str)
@printf("         winding vector (m=+F..-F): %s\n", join(wv, ","))
@printf("D modul: spin S(k) peak=%.3f @k=%.2f   density S(k) peak=%.3f @k=%.2f\n",
    spin_mod, kspin, dens_mod, kdens)

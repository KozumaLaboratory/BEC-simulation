# Shared, gauge/frame-invariant phase-fingerprint metrics for an F-spinor dipolar
# BEC. SINGLE SOURCE for every consumer so the same physics is never hand-written
# twice (duplicated-physics-drift discipline):
#   phase_fingerprint.jl      — validate each metric on known imprints
#   phase_fingerprint_map.jl  — fingerprint every saved 2D(B×λ) cell
#   eu_flower_reference.jl     — validate the flux-closure low-end on a real Flower
#
# A fingerprint is one invariant VECTOR per state (see layers A–D in fingerprint()).
# All functions take an `FPCtx` first so there are NO module-level globals.

import SpinorBEC
using SpinorBEC: polyhedral_fingerprint, classify_polyhedral, winding_number_field,
    spin_matrices, cell_volume, SpinSystem
using FFTW: fft, fftfreq
using LinearAlgebra: norm, dot

struct FPCtx{G, M}
    grid::G
    NX::Int
    BOX::Float64
    DX::Float64
    DV::Float64
    D::Int
    F::Int
    SM::M
end

function fp_context(grid; box::Float64, F::Int)
    NX = grid.config.n_points[1]
    FPCtx(grid, NX, box, box / NX, cell_volume(grid), 2F + 1, F, spin_matrices(F))
end

spinor_at(ctx::FPCtx, psi, I) = ComplexF64[psi[I, c] for c in 1:ctx.D]

spin_fields(ctx::FPCtx, psi) = SpinorBEC._spin_expectation_fields(psi, ctx.grid)

# B. spinor coherence (gauge-invariant, multipole-complete): 1 uniform … 0 textured
function spinor_coherence(ctx::FPCtx, psi, dens)
    pk = argmax(dens); zref = spinor_at(ctx, psi, pk); zref ./= norm(zref)
    num = 0.0; den = 0.0
    @inbounds for I in CartesianIndices(dens)
        dens[I] > 0.02 * maximum(dens) || continue
        z = spinor_at(ctx, psi, I); nz = norm(z); nz > 1e-12 || continue
        num += dens[I] * abs2(dot(zref, z)) / nz^2; den += dens[I]
    end
    den > 0 ? num / den : 0.0
end

# C. ⟨L_z⟩ per atom (orbital angular momentum, central differences)
function mean_Lz(ctx::FPCtx, psi, dens)
    NX, DX = ctx.NX, ctx.DX
    xs = collect(ctx.grid.x[1]); ys = collect(ctx.grid.x[2])
    Lz = 0.0; nrm = 0.0
    @inbounds for c in 1:ctx.D, k in 1:NX, j in 2:(NX-1), i in 2:(NX-1)
        ψ = psi[i, j, k, c]
        dψx = (psi[i+1, j, k, c] - psi[i-1, j, k, c]) / (2DX)
        dψy = (psi[i, j+1, k, c] - psi[i, j-1, k, c]) / (2DX)
        Lzψ = -im * (xs[i] * dψy - ys[j] * dψx)      # L_z = -i (x ∂_y - y ∂_x)
        Lz += real(conj(ψ) * Lzψ); nrm += abs2(ψ)
    end
    nrm > 0 ? Lz / nrm : 0.0
end

mean_Fz(ctx::FPCtx, fz, dens) = sum(fz) * ctx.DV / (sum(dens) * ctx.DV)

# C. per-component net winding at z-midplane, gated on component population
function winding_vector(ctx::FPCtx, psi)
    kz = ctx.NX ÷ 2 + 1
    tot = sum(abs2, psi)
    map(1:ctx.D) do c
        pop = sum(abs2, view(psi, :, :, :, c)) / tot
        pop < 1e-3 ? "·" :
        string(sum(view(winding_number_field(psi, ctx.grid; component=c), :, :, kz)))
    end
end

# C. scalar spin chirality / 2D skyrmion density (z-midplane, density-weighted)
function chirality_and_Q2d(ctx::FPCtx, fx, fy, fz, dens)
    NX, DX = ctx.NX, ctx.DX
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
# voxel (|F|>thr); unmagnetised ⇒ NaN (N/A).
function flux_closure_fraction(ctx::FPCtx, fx, fy, fz)
    NX, DX = ctx.NX, ctx.DX
    fmag = sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)
    fthr = 0.05 * maximum(fmag)
    maximum(fmag) < 1e-8 && return NaN
    divsq = 0.0; gradsq = 0.0
    @inbounds for k in 2:(NX-1), j in 2:(NX-1), i in 2:(NX-1)
        fmag[i, j, k] > fthr || continue
        dxFx = (fx[i+1, j, k] - fx[i-1, j, k]) / (2DX)
        dyFy = (fy[i, j+1, k] - fy[i, j-1, k]) / (2DX)
        dzFz = (fz[i, j, k+1] - fz[i, j, k-1]) / (2DX)
        divsq += (dxFx + dyFy + dzFz)^2
        for Fc in (fx, fy, fz)
            gradsq += ((Fc[i+1, j, k]-Fc[i-1, j, k])/(2DX))^2 +
                      ((Fc[i, j+1, k]-Fc[i, j-1, k])/(2DX))^2 +
                      ((Fc[i, j, k+1]-Fc[i, j, k-1])/(2DX))^2
        end
    end
    gradsq > 0 ? sqrt(divsq / gradsq) : 0.0
end

# D. structure-factor peak beyond the cloud envelope
function struct_peak(ctx::FPCtx, field, dens)
    NX, DX = ctx.NX, ctx.DX
    rms = sqrt(sum(dens[I] * sum(abs2, Tuple(I) .- (NX+1)/2) for I in CartesianIndices(dens)) /
               sum(dens)) * DX
    kenv = 1 / max(rms, DX)
    kf = 2π .* fftfreq(NX, 1 / DX)
    kg = [sqrt(kf[i]^2 + kf[j]^2 + kf[l]^2) for i in 1:NX, j in 1:NX, l in 1:NX]
    S = abs.(fft(field)) .^ 2
    beyond = kg .> 3 * kenv
    tot = sum(S)
    (any(beyond) && tot > 1e-30) || return (0.0, 0.0)
    (maximum(S[beyond]) / tot, kg[argmax(S .* beyond)])
end

# ---------- full fingerprint: one NamedTuple of every invariant ----------
function fingerprint(ctx::FPCtx, psi)
    F = ctx.F
    dens = dropdims(sum(abs2, psi; dims=4); dims=4)
    fx, fy, fz = spin_fields(ctx, psi)
    pk = argmax(dens); zbulk = spinor_at(ctx, psi, pk); zbulk ./= norm(zbulk)

    sigma = polyhedral_fingerprint(zbulk, F)                                   # A
    mF = sqrt(real(dot(zbulk, ctx.SM.Fx * zbulk))^2 +
              real(dot(zbulk, ctx.SM.Fy * zbulk))^2 +
              real(dot(zbulk, ctx.SM.Fz * zbulk))^2) / F
    coh = spinor_coherence(ctx, psi, dens)                                     # B
    Lz = mean_Lz(ctx, psi, dens); Fz = mean_Fz(ctx, fz, dens); Jz = Lz + Fz    # C
    wv = winding_vector(ctx, psi)
    χ = chirality_and_Q2d(ctx, fx, fy, fz, dens)
    fc = flux_closure_fraction(ctx, fx, fy, fz)
    spin_mod, kspin = struct_peak(ctx, fx, dens)                               # D
    dens_mod, kdens = struct_peak(ctx, ComplexF64.(dens .- sum(dens)/length(dens)), dens)
    loc = classify_polyhedral(zbulk, F)

    (; sigma, mF, coh, Lz, Fz, Jz, winding=wv, chirality=χ, fluxclosure=fc,
       spin_mod, kspin, dens_mod, kdens, inert=loc.best, inert_score=loc.score)
end

# pretty-print one fingerprint (shared by the validation + reference drivers)
function print_fingerprint(ctx::FPCtx, fp, name)
    F = ctx.F
    @printf("=== fingerprint: %s  (grid %d^3) ===\n", name, ctx.NX)
    @printf("A local: |⟨F⟩|/F=%.3f  inert≈%s(%.3f)  σ_S=[%s]\n",
        fp.mF, fp.inert, fp.inert_score,
        join([@sprintf("%d:%.3f", S, fp.sigma[S]) for S in 0:2:(2F)], " "))
    @printf("B unif : spinor coherence g=%.3f  (1 uniform … 0 textured)\n", fp.coh)
    fc_str = fp.coh > 0.9 ? "N/A(uniform)" :
             (isnan(fp.fluxclosure) ? "N/A(|F|≈0)" : @sprintf("%.3f", fp.fluxclosure))
    @printf("C topo : Jz=%.3f (Lz=%.3f+Fz=%.3f)  chirality=%+.3e  fluxclosure ‖∇·F‖/‖∇F‖=%s\n",
        fp.Jz, fp.Lz, fp.Fz, fp.chirality, fc_str)
    @printf("         winding vector (m=+F..-F): %s\n", join(fp.winding, ","))
    @printf("D modul: spin S(k) peak=%.3f @k=%.2f   density S(k) peak=%.3f @k=%.2f\n",
        fp.spin_mod, fp.kspin, fp.dens_mod, fp.kdens)
end

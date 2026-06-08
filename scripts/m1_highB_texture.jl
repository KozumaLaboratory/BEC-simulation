#!/usr/bin/env julia
# scripts/m1_highB_texture.jl
#
# Capstone reconciliation for the static-B-axis statement. The crossover +
# conjugate-field result implies the WHOLE Ω=0 B-axis is one canting
# crossover (⟨F_x⟩: 0→F, zero transitions). But the pre-cleanup label
# "B=10/100 nT = coreless PCV / Mermin-Ho texture (⟨L_z⟩=0)" CONTRADICTS
# the measured ⟨F_x⟩≈F (near-uniform x-polarisation): a genuine spin
# texture would have the spin direction VARY in space, dropping ⟨F_x⟩
# below |F|. One cheap look settles it.
#
# Decisive metric: alignment = Σ f_x / Σ |f|  (1 = every local spin points
# +x → uniform x-ferromagnet; <1 = spins tilt away → texture), plus the
# density-weighted local magnitude ⟨|F|⟩/N (= F if maximally stretched) and
# the spread of the local polar angle from x. ⟨L_z⟩ for circulation.
#   uniform x-ferro ⇒ alignment≈1, angle-std≈0, whole B-axis = 1 crossover
#                     (retire the stale PCV label).
#   genuine texture ⇒ alignment<1 / large angle-std ⇒ characterise as a
#                     ⟨L_z⟩=0 spatial structure separately.
# Either way the static B-axis becomes a definitive statement.

using SpinorBEC
using SpinorBEC: newton_cg_ground_state, spin_density_vector,
    orbital_angular_momentum
using JLD2
using Printf
using LinearAlgebra
using Statistics

const TW = eu151_preset()
const DIR = "runs/sprint5_M1_multistart_groundstate"
const BS = haskey(ENV, "M1_BS") ? parse.(Float64, split(ENV["M1_BS"], ",")) : [5.0, 10.0, 100.0]

zeeman_for(B) = TimeDependentZeeman(
    ConstantWaveform(0.0), ConstantWaveform(0.0),
    ConstantWaveform(B * TW.p_per_nT), ConstantWaveform(0.0),
)
function build_cpu_ws(B)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=0.0)
    make_workspace(; grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman_for(B), potential=TW.potential, sim_params=sp,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false, backend=CPUBackend())
end
load_psi(B) = JLD2.load(joinpath(DIR, @sprintf("cell_B%.1f_Om0.00.jld2", B)), "psi")

@printf("High-B spin-texture vs uniform-x-ferromagnet (static B-axis capstone)\n\n")
@printf("%-7s %8s %8s %8s %10s %10s %9s %9s %9s\n",
    "B", "Fx/N", "Fy/N", "Fz/N", "|F|/N", "align", "θ_mean°", "θ_std°", "Lz/N")
println("-"^86)
for B in BS
    ws = build_cpu_ws(B)
    out = newton_cg_ground_state(ws, load_psi(B);
        tol=1e-7, max_outer=40, max_cg=15, sobolev_alpha=0.04, verbose=false)
    ψ = out.psi
    fx, fy, fz = spin_density_vector(ψ, ws.spin_matrices, 3)
    n = dropdims(sum(abs2, ψ; dims=4); dims=4)
    Ntot = sum(n)
    fmag = @. sqrt(fx^2 + fy^2 + fz^2)
    FxN = sum(fx) / Ntot
    FyN = sum(fy) / Ntot
    FzN = sum(fz) / Ntot
    FmagN = sum(fmag) / Ntot
    align = sum(fx) / (sum(fmag) + eps())     # Σf_x / Σ|f|
    # local polar angle from +x, where there is appreciable spin density
    mask = fmag .> 1e-6 * maximum(fmag)
    cosθ = clamp.(fx[mask] ./ fmag[mask], -1, 1)
    θ = acosd.(cosθ)
    w = fmag[mask]
    θ_mean = sum(w .* θ) / sum(w)
    θ_std = sqrt(sum(w .* (θ .- θ_mean) .^ 2) / sum(w))
    Lz = orbital_angular_momentum(ψ, ws.grid, ws.fft_plans) / Ntot
    @printf("%-7.1f %8.4f %8.4f %8.4f %10.4f %10.5f %9.3f %9.3f %9.2e\n",
        B, FxN, FyN, FzN, FmagN, align, θ_mean, θ_std, Lz)
    flush(stdout)
end
println("\nRead: align≈1, |F|/N≈F=6, θ_std≈0 ⇒ UNIFORM x-ferromagnet (no texture)")
println("      ⇒ the whole Ω=0 B-axis is ONE canting crossover; retire the PCV label.")
println("      align<1 / large θ_std ⇒ genuine texture, characterise separately.")

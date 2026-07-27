# Is the trap-shaping Einstein–de Haas transfer QUANTISED?
#
# A κ ramp conserves J_z (the trap is axially symmetric), and it moves ⟨L_z⟩ and
# ⟨S_z⟩ by what looked like exactly one unit at κ: 0.8 → 1.8. Two readings of that
# would look identical in ⟨L_z⟩ alone:
#
#   (a) quantised — the depolarised components each carry an integer phase winding
#       ℓ_m, and the orbital angular momentum is the population-weighted sum Σ n_m ℓ_m
#       (the Matsui/Kozuma EdH signature, driven here by TRAP SHAPE, not by a field);
#   (b) smooth   — the texture merely rotates, carrying a non-integer circulation.
#
# The discriminator is the identity  ⟨L_z⟩ = Σ_m n_m ℓ_m.  If it holds, every bit of
# the transferred angular momentum sits in quantised vortices; the residual measures
# how much does not.
#
# Reads the endpoint ψ of each κ_1 run written by eu_kappa_ramp_protocol.jl with
# KR_SAVE_PSI=1, and reports per-κ_1: ⟨L_z⟩, ⟨S_z⟩, per-component populations and
# windings, Σ n_m ℓ_m, and the residual.
#
# Env:
#   EW_ROOT=figs/eu_kappa_scan      dir holding k<κ_1>/B<B>/…_final.jld2
#   EW_OUT=figs/eu_kappa_scan/edh_quantisation.csv
#   EW_THRESH=1e-3                  density floor (relative to peak) for phase reads
#
#   julia --project=. scripts/eu_kappa_edh_winding.jl

using SpinorBEC
using SpinorBEC: Grid, GridConfig, make_grid, SpinSystem, make_fft_plans,
    winding_number_field, orbital_angular_momentum, magnetization,
    component_populations, cell_volume
using DelimitedFiles: writedlm
using JLD2: jldopen
using Printf

const ROOT = get(ENV, "EW_ROOT", "figs/eu_kappa_scan")
const OUT = get(ENV, "EW_OUT", joinpath(ROOT, "edh_quantisation.csv"))
const THRESH = haskey(ENV, "EW_THRESH") ? parse(Float64, ENV["EW_THRESH"]) : 1e-3

"""Population-weighted winding of one component, read in the z-midplane.

The winding field is per-plaquette and per-z-slice; the midplane is where the
condensate is densest, so its plaquette sum is the cleanest integer. Summing the
plaquette field over the plane counts the enclosed charge, and the density mask
keeps vacuum phase noise out of it."""
function component_winding(psi, grid, c::Int, dens_peak::Float64)
    w = winding_number_field(psi, grid; component=c, threshold=THRESH * dens_peak)
    kz = size(psi, 3) ÷ 2 + 1
    sum(view(w,:,:,kz))
end

rows = Any[]
for kdir in sort(filter(isdir, readdir(ROOT; join=true)))
    for bdir in sort(filter(isdir, readdir(kdir; join=true)))
        for f in sort(filter(p -> endswith(p, "_final.jld2"), readdir(bdir; join=true)))
            d = jldopen(f, "r") do io
                (; psi=Array{ComplexF64}(io["psi"]), k1=io["kappa_1"], k0=io["kappa_0"],
                    tau=io["tau"], B=io["B_uG"], n=io["grid_n_points"],
                    box=io["grid_box_size"])
            end
            grid = make_grid(GridConfig(Tuple(d.n), Tuple(d.box)))
            sys = SpinSystem(6)
            plans = make_fft_plans(grid.config.n_points)
            Lz = orbital_angular_momentum(d.psi, grid, plans)
            Sz = magnetization(d.psi, grid, sys)
            pops = component_populations(d.psi, grid, sys).populations
            dens_peak = maximum(sum(abs2, d.psi; dims=4))
            ws = [component_winding(d.psi, grid, c, dens_peak) for c in 1:size(d.psi, 4)]
            # only components carrying real population can define a winding
            keep = pops .> 1e-4
            Lz_quant = sum(pops[keep] .* ws[keep])
            push!(
                rows,
                (; kappa_0=d.k0, kappa_1=d.k1, tau=d.tau, B_uG=d.B,
                    Lz, Sz, Jz=Lz + Sz, Lz_quantised=Lz_quant, residual=Lz - Lz_quant,
                    n_components_kept=count(keep),
                    windings=join(string.(ws[keep]), "|"),
                    pops=join((@sprintf("%.4f", p) for p in pops[keep]), "|")),
            )
            @printf(
                "κ_1=%.2f  ⟨L_z⟩=%+.4f  Σ n_m ℓ_m=%+.4f  residual=%+.4f  ⟨S_z⟩=%+.4f  J_z=%+.4f\n",
                d.k1, Lz, Lz_quant, Lz - Lz_quant, Sz, Lz + Sz)
            @printf("           ℓ = [%s]\n           n = [%s]\n",
                join(string.(ws[keep]), ", "),
                join((@sprintf("%.3f", p) for p in pops[keep]), ", "))
            flush(stdout)
        end
    end
end

if isempty(rows)
    @warn "no *_final.jld2 under $ROOT — run the κ_1 scan with KR_SAVE_PSI=1"
else
    sort!(rows; by=r -> r.kappa_1)
    ks = collect(keys(rows[1]))
    open(OUT, "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for r in rows
            writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
        end
    end
    println("\nwrote $OUT")
    println("""
    Read it as: if ⟨L_z⟩ tracks Σ n_m ℓ_m with a small residual, the trap-shaping
    transfer is carried by quantised vortices and ⟨L_z⟩(κ_1) should be a STAIRCASE.
    A large residual means the texture is simply rotating and the '1 ħ' was a
    coincidence of this κ span.
    """)
end

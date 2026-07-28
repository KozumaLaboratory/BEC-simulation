# SHOWS: aspect ratio is an orthogonal lever separating c1 from DDI in Eu spin-mixing.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — c1-DDI separation).
# REPLACES: nothing (new; closes the campaign's one flagged unverified gap). Lib: eu_spinmix_lib.jl.
# c1-DDI orthogonal-separation test: does varying the trap ASPECT RATIO break the c1↔DDI
# degeneracy in Eu spin-mixing? DDI is anisotropic (geometry-dependent), contact c1 is isotropic.
# If the DDI-induced shift of the spin-mixing observable VARIES with aspect ratio λ, then two
# geometries give independent constraints ⇒ c1 (λ-independent) and c_dd (λ-dependent) separable.
# Builds on the workflow's spinmix.jl machinery.

include(joinpath(@__DIR__, "eu_spinmix_lib.jl"))
using Statistics

# spin-mixing observable: peak-to-peak of ⟨Fz²⟩(t)=Σ m² N_m over the quench (m from +F..-F).
function fz2_amplitude(times, pops)
    D = size(pops, 1); F = ATOM.F
    ms = [F - (c - 1) for c in 1:D]              # c=1 → m=+F
    fz2 = [sum(ms .^ 2 .* pops[:, k]) for k in 1:size(pops, 2)]
    (maximum(fz2) - minimum(fz2), fz2)
end

function run_case(λ; c1=C1_BASE, Bg=0.1, ddi=true, ni=1200, nq=1400, se=40)
    grid = SB.make_grid(SB.GridConfig(NPTS, BOX))
    pot = SB.HarmonicTrap{3}((1.0, 1.0, λ))       # aspect ratio λ = ωz/ωr
    psi_r = relax_envelope(grid, pot; c1=c1, n_steps=ni)
    psi_t = transverse_from_envelope(psi_r, grid)
    q = qval(Bg)
    t, p = run_quench(grid, pot, psi_t; c1=c1, q=q, enable_ddi=ddi, n_steps=nq, save_every=se)
    amp, _ = fz2_amplitude(t, p)
    amp
end

const OUT = length(ARGS) >= 1 ? ARGS[1] : "c1ddi_out"
mkpath(OUT)
const SMOKE = length(ARGS) >= 2 && ARGS[2] == "smoke"
lambdas = SMOKE ? [1.0] : [0.5, 1.0, 2.0]        # prolate(cigar) / iso / oblate(pancake)
ni = SMOKE ? 250 : 1200; nq = SMOKE ? 300 : 1400

@printf("λ      amp(DDI on)   amp(DDI off)   DDI shift = (on-off)/off\n")
open(joinpath(OUT, "c1_ddi_ortho.csv"), "w") do io
    println(io, "lambda,amp_ddi_on,amp_ddi_off,ddi_shift")
    for λ in lambdas
        aon = run_case(λ; ddi=true, ni=ni, nq=nq)
        aoff = run_case(λ; ddi=false, ni=ni, nq=nq)
        shift = (aon - aoff) / max(aoff, 1e-12)
        @printf("%.2f   %.4e    %.4e    %+.3f\n", λ, aon, aoff, shift)
        @printf(io, "%.3f,%.6e,%.6e,%.5f\n", λ, aon, aoff, shift)
        flush(stdout)
    end
end
println("VERDICT: if the DDI shift changes with λ, aspect ratio is a valid orthogonal lever ",
        "(multi-geometry fit separates c1 from c_dd). If ~constant, it is not.")

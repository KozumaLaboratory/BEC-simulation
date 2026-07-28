# SHOWS: single-λ spin-mixing sensitivity (∂lnA/∂ln c1, ∂lnA/∂ln c_dd) — the Fisher rows
#        feeding the aspect-ratio c1-extraction design. Run at λ=0.5,1.0,2.0; plot combines them.
# DOC:   docs/guides/eu_evaporation_optimization.md ("Experimental campaign" — c1-DDI separation).
# REPLACES: nothing (new). Lib: eu_spinmix_lib.jl. Usage: julia eu_aspect_sensitivity.jl <λ> <out.csv>.
# Single-λ sensitivity (∂lnA/∂lnc1, ∂lnA/∂lncdd) at ONE aspect ratio, small + fast.
# Completes the Fisher design: λ=0.5,1.0 already measured; this fills λ from ARGS.
include(joinpath(@__DIR__, "eu_spinmix_lib.jl"))
using Printf

function amplitude(λ; c1, md, Bg=0.1, ni, nq)
    grid = SB.make_grid(SB.GridConfig(NPTS, BOX))
    pot = SB.HarmonicTrap{3}((1.0, 1.0, λ))
    psi_r = relax_envelope(grid, pot; c1=c1, n_steps=ni)
    psi_t = transverse_from_envelope(psi_r, grid)
    q = qval(Bg); sys = SB.SpinSystem(ATOM.F)
    inter = SB.InteractionParams(Dict{Int,Float64}(0 => C0, 1 => c1))
    sp = SB.SimParams(; dt=0.005, n_steps=nq, imaginary_time=false, save_every=40)
    ws = SB.make_workspace(; grid=grid, atom=ATOM, interactions=inter,
        zeeman=SB.ZeemanParams(0.0, q), potential=pot, sim_params=sp, psi_init=copy(psi_t),
        enable_ddi=true, c_dd=md * C_DD, secular_ddi=false)
    F = ATOM.F; D = sys.n_components; ms = [F - (c - 1) for c in 1:D]
    fz2 = Float64[]
    cb = SB.SimulationCallbacks(; on_snapshot=(w, s, sn) -> push!(fz2,
        sum(ms .^ 2 .* SB.component_populations(w.state.psi, grid, sys).populations)))
    SB.run_simulation!(ws; callbacks=cb)
    maximum(fz2) - minimum(fz2)
end

λ = parse(Float64, ARGS[1])
out = ARGS[2]
ni = 900; nq = 1000; dc1 = 0.05; dmd = 0.10
A0 = amplitude(λ; c1=C1_BASE, md=1.0, ni=ni, nq=nq)
Ap1 = amplitude(λ; c1=C1_BASE * (1 + dc1), md=1.0, ni=ni, nq=nq)
Apd = amplitude(λ; c1=C1_BASE, md=1.0 + dmd, ni=ni, nq=nq)
s1 = (Ap1 - A0) / A0 / dc1; sd = (Apd - A0) / A0 / dmd
@printf("λ=%.2f: A0=%.4e s1=%+.5f sd=%+.5f\n", λ, A0, s1, sd)
open(out, "w") do io
    @printf(io, "%.3f,%.6e,%.5f,%.5f\n", λ, A0, s1, sd)
end

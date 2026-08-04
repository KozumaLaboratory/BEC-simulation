# WHERE does `lhy = none` stop reaching a ground state?
#
# One measured point is not a criterion. `bench/itp_fused_chain_accuracy.jl` found
# every arm NaN at Eu F=6, c_dd = 211, c₁/c₀ = −0.05, lhy = none — and at +0.05 it
# ran the step cap to a different state (E = 7.86 against 776.7 with a table).
# From that I started counting configs that share the COMBINATION, which counts my
# own regex rather than affected runs: `runs/matsui_fig4b/*` is ITP + DDI + no LHY
# and that arc reached a resolved answer, so it plainly did not diverge.
#
# So the useful artifact is the BOUNDARY, not a tally. This sweeps the dipolar
# strength and the spin coupling at fixed everything else and reports, for each
# point, whether a short ITP stays finite — cheap, because divergence shows up in
# a few hundred steps, not at convergence.
#
# It deliberately does NOT run to convergence: the question is "does the state
# leave the finite range", and a run that is merely slow answers it the same way a
# converged one does.
#
#   julia --project=. bench/lhy_none_divergence_boundary.jl [n] [steps]

using Printf
import CUDA
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
# 800, not 3000. Divergence is a fast event — the c₁ = −0.05 cell NaNs long
# before then — and the measured cost of a row was dominated by 7 fresh
# `make_workspace` calls (padded DDI buffers + FFT plans), not by the stepping.
# Stepping less keeps every cell rather than thinning the sweep.
const STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 800
const DT = 0.002
const TIMING_LOG = get(ENV, "SPINORBEC_CELL_TIMING",
    joinpath(get(ENV, "SPINORBEC_GAP_CACHE", tempdir()), "boundary_cell_timing.log"))

"Run a short ITP and report what happened to the state, not whether it converged."
function probe(; c1_ratio, cdd_scale, lhy)
    grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    ws = try
        make_workspace(;
            grid, atom=Eu151, interactions=eu_interaction_params(c1_ratio),
            zeeman=ZeemanParams(EU_p_weak, 0.0),
            potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
            sim_params=SimParams(; dt=DT, n_steps=1, imaginary_time=true,
                save_every=10^9),
            psi_init=psi0, enable_ddi=true, c_dd=cdd_scale * EU_c_dd,
            ddi_padding=true, ddi_trunc_radius=-1.0,
            spinor_lhy=(lhy === :none ? nothing : lhy), backend=CUDABackend())
    catch e
        # A closed form that REFUSES is a distinct outcome from one that blows up,
        # and folding them together is what made `lhy=none` look like the only
        # option at c₁ < 0.
        return (:refused, NaN)
    end
    nc = ws.spin_matrices.system.n_components
    psi = ws.state.psi
    SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
    for _ in 1:STEPS
        SpinorBEC._outer_potential_fwd!(ws, DT / 4, nc, 3, true)
        SpinorBEC._ddi_step!(ws, DT / 2, 3, true)
        SpinorBEC._outer_potential_bwd!(ws, DT / 4, nc, 3, true)
        SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), psi, 0.0, false, ws)
        SpinorBEC._outer_potential_fwd!(ws, DT / 4, nc, 3, true)
        SpinorBEC._ddi_step!(ws, DT / 2, 3, true)
        SpinorBEC._outer_potential_bwd!(ws, DT / 4, nc, 3, true)
        SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
    end
    CUDA.synchronize()
    E = SpinorBEC.total_energy(ws)
    isfinite(E) || return (:diverged, NaN)
    (:finite, E)
end

println("="^78)
println("`lhy = none` divergence boundary — Eu F=6 D=13, $(N_GRID)³, $(STEPS) ITP steps")
println("c_dd scale 1.0 = the production $(round(EU_c_dd; sigdigits=4))")
println("="^78)

# THE SWEEP IS OVER-SCOPED FOR WHAT IS LEFT TO ASK. Three c_dd scales are already
# measured to diverge at c₁ = −0.05 — 0.0 and 0.1 here, and 1.0 from
# `bench/itp_fused_chain_accuracy.jl` — so "does the dipole move the boundary" is
# answered: it does not. What is NOT known is where between −0.05 and −0.02 the
# boundary sits, and that needs c₁ refinement at ONE c_dd, not a grid.
#
# Two full-grid attempts were killed at the wall clock with 2 of 5 rows, and
# cutting the step count 3000 → 800 changed nothing — which confirms the cost is
# per-CELL workspace construction and not the stepping, and means the fix has to
# remove cells rather than steps. 35 cells → 8.
const C1S = (-0.05, -0.045, -0.04, -0.035, -0.03, -0.025, -0.02, 0.0)
const SCALES = (1.0,)

for lhy in (:none, :polar_contact)
    println("\n--- lhy = $lhy   (cells: finite E, DIVERGED, or REFUSED at build)")
    flush(stdout)
    @printf("  %-10s", "c_dd×")
    for c1 in C1S
        @printf(" %11s", "c₁=$(c1)")
    end
    println()
    for sc in SCALES
        @printf("  %-10.2f", sc)
        for c1 in C1S
            t0 = time()
            st, E = probe(; c1_ratio=c1, cdd_scale=sc, lhy)
            # Per-cell timing to a FILE, not to stderr: the job script redirects
            # `2>&1` into the same pipe, so stderr lands mid-row and mangles the
            # table it was added to explain.
            open(TIMING_LOG, "a") do io
                @printf(io, "cell c1=%+.3f cdd=%.2f lhy=%-14s %7.1f s  %s\n",
                    c1, sc, lhy, time() - t0, st)
            end
            # Reclaim per CELL, not per row: seven 32³ padded-DDI workspaces
            # accumulating inside one row is what took maxvmem to 205 G.
            GC.gc(true)
            CUDA.reclaim()
            @printf(" %11s", st === :finite ? @sprintf("%.4g", E) :
                              st === :diverged ? "DIVERGED" : "refused")
        end
        println()
        # Flush. Third bench in this session to need it said explicitly: Julia
        # block-buffers stdout to a pipe, so a row that has finished is invisible
        # until the buffer fills, and the run looks stalled. `grep
        # --line-buffered` only fixes the DOWNSTREAM half.
        flush(stdout)
        GC.gc(true)
        CUDA.reclaim()
    end
end

println("""

[read] A `refused` cell is the closed form declining to extrapolate, which is a
different event from `DIVERGED` and must not be read as one — conflating them is
what made `lhy = none` look like the only option at c₁ < 0.

What this is FOR: the earlier finding was one diverging point, and counting the
configs that share its combination counts a regex, not affected runs — the
`matsui_fig4b` arc is ITP + DDI + no LHY and reached a resolved answer. A boundary
in (c_dd, c₁) says which configs are actually near it; a tally never could.""")

# Calibrate the guard's threshold instead of guessing it.
#
# The defect: in a free-space droplet the ITP fixed point is set by dt, not by the
# Hamiltonian (see a7). What makes that regime different from a trapped gas is
# that the total energy is a small residual of large, nearly cancelling terms —
# contact +31340 against DDI -37608 for a net -6268 — so the O(dt^p) splitting
# error is large compared with the quantity being minimised.
#
# The candidate diagnostic is therefore a CANCELLATION RATIO
#
#     R = |E_total| / sum_terms |E_term|
#
# small R = the answer is a small difference of big numbers. This script measures R
# on both sides of the known behaviour: the droplet cells (where ITP is wrong) and
# the trapped cases from a6 (where ITP and L-BFGS agree to ~1e-6). A threshold is
# only worth having if those two populations separate.

using SpinorBEC
using Printf

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

"R = |E_total| / Σ|E_term| over the registry's energy decomposition."
function cancellation_ratio(e)
    terms = (:kinetic, :trap, :density, :spin, :ddi, :lhy, :zeeman, :singlet_pair, :tensor)
    s = 0.0
    for k in terms
        hasproperty(e, k) || continue
        v = getproperty(e, k)
        v isa Number && (s += abs(v))
    end
    (; R=(s > 0 ? abs(e.total) / s : NaN), sum_abs=s, total=e.total)
end

function droplet_row(name; n=48, box_sigma=2.5)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=b.psi0)
    (; label="droplet $name (free space)", cancellation_ratio(energy_decomposition(ws))...)
end

function trap_row(; label, c0, c_lhy, c_dd, n=32, box=12.0, omega=(1.0, 1.0, 1.0), F=1)
    atom = AtomSpecies("probe", SpinorBEC.Units.AMU * 151, F,
        100 * SpinorBEC.Units.BOHR_RADIUS, 0.0,
        4.5 * SpinorBEC.Units.BOHR_MAGNETON, 4.5)
    grid = make_grid(GridConfig{3}((n, n, n), (box, box, box)))
    psi0 = init_psi(grid, SpinSystem(F); state=:spin_coherent, init_theta=π / 2,
        init_phi=π / 2, init_vortex_charge=1)
    ws = make_workspace(; grid, atom,
        interactions=InteractionParams(Dict(0 => c0); c_lhy=c_lhy),
        zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap(omega),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=(c_dd != 0), c_dd=Float64(c_dd), secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=psi0)
    (; label=label, cancellation_ratio(energy_decomposition(ws))...)
end

println("="^92)
println("CANCELLATION RATIO  R = |E_total| / Σ|E_term|   (small R = stiff: a small")
println("residual of large terms, where the split-step ITP fixed point moves with dt)")
println("="^92)
@printf("%-42s %12s %14s %12s\n", "configuration", "E_total", "Σ|E_term|", "R")
println("-"^92)
rows = []
for nm in ("P0", "P1", "C1", "C0")
    r = droplet_row(nm)
    push!(rows, (; r..., stiff=true))
    @printf("%-42s %12.3f %14.3f %12.5f\n", r.label, r.total, r.sum_abs, r.R)
end
println()
for (lab, c0, cl, cd) in (("trap: contact only", 500.0, 0.0, 0.0),
    ("trap: contact + scalar LHY", 500.0, 500.0, 0.0),
    ("trap: contact + DDI", 500.0, 0.0, 200.0),
    ("trap: contact + LHY + DDI", 500.0, 500.0, 200.0),
    ("trap: contact + strong DDI", 500.0, 0.0, 450.0))
    r = trap_row(; label=lab, c0=c0, c_lhy=cl, c_dd=cd)
    push!(rows, (; r..., stiff=false))
    @printf("%-42s %12.3f %14.3f %12.5f\n", r.label, r.total, r.sum_abs, r.R)
end
println("-"^92)
stiff = [r.R for r in rows if r.stiff]
soft = [r.R for r in rows if !r.stiff]
@printf("  stiff (ITP known wrong): max R = %.5f\n", maximum(stiff))
@printf("  soft  (ITP known right): min R = %.5f\n", minimum(soft))
sep = minimum(soft) / maximum(stiff)
@printf("  separation = %.1f x  %s\n", sep,
    sep > 3 ? "-> a threshold between them is meaningful" :
    "-> populations OVERLAP; R is the wrong diagnostic, do not gate on it")
@printf("\n  suggested threshold: R < %.2f  (geometric mean of the two extremes)\n",
    sqrt(maximum(stiff) * minimum(soft)))

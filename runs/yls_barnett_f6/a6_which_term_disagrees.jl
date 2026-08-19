# Which Hamiltonian term makes ITP and the energy functional disagree?
#
# Established: seeded with the same state, in free space with
# contact + scalar LHY + full DDI at F=1,
#   ITP    -> E = -653.8, rho_max =  7101 D0     (energy RISES from the seed's -770)
#   L-BFGS -> E = -885.2, rho_max = 12714 D0     (grad_norm 1e-7; paper says 13000)
# L-BFGS minimises `energy_gradient!`, which is FD-gated against
# `energy_contribution`. ITP walks `apply_step!`. Those are different faces of the
# same term, and the repo's FD oracle covers energy<->operator, NOT
# energy<->propagator. So one term's propagator disagrees with its energy.
#
# This probe turns the terms on one at a time in a HARMONIC TRAP (so every
# combination has a bound state and both minimisers have somewhere to go) and
# reports the ITP-vs-L-BFGS energy gap per combination. The first combination that
# disagrees names the term.
#
# Positive control: contact-only in a trap is the textbook Thomas-Fermi case; if
# THAT disagrees the probe itself is broken.

using SpinorBEC
using Printf

const A6_N = 15000

function one_case(; label, c0, c_lhy, c_dd, n=48, box=12.0, omega=(1.0, 1.0, 1.0),
    dt=1e-3, n_steps=20000, gpu=true, F=1)
    atom = AtomSpecies("probe", SpinorBEC.Units.AMU * 151, F,
        100 * SpinorBEC.Units.BOHR_RADIUS, 0.0,
        4.5 * SpinorBEC.Units.BOHR_MAGNETON, 4.5)
    grid = make_grid(GridConfig{3}((n, n, n), (box, box, box)))
    pot = HarmonicTrap(omega)
    ip = InteractionParams(Dict(0 => c0); c_lhy=c_lhy)
    # seed: spin-coherent along y with an azimuthal texture, so DDI sees a real
    # spin texture rather than a uniform polarisation
    sys = SpinSystem(F)
    psi0 = init_psi(grid, sys; state=:spin_coherent, init_theta=π / 2,
        init_phi=π / 2, init_vortex_charge=1)
    common = (; grid, atom, interactions=ip, zeeman=ZeemanParams(0.0, 0.0),
        potential=pot, psi_init=psi0,
        enable_ddi=(c_dd != 0), c_dd=Float64(c_dd), secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        backend=(gpu ? CUDABackend() : CPUBackend()), verbose=false)
    itp = find_ground_state(; common..., dt=dt, n_steps=n_steps, tol=1e-11,
        save_every=n_steps ÷ 4)
    lb = find_ground_state(; common..., method=:lbfgs, n_steps=3000, tol=1e-10)
    gap = (itp.energy - lb.energy) / abs(lb.energy)
    @printf("%-28s c0=%7.1f c_lhy=%8.1f c_dd=%7.2f | ITP %+12.6f  LBFGS %+12.6f  gap %+9.2e %s\n",
        label, c0, c_lhy, c_dd, itp.energy, lb.energy, gap,
        abs(gap) < 1e-4 ? "agree" : "<-- DISAGREE")
    flush(stdout)
    (; label, itp=itp.energy, lbfgs=lb.energy, gap)
end

function main_a6(; gpu=true)
    println("="^120)
    println("ITP vs L-BFGS, one term at a time, in a harmonic trap (both have a bound state)")
    println("  gap = (E_ITP - E_LBFGS)/|E_LBFGS|. ITP cannot be ABOVE the minimiser unless")
    println("  its propagator is not the gradient flow of the reported energy.")
    println("="^120)
    rows = []
    push!(rows, one_case(; label="contact only (pos. control)", c0=500.0, c_lhy=0.0, c_dd=0.0, gpu=gpu))
    push!(rows, one_case(; label="contact + scalar LHY", c0=500.0, c_lhy=500.0, c_dd=0.0, gpu=gpu))
    push!(rows, one_case(; label="contact + DDI", c0=500.0, c_lhy=0.0, c_dd=200.0, gpu=gpu))
    push!(rows, one_case(; label="contact + LHY + DDI", c0=500.0, c_lhy=500.0, c_dd=200.0, gpu=gpu))
    push!(rows, one_case(; label="LHY only", c0=0.0, c_lhy=500.0, c_dd=0.0, gpu=gpu))
    push!(rows, one_case(; label="DDI only", c0=0.0, c_lhy=0.0, c_dd=200.0, gpu=gpu))
    println("="^120)
    bad = filter(r -> abs(r.gap) >= 1e-4, rows)
    if isempty(bad)
        println("  All combinations agree in the trap: the free-space droplet case must be")
        println("  reproduced here before the term can be named.")
    else
        println("  disagreeing combinations: ", join((r.label for r in bad), " | "))
    end
    rows
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_a6()

# Wiring positive control, before any ITP: does THIS code reproduce the paper's
# DDI normalization?
#
# For any fully polarized, divergence-free (flux-closure) magnetization
# M = mu_tot * rho * nhat, the dipolar kernel's transverse part vanishes
# (k . M_k = 0) and only the -1/3 trace piece survives:
#
#     E_ddi = -(c_dd/6) int |f|^2 dr = -(a_dd/a_s) * E_s = -eps_dd * E_s
#
# with a_dd = mu_0 mu_tot^2 M / (12 pi hbar^2) built from the TOTAL moment
# mu_tot = g_F F mu_B. This is Eq. (S7) of Yan-Li-Saito 2026, and it is exact,
# F-generic and scale-free -- so it is a hard gate on:
#   * the DDI prefactor convention (c_dd = mu_0 (g_F mu_B)^2, no 4 pi)
#   * the F^2 supplied by the spin operators rather than by c_dd
#   * the eps_dd bookkeeping (total moment, not per-unit-spin)
#   * the contact coefficient c_0 = 4 pi (a_s/a_ho) N
# and it is exactly the ratio the whole eps_dd > 1 self-binding threshold
# rests on. A factor of 4 pi, or an F^2, anywhere in that chain shows up here.
#
# The gate carries its own probes: a flux-closure texture must give -eps_dd,
# and a uniformly z-polarized cloud of the SAME density must not (its
# div M != 0, so the transverse part contributes). A test that cannot fail
# proves nothing.

using SpinorBEC
using Printf

const a0 = SpinorBEC.Units.BOHR_RADIUS

"""
Torus density profile of the paper's variational ansatz (Eq. S5):
    rho(r,z) ∝ r^(2 lam) exp(-r^2/sr^2 - z^2/sz^2)
carrying the flux-closure spin texture exp(-i S_z phi) zeta^(y), i.e. spins
polarized along the local azimuthal direction. `texture=:uniform_z` swaps that
for a z-polarized spinor at the same density (the negative control).
"""
function flux_closure_torus(grid::Grid{3}, F::Int; lam=1.5, sr=1.0, sz=0.87,
    texture::Symbol=:flux_closure)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    sm = spin_matrices(F)
    U_y = exp(-1im * (π / 2) * Matrix(sm.Fy))
    c_base = U_y[:, 1]                     # |m_y = +F> in the m_z basis
    @inbounds for I in CartesianIndices(n_pts)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        r2 = x^2 + y^2
        amp = sqrt(r2^lam * exp(-r2 / sr^2 - z^2 / sz^2))
        phi = atan(y, x)
        for c in 1:D
            m = F - (c - 1)
            psi[I, c] = if texture === :flux_closure
                amp * c_base[c] * cis(-m * (phi + π / 2))
            else
                amp * (c == 1 ? 1.0 + 0im : 0.0im)
            end
        end
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

"E_ddi / E_contact for the given atom, at eps_dd fixed by choice of a_s."
function ratio(atom_base::AtomSpecies; eps_dd::Float64, n::Int, box::Float64,
    texture::Symbol, N_atoms::Int=15000, omega_ref::Float64=100.0, padding::Bool=true)
    F = atom_base.F
    a_dd = SpinorBEC.compute_a_dd(atom_base)
    a_s = a_dd / eps_dd
    atom = AtomSpecies(atom_base.name, atom_base.mass, F, a_s, 0.0,
        atom_base.mu_mag, atom_base.g_F)
    a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
    c0 = 4π * (a_s / a_ho) * N_atoms
    c_dd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N_atoms, omega_ref=omega_ref)

    grid = make_grid(GridConfig{3}((n, n, n), (box, box, box)))
    psi0 = flux_closure_torus(grid, F; texture=texture)
    ws = make_workspace(;
        grid, atom,
        interactions=InteractionParams(Dict(0 => c0)),   # c0 only, c1 = 0 (paper's model)
        zeeman=ZeemanParams(0.0, 0.0),
        potential=NoPotential(),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=true, c_dd=c_dd, secular_ddi=false,
        ddi_padding=padding, ddi_trunc_radius=-1.0,
        psi_init=psi0,
    )
    e = energy_decomposition(ws)
    (; E_s=e.density, E_ddi=e.ddi, ratio=e.ddi / e.density, eps_dd=eps_dd,
        a_s_over_a0=a_s / a0, c0=c0, c_dd=c_dd)
end

println("="^80)
println("FLUX-CLOSURE DDI IDENTITY   E_ddi / E_contact = -eps_dd   (paper Eq. S7)")
println("="^80)
println("  exact for any divergence-free fully polarized magnetization;")
println("  a_dd from the TOTAL moment mu = g_F F mu_B.")
println()
@printf("%-22s %-4s %-5s %-8s %11s %11s %9s %8s\n",
    "atom", "F", "n", "eps_dd", "E_contact", "E_ddi", "ratio", "dev %")
println("-"^80)

rows = []
for (label, atom) in (("Eu151_f1_effective", SpinorBEC.Eu151_f1_effective),
    ("Eu151 (F=6)", SpinorBEC.Eu151))
    for eps in (1.2, 0.5402)
        for n in (48, 64, 80)
            r = ratio(atom; eps_dd=eps, n=n, box=12.0, texture=:flux_closure)
            dev = 100 * (abs(r.ratio) - eps) / eps
            @printf("%-22s %-4d %-5d %-8.4f %11.4f %11.4f %9.5f %+8.2e\n",
                label, atom.F, n, eps, r.E_s, r.E_ddi, r.ratio, dev)
            push!(rows, (; label, F=atom.F, n, eps, r.ratio, dev))
        end
    end
end

println()
println("NEGATIVE CONTROL --- same density, spins uniformly along z (div M != 0).")
println("If this also returns -eps_dd the gate is measuring nothing.")
@printf("%-22s %-4s %-5s %-8s %9s\n", "atom", "F", "n", "eps_dd", "ratio")
println("-"^80)
for (label, atom) in (("Eu151_f1_effective", SpinorBEC.Eu151_f1_effective),
    ("Eu151 (F=6)", SpinorBEC.Eu151))
    r = ratio(atom; eps_dd=1.2, n=64, box=12.0, texture=:uniform_z)
    @printf("%-22s %-4d %-5d %-8.4f %9.5f\n", label, atom.F, 64, 1.2, r.ratio)
end

println()
println("UNPADDED periodic kernel, for reference (production default is padded):")
for (label, atom) in (("Eu151_f1_effective", SpinorBEC.Eu151_f1_effective),
    ("Eu151 (F=6)", SpinorBEC.Eu151))
    r = ratio(atom; eps_dd=1.2, n=64, box=12.0, texture=:flux_closure, padding=false)
    @printf("  %-22s ratio = %9.5f  (dev %+.2f %%)\n", label, r.ratio,
        100 * (abs(r.ratio) - 1.2) / 1.2)
end

println()
println("="^80)
println("VERDICT")
println("="^80)
worst = maximum(abs(r.dev) for r in rows)
@printf("  worst |deviation| over F = {1,6} x eps_dd = {1.2, 0.5402} x n = {48,64,80}: %.2f %%\n",
    worst)
println(worst < 5 ?
        "  PASS: the repo's DDI + contact chain reproduces the paper's Eq. (S7)\n" *
        "        identity, so the eps_dd used by this campaign is the paper's eps_dd,\n" *
        "        at F=1 and at F=6 alike." :
        "  FAIL: the unit mapping or a prefactor is wrong -- do not run anything else.")

# Term-by-term differential check: our energy functional evaluated ON the paper's
# variational ansatz, against the paper's closed forms (Eqs. S6-S8) at the same
# (lambda, sigma_r, sigma_z).
#
# Why: the ITP relaxes AWAY from the variational droplet (peak density falls
# monotonically with imaginary time), and the grid/box scan showed that is not a
# resolution or box artifact (rho_max is grid-independent to 0.4 % and
# box-independent to 2 %). Either the true eGPE minimizer really is more diffuse
# than the ansatz, or one term of our functional has the wrong magnitude. Those
# two are distinguished without any time evolution at all: evaluate both
# expressions for the SAME wave function.
#
# This is a stronger gate than the flux-closure ratio (a3): that one is a ratio of
# contact to DDI and is blind to a wrong kinetic or LHY magnitude. Here every
# term is compared separately, so the answer names the term.

using SpinorBEC
using Printf
using SpecialFunctions: loggamma

include(joinpath(@__DIR__, "b_egpe_cells.jl"))

"Paper's closed-form terms (per particle, units hbar^2/(M L0^2))."
function analytic_terms(; lam, sr, sz, eps_dd, N, F, l)
    E_kin = 0.5 * ((2 + (F + 2 * l^2) / lam) / (2 * sr^2) + 1 / (2 * sz^2))
    E_s = exp(loggamma(lam + 0.5) - loggamma(lam + 1)) / (sqrt(2) * π * sr^2 * sz)
    E_ddi = -eps_dd * E_s
    lg = ((5 * lam + 17) / 2) * log(2) + log(lam) + loggamma(5 * lam / 2) -
         log(3) - (7 / 4) * log(π) - ((5 * lam + 3) / 2) * log(5) - 2.5 * loggamma(lam + 1)
    E_lhy = exp(lg) * lima_pelster_Q5(eps_dd) / (N * sr^3 * sz^1.5)
    (; kinetic=E_kin, density=E_s, ddi=E_ddi, lhy=E_lhy,
        total=E_kin + E_s + E_ddi + E_lhy)
end

function compare(name; n=96, box_sigma=2.5)
    cell = CELLS[name]
    b = build_cell(cell; n=n, box_sigma=box_sigma)
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=b.psi0)
    e = energy_decomposition(ws)
    a = analytic_terms(; lam=b.v.lambda, sr=b.v.sigma_r, sz=b.v.sigma_z,
        eps_dd=cell.eps_dd, N=cell.N, F=b.F, l=abs(cell.l))

    println("="^92)
    @printf("CELL %s  n=%d box=%.3f L0  dx=%.2e L0 | lambda=%.4f sr=%.5f sz=%.5f L0 (L0 units)\n",
        name, n, b.box / b.S, b.box / n / b.S, b.v.lambda, b.v.sigma_r, b.v.sigma_z)
    println("  energy per particle in hbar^2/(M L0^2); code values are E[hbar*omega]*S^2")
    println("="^92)
    @printf("%-10s %16s %16s %12s\n", "term", "code", "paper closed form", "code/paper")
    println("-"^92)
    for k in (:kinetic, :density, :ddi, :lhy)
        code = getproperty(e, k) * b.S^2
        ana = getproperty(a, k)
        @printf("%-10s %16.3f %16.3f %12.6f\n", String(k), code, ana, code / ana)
    end
    println("-"^92)
    @printf("%-10s %16.3f %16.3f %12.6f\n", "total", e.total * b.S^2, a.total,
        e.total * b.S^2 / a.total)
    println()
    (; code=e, analytic=a, S=b.S, b)
end

function main_a4(args)
    names = isempty(args) ? ["P0", "P1", "C1"] : args
    for nm in names
        # two resolutions: the discretization of a peaked r^(2 lambda) profile is
        # the only expected source of disagreement, so it must shrink with n.
        for n in (64, 96)
            compare(String(nm); n=n)
        end
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main_a4(ARGS)

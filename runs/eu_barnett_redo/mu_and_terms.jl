# What is mu, and which term makes it what it is?
#
# `run_core.jl` prints `mu = -log(nrm) / (2 GS_DT)`. Imaginary time gives
# nrm ~ 1 - mu*dt, so -log(nrm)/dt = mu and the printed number is mu/2. That matters:
# every length scale quoted from it moves by sqrt(2), and a claimed factor-2.2
# disagreement with the Thomas-Fermi value was really that factor of two.
#
# So mu is computed here the only way that cannot be misread: apply the Hamiltonian to
# the converged state and take the inner product. `apply_operator!` ACCUMULATES
# (out .+= H psi) and the caller zeroes out first, per the HamTerm protocol.
#
# The per-term energies come from `energy_decomposition`, which answers the second
# question at the same time: how much of mu the DDI removes for an in-plane-polarised
# cloud in a pancake trap (omega_z = 2 omega_perp), where the dipoles lie in the plane
# and the DDI is attractive along them.
using SpinorBEC
using Printf, FFTW, LinearAlgebra

const NPTS = (48, 48, 24)
const BOX = (28.0, 28.0, 18.0)
const OMEGA_TRAP = (1.0, 1.0, 2.0)
const N_ATOMS = 30000
const OMEGA_REF = 628.3
const B_GAUSS = 9.216e-4
const GS_DT = 0.004
const GS_STEPS = 4000

const ATOM = SpinorBEC.resolve_atom(:Eu151)
const D = 2 * ATOM.F + 1
const SM = spin_matrices(ATOM.F)
const GRID = make_grid(GridConfig(NPTS, BOX))
const DV = cell_volume(GRID)
const C0 = compute_c_total(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const C1 = -0.005 * C0
const C_DD = compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const EPS_DD = SpinorBEC.compute_a_dd(ATOM) / ATOM.a_s
const C_LHY = scalar_lhy_coefficient(ATOM.a_s / A_HO, N_ATOMS; eps_dd=EPS_DD)
const P_ZEE = SpinorBEC.Units.bfield_to_p(B_GAUSS, ATOM.g_F, OMEGA_REF)

const V_TRAP = let V = zeros(Float64, NPTS...)
    for I in CartesianIndices(V)
        V[I] = 0.5 * sum(OMEGA_TRAP[d]^2 * GRID.x[d][I[d]]^2 for d in 1:3)
    end
    V
end

function seed()
    chi = exp(-im * π * Matrix(SM.Fz)) * exp(-im * (π / 2) * Matrix(SM.Fy)) *
          ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:D]
    psi = zeros(ComplexF64, NPTS..., D)
    for k in axes(psi, 3), j in axes(psi, 2), i in axes(psi, 1)
        env = exp(-(GRID.x[1][i]^2 + GRID.x[2][j]^2 +
                    OMEGA_TRAP[3] * GRID.x[3][k]^2) / (2 * 2.5^2))
        for c in 1:D
            psi[i, j, k, c] = env * chi[c]
        end
    end
    psi ./ sqrt(sum(abs2, psi) * DV)
end

function build(; ddi::Bool, lhy::Bool)
    zee = TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
                              ConstantWaveform(P_ZEE), ConstantWaveform(0.0))
    ws = make_workspace(; grid=GRID, atom=ATOM,
        interactions=InteractionParams(Dict(0 => C0, 1 => C1);
                                       c_lhy=(lhy ? C_LHY : 0.0)),
        zeeman=zee, potential=NoPotential(),
        sim_params=SimParams(; dt=GS_DT, n_steps=GS_STEPS,
                             imaginary_time=true, normalize_every=0),
        psi_init=seed(), enable_ddi=ddi, c_dd=C_DD, backend=CPUBackend())
    copyto!(ws.potential_values, V_TRAP)
    ws
end

function relax!(ws)
    mu_printed = 0.0
    for _ in 1:GS_STEPS
        split_step!(ws)
        nrm = sqrt(sum(abs2, ws.state.psi) * DV)
        if nrm > 0
            mu_printed = -log(nrm) / (2 * GS_DT)
            ws.state.psi ./= nrm
        end
    end
    mu_printed
end

# mu from the operator itself: <psi|H_GP|psi> / <psi|psi>.
function mu_operator(ws)
    psi = ws.state.psi
    out = similar(psi); fill!(out, 0)
    for term in build_h_terms_registry(ws)
        apply_operator!(out, term, ws, psi)
    end
    real(sum(conj.(psi) .* out) * DV) / (sum(abs2, psi) * DV)
end

wbar = (OMEGA_TRAP[1] * OMEGA_TRAP[2] * OMEGA_TRAP[3])^(1 / 3)
mu_tf = (wbar / 2) * (15 * C0 / (4π))^0.4
@printf("grid %s   c0=%.1f c1=%.3f c_dd=%.3f c_lhy=%.4g eps_dd=%.4f\n",
        NPTS, C0, C1, C_DD, C_LHY, EPS_DD)
@printf("TF (contact only, from c0): mu = %.4f\n\n", mu_tf)

for (lbl, ddi, lhy) in (("contact only", false, false),
                        ("contact + LHY", false, true),
                        ("contact + DDI", true, false),
                        ("FULL (contact+DDI+LHY)", true, true))
    ws = build(; ddi, lhy)
    mp = relax!(ws)
    mo = mu_operator(ws)
    @printf("%-24s  printed mu/2 = %8.4f   2x = %8.4f   OPERATOR mu = %8.4f   mu/mu_TF = %.3f\n",
            lbl, mp, 2mp, mo, mo / mu_tf)
    if ddi && lhy
        ed = energy_decomposition(ws, ws.state.psi)
        println("\n  per-term energy of the FULL state:")
        for (k, v) in sort(collect(pairs(ed)), by=x -> -abs(last(x)) isa Number ? -abs(last(x)) : 0.0)
            v isa Number && @printf("    %-22s %+12.5f\n", k, v)
        end
    end
end

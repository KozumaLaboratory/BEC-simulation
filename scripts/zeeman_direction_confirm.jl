# Empirical confirmation of the Zeeman ground-state direction.
# Physical +Bz on a positive-g_F atom must give spin DOWN (moment ∥ B,
# angular momentum anti-∥ B). Exercises the production g_F → dimensionless
# chain (`_gauss_to_dimless`) then ITP, and reports the sign of ⟨F_z⟩.

using SpinorBEC

const OMEGA_REF = 2π * 1.0e6   # 1 MHz ref (keeps dimensionless bz ~ O(1))
const B_GAUSS = 1.0            # physical +Bz = +1 Gauss

function run_case(atom, label)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    bz = SpinorBEC._gauss_to_dimless(B_GAUSS, atom.g_F, OMEGA_REF)
    zeeman = TimeDependentZeeman(
        ConstantWaveform(bz),     # p = Bz (dominant)
        ConstantWaveform(0.0),    # q
        ConstantWaveform(0.05),   # Bx parity breaker
        ConstantWaveform(0.0),    # By
    )
    r = find_ground_state(;
        grid, atom,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman, potential=HarmonicTrap((1.0, 1.0, 1.0)),
        dt=0.01, n_steps=800, tol=0.0,
        initial_state=:spin_coherent,
        init_state_params=Dict(:init_theta => π / 2, :init_phi => 0.0),
        verbose=false, enable_ddi=false,
    )
    psi = Array(r.workspace.state.psi)
    sm = r.workspace.spin_matrices
    F = sm.system.F
    cv = cell_volume(grid)
    _, _, fz = spin_density_vector(psi, sm, 3)
    Fz = sum(fz) * cv

    nc = size(psi, ndims(psi))
    pops = [sum(abs2, selectdim(psi, ndims(psi), c)) * cv for c in 1:nc]
    mdom = F - (argmax(pops) - 1)

    code_dir = Fz > 0 ? "UP (m>0)" : "DOWN (m<0)"
    phys_dir = atom.g_F > 0 ? "DOWN (m<0)" : "UP (m>0)"  # +Bz: moment ∥ B
    verdict = (Fz > 0) == (atom.g_F > 0) ? "INVERTED ✗" : "matches physics ✓"

    println("="^64)
    println("$label   g_F = $(atom.g_F),  F = $F,  bz(dimless) = $(round(bz; digits=4))")
    println("  ⟨F_z⟩ = $(round(Fz; digits=4))   dominant m = $mdom")
    println("  CODE says   : $code_dir")
    println("  PHYSICS says: $phys_dir   (+Bz, moment aligns B ⇒ J anti-aligns)")
    println("  VERDICT     : $verdict")
end

run_case(He4star, "He4*  (g_F>0, pure electron spin S=1)")
run_case(Rb87, "Rb87  (g_F<0, F=1 lower manifold)")
println("="^64)

# Does the combined preconditioner P_C = P_V^½ P_K P_V^½ lower the L-BFGS
# gradient floor on the weak-field Eu+DDI soft manifold, vs the kinetic-only
# Sobolev preconditioner? Same ITP-warmed start, same step budget.
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem, CPUBackend
using Printf

const SMOKE = get(ENV, "PC_SMOKE", "") == "1"
geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
NX = SMOKE ? 16 : Int(geti("PC_GRID", 24))
ITP = SMOKE ? 200 : Int(geti("PC_ITP", 3000))
LBF = SMOKE ? 60 : Int(geti("PC_LBFGS", 600))
AV = geti("PC_AV", 10.0)
AK = geti("PC_AK", 1.0)

preset = eu151_preset(; n_pts=(NX, NX, NX), box=(24.0, 24.0, 24.0), trap_ratios=(1.0, 1.0, 1.1818))
sys = SpinSystem(preset.atom.F)
p_zee = Units.bfield_to_p(10.0 * 1e-6, preset.atom.g_F, preset.omega_ref)
common = (; grid=preset.grid, atom=preset.atom, interactions=preset.interactions,
    potential=preset.potential, zeeman=ZeemanParams(p_zee, 0.0), enable_ddi=true,
    c_dd=preset.c_dd, secular_ddi=false, backend=CPUBackend())

@printf("Precond compare: grid=%d^3 ITP=%d LBFGS=%d  α_V=%.1f α_K=%.1f\n", NX, ITP, LBF, AV, AK)

# shared ITP-warmed symmetry-broken start
psi0 = init_psi(preset.grid, sys; state=:m_plus_F)
add_white_noise!(psi0, 0.02, 1, preset.grid)
gs = find_ground_state(; common..., psi_init=psi0, dt=0.002, n_steps=ITP, tol=1e-12, verbose=false)
psi_start = Array{ComplexF64}(gs.workspace.state.psi)
@printf("ITP start: E=%.4f\n", gs.energy)

r_sob = find_ground_state_lbfgs(; common..., psi_init=copy(psi_start),
    n_steps=LBF, tol=1e-13, m_lbfgs=10, verbose=false)         # Sobolev (default)
r_pc = find_ground_state_lbfgs(; common..., psi_init=copy(psi_start),
    n_steps=LBF, tol=1e-13, m_lbfgs=10,
    precond_alpha_v=AV, precond_alpha_k=AK, verbose=false)      # combined P_C

@printf("\n  Sobolev (kinetic-only): E=%.6f  |gradE|=%.4e\n", r_sob.energy, r_sob.grad_norm)
@printf("  Combined P_C          : E=%.6f  |gradE|=%.4e\n", r_pc.energy, r_pc.grad_norm)
@printf("  grad floor ratio (PC/Sob) = %.3f   energy Δ = %+.2e\n",
    r_pc.grad_norm / r_sob.grad_norm, r_pc.energy - r_sob.energy)
println(r_pc.grad_norm < r_sob.grad_norm ? ">>> P_C LOWERS the grad floor" :
        ">>> P_C does NOT help (tune α_V/α_K)")
println("DONE")

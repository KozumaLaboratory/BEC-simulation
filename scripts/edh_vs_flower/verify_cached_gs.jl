# scripts/edh_vs_flower/verify_cached_gs.jl
# Load a cached LBFGS ground state (computed under an OLDER compute scheme on
# Tsubame) and recompute its energy + gradient norm under the CURRENT main
# Hamiltonian. If grad_norm stays at the cached value (~1e-3), the compute
# scheme is physically compatible and the cached asset is reusable; if it
# blows up, the scheme changed the physics and the asset must be recomputed.
#
# Usage: julia --project=. scripts/edh_vs_flower/verify_cached_gs.jl <gs.jld2>
using SpinorBEC
using SpinorBEC: eu151_preset, ZeemanParams, find_ground_state_lbfgs, Units,
                 CPUBackend
using JLD2, Printf

const GS = ARGS[1]
d = jldopen(GS, "r") do f
    (psi = ComplexF64.(f["psi"]), B = f["B_gauss"], n = f["grid_n"],
     box = f["grid_box"], N = f["n_atoms"], E0 = f["E"], g0 = f["grad_norm"],
     sha = f["git_sha"])
end
@printf("[verify] cached: B=%.4g G  grid=%s  box=%s  N=%d  E0=%.6g  grad0=%.3e\n",
    d.B, string(Tuple(d.n)), string(Tuple(d.box)), Int(d.N), d.E0, d.g0)

preset = eu151_preset(; n_atoms=Int(d.N), n_pts=Tuple(Int.(d.n)),
    box=Tuple(Float64.(d.box)), trap_ratios=(1.0, 1.0, 1.181818), omega_ref=691.1504)
p = Units.bfield_to_p(d.B * 1e-4, preset.atom.g_F, preset.omega_ref)  # Gauss→Tesla→p
zeeman = ZeemanParams(p, 0.0)

# n_steps=1: find_ground_state_lbfgs recomputes grad_norm at the *input* ψ
# (the spine G is evaluated at the returned ψ; one step barely moves it).
gl = find_ground_state_lbfgs(;
    grid=preset.grid, atom=preset.atom, interactions=preset.interactions,
    zeeman=zeeman, potential=preset.potential,
    psi_init=d.psi, n_steps=1, tol=1e-12, m_lbfgs=10, sobolev_alpha=0.5,
    enable_ddi=true, c_dd=preset.c_dd, secular_ddi=false,
    backend=CPUBackend(), verbose=false,
)
@printf("[verify] under CURRENT main:  E=%.6g  grad_norm=%.3e\n", gl.energy, gl.grad_norm)
@printf("[verify] ΔE/|E| = %.3e   grad ratio (new/old) = %.2f\n",
    abs(gl.energy - d.E0) / abs(d.E0), gl.grad_norm / d.g0)
println(gl.grad_norm < 5e-3 ? "[verify] VERDICT: scheme-compatible (still ~stationary)" :
                              "[verify] VERDICT: NOT stationary under current scheme — recompute")

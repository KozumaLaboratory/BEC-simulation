# Certify the weak-field Eu+DDI broken state: project the Goldstone
# (L_z+F_z)ψ out of the constrained-BdG spectrum and read the remaining
# λ_min sign. Goldstone-deflated λ_min > 0 ⇒ soft MINIMUM on the U(1)
# quotient; < 0 ⇒ a deeper saddle (more symmetry breaking needed) or the
# state is not stationary enough. Compares deflated vs un-deflated.
#
#   julia --project=. scripts/eu_goldstone_deflate.jl
#   GD_SMOKE=1 -> grid 16, tiny
using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem,
    constrained_hessian_params, trapped_bdg_low_modes, CPUBackend, make_fft_plans
using FFTW, Printf

const SMOKE = get(ENV, "GD_SMOKE", "") == "1"
geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
NX = SMOKE ? 16 : Int(geti("GD_GRID", 24))
ITP = SMOKE ? 300 : Int(geti("GD_ITP", 4000))
LBF = SMOKE ? 50 : Int(geti("GD_LBFGS", 800))
NITER = SMOKE ? 10 : Int(geti("GD_MAXITER", 40))
NEV = 4

preset = eu151_preset(; n_pts=(NX, NX, NX), box=(24.0, 24.0, 24.0), trap_ratios=(1.0, 1.0, 1.1818))
sys = SpinSystem(preset.atom.F)
p_zee = Units.bfield_to_p(10.0 * 1e-6, preset.atom.g_F, preset.omega_ref)
common = (; grid=preset.grid, atom=preset.atom, interactions=preset.interactions,
    potential=preset.potential, zeeman=ZeemanParams(p_zee, 0.0), enable_ddi=true,
    c_dd=preset.c_dd, secular_ddi=false, backend=CPUBackend())

@printf("Goldstone-deflated BdG certification: grid=%d^3\n", NX)
psi0 = init_psi(preset.grid, sys; state=:m_plus_F); add_white_noise!(psi0, 0.02, 1, preset.grid)
gs = find_ground_state(; common..., psi_init=psi0, dt=0.002, n_steps=ITP, tol=1e-12, verbose=false)
gl = find_ground_state_lbfgs(; common..., psi_init=Array{ComplexF64}(gs.workspace.state.psi),
    n_steps=LBF, tol=1e-13, m_lbfgs=10, verbose=false)
ws = gl.workspace; ψ = ws.state.psi
@printf("state: E=%.4f  |gradE|=%.3e\n", gl.energy, gl.grad_norm)

grid = preset.grid; n_pts = ntuple(d -> size(ψ, d), 3); D = size(ψ, 4); F = preset.atom.F
m_vals = Float64[F - (c - 1) for c in 1:D]
dV = prod(grid.dx); ipR(a, b) = real(sum(conj.(a) .* b)) * dV
plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
function Lz_apply(ψ)
    out = similar(ψ); pk = zeros(ComplexF64, n_pts); dx = similar(pk); dy = similar(pk)
    for c in 1:D
        pk .= ψ[:, :, :, c]; plans.forward * pk
        @inbounds for I in CartesianIndices(n_pts)
            dx[I] = im * grid.k[1][I[1]] * pk[I]; dy[I] = im * grid.k[2][I[2]] * pk[I]
        end
        plans.inverse * dx; plans.inverse * dy
        @inbounds for I in CartesianIndices(n_pts)
            out[I, c] = -im * (grid.x[1][I[1]] * dy[I] - grid.x[2][I[2]] * dx[I])
        end
    end
    out
end
pH = constrained_hessian_params(ws, ψ)
g = -im .* (Lz_apply(ψ) .+ ψ .* reshape(m_vals, 1, 1, 1, D))   # (L_z+F_z)ψ Goldstone tangent
g = g .- ψ .* (ipR(ψ, g) / pH.n2)                              # project ⊥ ψ
g ./= sqrt(ipR(g, g))

println("\n=== un-deflated low modes ===")
u = trapped_bdg_low_modes(ws, ψ; nev=NEV, block=10, max_iter=NITER, tol=1e-5)
for i in 1:length(u.λ); @printf("  λ%d = %+.4e\n", i, u.λ[i]); end
@printf("  converged=%s\n", u.converged)

println("\n=== Goldstone-DEFLATED low modes  (project (L_z+F_z)ψ out) ===")
d = trapped_bdg_low_modes(ws, ψ; nev=NEV, block=10, max_iter=NITER, tol=1e-5, extra_nullspace=[g])
for i in 1:length(d.λ); @printf("  λ%d = %+.4e\n", i, d.λ[i]); end
@printf("  converged=%s\n", d.converged)

println("\n=== VERDICT ===")
lm = d.λ[1]
@printf("deflated λ_min = %+.4e  →  %s\n", lm,
    lm > 1e-3 ? "soft MINIMUM on the U(1) quotient" :
    lm > -1e-3 ? "marginal (≈0, more Goldstones or not stationary)" :
    "still NEGATIVE: deeper saddle or non-stationary state")
println("DONE")

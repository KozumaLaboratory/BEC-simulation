# WHY does the weak-field Eu+DDI ground state refuse to converge / show a
# soft manifold? Hypothesis: the axially-symmetric (trap z-axis) B->0 + DDI
# Hamiltonian has an exact U(1) of simultaneous spin+space rotation about z,
# e^{-iθ(L_z+F_z)}; the DDI-driven transverse order breaks it spontaneously ->
# Goldstone zero mode -> GS is a degenerate ORBIT (circle), not a point.
#
# Decisive test (needs no converged GS — a symmetry holds for ANY ψ):
#   the symmetry tangent g = -i(L_z+F_z)ψ should be a (near-)zero mode of the
#   constrained Hessian: ρ = <g,H_c g>/<g,g> ≈ 0, FAR below the random/F_z-only/
#   L_z-only Rayleigh quotients. If so, the flat direction = the broken U(1)
#   Goldstone — that is the reason the optimizer wanders and floors.
#
#   julia --project=. scripts/eu_goldstone_reason.jl      (CPU, grid 24)
#   GR_SMOKE=1 -> grid 16, tiny steps

using SpinorBEC
using SpinorBEC: Units, eu151_preset, ZeemanParams, find_ground_state,
    find_ground_state_lbfgs, init_psi, add_white_noise!, SpinSystem,
    constrained_hessian_params, constrained_hessian_action,
    trapped_bdg_low_modes, CPUBackend, make_fft_plans
using FFTW, LinearAlgebra, Printf

const SMOKE = get(ENV, "GR_SMOKE", "") == "1"
geti(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const NX  = SMOKE ? 16 : Int(geti("GR_GRID", 24))
const BOX = geti("GR_BOX", 24.0)
const BUG = geti("GR_B_UG", 10.0)
const ITP = SMOKE ? 300 : Int(geti("GR_ITP", 3000))
const LBF = SMOKE ? 50 : Int(geti("GR_LBFGS", 300))

preset = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, 1.1818))
sys = SpinSystem(preset.atom.F)
p_zee = Units.bfield_to_p(BUG * 1e-6, preset.atom.g_F, preset.omega_ref)
zee = ZeemanParams(p_zee, 0.0)
common = (; grid=preset.grid, atom=preset.atom, interactions=preset.interactions,
    potential=preset.potential, zeeman=zee, enable_ddi=true, c_dd=preset.c_dd,
    secular_ddi=false, backend=CPUBackend())

@printf("Goldstone-reason probe: grid=%d^3 box=%.1f B=%.1f uG (CPU)\n", NX, BOX, BUG)

# Symmetry-broken cascade state (need NOT be fully converged for a symmetry test)
psi0 = init_psi(preset.grid, sys; state=:m_plus_F)
add_white_noise!(psi0, 0.02, 1, preset.grid)
gs = find_ground_state(; common..., psi_init=psi0, dt=0.002, n_steps=ITP, tol=1e-12, verbose=false)
gl = find_ground_state_lbfgs(; common..., psi_init=Array{ComplexF64}(gs.workspace.state.psi),
    n_steps=LBF, tol=1e-12, m_lbfgs=10, verbose=false)
ws = gl.workspace
ψ = ws.state.psi
@printf("cascade state: E=%.4f  |gradE|=%.3e\n", gl.energy, gl.grad_norm)

grid = preset.grid
n_pts = ntuple(d -> size(ψ, d), 3)
D = size(ψ, 4)
F = preset.atom.F
m_vals = Float64[F - (c - 1) for c in 1:D]
dV = prod(grid.dx)
ipR(a, b) = real(sum(conj.(a) .* b)) * dV

# L_z operator on each component: -i (x ∂_y - y ∂_x)  (FFT derivatives)
plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
function Lz_apply(ψ)
    out = similar(ψ)
    pk = zeros(ComplexF64, n_pts); dx = similar(pk); dy = similar(pk)
    for c in 1:D
        pc = ψ[:, :, :, c]
        pk .= pc; plans.forward * pk
        @inbounds for I in CartesianIndices(n_pts)
            dx[I] = im * grid.k[1][I[1]] * pk[I]
            dy[I] = im * grid.k[2][I[2]] * pk[I]
        end
        plans.inverse * dx; plans.inverse * dy
        @inbounds for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]; y = grid.x[2][I[2]]
            out[I, c] = -im * (x * dy[I] - y * dx[I])
        end
    end
    out
end
Fz_apply(ψ) = ψ .* reshape(m_vals, 1, 1, 1, D)

Lzψ = Lz_apply(ψ)
Fzψ = Fz_apply(ψ)

# First-order symmetry test (CONVERGENCE-INDEPENDENT). If G generates a
# symmetry of E + the norm constraint, then dE/dθ along g = -iGψ is
# <∇E, g>_R = 0 for ANY ψ — the energy is flat along the symmetry orbit
# everywhere, not just at a stationary point. So at an UNCONVERGED state
# (∇E sizable) the gradient must be ORTHOGONAL to the true symmetry tangent
# while having a component along non-symmetry directions.
pH = constrained_hessian_params(ws, ψ)
tanproj(v) = v .- ψ .* (ipR(ψ, v) / pH.n2)
grad = similar(ψ)
SpinorBEC.energy_gradient!(grad, ψ, ws)  # grad = ∇E (raw, incl. 2μψ normal part)
gradt = tanproj(grad)                    # physical (constraint-tangent) gradient
gnorm = sqrt(ipR(gradt, gradt))

function gcos(v)
    g = tanproj(v); n = ipR(g, g)
    n < 1e-30 && return (NaN, NaN)
    g ./= sqrt(n)
    proj = ipR(gradt, g)                 # <∇E_tang, ĝ>_R = dE/dθ along this direction
    (proj, abs(proj) / gnorm)            # (component, cosine with the tangent ∇E)
end

gcombo = -im .* (Lzψ .+ Fzψ)
gfz = -im .* Fzψ
glz = -im .* Lzψ
grand = randn(ComplexF64, size(ψ))

@printf("\n|∇E| = %.4e\n", gnorm)
println("=== first-order: <∇E, ĝ> along candidate symmetry directions ===")
println("    (exact symmetry ⇒ component ≈ 0, cosine ≈ 0, at ANY ψ)")
for (lbl, v) in (("(L_z+F_z) combined U(1)", gcombo), ("F_z spin-only", gfz),
        ("L_z space-only", glz), ("random control", grand))
    p, c = gcos(v)
    @printf("  %-24s  <∇E,ĝ> = %+.4e   cos = %.4e\n", lbl, p, c)
end

println("\n=== lowest constrained-Hessian modes (nev=3) ===")
lm = trapped_bdg_low_modes(ws, ψ; nev=3, block=8, max_iter=SMOKE ? 8 : 25, tol=1e-5)
for i in 1:length(lm.λ)
    @printf("  mode %d: λ = %+.4e\n", i, lm.λ[i])
end
@printf("  converged=%s\n", lm.converged)
println("\nINTERPRETATION: if ρ(L_z+F_z) ≈ lowest λ ≈ 0, and ρ(F_z)/ρ(L_z)/ρ(rand)")
println("are O(1)+, then the broken U(1) (L_z+F_z) is the flat Goldstone — the")
println("reason the GS is an orbit and the optimizer wanders / floors.")
println("DONE")

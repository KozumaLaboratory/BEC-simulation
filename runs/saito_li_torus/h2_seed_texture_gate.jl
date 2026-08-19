# Gate on `runs/saito_li_torus/config.yaml`: does the config the runner
# COMPILES carry the physics the header claims?
#
# Every check here failed on the config as committed before 2026-08-19, which
# is the point: the file read as a faithful transcription of the paper and was
# not one. Cheap (no solver, no GPU) and meant to be re-run after any edit.
#
#   julia --project=. runs/saito_li_torus/h2_seed_texture_gate.jl

using SpinorBEC
using SpinorBEC: load_config, compute_a_dd, effective_eps_dd,
    effective_a_s_over_a_ho, scalar_lhy_coefficient, lima_pelster_Q5,
    ATOM_REGISTRY, Units, Grid, GridConfig, SpinSystem, init_psi, spin_matrices
using Printf
using LinearAlgebra: dot

const CONFIG = joinpath(@__DIR__, "config.yaml")
const EPS_TARGET = 1.3
const A_B = Units.BOHR_RADIUS

# Requirements from `h1_variational_cross_check.jl` (repo Eu151, F=6, N=15000,
# eps_dd=1.3). Lengths in a_ho.
const REQ = (sigma_r=0.5883, sigma_z=0.4329, r_mean=1.2202,
    box_xy_min=5.08, box_z_min=2.63, n_peak_N=0.52220)

const failures = String[]
function check(ok::Bool, label::AbstractString, detail::AbstractString)
    println(ok ? "  PASS  $label — $detail" : "  FAIL  $label — $detail")
    ok || push!(failures, label)
    ok
end

println("="^78)
println("config gate: ", CONFIG)
println("="^78)

# `load_config` normalises mixins/defaults/units into `raw_data`; the derived
# couplings (c_dd, c_lhy, lhy_kind) are written by `_resolve_derived_params!`,
# which the runner calls from `_resolve_gs_atom`. Call it the same way so this
# gate sees exactly what a run sees.
cfg = load_config(CONFIG)
step = cfg.raw_data["pipeline"][1]["ground_state"]
atom = SpinorBEC.resolve_atom(Symbol(step["atom"]))
SpinorBEC._resolve_derived_params!(step, atom; verbose=true)
inter = step["interactions"]
N = Int(inter["N_atoms"])
ω = Float64(inter["omega_ref"])
a_ho = sqrt(Units.HBAR / (atom.mass * ω))

c_total = Float64(inter["c_total"])
c_dd = Float64(step["ddi"]["c_dd"])
c_lhy = Float64(get(inter, "c_lhy", get(step["lhy"], "c_lhy", NaN)))
eps_eff = effective_eps_dd(atom.F, c_total, c_dd)
a_s_eff = effective_a_s_over_a_ho(c_total, N) * a_ho

println("\n-- couplings the runner will use --")
@printf("  c_total = %.4f   c_dd = %.4f   c_lhy = %.4f\n", c_total, c_dd, c_lhy)
@printf("  a_s_eff = %.4f a_B  (atom %.1f a_B)   eps_dd_eff = %.6f\n",
    a_s_eff / A_B, atom.a_s / A_B, eps_eff)

check(isapprox(eps_eff, EPS_TARGET; rtol=2e-4), "eps_dd",
    "effective $(round(eps_eff; digits=6)) vs target $EPS_TARGET")

c_lhy_want = scalar_lhy_coefficient(a_s_eff / a_ho, N; eps_dd=eps_eff)
check(isapprox(c_lhy, c_lhy_want; rtol=1e-3), "c_lhy follows the effective a_s",
    "config $(round(c_lhy; digits=3)) vs $(round(c_lhy_want; digits=3)); " *
    "the atom's a_s would give " *
    "$(round(scalar_lhy_coefficient(atom.a_s / a_ho, N; eps_dd=compute_a_dd(atom)/atom.a_s); digits=3))",
)

check(isapprox(lima_pelster_Q5(EPS_TARGET), 3.716083; rtol=1e-5),
    "Q5 == the paper's chi(eps_dd)",
    "Q5(1.3) = $(round(lima_pelster_Q5(EPS_TARGET); digits=6)), " *
    "independent quadrature 3.71640")

println("\n-- geometry --")
box = Float64.(step["grid"]["box"])
n = Int.(step["grid"]["n"])
@printf("  box = %s a_ho   n = %s   dx = [%.4f, %.4f, %.4f] a_ho\n",
    box, n, box[1] / n[1], box[2] / n[2], box[3] / n[3])
check(box[1] >= REQ.box_xy_min && box[2] >= REQ.box_xy_min, "box_xy fits the droplet",
    "$(box[1]) a_ho vs $(REQ.box_xy_min) required (1e-4 of peak density)")
check(box[3] >= REQ.box_z_min, "box_z fits the droplet",
    "$(box[3]) a_ho vs $(REQ.box_z_min) required")
check(box[1] / n[1] < REQ.sigma_z / 4, "dx_xy resolves sigma_z",
    "dx_xy $(round(box[1]/n[1]; digits=4)) a_ho, sigma_z $(REQ.sigma_z) a_ho " *
    "=> $(round(REQ.sigma_z/(box[1]/n[1]); digits=1)) points")

println("\n-- solver --")
check(get(step, "method", "itp") == "lbfgs", "method is lbfgs",
    "ITP's fixed point is dt-displaced in this regime (44 % in peak density " *
    "on the sibling droplet, while reporting dpsi = 3e-6)")
check(Bool(get(step["ddi"], "padded", true)), "DDI is zero-padded",
    "a self-bound object in a periodic box otherwise sees its own images")

println("\n-- the trap is free space, or a cage small enough not to matter --")
# `config.yaml` is free space (`potential: {type: none}`). An earlier revision
# used a weak harmonic cage to hold the droplet on the origin; the field-axis
# and EdH cells here still do, because a quenched droplet drifts. Either is
# admissible, but the cage has to be shown irrelevant rather than assumed so.
let pot = get(step, "potential", Dict()), ω = pot isa Dict ? get(pot, "omega", nothing) : nothing
    if ω === nothing
        check(true, "free space",
            "potential.type = $(pot isa Dict ? get(pot, "type", "none") : "none"); " *
            "no cage to justify")
    else
        ωt = Float64.(ω)
        r2 = REQ.sigma_r^2 * (3.5452 + 1)
        z2 = REQ.sigma_z^2 / 2
        V_over_N = 0.5 * ωt[1]^2 * (r2 + z2)
        check(abs(V_over_N / 1.3592) < 1e-3, "trap energy negligible",
            "<V>/N = $(round(V_over_N; sigdigits=3)) vs |E|/N = 1.359 hbar w_ref " *
            "=> $(round(V_over_N / 1.3592; sigdigits=3))")
    end
end

println("\n-- the seed really is the paper's magnetic vortex --")
# Build it on a small grid and measure the texture, rather than trusting the name.
grid = SpinorBEC.make_grid(GridConfig((32, 32, 32), (box[1], box[2], box[3])))
sys = SpinSystem(atom.F)
isp = step["init_state_params"]
psi = init_psi(grid, sys; state=Symbol(step["initial_state"]),
    init_theta=Float64(isp["init_theta"]), init_phi=Float64(isp["init_phi"]),
    init_vortex_charge=Int(isp["init_vortex_charge"]))

"""
Measure the seed's spin texture on the z = 0 plane, over the annulus the torus
actually occupies. Returns the worst alignment with phi_hat, the largest
|f_z|/|f|, the worst polarization |f|/(F rho), and the number of points used —
the count is reported so that a probe which sampled nothing cannot pass by
leaving every extremum at its initial value.
"""
function probe_texture(psi, grid, F; r_lo=0.6, r_hi=2.4)
    sm = spin_matrices(F)
    Fx, Fy, Fz = Matrix(sm.Fx), Matrix(sm.Fy), Matrix(sm.Fz)
    nx, ny, nz = size(psi)[1:3]
    k = nz ÷ 2 + 1
    worst_align, max_fz, worst_pol, n = 1.0, 0.0, 1.0, 0
    s = Vector{ComplexF64}(undef, size(psi, 4))
    for i in 1:nx, j in 1:ny
        x, y = grid.x[1][i], grid.x[2][j]
        r = hypot(x, y)
        (r_lo < r < r_hi) || continue
        @views s .= psi[i, j, k, :]
        dens = sum(abs2, s)
        dens > 1e-16 || continue
        fx = real(dot(s, Fx * s))
        fy = real(dot(s, Fy * s))
        fz = real(dot(s, Fz * s))
        fmag = sqrt(fx^2 + fy^2 + fz^2)
        worst_align = min(worst_align, (fx * (-y / r) + fy * (x / r)) / fmag)
        max_fz = max(max_fz, abs(fz) / fmag)
        worst_pol = min(worst_pol, fmag / (F * dens))
        n += 1
    end
    (; worst_align, max_fz, worst_pol, n)
end

t = probe_texture(psi, grid, atom.F)
worst_align, max_fz, worst_pol, n_sampled = t.worst_align, t.max_fz, t.worst_pol, t.n
@printf("  sampled %d points in 0.6 < r < 2.4 a_ho on z = 0\n", n_sampled)
check(n_sampled > 200, "seed probe actually sampled the shell",
    "$n_sampled points (a probe that sampled nothing would pass everything else)")
check(worst_align > 0.999, "magnetization is azimuthal (n_hat = phi_hat)",
    "min cos(angle to phi_hat) = $(round(worst_align; digits=6))")
check(max_fz < 1e-9, "f_z vanishes (required by the paper's ansatz)",
    "max |f_z|/|f| = $(round(max_fz; sigdigits=3))")
check(worst_pol > 0.999, "fully polarized (|f| = F rho), as Eq. (1) assumes",
    "min |f|/(F rho) = $(round(worst_pol; digits=6))")

println("\n-- the generalized seed circulates about EVERY axis --")
# `b_cells.seed_torus(...; axis=)` builds the magnetic vortex about x, y or z;
# the EdH arm (paper Fig. 4) needs axis = y. A wrong spinor convention there is
# invisible at axis = z — it only flips the (degenerate) circulation sign — but
# at a tilted axis it destroys the circulation while leaving the DENSITY a
# perfect torus. That is exactly what the Condon-Shortley (-1)^{F-m} did on
# 2026-08-19: <f.phi_hat> fell to 0.000 and the density looked right.
include(joinpath(@__DIR__, "h3_cells.jl"))
let cell = (; seed=:torus, N=15000, eps_dd=1.3, Bz_mG=0.0)
    bb = build_cell(cell; n=(40, 40, 40), box=(6.5, 6.5, 6.5))
    for (axname, axi) in (("x", 1), ("y", 2), ("z", 3))
        p = seed_torus(bb.grid, bb.F; lam=bb.lam, sr=bb.sr, sz=bb.sz, axis=axi)
        rho = SpinorBEC.total_density(p, 3)
        smx = spin_matrices(bb.F)
        gx, gy, gz = SpinorBEC.spin_density_vector(p, smx, 3)
        e3 = [axi == 1, axi == 2, axi == 3] .* 1.0
        num, den = 0.0, 0.0
        for I in CartesianIndices(rho)
            rvec = [bb.grid.x[1][I[1]], bb.grid.x[2][I[2]], bb.grid.x[3][I[3]]]
            f = [gx[I], gy[I], gz[I]]
            fn = sqrt(sum(abs2, f))
            fn > 1e-14 || continue
            perp = rvec - sum(rvec .* e3) * e3
            pn = sqrt(sum(abs2, perp))
            pn > 1e-6 || continue
            ph =
                [e3[2] * perp[3] - e3[3] * perp[2], e3[3] * perp[1] - e3[1] * perp[3],
                    e3[1] * perp[2] - e3[2] * perp[1]] ./ pn
            num += rho[I] * sum(f .* ph) / fn
            den += rho[I]
        end
        circ = num / den
        check(abs(circ) > 0.999, "seed axis=$axname circulates",
            "<f_hat . phi_hat> = $(round(circ; digits=5)) (|.| must be 1; " *
            "0 means the texture is radial/polar while the density still looks right)")
    end
end

println()
println("="^78)
if isempty(failures)
    println("ALL CHECKS PASS")
else
    println("FAILURES: ", join(failures, ", "))
    exit(1)
end

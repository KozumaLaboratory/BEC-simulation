using SpinorBEC, Printf, LinearAlgebra

# Smoke test for Multi-Product Splitting (Chin-Geiser, IMA J. Numer.
# Anal. 31 (2011) 1552; see also Chin arXiv:0809.3739).
#
# Run:
#   julia --project=. scripts/bench/mps_smoke.jl
#
# This is exploratory — NOT part of the regular test suite. Used to
# evaluate whether MPS retains order 4 under our spinor + DDI
# Hamiltonian (where Yoshida6 collapses to order 1, see
# `test/hamiltonian/test_integrator_order_meanfield.jl` and
# `docs/design/integrator_modernization_plan.md`).
#
# Reference results (rotating-basis 8³ F=1, T=0.2, 2026-05-11):
#   autonomous: MPS-4 order 3.95→3.14, err ~10× better than Y4 same cost
#   full MF:    MPS-4 order 3.94→3.03, retains order while Y4 drops to 2.94
#   norm drift: ~4e-10 (bounded as O(h⁴) predicted, vs ~1e-14 for unitary Y4)

# Multi-Product Splitting (Chin-Geiser): 4th-order via Richardson
# extrapolation of Strang substeps.
#
#   T_4(h) ψ = -1/3 · S(h) ψ  +  4/3 · S(h/2)² ψ
#
# where S(h) is one Strang step. Local error analysis:
#   S(h)         local err = α h³ + β h⁵ + …
#   S(h/2)² over h: 2·α(h/2)³ = α h³/4 leading
#   T_4 combination: -1/3·α h³ + 4/3·α h³/4 = 0   ← O(h³) cancels
#                    next order: -β/3 h⁵ + β/12 h⁵ ≠ 0
#   ⇒ local O(h⁵), global O(h⁴)
#
# Norm: ψ_MPS = -1/3 ψ_a + 4/3 ψ_b is NOT exactly unitary even with
# unitary substeps. But ψ_a, ψ_b both approximate the same unitary
# ψ_true to O(h³), so the linear combination = ψ_true + O(h⁵), giving
# norm preserved to O(h⁵) per step / O(h⁴) global. Practically:
# bounded drift, may need periodic re-normalization for long runs.

config = GridConfig((8, 8, 8), (6.0, 6.0, 6.0))
grid = SpinorBEC.make_grid(config)
V_trap = zeros(8, 8, 8)
@inbounds for I in CartesianIndices(V_trap)
    x = grid.x[1][I[1]]
    y = grid.x[2][I[2]]
    z = grid.x[3][I[3]]
    V_trap[I] = 0.5 * (x*x + y*y + z*z)
end

function build_ws(c1, c_dd)
    ws = SpinorBEC.make_rotating_basis_ws(
        grid, 1, V_trap;
        p=10.0, q=0.0, c0=20.0, c1=c1, c_dd=c_dd,
        theta_func=(t) -> π/6, phi_func=(t) -> 1.0*t,
        theta_dot_func=(t) -> 0.0, phi_dot_func=(t) -> 1.0,
        gauge_fix=false,
    )
    @inbounds for I in CartesianIndices(grid.config.n_points)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        ws.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / 2)
    end
    SpinorBEC.normalize_rotating!(ws)
    ws
end

# One MPS-4 step, in-place (overwrites ws.psi_tilde).
# Buffers: needs 2 ψ-shaped scratch arrays.
function mps4_step!(ws, h::Float64; t::Float64=0.0)
    psi0 = copy(ws.psi_tilde)

    # Branch a: S(h) once
    SpinorBEC.split_step_rotating!(ws, h, t)
    psi_a = copy(ws.psi_tilde)

    # Branch b: S(h/2) twice
    copyto!(ws.psi_tilde, psi0)
    SpinorBEC.split_step_rotating!(ws, h/2, t)
    SpinorBEC.split_step_rotating!(ws, h/2, t + h/2)
    psi_b = ws.psi_tilde   # already in-place

    @. psi_b = (4/3) * psi_b - (1/3) * psi_a
    nothing
end

function evolve_mps4!(ws, n_steps::Int, h::Float64; t0::Float64=0.0)
    t = t0
    for _ in 1:n_steps
        mps4_step!(ws, h; t=t)
        t += h
    end
    t
end

function final_psi(driver, h, c1, c_dd; T_final=0.2)
    ws = build_ws(c1, c_dd)
    n = Int(round(T_final/h))
    driver(ws, n, h)
    copy(ws.psi_tilde)
end

function err_at(driver, h, c1, c_dd, psi_ref; T_final=0.2)
    sqrt(sum(abs2, final_psi(driver, h, c1, c_dd; T_final) - psi_ref))
end

# Norm vs time, single integrator
function norm_drift(driver, h, c1, c_dd; T_final=0.2)
    ws = build_ws(c1, c_dd)
    n = Int(round(T_final/h))
    driver(ws, n, h)
    SpinorBEC.rotating_norm(ws)
end

@printf("=== MPS-4 smoke test (rotating-basis 8³, F=1) ===\n\n")

for (label, c1, c_dd) in [
        ("autonomous (c1=c_dd=0)", 0.0, 0.0),
        ("DDI only", 0.0, 0.3),
        ("c1 only", 0.5, 0.0),
        ("full MF", 0.5, 0.3),
    ]
    @printf("--- %s ---\n", label)
    psi_ref = final_psi(SpinorBEC.evolve_rotating!, 0.0001, c1, c_dd)

    @printf("%-9s  %12s  %12s  %12s  %6s %6s\n",
        "scheme", "err@.04", "err@.02", "err@.01", "ord_a", "ord_b")
    for (name, drv) in [
            ("Strang", SpinorBEC.evolve_rotating!),
            ("Yoshida4", SpinorBEC.evolve_rotating_yoshida4!),
            ("MPS-4", evolve_mps4!),
        ]
        e1 = err_at(drv, 0.04, c1, c_dd, psi_ref)
        e2 = err_at(drv, 0.02, c1, c_dd, psi_ref)
        e3 = err_at(drv, 0.01, c1, c_dd, psi_ref)
        @printf("%-9s  %12.3e  %12.3e  %12.3e  %6.2f %6.2f\n",
            name, e1, e2, e3, log2(e1/e2), log2(e2/e3))
    end

    # Norm drift (should be 1.0 for unitary schemes)
    @printf("Norm drift after T=0.2 at h=0.02:\n")
    for (name, drv) in [
            ("Strang", SpinorBEC.evolve_rotating!),
            ("Yoshida4", SpinorBEC.evolve_rotating_yoshida4!),
            ("MPS-4", evolve_mps4!),
        ]
        nrm = norm_drift(drv, 0.02, c1, c_dd)
        @printf("  %-9s  norm = %.10f  drift = %.2e\n", name, nrm, nrm - 1.0)
    end
    println()
end

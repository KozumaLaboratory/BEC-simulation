# Sneaky-prover (adversarial verifier hardening) for the StabilitySpec gate.
#
# Research basis (deep-research 2026-06-22): a strong / even SOUND verifier is
# NOT automatically non-hackable. RLVR-trained models game verifiers that check
# only EXTENSIONAL (output-level) correctness (arXiv:2604.15149), and
# Prover-Verifier Games (arXiv:2407.13692) show a verifier must be hardened
# against a SNEAKY prover that crafts inputs which pass the check WITHOUT the
# intended property — adversarial co-training raises verifier robustness.
#
# Applied here: the "sneaky prover" hands the gate states that are NOT stable
# minima and asserts the gate REFUSES to certify them (never :pass). A false
# ACCEPT is a gate hole to patch. This is the active-adversary upgrade of the
# frozen replay in test_stability_indeterminate.jl.
#
# Attack — energetic axis, Lanczos hidden-mode: a polar state at c1<0 is a
# STATIONARY SADDLE (the ferromagnetic branch is lower in energy; symmetry of a
# pure-m=0 seed keeps LBFGS on the polar critical point rather than breaking to
# FM — cf. test_level4_f1_phase_emergence's polar-saddle reference). Its single
# negative Hessian direction mixes in m=±1. The energetic axis MUST resolve that
# negative mode (:fail) and not report a converged positive λ_min — which would
# mean the random-seed single-vector Lanczos missed a hidden eigenvalue, the
# stability_verdict_from_nonstationary_point failure class as an adversarial probe.

using Test
using SpinorBEC
using Random: MersenneTwister

@testset "StabilitySpec sneaky-prover — no false ACCEPT of a stationary saddle" begin
    n = 64
    box = 14.0
    grid = make_grid(GridConfig((n,), (box,)))
    atom = Rb87
    # c1 < 0 ⇒ ferromagnetic ground state; the polar state is a saddle.
    interactions = InteractionParams(Dict(0 => 1.0, 1 => -0.3))
    zeeman = ZeemanParams(0.0, 0.0)
    potential = HarmonicTrap((1.0,))
    ws = make_workspace(;
        grid, atom, interactions, zeeman, potential,
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true))

    # Pure polar seed (0,1,0)·gaussian. With no symmetry-breaking kick, LBFGS
    # stays on the polar manifold and converges to the polar SADDLE.
    seed = zeros(ComplexF64, n, 3)
    for i in 1:n
        seed[i, 2] = exp(-grid.x[1][i]^2 / 2)
    end
    seed ./= sqrt(sum(abs2, seed) * cell_volume(grid))
    find_ground_state_lbfgs(;
        ws_init=ws, psi_init=seed, n_steps=800, tol=1e-10,
        target_magnetization=0.0, verbose=false)
    ψ_saddle = copy(ws.state.psi)

    # Ground truth: with ample Lanczos budget the lowest Hessian eigenvalue is
    # strongly negative (the ferromagnetic direction) — a genuine saddle, not a
    # marginal mode. (E_polar > E_FM here, so polar is not the ground state.)
    ref = trapped_bdg_lowest_eigenvalue(ws, ψ_saddle; niter=200, rng=MersenneTwister(1))
    @test ref.converged
    @test ref.λ_min < -0.1

    # The saddle IS stationary, so the gate must reject it on the ENERGETIC axis.
    # Small bdg_dim_cap ⇒ the dynamical axis abstains (keeps this fast); the
    # sneaky claim is entirely about the energetic verdict.

    # (1) At a TINY Lanczos budget the gate cannot certify the sign and
    # ABSTAINS — it does NOT falsely ACCEPT, and crucially it does NOT guess
    # :fail without convergence. (niter=5 genuinely under-resolves a 64-pt
    # system — exactly the abstain the three-valued discipline exists for. The
    # default budget (niter=300) + adaptive early-stop now RESOLVES this
    # well-separated saddle, so the abstain invariant is exercised with an
    # explicit tiny budget rather than the default.)
    res_lo = check(StabilitySpec(; bdg_dim_cap=100, niter=5), ws, ψ_saddle;
        rng=MersenneTwister(1))
    stat = first(p.second for p in res_lo.details if p.first === :stationarity)
    en_lo = first(p.second for p in res_lo.details if p.first === :energetic)
    @test stat.status === :pass                  # the polar saddle IS a stationary point
    @test !en_lo.converged                       # Lanczos under-resolved at the default budget
    @test en_lo.status === :indeterminate        # ⇒ abstain, NOT a guessed verdict
    @test res_lo.status !== :pass                # never certify the saddle as stable

    # (2) Escalating the Lanczos budget (the L1 diagnose→escalate→resubmit move)
    # resolves the negative mode and the gate DEFINITIVELY rejects the saddle —
    # the random-seed Lanczos did NOT hide the negative eigenvalue.
    res_hi = check(StabilitySpec(; bdg_dim_cap=100, niter=200), ws, ψ_saddle;
        rng=MersenneTwister(1))
    en_hi = first(p.second for p in res_hi.details if p.first === :energetic)
    @test en_hi.converged
    @test en_hi.λ_min < -StabilitySpec().λ_tol
    @test en_hi.status === :fail                 # saddle rejected once resolved — no hole
    @test res_hi.status !== :pass
end

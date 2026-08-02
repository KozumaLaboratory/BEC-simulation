# Bitwise fingerprint of a short ITP run, for comparing two commits.
#
# The three CPU changes in the ITP hot path (dropping the padded memset, reading
# Φ's corner through an index map instead of a materialised crop, threading the
# spin-mixing angle pre-pass) are all argued to be exact. Argument is not
# evidence: run this in the baseline worktree and in the optimised one and the
# hashes must match to the bit.
#
#   julia --project=. bench/itp_state_fingerprint.jl [n] [steps]
#
# `hash` over the raw bits, not a tolerance — the point is that nothing moved,
# and any tolerance would let a real numerical change through as "close enough".

using Printf
using SpinorBEC

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 16
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 40

include(joinpath(@__DIR__, "eu151_params.jl"))

grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
psi0 = init_psi(grid, SpinSystem(6); state = :spin_coherent,
    init_theta = π / 4, init_phi = 0.3)

gs = find_ground_state(;
    grid, atom = Eu151,
    interactions = eu_interaction_params(0.05),
    zeeman = ZeemanParams(EU_p_weak, 0.0),
    potential = HarmonicTrap((1.0, 1.0, EU_λ_z)),
    psi_init = psi0,
    dt = 0.002, n_steps = N_STEPS, tol = 0.0,   # tol=0 ⇒ never converges early
    save_every = max(1, N_STEPS ÷ 4),
    enable_ddi = true, c_dd = EU_c_dd,
    ddi_padding = true, ddi_trunc_radius = -1.0,
    verbose = false,
)

psi = gs.workspace.state.psi
bits = reinterpret(UInt64, vec(reinterpret(Float64, vec(psi))))
@printf("n=%d steps=%d\n", N_GRID, N_STEPS)
@printf("psi_hash   = 0x%016x\n", hash(bits))
@printf("energy     = %.17g\n", gs.energy)
@printf("norm2      = %.17g\n", sum(abs2, psi))
@printf("converged  = %s  last_step = %d\n", gs.converged, gs.last_step)

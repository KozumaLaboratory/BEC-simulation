#!/usr/bin/env julia
#
# scripts/loop/verify.jl <candidate.toml>
#
# The ISOLATED, three-valued physics verifier for the Loop Engineering inner
# gate (docs/design/loop_engineering_architecture.md). The loop agent invokes
# this process but cannot grade itself: the verdict is THIS process's own gate
# run, never a claim in the transcript. It emits exactly one token line and a
# matching exit code:
#
#   VERIFY: ACCEPT|REJECT|ABSTAIN <content_id> <verify_sha> — <reason>
#   exit 0 (ACCEPT) · 2 (REJECT) · 3 (ABSTAIN) · 4 (malformed input)
#
# `content_id` = sha256 of the candidate TOML (the proposal's identity, CAS-
# style). `verify_sha` = sha256 of THIS script (a version pin, so a token from
# a tampered verifier is distinguishable — the Stop hook re-runs the frozen
# good/bad suite to catch silent weakening).
#
# MULTI-INVARIANT by design (research: a single-scalar "matches reference" gate
# is gameable): norm conservation AND the three-valued StabilitySpec. The
# stability verdict drives the token — :pass→ACCEPT, :fail→REJECT,
# :indeterminate→ABSTAIN (the loop escalates budget on ABSTAIN, never coerces
# it to ACCEPT).
#
# The candidate is DATA (TOML), not code — the agent cannot inject Julia.
# Schema:
#   name = "..."                      # informational
#   [physics]
#   atom = "Rb87"                     # SpinorBEC atom const (Rb87 / Eu151 / ...)
#   dims = [64]                       # grid points per spatial dim
#   box  = [14.0]                     # box size per spatial dim
#   c0 = 1.0 ; c1 = 0.1 ; q = 0.5     # contact c0/c1 + quadratic Zeeman
#   [solve]
#   n_steps = 600 ; tol = 1e-10
#   [gate]
#   niter = 60 ; eps_stat = 1e-4 ; bdg_dim_cap = 4000
#
# Mock mode (harness mechanism tests only): BEC_LOOP_MOCK ∈ {accept,reject,
# abstain} short-circuits the physics (emits BEFORE loading SpinorBEC) so the
# bash mechanism test does not pay a ground-state solve.

using SHA: sha256, bytes2hex

const ACCEPT_RC = 0
const REJECT_RC = 2
const ABSTAIN_RC = 3
const MALFORMED_RC = 4

_short(s) = length(s) > 16 ? s[1:16] : s
emit(status, cid, vsha, reason) = println("VERIFY: $status $cid $vsha — $reason")

verify_sha = _short(bytes2hex(sha256(read(@__FILE__))))

if isempty(ARGS)
    emit("ABSTAIN", "-", verify_sha, "usage: verify.jl <candidate.toml>")
    exit(MALFORMED_RC)
end
candidate = ARGS[1]
if !isfile(candidate)
    emit("ABSTAIN", "-", verify_sha, "no such candidate file: $candidate")
    exit(MALFORMED_RC)
end
content_id = _short(bytes2hex(sha256(read(candidate))))

mock = lowercase(get(ENV, "BEC_LOOP_MOCK", ""))
if mock == "accept"
    emit("ACCEPT", content_id, verify_sha, "mock")
    exit(ACCEPT_RC)
elseif mock == "reject"
    emit("REJECT", content_id, verify_sha, "mock")
    exit(REJECT_RC)
elseif mock == "abstain"
    emit("ABSTAIN", content_id, verify_sha, "mock")
    exit(ABSTAIN_RC)
end

# --- real physics path (heavy: a ground-state solve + the gate) -------------
# Loaded only past the mock short-circuit so the mechanism test stays fast.
using TOML: parsefile
using SpinorBEC

spec = try
    parsefile(candidate)
catch e
    emit("ABSTAIN", content_id, verify_sha, "unparseable TOML: $(sprint(showerror, e))")
    exit(MALFORMED_RC)
end

ph = get(spec, "physics", Dict{String, Any}())
sv = get(spec, "solve", Dict{String, Any}())
gt = get(spec, "gate", Dict{String, Any}())

atom = try
    getfield(SpinorBEC, Symbol(ph["atom"]))::AtomSpecies
catch
    emit("ABSTAIN", content_id, verify_sha, "unknown atom $(get(ph, "atom", "?"))")
    exit(MALFORMED_RC)
end
F = atom.F
D = 2F + 1
dims = Tuple(Int.(ph["dims"]))
box = Tuple(Float64.(ph["box"]))
c0 = Float64(get(ph, "c0", 1.0))
c1 = Float64(get(ph, "c1", 0.0))
q = Float64(get(ph, "q", 0.0))
n_steps = Int(get(sv, "n_steps", 600))
tol = Float64(get(sv, "tol", 1.0e-10))
niter = Int(get(gt, "niter", 60))
eps_stat = Float64(get(gt, "eps_stat", 1.0e-4))
cap = Int(get(gt, "bdg_dim_cap", 4000))

grid = make_grid(GridConfig(dims, box))
ws = make_workspace(;
    grid, atom,
    interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
    zeeman=ZeemanParams(0.0, q),
    potential=HarmonicTrap(ntuple(_ -> 1.0, length(dims))),
    sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
)
# polar seed: m=0 (middle) component, Gaussian envelope.
seed = zeros(ComplexF64, dims..., D)
for I in CartesianIndices(dims)
    r2 = sum(d -> grid.x[d][I[d]]^2, 1:length(dims))
    seed[I, F + 1] = exp(-r2 / 2)
end
seed ./= sqrt(sum(abs2, seed) * cell_volume(grid))

# LBFGS for a cheap global descent, then Newton-CG to a TIGHT stationary point
# (trust-region second order — plain LBFGS plateaus above ε_stat on ≳32-pt
# grids, and the gate must judge an actually-stationary ψ). Newton-CG solves
# ∇E=0, so it lands on the critical point whether it is a minimum or a saddle.
find_ground_state_lbfgs(;
    ws_init=ws, psi_init=seed, n_steps=n_steps, tol=tol,
    target_magnetization=0.0, verbose=false)
polished = newton_cg_ground_state(ws, copy(ws.state.psi); tol=1.0e-9, max_outer=80)
ψ = copy(polished.psi)

# Robust invariant first: norm conservation. Then the three-valued gate.
norm2 = real(sum(abs2, ψ)) * cell_volume(grid)
if !isfinite(norm2) || abs(norm2 - 1) > 1e-6
    emit("REJECT", content_id, verify_sha, "norm not conserved: ‖ψ‖²=$(round(norm2, sigdigits=6))")
    exit(REJECT_RC)
end

res = check(StabilitySpec(; niter, ε_stat=eps_stat, bdg_dim_cap=cap), ws, ψ)
if res.status === :pass
    emit("ACCEPT", content_id, verify_sha, res.summary)
    exit(ACCEPT_RC)
elseif res.status === :fail
    emit("REJECT", content_id, verify_sha, res.summary)
    exit(REJECT_RC)
else
    emit("ABSTAIN", content_id, verify_sha, res.summary)
    exit(ABSTAIN_RC)
end

# Is psi a reproducible artifact at all?
#
# Job 8339392 measured the same command line twice ("smoke" and "blas1",
# byte-identical invocations) and got two different psi hashes with an energy
# agreeing to all 15 printed digits. A hash says "different" and nothing else,
# so it cannot distinguish a last-ulp wobble from a different state — and the
# cutover parity verdict currently rests on exactly such hashes.
#
# This reports magnitudes: max|dpsi|, the relative energy gap, and both, for
# repeats WITHIN one process and ACROSS processes.
import CUDA
using SpinorBEC, LinearAlgebra, SHA, Printf

function solve()
    grid = make_grid(GridConfig{3}((24, 24, 24), (8.0, 8.0, 8.0)))
    atom = resolve_atom(:Eu151)
    gs = find_ground_state(; grid, atom,
        interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.1)),
        potential=HarmonicTrap((1.0, 1.0, 1.2)),
        dt=1.0e-3, n_steps=400, tol=1.0e-12, initial_state=:polar, verbose=false)
    (ComplexF64.(Array(gs.workspace.state.psi)), Float64(gs.energy))
end

tag = isempty(ARGS) ? "?" : ARGS[1]
a, Ea = solve()
b, Eb = solve()
h(x) = bytes2hex(sha256(reinterpret(UInt8, vec(x))))[1:16]
@printf("REPRO %-8s in-process  maxdpsi=%.3e  relE=%.3e  hashes %s %s  same=%s\n",
    tag, maximum(abs.(a .- b)), abs(Ea - Eb) / abs(Ea), h(a), h(b), a == b)
# emit one state so the caller can compare ACROSS processes
@printf("REPRO %-8s emit        hash=%s  E=%.17g  maxabs=%.17g  sum=%.17g\n",
    tag, h(a), Ea, maximum(abs.(a)), sum(abs2, a))

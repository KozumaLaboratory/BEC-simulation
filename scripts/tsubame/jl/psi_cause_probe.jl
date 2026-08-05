# WHAT makes psi differ across processes? Alignment is refuted (measured locally:
# a 64^3 in-place complex FFT gives a bit-identical result from a 64-byte-aligned
# and a 16-mod-64 buffer, under both ESTIMATE and MEASURE). So narrow it by
# bisecting the pipeline: which stage's output already differs?
import CUDA
using SpinorBEC, SHA, Printf, LinearAlgebra, FFTW
h(x) = bytes2hex(sha256(reinterpret(UInt8, vec(ComplexF64.(Array(x))))))[1:16]
tag = isempty(ARGS) ? "?" : ARGS[1]

grid = make_grid(GridConfig{3}((24, 24, 24), (8.0, 8.0, 8.0)))
atom = resolve_atom(:Eu151)
ip = InteractionParams(Dict(0 => 10.0, 1 => 0.1))
pot = HarmonicTrap((1.0, 1.0, 1.2))

ws0 = make_workspace(; grid, atom, interactions=ip, potential=pot,
    sim_params=SimParams(; dt=1.0e-3, n_steps=1, save_every=1))
@printf("CAUSE %-6s stage=init            hash=%s\n", tag, h(ws0.state.psi))
@printf("CAUSE %-6s stage=Vtrap           hash=%s\n", tag, h(ComplexF64.(evaluate_potential(pot, grid))))
@printf("CAUSE %-6s stage=ksquared        hash=%s\n", tag, h(ComplexF64.(grid.k_squared)))

# one FFT round trip on the init state
buf = ComplexF64.(Array(ws0.state.psi)[:, :, :, 1])
p = plan_fft!(copy(buf))
b2 = copy(buf); p * b2
@printf("CAUSE %-6s stage=fft1            hash=%s\n", tag, h(b2))

for nst in (1, 10, 100, 400)
    r = find_ground_state(; grid, atom, interactions=ip, potential=pot,
        dt=1.0e-3, n_steps=nst, tol=1.0e-14, initial_state=:polar, verbose=false)
    @printf("CAUSE %-6s stage=itp%-4d         hash=%s  E=%.17g\n",
        tag, nst, h(r.workspace.state.psi), Float64(r.energy))
end
@printf("CAUSE %-6s env blas=%d fftw_threads=%d julia_threads=%d\n",
    tag, BLAS.get_num_threads(), FFTW.get_num_threads(), Threads.nthreads())

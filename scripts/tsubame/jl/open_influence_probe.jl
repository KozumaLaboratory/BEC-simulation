# One condition per process. Called as:
#     julia --project=. scripts/tsubame/jl/open_influence_probe.jl <label>
#
# A separate FILE and not a `julia -e` heredoc: the previous revision nested a
# bash heredoc inside a double-quoted `-e` string inside a shell function, and
# the escaping broke silently — the job ran to completion in 17 s, printed five
# section headers and no rows, because the output filter matched by FORM
# (`grep -E '^COST|ERROR'`) and the actual error had neither shape. Nothing here
# is quoted by the shell.
import CUDA
using SpinorBEC, LinearAlgebra, FFTW, SHA, Printf

label = isempty(ARGS) ? "unlabelled" : ARGS[1]

# Measured (job 8338648): find_ground_state returns
# (:workspace,:converged,:energy,:dE,:dpsi,:interrupted,:last_step) and
# hasproperty(r.workspace, :psi) is FALSE. Locate psi rather than guess at it.
function probe_psi(gs)
    ws = gs.workspace
    hasproperty(ws, :state) && hasproperty(ws.state, :psi) && return Array(ws.state.psi)
    for f in propertynames(ws)
        v = getproperty(ws, f)
        v isa AbstractArray{<:Complex} && ndims(v) == 4 && return Array(v)
    end
    error("no 4-D complex array on the workspace; fields = $(propertynames(ws))")
end

grid = make_grid(GridConfig{3}((24, 24, 24), (8.0, 8.0, 8.0)))
atom = resolve_atom(:Eu151)
ip = InteractionParams(Dict(0 => 10.0, 1 => 0.1))
gs = find_ground_state(; grid, atom, interactions=ip,
    potential=HarmonicTrap((1.0, 1.0, 1.2)),
    dt=1.0e-3, n_steps=400, tol=1.0e-12, initial_state=:polar, verbose=false)
psi = ComplexF64.(probe_psi(gs))
h = bytes2hex(sha256(reinterpret(UInt8, vec(psi))))[1:16]
@printf("COST %-18s E=%.15g norm=%.15g psi=%s blas=%d fftw=%s\n",
    label, Float64(gs.energy), sum(abs2, psi), h,
    BLAS.get_num_threads(), get(ENV, "SPINORBEC_FFTW_PLAN", "default"))

# Build a sysimage that includes the heavy F=6 24³ DDI + rotating-frame +
# LBFGS + Sobolev specialisations needed by M1-ITP and follow-on production
# runs. Builds on top of scripts/build_sysimage.jl (which only covers F=1
# rotating-basis API), targeting the M0/M1/M2 codepath instead.
#
# WARNING: the precompile workload exercises the same heavy specialisation
# cascade that is the *cause* of the 28-30 GB JIT RSS we're trying to
# avoid in production. The build itself uses comparable memory. Run under
# a cgroup scope with MemoryMax≥29G so a misjudged allocation does not
# take down WSL/host:
#
#   systemd-run --user --scope -p MemoryMax=29G -p MemorySwapMax=0 \
#     --slice=sysbuild.slice -- \
#     julia --project=. --heap-size-hint=24G scripts/build_sysimage_full.jl
#
# Output: spinor_sysimage_full.so (~400-700 MB). Later usage:
#   julia --project=. --sysimage=spinor_sysimage_full.so <script>
#   → Julia startup RSS ≈ 5-7 GB instead of 28-30 GB.

using Pkg
let
    _names = (p.name for p in values(Pkg.dependencies()))
    "PackageCompiler" in _names || Pkg.add("PackageCompiler")
end

using PackageCompiler

const PRECOMPILE_SCRIPT = joinpath(@__DIR__, "_sysimage_precompile_full.jl")
const OUTPUT = joinpath(@__DIR__, "..", "spinor_sysimage_full.so")

open(PRECOMPILE_SCRIPT, "w") do io
    write(
        io,
        """
# Exercises the heavy M1-ITP code path so PackageCompiler captures the
# right method specialisations for F=6 24³ DDI + rotating-frame + LBFGS
# + Sobolev.
import CUDA
using SpinorBEC
using LinearAlgebra
using Random

const F = 6
const TW = eu151_preset()

ip = TW.interactions
sys = SpinSystem(F)
psi_init = init_psi(TW.grid, sys; state=:polar)
rng = MersenneTwister(1)
for i in eachindex(psi_init)
    psi_init[i] += 0.01 * (randn(rng) + im * randn(rng))
end
n = sqrt(sum(abs2, psi_init) * SpinorBEC.cell_volume(TW.grid))
psi_init ./= n
zeeman = ZeemanParams(0.385, 0.0)

# Tiny ITP + rotating-frame to specialise the path
ws, conv, E, _, _ = find_ground_state(;
    grid=TW.grid, atom=TW.atom, interactions=ip, zeeman=zeeman, potential=TW.potential,
    dt=0.005, n_steps=20, tol=1e-8,
    initial_state=:polar, verbose=false, psi_init=psi_init,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    rotating_frame_omega=0.4, backend=CUDABackend())

# Tiny LBFGS + Sobolev to specialise that path too
psi_after = Array(ws.state.psi)
res = find_ground_state_lbfgs(;
    grid=TW.grid, atom=TW.atom, interactions=ip, zeeman=zeeman, potential=TW.potential,
    n_steps=10, tol=1e-9,
    initial_state=:polar, psi_init=psi_after,
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    backend=CUDABackend(), verbose=false, sobolev_alpha=0.02)

# Energy decomposition + observables
b = energy_decomposition(ws)
sm = ws.spin_matrices
fx, fy, fz = spin_density_vector(Array(ws.state.psi), sm, 3)

# Real-time path (M0): tiny run_simulation! to specialise that branch
sp = SimParams(; dt=0.005, n_steps=10, imaginary_time=false,
    normalize_every=0, save_every=10, rotating_frame_omega=0.0)
ws2 = make_workspace(; grid=TW.grid, atom=TW.atom, interactions=ip,
    zeeman=zeeman, potential=TW.potential, sim_params=sp,
    psi_init=Array(ws.state.psi),
    enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
    backend=CUDABackend())
run_simulation!(ws2)

println("[precompile workload] specialisations exercised")
""",
    )
end

@info "Building sysimage with F=6 24³ DDI + rotating-frame + LBFGS + Sobolev workload"
@info "This will take ~30-60 minutes and use ~25-29 GB peak RSS"
@info "Output" path=OUTPUT

create_sysimage(
    [:SpinorBEC];
    sysimage_path=OUTPUT,
    precompile_execution_file=PRECOMPILE_SCRIPT,
)

println("\n✅ Sysimage built: $OUTPUT")
println("Future runs:  julia --project=. --sysimage=$OUTPUT <script>")
println("Expected Julia startup RSS: 5-7 GB (vs 28-30 GB JIT cost)")

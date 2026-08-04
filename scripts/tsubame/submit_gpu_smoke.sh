#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=0:15:00
#$ -N gpu_smoke
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
#
# Minimal GPU smoke: build a workspace with a TABULATED LHY and take one step.
# Deliberately does NOT pipe through `tail` — truncating the output is how the
# A/B job hid the exception header that made this necessary.
$JULIA --project=. -e '
import CUDA; using SpinorBEC
grid = make_grid(GridConfig((16,16,16),(12.0,12.0,12.0)))
psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent, init_theta=0.6, init_phi=0.3)
for kind in (nothing, :polar_contact)
    println("--- spinor_lhy = ", repr(kind)); flush(stdout)
    ws = make_workspace(; grid, atom=Eu151,
        interactions=InteractionParams(Dict(0=>8.0, 1=>-0.4)),
        potential=HarmonicTrap((1.0,1.0,1.0)),
        sim_params=SimParams(; dt=0.002, n_steps=1, imaginary_time=true),
        psi_init=psi0, enable_ddi=true, c_dd=1.0,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=kind, backend=CUDABackend())
    println("    workspace ok, lhy=", typeof(ws.lhy)); flush(stdout)
    SpinorBEC.split_step!(ws); CUDA.synchronize()
    println("    step ok, norm=", sum(abs2, ws.state.psi)); flush(stdout)
end
println("SMOKE ok")'
echo "rc=$?"
echo "ALL DONE $(date)"

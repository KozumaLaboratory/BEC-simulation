#!/usr/bin/env julia
# scripts/sprint5_A1_v3_gpu_bench.jl
#
# Time-calibration benchmark for the GPU digital-twin run. 1 init
# (icosahedral_explicit) at 24³ box=(30,30,26) N=5×10⁴ digital-twin
# parameters, n_steps=500. Reports wall-clock so we can scope the
# full 6-init run before committing.
#
# Run:  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. scripts/sprint5_A1_v3_gpu_bench.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000   # Matsui digital twin
const OMEGA_REF = 691.15

# Matsui digital twin: ω = (110, 110, 130) Hz → aspect = (1, 1, 1.1818)
# Box sized to fit TF profile at N=50000: μ ≈ 115 → R_TF ≈ 15
# Box (30, 30, 26): dx_perp = 1.25, dx_z = 1.083 at 24³
const GRID = make_grid(GridConfig((24, 24, 24), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))
const ZEEMAN = ZeemanParams(0.0, 0.0)

# Matsui-literal channel set: c_n = 0 for n ≥ 2 (only c_0, c_1 known via a_12)
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const N_STEPS_BENCH = 500
const DT = 0.005
const TOL = 1e-12   # never reached; just want full N_STEPS

function build_psi_Ih(sys)
    ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
    psi = init_psi(GRID, sys; state=:polar)
    for k in 1:size(psi, 3), j in 1:size(psi, 2), i in 1:size(psi, 1)
        spatial_amp = sqrt(sum(abs2, view(psi, i, j, k, :)))
        for c in 1:size(psi, 4)
            psi[i, j, k, c] = spatial_amp * ζ[c]
        end
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
    n > 0 && (psi ./= n)
    return psi
end

function main()
    println("=== GPU benchmark — digital twin geometry ===\n")
    @printf "Atom: %s, N=%d, ω=(110, 110, 130) Hz aspect=(1,1,1.1818)\n" ATOM.name N_ATOMS
    @printf "Grid: 24³ box=(30, 30, 26)\n"
    @printf "c_total (dimless) = %.4e   c_dd = %.4e   c_dd/c_total = %.4f\n" C_TOTAL C_DD_DIMLESS (
        C_DD_DIMLESS / C_TOTAL
    )
    @printf "Channel set: Matsui-literal (c_0=%.3e, c_1=%.3e, c_n=0 for n≥2)\n\n" C0 C1

    @info "CUDA functional?" CUDA.functional()
    @info "Free memory (GB)" CUDA.free_memory() / 1e9

    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    sys = SpinSystem(F)
    psi_init = build_psi_Ih(sys)

    println("Pre-ITP setup ...")
    t0 = time()
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT, n_steps=N_STEPS_BENCH, tol=TOL,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        backend=CUDABackend())
    t_total = time() - t0
    t_per_step = t_total / N_STEPS_BENCH
    println()
    @printf "After %d ITP steps:\n" N_STEPS_BENCH
    @printf "  Wall-clock: %.2f sec total → %.4f sec/step\n" t_total t_per_step
    @printf "  E = %.6f   conv = %s\n" E (conv ? "✓" : "✗")
    @printf "  Free GPU memory after run: %.2f GB\n\n" (CUDA.free_memory() / 1e9)

    # Scope projections
    println("--- Scope projections ---")
    for n_steps in [4000, 8000, 12000, 20000]
        per_init = n_steps * t_per_step / 60   # minutes
        for n_inits in [3, 6]
            total_h = per_init * n_inits / 60
            @printf "  n_steps=%d × %d inits → %.1f min/init × %d = %.2f h\n" n_steps n_inits per_init n_inits total_h
        end
    end

    println("\n=== Done ===")
end

main()

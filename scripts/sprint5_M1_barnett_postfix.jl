#!/usr/bin/env julia
# Post-fix verification: after _shift_zeeman_for_rotating_frame sign flip,
# the user-facing convention should be:
#   user passes z.p = p_lab (lab-frame Zeeman),
#   workspace adds Barnett −Ω·F_z automatically (effective_p = z.p + Ω).
#
# Expected (Ω = 0.4, B = 0): ⟨F_z⟩ ≈ +1.9 (matches B = 2.6 nT static reference).
# Negative result here would indicate the sign flip is still wrong somewhere.

import CUDA
using SpinorBEC
using LinearAlgebra
using Printf

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()

function fz_lz_at(p_lab::Float64, omega::Float64)
    sys = SpinSystem(TW.F)
    psi_init = init_psi(TW.grid, sys; state=:polar)
    add_noise!(psi_init, 0.01, 1, TW.grid)
    zeeman = ZeemanParams(p_lab, 0.0)
    ws, conv, E, _, _ = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=500, tol=1e-7, initial_state=:polar, verbose=false,
        psi_init=psi_init, enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega, backend=CUDABackend())
    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    fz_total = sum(fz) * SpinorBEC.cell_volume(TW.grid)
    Lz = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
    CUDA.reclaim()
    return fz_total, Lz, E
end

println("=== Post-fix Barnett verification (z.p = p_lab, expect +F_z) ===\n")

# Sanity: Ω=0, p_lab=0 → no rotation, no Zeeman → ⟨F_z⟩≈0
println("--- Ω = 0 sanity ---")
fz, Lz, E = fz_lz_at(0.0, 0.0)
@printf "  Ω=0.00, p_lab=0: ⟨F_z⟩=%+.3e  ⟨L_z⟩=%+.3e  E=%.4f\n\n" fz Lz E

# Barnett sweep at B=0
println("--- Barnett: p_lab=0, sweep Ω (expect ⟨F_z⟩ ↑ monotonically) ---")
println("  Coherence check: ⟨F_z⟩ and ⟨L_z⟩ both > 0 (same sign for same Ω)")
println("  Coefficient check: physical −Ω·F_z, so |⟨F_z⟩| ∝ Ω at small Ω (not 2Ω)")
@printf "  %-8s %-15s %-15s %-12s\n" "Ω" "⟨F_z⟩" "⟨L_z⟩" "E"
for omega in [0.0, 0.1, 0.2, 0.4, 0.6]
    fz, Lz, E = fz_lz_at(0.0, omega)
    @printf "  %-8.2f %+.4e   %+.4e   %.4f\n" omega fz Lz E
end

println("\n=== Done ===")

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
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000
const OMEGA_REF = 691.15
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD = SpinorBEC.compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const GRID = make_grid(GridConfig((24, 24, 24), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))

function fz_lz_at(p_lab::Float64, omega::Float64)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:polar)
    rng = MersenneTwister(1)
    @inbounds for i in eachindex(psi_init)
        ;
        psi_init[i] += 0.01*(randn(rng)+im*randn(rng));
    end
    psi_init ./= sqrt(sum(abs2, psi_init) * SpinorBEC.cell_volume(GRID))
    zeeman = ZeemanParams(p_lab, 0.0)
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip, zeeman=zeeman, potential=POT,
        dt=0.005, n_steps=500, tol=1e-7, initial_state=:polar, verbose=false,
        psi_init=psi_init, enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        rotating_frame_omega=omega, backend=CUDABackend())
    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    fz_total = sum(fz) * SpinorBEC.cell_volume(GRID)
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

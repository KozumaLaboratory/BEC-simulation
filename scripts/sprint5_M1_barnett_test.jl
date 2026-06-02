#!/usr/bin/env julia
# Diagnostic: does Barnett -ΩF_z enter the rotating-frame Hamiltonian?
# Test by setting B=0 and sweeping Ω. If Barnett is IN, ⟨F_z⟩ rises with Ω.
# Compares three implementations:
#   v0  p_input = p_lab          (was implicitly using; effective_p = p_lab − Ω → NO Barnett)
#   v1  p_input = p_lab + Ω      (what the user wrote in spec; effective_p = p_lab → no Barnett)
#   v2  p_input = p_lab + 2Ω     (cancels the code's auto -Ω shift; effective_p = p_lab + Ω → Barnett ON)
#
# Expected (Ω=0.4): v0→⟨F_z⟩~-2, v1→⟨F_z⟩~0, v2→⟨F_z⟩~+2 (≈ value at B=2.6 nT static)

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
const D = 13

function fz_at(p_input::Float64, omega::Float64)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:polar)
    rng = MersenneTwister(1)
    @inbounds for i in eachindex(psi_init)
        ;
        psi_init[i] += 0.01*(randn(rng)+im*randn(rng));
    end
    psi_init ./= sqrt(sum(abs2, psi_init) * SpinorBEC.cell_volume(GRID))
    zeeman = ZeemanParams(p_input, 0.0)
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip, zeeman=zeeman, potential=POT,
        dt=0.005, n_steps=500, tol=1e-7, initial_state=:polar, verbose=false,
        psi_init=psi_init, enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        rotating_frame_omega=omega, backend=CUDABackend())
    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    fz_total = sum(fz) * SpinorBEC.cell_volume(GRID)
    return fz_total, E
end

println("=== Barnett diagnostic: B=0, sweep Ω ===\n")
println("Expected: if -Ω·F_z is in the rotating-frame functional, ⟨F_z⟩ rises with Ω.")
println(
    "Equivalent static B for Ω=0.4: B_B = Ω/γ ≈ 2.7 nT → ⟨F_z⟩ should ≈ 1.87 (previous B=2.6 nT result).\n",
)

# Test all three at one Ω first
omega_test = 0.4

println("--- B=0, Ω=$omega_test, 3 variants ---")
for (label, p_input) in [
    ("v0  p_input=0          (= p_lab + 0)", 0.0),
    ("v1  p_input=Ω          (M1-ITP original, expected NO Barnett)", omega_test),
    ("v2  p_input=2Ω         (cancels auto -Ω shift, expected Barnett ON)", 2*omega_test),
]
    @printf "%-50s ⟨F_z⟩ = " label
    flush(stdout)
    fz, E = fz_at(p_input, omega_test)
    @printf "%+.3e   E=%.4f\n" fz E
end

println("\n--- v2 sweep Ω at B=0 (check ⟨F_z⟩ vs Ω trend) ---")
for omega in [0.0, 0.1, 0.2, 0.4, 0.6]
    fz, E = fz_at(2*omega, omega)
    @printf "  Ω=%.2f  p_input=%.2f  ⟨F_z⟩=%+.3e  E=%.4f\n" omega (2*omega) fz E
end

println("\n=== Done ===")

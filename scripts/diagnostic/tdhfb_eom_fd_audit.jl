# TDHFB EOM ↔ energy functional finite-difference variational audit.
#
# For canonical Hamiltonian dynamics:
#   iφ̇_a = δE/δφ*_a
# This script extracts U^φ + Δ^φ from the code's `_tdhfb_phi_subupdate!`
# formula and compares against numerically computed δE/δφ*_a (Wirtinger
# derivative) from finite differences on `tdhfb_energy`.
#
# Use this script as a debugging tool when modifying the TDHFB EOM/E
# correspondence — it pinpoints which term(s) have variational
# inconsistency without relying on analytical derivations.
#
# Current status (2026-05-12): the per-term ratios at single-voxel test
# point are:
#   φ⁴ term      ratio = 0.43 (complex: 2.3 - 1.7i)
#   φ²ρ term     ratio = 1.66
#   φφκ* (Δ^φ)   ratio = 1.11
# Not a single factor-2 mismatch — possibly a deeper structural issue
# in how Re() in tdhfb_energy interacts with the Wirtinger derivative,
# or in V's index conventions. Logged in memory/tdhfb_perf_findings.md.
#
# Run: julia --project=. scripts/diagnostic/tdhfb_eom_fd_audit.jl

using SpinorBEC, LinearAlgebra, Random, Printf

const F = 1
const D = 2F + 1

function _single_voxel_test()
    Random.seed!(101)
    phi_value = randn(ComplexF64, D) .* 0.3
    A = randn(ComplexF64, D, D) .* 0.05
    rho_value = (A + A') / 2
    B = randn(ComplexF64, D, D) .* 0.05
    kappa_value = (B + transpose(B)) / 2

    phi = reshape(phi_value, 1, D)
    rho = reshape(rho_value, 1, D, D)
    kappa = reshape(kappa_value, 1, D, D)

    state = init_tdhfb_vacuum(phi)
    state.rho .= rho
    state.kappa .= kappa
    V_ext = zeros(Float64, 1, D)
    gS = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)
    V_chan = SpinorBEC.channel_kernel(F, gS)

    # Build U^φ, Δ^φ from the code's formula at this state
    U_phi = zeros(ComplexF64, D, D)
    Delta_phi = zeros(ComplexF64, D, D)
    @inbounds for c in 1:D, c_p in 1:D
        uval = ComplexF64(0)
        dval = ComplexF64(0)
        for c2 in 1:D, c2_p in 1:D
            Vk = V_chan[c, c_p, c2, c2_p]
            Vk == 0.0 && continue
            uval += Vk * (conj(phi_value[c2_p]) * phi_value[c2]
                          + rho_value[c2, c2_p])
            dval += Vk * kappa_value[c2, c2_p]
        end
        U_phi[c, c_p] = uval
        Delta_phi[c, c_p] = dval
    end

    eom_from_W = U_phi * phi_value .+ Delta_phi * conj(phi_value)

    # Numerical δE/δφ* via Wirtinger
    out_fd = zeros(ComplexF64, D)
    eps = 1e-6
    for c in 1:D
        E0 = tdhfb_energy(state, F, gS, V_ext)
        state.phi[1, c] += eps
        Ep = tdhfb_energy(state, F, gS, V_ext)
        dE_dRe = (Ep - E0) / eps
        state.phi[1, c] -= eps
        state.phi[1, c] += 1im * eps
        Ep2 = tdhfb_energy(state, F, gS, V_ext)
        dE_dIm = (Ep2 - E0) / eps
        state.phi[1, c] -= 1im * eps
        out_fd[c] = (dE_dRe + 1im * dE_dIm) / 2
    end

    return (eom = eom_from_W, fd = out_fd,
            phi = phi_value, rho = rho_value, kappa = kappa_value)
end

result = _single_voxel_test()

@printf("=== TDHFB single-voxel EOM ↔ FD δE/δφ* audit ===\n")
@printf("F=%d, single voxel, V_ext=0 (so E_kin=E_trap=0; only E_int)\n\n", F)
@printf("%-5s %-30s %-30s %-10s\n",
    "c", "EOM = (U^φ φ + Δ^φ φ*)", "FD δE/δφ*", "|ratio|")
for c in 1:D
    e = result.eom[c]; f = result.fd[c]
    r = abs(f) > 1e-10 ? abs(e)/abs(f) : NaN
    @printf("  %-3d %s   %s   %.4f\n", c, string(e), string(f), r)
end
rel_dev = norm(result.eom .- result.fd) / max(norm(result.fd), 1e-30)
@printf("\n‖EOM − FD‖ / ‖FD‖ = %.3e\n", rel_dev)
if rel_dev < 0.01
    @printf("✓ EOM matches δE/δφ* to better than 1%% — variational consistent\n")
elseif rel_dev < 0.5
    @printf("△ EOM has %d%% deviation — residual factor or partial bug\n", round(Int, 100*rel_dev))
else
    @printf("✗ EOM diverges from δE/δφ* by %d%% — structural bug\n", round(Int, 100*rel_dev))
end

# Per-term FD audit: for EACH of the 5 E_int pieces, compute δE_piece/δφ*
# numerically via Wirtinger FD, and compare against TWO possible code
# extraction conventions:
#   (A) V[c, c_p, c2, c2_p]  ← original
#   (B) V[c_p, c, c2, c2_p]  ← slot 1↔2 swap
# AND test the index of ρ / κ contractions (slot 3↔4 swap on those):
#   ρ_{c2, c2_p} vs ρ_{c2_p, c2}
#   κ_{c2, c2_p} vs κ_{c2_p, c2}
# That's 4 conventions per piece. Find which one matches FD per piece.

using SpinorBEC, LinearAlgebra, Random, Printf

const F = 1
const D = 2F + 1
Random.seed!(101)

phi_value = randn(ComplexF64, D) .* 0.3
A = randn(ComplexF64, D, D) .* 0.05
rho_value = (A + A') / 2
B = randn(ComplexF64, D, D) .* 0.05
kappa_value = (B + transpose(B)) / 2

gS = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)
V_chan = SpinorBEC.channel_kernel(F, gS)

# Energy piece evaluators
function E_phi4(phi_v, V_chan, D)
    s = 0.0im
    for c in 1:D, c_p in 1:D, c2 in 1:D, c2_p in 1:D
        Vk = V_chan[c, c_p, c2, c2_p]
        Vk == 0.0 && continue
        s += Vk * conj(phi_v[c_p]) * conj(phi_v[c2_p]) * phi_v[c] * phi_v[c2]
    end
    0.5 * real(s)
end

function E_phi2_rho(phi_v, rho_v, V_chan, D)
    s = 0.0im
    for c in 1:D, c_p in 1:D, c2 in 1:D, c2_p in 1:D
        Vk = V_chan[c, c_p, c2, c2_p]
        Vk == 0.0 && continue
        s += Vk * 2 * rho_v[c, c_p] * conj(phi_v[c2_p]) * phi_v[c2]
    end
    0.5 * real(s)
end

function E_phi_phi_kappa(phi_v, kappa_v, V_chan, D)
    s = 0.0im
    for c in 1:D, c_p in 1:D, c2 in 1:D, c2_p in 1:D
        Vk = V_chan[c, c_p, c2, c2_p]
        Vk == 0.0 && continue
        s += Vk * 2 * real(phi_v[c] * phi_v[c2] * conj(kappa_v[c_p, c2_p]))
    end
    0.5 * real(s)
end

# FD δE_piece/δφ*_a via Wirtinger
function fd_wirtinger(E_func, phi_v; eps=1e-6)
    out = zeros(ComplexF64, length(phi_v))
    for c in 1:length(phi_v)
        E0 = E_func(phi_v)
        phi_v[c] += eps
        Ep = E_func(phi_v)
        dE_dRe = (Ep - E0) / eps
        phi_v[c] -= eps
        phi_v[c] += 1im * eps
        Ep2 = E_func(phi_v)
        dE_dIm = (Ep2 - E0) / eps
        phi_v[c] -= 1im * eps
        out[c] = (dE_dRe + 1im * dE_dIm) / 2
    end
    out
end

# Code form: (U^φ φ)_c where U^φ_{c,c_p} = Σ V[?, ?, ?, ?] · (...)
# Test 4 conventions: (V_slot_swap × ρ_or_κ_index_swap)
# For φ⁴ piece (no ρ/κ): only V slot swap matters
function eom_phi4_form(phi_v, V_chan, D; V_swap=false)
    out = zeros(ComplexF64, D)
    for c in 1:D, c_p in 1:D
        Uab = 0.0im
        for c2 in 1:D, c2_p in 1:D
            Vk = V_swap ? V_chan[c_p, c, c2, c2_p] : V_chan[c, c_p, c2, c2_p]
            Vk == 0.0 && continue
            Uab += Vk * conj(phi_v[c2_p]) * phi_v[c2]
        end
        out[c] += Uab * phi_v[c_p]
    end
    out
end

# For φ²ρ piece: V slot AND ρ index swap
function eom_phi2_rho_form(phi_v, rho_v, V_chan, D; V_swap=false, rho_swap=false)
    out = zeros(ComplexF64, D)
    for c in 1:D, c_p in 1:D
        Uab = 0.0im
        for c2 in 1:D, c2_p in 1:D
            Vk = V_swap ? V_chan[c_p, c, c2, c2_p] : V_chan[c, c_p, c2, c2_p]
            Vk == 0.0 && continue
            rho_term = rho_swap ? rho_v[c2_p, c2] : rho_v[c2, c2_p]
            Uab += Vk * rho_term
        end
        out[c] += Uab * phi_v[c_p]
    end
    out
end

# For φφκ* piece: Δ^φ · φ*. Test V slot conventions (1↔2, 2↔3) and κ swap.
function eom_kappa_form(phi_v, kappa_v, V_chan, D; V_conv=:orig, kappa_swap=false)
    out = zeros(ComplexF64, D)
    for c in 1:D, c_p in 1:D
        Dab = 0.0im
        for c2 in 1:D, c2_p in 1:D
            Vk = if V_conv === :orig
                V_chan[c, c_p, c2, c2_p]
            elseif V_conv === :slot_1_2
                V_chan[c_p, c, c2, c2_p]
            elseif V_conv === :slot_2_3
                V_chan[c, c2, c_p, c2_p]
            elseif V_conv === :slot_1_2_and_2_3  # c → 1, c_p → 2 to slot 3
                V_chan[c2, c, c_p, c2_p]
            else
                error("unknown V_conv")
            end
            Vk == 0.0 && continue
            kappa_term = kappa_swap ? kappa_v[c2_p, c2] : kappa_v[c2, c2_p]
            Dab += Vk * kappa_term
        end
        out[c] += Dab * conj(phi_v[c_p])
    end
    out
end

@printf("=== Per-term FD audit ===\n\n")

# ── φ⁴ piece ──
fd_phi4 = fd_wirtinger(p -> E_phi4(p, V_chan, D), copy(phi_value))
@printf("φ⁴ piece — δE/δφ* = %s\n", fd_phi4[1])
for V_swap in (false, true)
    eom = eom_phi4_form(phi_value, V_chan, D; V_swap=V_swap)
    rel = norm(eom - fd_phi4) / norm(fd_phi4)
    @printf("  V_swap=%s: rel dev = %.3e  %s\n",
        V_swap, rel, rel < 1e-4 ? "✓" : "")
end

# ── φ²ρ piece ──
fd_phi2_rho = fd_wirtinger(p -> E_phi2_rho(p, rho_value, V_chan, D), copy(phi_value))
@printf("\nφ²ρ piece — δE/δφ* = %s\n", fd_phi2_rho[1])
for V_swap in (false, true), rho_swap in (false, true)
    eom = eom_phi2_rho_form(phi_value, rho_value, V_chan, D;
        V_swap=V_swap, rho_swap=rho_swap)
    rel = norm(eom - fd_phi2_rho) / max(norm(fd_phi2_rho), 1e-20)
    @printf("  V_swap=%s, rho_swap=%s: rel dev = %.3e  %s\n",
        V_swap, rho_swap, rel, rel < 1e-4 ? "✓" : "")
end

# ── φφκ* piece — extended V conv search ──
fd_kappa = fd_wirtinger(p -> E_phi_phi_kappa(p, kappa_value, V_chan, D), copy(phi_value))
@printf("\nφφκ* piece — δE/δφ* = %s\n", fd_kappa[1])
for V_conv in (:orig, :slot_1_2, :slot_2_3, :slot_1_2_and_2_3),
    kappa_swap in (false, true)

    eom = eom_kappa_form(phi_value, kappa_value, V_chan, D;
        V_conv=V_conv, kappa_swap=kappa_swap)
    rel = norm(eom - fd_kappa) / max(norm(fd_kappa), 1e-20)
    @printf("  V_conv=%-20s, kappa_swap=%s: rel dev = %.3e  %s\n",
        V_conv, kappa_swap, rel, rel < 1e-4 ? "✓" : "")
end

@printf("\n=== Verdict ===\n")
@printf("Per-term winning conventions identify the correct U^φ + Δ^φ\n")
@printf("formulation. Apply each to strang_step.jl and test C4.\n")

# Verify FULL EOM with the convention selected per-term matches full FD
function eom_full_after_fix(phi_v, rho_v, kappa_v, V_chan, D)
    out = zeros(ComplexF64, D)
    for c in 1:D, c_p in 1:D
        Uab = 0.0im
        Dab = 0.0im
        for c2 in 1:D, c2_p in 1:D
            # U^φ piece: V slot 1↔2 swap
            Vk_U = V_chan[c_p, c, c2, c2_p]
            if Vk_U != 0.0
                Uab += Vk_U * (conj(phi_v[c2_p]) * phi_v[c2] + rho_v[c2, c2_p])
            end
            # Δ^φ piece: V slot 2↔3 swap
            Vk_D = V_chan[c, c2, c_p, c2_p]
            if Vk_D != 0.0
                Dab += Vk_D * kappa_v[c2, c2_p]
            end
        end
        out[c] += Uab * phi_v[c_p] + Dab * conj(phi_v[c_p])
    end
    out
end

# FD of FULL E_int (all pieces)
function E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
    E_phi4(phi_v, V_chan, D) +
    E_phi2_rho(phi_v, rho_v, V_chan, D) +
    E_phi_phi_kappa(phi_v, kappa_v, V_chan, D)
end

fd_full = fd_wirtinger(p -> E_int_full(p, rho_value, kappa_value, V_chan, D), copy(phi_value))
eom_after = eom_full_after_fix(phi_value, rho_value, kappa_value, V_chan, D)
@printf("\n=== FULL state EOM (after per-term fix) vs FD ===\n")
@printf("EOM:  %s\n", eom_after[1])
@printf("FD:   %s\n", fd_full[1])
@printf("rel dev = %.3e\n", norm(eom_after - fd_full) / norm(fd_full))

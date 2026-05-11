# Audit δE/δκ*_{a,b} and δE/δρ_{a,b} via FD, find correct V conventions
# for Δ^R and U^R.

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

# Energy pieces (mirroring energy.jl)
function E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
    s = 0.0im
    for c in 1:D, c_p in 1:D, c2 in 1:D, c2_p in 1:D
        Vk = V_chan[c, c_p, c2, c2_p]
        Vk == 0.0 && continue
        phi4 = conj(phi_v[c_p]) * conj(phi_v[c2_p]) * phi_v[c] * phi_v[c2]
        phi2_rho = 2 * rho_v[c, c_p] * conj(phi_v[c2_p]) * phi_v[c2]
        rho_rho = rho_v[c, c_p] * rho_v[c2, c2_p]
        kk = conj(kappa_v[c, c2]) * kappa_v[c_p, c2_p]
        cross = 2 * real(phi_v[c] * phi_v[c2] * conj(kappa_v[c_p, c2_p]))
        s += Vk * (phi4 + phi2_rho + rho_rho + kk + cross)
    end
    0.5 * real(s)
end

# δE/δκ*_{a,b} via Wirtinger FD
function fd_dE_dkappa_star(phi_v, rho_v, kappa_v, gS, F, D; eps=1e-6)
    out = zeros(ComplexF64, D, D)
    for a in 1:D, b in 1:D
        E0 = E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
        # Re part
        kappa_v[a, b] += eps
        Ep = E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
        dRe = (Ep - E0) / eps
        kappa_v[a, b] -= eps
        # Im part
        kappa_v[a, b] += 1im * eps
        Ep2 = E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
        dIm = (Ep2 - E0) / eps
        kappa_v[a, b] -= 1im * eps
        out[a, b] = (dRe + 1im * dIm) / 2
    end
    out
end

# δE/δρ_{a,b} via Wirtinger FD (for Hermitian ρ — symmetric vary)
function fd_dE_drho(phi_v, rho_v, kappa_v, gS, F, D; eps=1e-6)
    out = zeros(ComplexF64, D, D)
    for a in 1:D, b in 1:D
        E0 = E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
        rho_v[a, b] += eps
        Ep = E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
        dRe = (Ep - E0) / eps
        rho_v[a, b] -= eps
        rho_v[a, b] += 1im * eps
        Ep2 = E_int_full(phi_v, rho_v, kappa_v, V_chan, D)
        dIm = (Ep2 - E0) / eps
        rho_v[a, b] -= 1im * eps
        out[a, b] = (dRe + 1im * dIm) / 2
    end
    out
end

# Code conventions to test for Δ^R = δE/δκ* = V[?, ?, ?, ?] · (φφ + κ)
function delta_R_form(phi_v, kappa_v, V_chan, D; V_conv=:orig, kappa_idx=:c2_c2p)
    out = zeros(ComplexF64, D, D)
    for c in 1:D, c_p in 1:D
        for c2 in 1:D, c2_p in 1:D
            Vk = if V_conv === :orig
                V_chan[c, c_p, c2, c2_p]
            elseif V_conv === :slot_1_2
                V_chan[c_p, c, c2, c2_p]
            elseif V_conv === :slot_2_3
                V_chan[c, c2, c_p, c2_p]
            elseif V_conv === :slot_1_3
                V_chan[c2, c_p, c, c2_p]
            elseif V_conv === :slot_2_4
                V_chan[c, c2_p, c2, c_p]
            else
                error("unknown V_conv")
            end
            Vk == 0.0 && continue
            phi_term = phi_v[c2] * phi_v[c2_p]
            kappa_term = if kappa_idx === :c2_c2p
                kappa_v[c2, c2_p]
            elseif kappa_idx === :c2p_c2
                kappa_v[c2_p, c2]
            end
            out[c, c_p] += Vk * (phi_term + kappa_term)
        end
    end
    out
end

# U^R = δE/δρ_{c_p, c} = V[?, ?, ?, ?] · (φ*φ + ρ)  with factor option
function U_R_form(phi_v, rho_v, V_chan, D; V_conv=:orig, rho_idx=:c2_c2p, factor=1.0)
    out = zeros(ComplexF64, D, D)
    for c in 1:D, c_p in 1:D
        for c2 in 1:D, c2_p in 1:D
            Vk = if V_conv === :orig
                V_chan[c, c_p, c2, c2_p]
            elseif V_conv === :slot_1_2
                V_chan[c_p, c, c2, c2_p]
            elseif V_conv === :slot_2_3
                V_chan[c, c2, c_p, c2_p]
            end
            Vk == 0.0 && continue
            phi_term = conj(phi_v[c2_p]) * phi_v[c2]
            rho_term = if rho_idx === :c2_c2p
                rho_v[c2, c2_p]
            elseif rho_idx === :c2p_c2
                rho_v[c2_p, c2]
            end
            out[c, c_p] += factor * Vk * (phi_term + rho_term)
        end
    end
    out
end

# --- δE/δκ* audit ---
@printf("=== δE/δκ* (= Δ^R variational target) ===\n")
fd_dkappa = fd_dE_dkappa_star(phi_value, rho_value, copy(kappa_value), gS, F, D)
@printf("FD δE/δκ*_{1,1} = %s\n", fd_dkappa[1, 1])
for V_conv in (:orig, :slot_1_2, :slot_2_3, :slot_1_3, :slot_2_4),
    kappa_idx in (:c2_c2p, :c2p_c2)
    DR = delta_R_form(phi_value, kappa_value, V_chan, D;
        V_conv=V_conv, kappa_idx=kappa_idx)
    rel = norm(DR .- fd_dkappa) / max(norm(fd_dkappa), 1e-20)
    @printf("  V_conv=%-12s, κ=%-7s: rel dev = %.3e  %s\n",
        V_conv, kappa_idx, rel, rel < 1e-4 ? "✓" : "")
end

# --- δE/δρ audit ---
@printf("\n=== δE/δρ (= U^R variational target) ===\n")
fd_drho = fd_dE_drho(phi_value, copy(rho_value), kappa_value, gS, F, D)
@printf("FD δE/δρ_{1,1} = %s\n", fd_drho[1, 1])
for V_conv in (:orig, :slot_1_2, :slot_2_3),
    rho_idx in (:c2_c2p, :c2p_c2),
    factor in (1.0, 2.0)
    UR = U_R_form(phi_value, rho_value, V_chan, D;
        V_conv=V_conv, rho_idx=rho_idx, factor=factor)
    rel = norm(UR .- fd_drho) / max(norm(fd_drho), 1e-20)
    @printf("  V_conv=%-12s, ρ=%-7s, factor=%.1f: rel dev = %.3e  %s\n",
        V_conv, rho_idx, factor, rel, rel < 1e-4 ? "✓" : "")
end

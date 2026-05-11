# Test different U^φ extraction conventions against FD δE/δφ*.

using SpinorBEC, LinearAlgebra, Random, Printf

F = 1
D = 2F + 1
Random.seed!(101)

phi_value = randn(ComplexF64, D) .* 0.3
A = randn(ComplexF64, D, D) .* 0.05
rho_value = (A + A') / 2
B = randn(ComplexF64, D, D) .* 0.05
kappa_value = (B + transpose(B)) / 2

V_chan = SpinorBEC.channel_kernel(F, Dict{Int, Float64}(0 => 0.5, 2 => 0.1))

# Variational δE/δφ*_a from φ⁴ piece directly: Σ V_{c,a;c2,c2'} φ*_{c2'} φ_c φ_{c2}
function variational_phi4(phi_value, V_chan, D)
    out = zeros(ComplexF64, D)
    for a in 1:D
        v = 0.0im
        for c in 1:D, c2 in 1:D, c2_p in 1:D
            Vk = V_chan[c, a, c2, c2_p]
            Vk == 0.0 && continue
            v += Vk * conj(phi_value[c2_p]) * phi_value[c] * phi_value[c2]
        end
        out[a] = v
    end
    out
end

# Code's form: U^φ_{a,b} = Σ V_{a,b;c2,c2'} φ*_{c2'} φ_{c2}; (U^φ φ)_a = Σ_b U^φ_{a,b} φ_b
function code_form_phi4(phi_value, V_chan, D)
    out = zeros(ComplexF64, D)
    for a in 1:D
        for b in 1:D
            Uab = 0.0im
            for c2 in 1:D, c2_p in 1:D
                Vk = V_chan[a, b, c2, c2_p]
                Vk == 0.0 && continue
                Uab += Vk * conj(phi_value[c2_p]) * phi_value[c2]
            end
            out[a] += Uab * phi_value[b]
        end
    end
    out
end

# Alt extraction: U^φ_{a,b} = Σ V_{b,a;c2,c2'} φ*_{c2'} φ_{c2}   (swap slot 1↔2)
function alt1_form_phi4(phi_value, V_chan, D)
    out = zeros(ComplexF64, D)
    for a in 1:D
        for b in 1:D
            Uab = 0.0im
            for c2 in 1:D, c2_p in 1:D
                Vk = V_chan[b, a, c2, c2_p]
                Vk == 0.0 && continue
                Uab += Vk * conj(phi_value[c2_p]) * phi_value[c2]
            end
            out[a] += Uab * phi_value[b]
        end
    end
    out
end

# Symmetric average (Hermitian)
function symmetric_form_phi4(phi_value, V_chan, D)
    (code_form_phi4(phi_value, V_chan, D) .+ alt1_form_phi4(phi_value, V_chan, D)) ./ 2
end

gS = Dict{Int, Float64}(0 => 0.5, 2 => 0.1)

# FD δE/δφ*_a (Wirtinger) on full energy with random ρ, κ
function fd_full(phi_value, rho_value, kappa_value, gS, F, D; eps=1e-6)
    state = init_tdhfb_vacuum(reshape(phi_value, 1, D))
    state.rho .= reshape(rho_value, 1, D, D)
    state.kappa .= reshape(kappa_value, 1, D, D)
    V_ext = zeros(Float64, 1, D)
    out = zeros(ComplexF64, D)
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
        out[c] = (dE_dRe + 1im * dE_dIm) / 2
    end
    out
end

# φ⁴-only FD
function fd_phi4_only(phi_value, gS, F, D; eps=1e-6)
    state = init_tdhfb_vacuum(reshape(phi_value, 1, D))
    V_ext = zeros(Float64, 1, D)
    out = zeros(ComplexF64, D)
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
        out[c] = (dE_dRe + 1im * dE_dIm) / 2
    end
    out
end

@printf("=== U^φ extraction forms vs FD (φ⁴ piece only, ρ=κ=0) ===\n\n")
var_phi4 = variational_phi4(phi_value, V_chan, D)
code_phi4 = code_form_phi4(phi_value, V_chan, D)
alt1_phi4 = alt1_form_phi4(phi_value, V_chan, D)
sym_phi4 = symmetric_form_phi4(phi_value, V_chan, D)
fd_phi4 = fd_phi4_only(phi_value, gS, F, D)

# Note: variational and FD should match (both compute δE/δφ* of complex E)
@printf("Variational δE/δφ*: %s\n", var_phi4[1])
@printf("FD δE/δφ*:          %s\n", fd_phi4[1])
@printf("ratio |var/FD| (c=1): %.4f\n", abs(var_phi4[1])/abs(fd_phi4[1]))
@printf("\n")

@printf("Code form:    %s, |ratio code/FD| = %.4f\n", code_phi4[1], abs(code_phi4[1])/abs(fd_phi4[1]))
@printf("Alt 1↔2 swap: %s, |ratio alt/FD|  = %.4f\n", alt1_phi4[1], abs(alt1_phi4[1])/abs(fd_phi4[1]))
@printf("Symmetric avg: %s, |ratio sym/FD| = %.4f\n", sym_phi4[1], abs(sym_phi4[1])/abs(fd_phi4[1]))
@printf("\n")

@printf("Diff norms:\n")
@printf("  ‖code − FD‖ / ‖FD‖     = %.3e\n", norm(code_phi4 - fd_phi4) / norm(fd_phi4))
@printf("  ‖alt − FD‖ / ‖FD‖      = %.3e\n", norm(alt1_phi4 - fd_phi4) / norm(fd_phi4))
@printf("  ‖sym − FD‖ / ‖FD‖      = %.3e\n", norm(sym_phi4 - fd_phi4) / norm(fd_phi4))
@printf("  ‖var − FD‖ / ‖FD‖      = %.3e\n", norm(var_phi4 - fd_phi4) / norm(fd_phi4))

# ───── Full ρ + κ test ─────
@printf("\n=== Full state with ρ, κ — current code's EOM vs FD ===\n")
function code_form_full(phi_v, rho_v, kappa_v, V_chan, D)
    out = zeros(ComplexF64, D)
    for c in 1:D
        for c_p in 1:D
            Uab = 0.0im
            Dab = 0.0im
            for c2 in 1:D, c2_p in 1:D
                Vk = V_chan[c_p, c, c2, c2_p]
                Vk == 0.0 && continue
                Uab += Vk * (conj(phi_v[c2_p]) * phi_v[c2] + rho_v[c2, c2_p])
                Dab += Vk * kappa_v[c2, c2_p]
            end
            out[c] += Uab * phi_v[c_p] + Dab * conj(phi_v[c_p])
        end
    end
    out
end
eom_now = code_form_full(phi_value, rho_value, kappa_value, V_chan, D)
fd_full_v = fd_full(phi_value, rho_value, kappa_value, gS, F, D)
@printf("EOM (round-4 slot 1↔2 swap): %s\n", eom_now[1])
@printf("FD δE/δφ*:                   %s\n", fd_full_v[1])
@printf("‖EOM − FD‖ / ‖FD‖ = %.3e\n", norm(eom_now .- fd_full_v) / norm(fd_full_v))

# Differentiable simulation scaffold (#62).
#
# Status: PROOF OF CONCEPT — uses ForwardDiff.jl on a 1D scalar GP toy
# to demonstrate ∇_θ E_GS[θ] computation. Real impl will need
# Enzyme.jl rules for cuFFT and our custom spin-rotation kernel.
#
# Real impl plan:
#   1. Enzyme.jl over the split-step hot path. Hard parts:
#      - cuFFT primitives (need custom adjoints)
#      - The Yoshida composition (mostly fine, all ops are unitary)
#      - apply_uniform_spin_rotation! (now allocation-free; should
#        differentiate cleanly via the matmul path added in 59a52a1)
#   2. Wrap find_ground_state in a "loss" closure: L(θ) = E[ψ_GS(θ)] +
#      α · ‖measured_n - ‖ψ_GS(θ)‖²‖² for fitting against experimental
#      Faraday or absorption images.
#   3. Adam-step θ; verify against finite differences first.

using ForwardDiff
using LinearAlgebra

# --- Toy 1D scalar GP ---------------------------------------------------
# i ∂_t ψ = (-½ ∂_x² + ½ω² x² + g |ψ|²) ψ
# Find GS energy as a function of trap frequency ω.

function toy_gs_energy(ω::T; n_x::Int = 64, L::T = T(8.0),
                       g::T = T(2.0), n_steps::Int = 800,
                       dt::T = T(0.01)) where {T<:Real}
    dx = 2L / n_x
    x = T[(-L + dx * (i - 1) + dx / 2) for i in 1:n_x]
    psi = exp.(-x .^ 2 ./ 2) .|> Complex{T}
    psi ./= sqrt(sum(abs2, psi) * dx)
    V = T(0.5) .* ω^2 .* x .^ 2

    # Spectral kinetic operator (no FFT — just diff matrix for AD friendliness)
    k = T(2π) ./ (T(2L)) .* T[i <= n_x ÷ 2 ? i - 1 : i - 1 - n_x for i in 1:n_x]
    K = T(0.5) .* k .^ 2

    for _ in 1:n_steps
        # Potential half-step
        n = abs2.(psi)
        @. psi *= exp(-(V + g * n) * dt / 2)
        # Kinetic full step (FFT replaced with a manual DFT for AD; only OK at small n_x)
        psi_k = _manual_dft(psi)
        @. psi_k *= exp(-K * dt)
        psi = _manual_idft(psi_k)
        @. psi *= exp(-(V + g * abs2(psi)) * dt / 2)
        psi ./= sqrt(sum(abs2, psi) * dx)
    end

    # Energy expectation
    n = abs2.(psi)
    psi_k = _manual_dft(psi)
    E_kin = sum(K .* abs2.(psi_k)) * dx
    E_pot = sum(V .* n) * dx
    E_int = T(0.5) * g * sum(n .^ 2) * dx
    real(E_kin + E_pot + E_int)
end

# Manual DFT — slow but differentiable through ForwardDiff. For real Enzyme
# work we'd hit cuFFT directly with custom adjoints.
function _manual_dft(x::AbstractVector{Complex{T}}) where {T}
    N = length(x)
    out = zeros(Complex{T}, N)
    for k in 0:N-1, n in 0:N-1
        out[k+1] += x[n+1] * exp(-2π * im * k * n / N)
    end
    out ./ sqrt(T(N))
end
function _manual_idft(X::AbstractVector{Complex{T}}) where {T}
    N = length(X)
    out = zeros(Complex{T}, N)
    for n in 0:N-1, k in 0:N-1
        out[n+1] += X[k+1] * exp(2π * im * k * n / N)
    end
    out ./ sqrt(T(N))
end

# --- Smoke: gradient of E_GS w.r.t. ω ----------------------------------
function main()
    ω0 = 1.0
    @info "Toy 1D GP: E_GS(ω = $ω0) and dE/dω via ForwardDiff"
    E0 = toy_gs_energy(ω0)
    dE = ForwardDiff.derivative(toy_gs_energy, ω0)
    @info "result" E_GS = E0 dE_dω = dE virial_check_x_dω = E0  # virial theorem links

    # Sanity: finite difference
    h = 1e-4
    fd = (toy_gs_energy(ω0 + h) - toy_gs_energy(ω0 - h)) / (2h)
    @info "finite-difference check" dE_FD = fd diff = abs(dE - fd)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

# Neural Quantum States (NQS) scaffold (#63).
#
# Status: PROOF OF CONCEPT — defines a tiny Restricted Boltzmann
# Machine ansatz for a small spin chain, runs a few Metropolis-Hastings
# samples, prints the variational energy. Strictly disconnected from
# the GP solver — NQS lives in lattice second-quantised formalism, not
# continuous ψ(x).
#
# Real impl plan:
#   1. Decide on the lattice problem first (super-Tonks chain?
#      frustrated spin lattice?). NQS is overkill for mean-field GP.
#   2. Pick the network family: RBM (analytic), FNN (more flexible),
#      transformer (state-of-art but slow).
#   3. Variational Monte Carlo with stochastic reconfiguration (SR)
#      or natural-gradient — plain Adam underfits.
#   4. Validate on a known exact-diagonalisation case (e.g. 4-site
#      transverse-field Ising) before scaling.

using Random
using LinearAlgebra
using Statistics

# --- Tiny RBM ansatz for an N-spin chain --------------------------------
#
# log ψ(σ) = Σ_i a_i σ_i + Σ_j log(2 cosh(b_j + Σ_i W_ji σ_i))
#
# σ_i ∈ {-1, +1}.

struct RBM
    a::Vector{ComplexF64}        # visible bias (N)
    b::Vector{ComplexF64}        # hidden bias (M)
    W::Matrix{ComplexF64}        # coupling (M, N)
end

RBM(N::Int, M::Int) = RBM(
    randn(ComplexF64, N) .* 0.1,
    randn(ComplexF64, M) .* 0.1,
    randn(ComplexF64, M, N) .* 0.1,
)

function log_psi(rbm::RBM, σ::AbstractVector{<:Real})
    a_term = sum(rbm.a .* σ)
    h_term = sum(log.(2 .* cosh.(rbm.b .+ rbm.W * σ)))
    a_term + h_term
end

# --- Transverse-field Ising local energy ------------------------------
# H = -J Σ σ_i^z σ_{i+1}^z - h Σ σ_i^x  (open boundary)
function tfi_local_energy(rbm::RBM, σ::Vector{Float64};
                          J::Float64 = 1.0, h::Float64 = 1.0)
    N = length(σ)
    E = 0.0 + 0.0im
    log_psi_σ = log_psi(rbm, σ)
    # Diagonal Ising
    for i in 1:(N - 1)
        E -= J * σ[i] * σ[i + 1]
    end
    # Off-diagonal transverse field: σ^x flips one spin
    for i in 1:N
        σ_flip = copy(σ); σ_flip[i] *= -1
        E -= h * exp(log_psi(rbm, σ_flip) - log_psi_σ)
    end
    real(E)
end

# --- Metropolis sampling ----------------------------------------------
function metropolis_sample!(rbm::RBM, σ::Vector{Float64}, n_steps::Int)
    N = length(σ)
    accepts = 0
    for _ in 1:n_steps
        i = rand(1:N)
        σ_new = copy(σ); σ_new[i] *= -1
        ratio = abs2(exp(log_psi(rbm, σ_new) - log_psi(rbm, σ)))
        if rand() < ratio
            σ .= σ_new
            accepts += 1
        end
    end
    accepts / n_steps
end

function variational_energy(rbm::RBM, σ::Vector{Float64};
                             n_samples::Int = 200, J::Float64 = 1.0,
                             h::Float64 = 1.0)
    energies = Float64[]
    for _ in 1:n_samples
        metropolis_sample!(rbm, σ, 5)
        push!(energies, tfi_local_energy(rbm, σ; J = J, h = h))
    end
    mean(energies), std(energies) / sqrt(n_samples)
end

function main()
    Random.seed!(2026_04_25)
    N = 4
    M = 8
    rbm = RBM(N, M)
    σ = Float64[rand([-1, 1]) for _ in 1:N]

    @info "tiny RBM | N=$N spins | M=$M hidden"
    accept_rate = metropolis_sample!(rbm, σ, 1000)   # warm-up
    @info "Metropolis warm-up" accept_rate
    E, σ_E = variational_energy(rbm, σ; n_samples = 500)
    @info "variational energy" E_per_site = E / N "± $(round(σ_E / N; digits = 3))"
    @info "(N=4 TFI exact GS ≈ -1.07/site at h/J=1.0; untrained RBM is well above.)"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

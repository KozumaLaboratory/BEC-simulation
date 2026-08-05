# Device-side Gaussian draws for the stochastic solvers (SGPE / SPGPE / TWA).
#
# The generic path in foundation/backend.jl draws on the host and copies. At
# 48³/D=3 that was 14.7 ms of a 15.1 ms SGPE step — 33× the unitary split-step —
# which is what made second-scale stochastic evolution look infeasible. CURAND
# fills in place with no PCIe traffic.
#
# `rng` is ignored: CURAND keeps one stream per device, seeded by
# `seed_device_rng!`. Reproducibility is per trajectory, not per call.

SpinorBEC._randn_fill!(::CUDABackend, arr::CuArray{<:Real}, _rng) = CUDA.randn!(arr)

SpinorBEC.seed_device_rng!(::CUDABackend, seed::Integer) = (CUDA.seed!(UInt64(seed)); nothing)

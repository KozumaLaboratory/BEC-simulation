# superfluid_fraction on a device array.
#
# Every loop in the implementation scalar-indexes, so a CuArray ψ would throw
# under CUDA's scalar-indexing guard unless the entry point brings it home.
# Analyzers get hosted by `_run_analyzer`, but the direct call is public API
# and has to stand on its own. Gated on CUDA.functional(); a no-op on CPU-only
# machines, load-bearing wherever a GPU runner exists.

using SpinorBEC
using Test

@testset "superfluid_fraction on device arrays (gated)" begin
    cuda_available = try
        import CUDA
        CUDA.functional()
    catch
        false
    end

    if !cuda_available
        @info "CUDA not functional — superfluid_fraction GPU test skipped"
        @test true
        return nothing
    end

    grid = make_grid(GridConfig((32, 16, 16), (10.0, 6.0, 6.0)))
    k = 2π / 10.0
    A = 0.6
    psi_h = zeros(ComplexF64, 32, 16, 16, 3)
    for (i, x) in enumerate(grid.x[1]), j in 1:16, l in 1:16
        psi_h[i, j, l, 2] = sqrt(1.0 + A * cos(k * x))
    end
    n_h = SpinorBEC.total_density(psi_h, 3)

    psi_d = CUDA.CuArray(psi_h)
    n_d = CUDA.CuArray(n_h)
    # `cu` downcasts to Float32 — the mixed-precision (`dtype: f32`) path — so
    # the entry point has to accept a Float32 density too, not only Float64.
    psi_d32 = CUDA.cu(psi_h)

    for method in (:leggett, :relaxed)
        host = superfluid_fraction(psi_h, grid; method)
        @test superfluid_fraction(psi_d, grid; method) ≈ host rtol = 1e-12
        @test superfluid_fraction(n_d, grid; method) ≈ host rtol = 1e-12
        @test superfluid_fraction(psi_d32, grid; method) ≈ host rtol = 1e-5
    end

    # The analytic anchor still has to hold through the device path.
    @test superfluid_fraction(psi_d, grid) ≈ sqrt(1 - A^2) rtol = 1e-8
end

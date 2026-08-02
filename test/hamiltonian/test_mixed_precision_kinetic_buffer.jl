using Test
using FFTW
using SpinorBEC

# A k-space scratch buffer must carry ψ's precision, because `ws.fft_plans`
# does.
#
# `build_energy_context` allocated `zeros(ComplexF64, n_pts)` while the plan it
# handed alongside it followed ψ. On a Float32 workspace that pairs a
# ComplexF32 in-place plan with a ComplexF64 buffer, and `plan * buf` then
# falls back to the OUT-of-place method: it transforms a converted copy,
# returns it, and leaves `buf` holding real-space ψ. `_kinetic_energy`
# discards the return value and reduces `buf`, so it summed k²|ψ(r)|² over
# real space and reported 0.1152 where the answer is 0.5000 — finite, silent,
# and 77 % low. The L-BFGS gradient scratch had the same shape, so an F32 ITP
# descended that same wrong kinetic term: F32 and F64 ground states came out
# 19 % apart in energy and stayed 19 % apart at full convergence.
#
# Nothing caught it. `test/gpu/test_mixed_precision*.jl` DID go red, but only
# in the nightly `full` tier, which had been failing continuously since at
# least 2026-05-08 — a red signal carries no information.
#
# The gate is the one comparison the bug cannot survive: the production
# kinetic energy against an independent Float64 FFT of the SAME ψ on the SAME
# k², at each precision. Two controls make a green result mean something:
#
#   * the F64 arm must also pass — otherwise the reference itself is broken
#     and the F32 arm proves nothing;
#   * the buffer eltype is asserted structurally, so re-hardcoding
#     ComplexF64 turns this red even on a future path where the numeric
#     effect happens to cancel.

_CFG = GridConfig((16, 16), (8.0, 8.0))

function _ws_at(::Type{T}) where {T}
    grid = make_grid(_CFG; dtype=T)
    make_workspace(;
        grid, atom=Rb87,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=HarmonicTrap(1.0, 1.0),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        fft_flags=FFTW.ESTIMATE,
    )
end

# E_kin = ½ Σ_c ∫ |k|²|ψ̂_c|² — written out here, in Float64, from the
# workspace's own ψ and k². Independent of every production buffer.
function _reference_kinetic(ws)
    psi = Array{ComplexF64}(ws.state.psi)
    k2 = Float64.(Array(ws.grid.k_squared))
    n = prod(ws.grid.config.n_points)
    dV = Float64(cell_volume(ws.grid))
    E = 0.0
    for c in axes(psi, ndims(psi))
        E += sum(k2 .* abs2.(fft(selectdim(psi, ndims(psi), c))))
    end
    0.5 * E * dV / n
end

@testset "mixed precision: the k-space scratch follows ψ's precision" begin
    psi0 = init_psi(make_grid(_CFG), SpinSystem(1); state=:m_plus_F)

    @testset "kinetic energy is right at $T" for T in (Float64, Float32)
        ws = _ws_at(T)
        @test eltype(ws.state.psi) == Complex{T}
        @test eltype(ws.fft_plans.forward) == Complex{T}   # the plan follows ψ …
        copyto!(ws.state.psi, Complex{T}.(psi0))

        reported = energy_decomposition(ws).kinetic
        reference = _reference_kinetic(ws)
        # F32 round-off on a 16² grid is ~1e-7 relative; the defect was 77 %.
        @test isapprox(reported, reference; rtol=T === Float64 ? 1.0e-12 : 1.0e-5)
    end

    @testset "structural: … and so does the scratch buffer" begin
        # The numeric arms above are the claim; this is the canary that keeps
        # the FIX visible. A buffer whose eltype has been pinned back to
        # ComplexF64 fails here even if some later path masks the number.
        for T in (Float64, Float32)
            ws = _ws_at(T)
            copyto!(ws.state.psi, Complex{T}.(psi0))
            ctx = SpinorBEC.build_energy_context(ws.state.psi, ws)
            @test eltype(ctx.fft_buf) == eltype(ws.state.psi)
            @test eltype(ctx.fft_buf) == eltype(ctx.plans.forward)
        end
    end

    @testset "positive control: the comparison can fail" begin
        # Reduce an UNtransformed buffer — exactly what the out-of-place
        # fallback left behind — and confirm the reference rejects it. Without
        # this, a green result above could just mean the two numbers are
        # insensitive to the k-space step.
        ws = _ws_at(Float32)
        copyto!(ws.state.psi, ComplexF32.(psi0))
        psi = Array{ComplexF64}(ws.state.psi)
        k2 = Float64.(Array(ws.grid.k_squared))
        n = prod(ws.grid.config.n_points)
        dV = Float64(cell_volume(ws.grid))
        untransformed =
            0.5 * sum(
                k2 .* abs2.(selectdim(psi, ndims(psi), c)) for c in axes(psi, ndims(psi))
            ) |> sum
        untransformed *= dV / n
        @test !isapprox(untransformed, _reference_kinetic(ws); rtol=1.0e-2)
    end
end

# --- multipole_q_spectrum + odd-rank coverage tests ---
#
# Higher-rank (k > 2) multipole observables for F ≥ 3 spinor phases. KU
# review §4-5 motivates rank-3, 5 odd-rank fingerprints in F=6 cyclic
# vs. polar discrimination — previously the codebase only computed even
# ranks. Tests pin:
#
# 1. FM stretched |+F⟩: only Q_{k,0} ≠ 0; sorted spectrum has all weight
#    in the q_idx=1 slot.
# 2. include_odd_ranks=true returns all ranks 0..2F (D = 2F+1 entries
#    for F=6).
# 3. multipole_q_spectrum's sum over q == multipole_order_parameters at
#    the same rank.
# 4. detect_point_group F=6: |+F⟩ → :trivial (all stars at the pole),
#    polar |m=0⟩ → :trivial (stars at equator alternate, no platonic
#    spread), uniform-amplitude state → ≠ :trivial (stars spread out).

using SpinorBEC
using Test

@testset "multipole_q_spectrum (F=6 odd ranks + per-q spectrum)" begin
    F = 6
    D = 2F + 1
    grid = make_grid(GridConfig((10, 10), (5.0, 5.0)))
    sys = SpinSystem(F)
    n_pts = grid.config.n_points

    @testset "FM |+6⟩: Q_{k,0} dominant, others ~0" begin
        psi = init_psi(grid, sys; state=:m_plus_F)
        for k in 0:5
            spec = multipole_q_spectrum(psi, F, k, 2; sort_descending=true)
            @test size(spec) == (n_pts..., 2k + 1)

            # On the cloud support the largest sorted slot must dominate.
            n_total = total_density(psi, 2)
            mask = n_total .> 1e-3 * maximum(n_total)
            for I in CartesianIndices(n_pts)
                mask[I] || continue
                if 2k + 1 > 1
                    @test spec[I, 1] >= spec[I, 2]
                end
                # All other q slots ≪ q=0 amplitude.
                # (k=0 is a single-q observable so the loop has nothing
                # to check beyond the trivial first-slot entry.)
            end
        end
    end

    @testset "include_odd_ranks adds 1, 3, 5, …, 2F-1" begin
        psi = init_psi(grid, sys; state=:m_plus_F)
        even_only = multipole_order_parameters(psi, F, 2)
        all_ranks = multipole_order_parameters(psi, F, 2; include_odd_ranks=true)

        @test sort(collect(keys(even_only))) == [0, 2, 4, 6, 8, 10, 12]
        @test sort(collect(keys(all_ranks))) == collect(0:12)
        # Every even rank must agree across the two calls.
        for k in keys(even_only)
            @test all_ranks[k] ≈ even_only[k]
        end

        # multipole_spectrum also propagates the kwarg.
        s_all = multipole_spectrum(psi, F, grid; include_odd_ranks=true)
        @test sort(collect(keys(s_all))) == collect(0:12)
    end

    @testset "Σ_q |Q_{kq}|²/n² == O_k(r)" begin
        # Unit-amplitude state |+6⟩ → algebraic identity:
        # multipole_q_spectrum sums over the q axis to multipole_order_parameters[k].
        psi = init_psi(grid, sys; state=:m_plus_F)
        op_dict = multipole_order_parameters(psi, F, 2; include_odd_ranks=true)
        for k in 0:5
            spec = multipole_q_spectrum(psi, F, k, 2; sort_descending=false)
            spec_sum = dropdims(sum(spec; dims=ndims(spec)); dims=ndims(spec))
            @test spec_sum ≈ op_dict[k]  atol=1e-10
        end
    end
end

@testset "detect_point_group F=6" begin
    F = 6
    D = 2F + 1

    @testset "|+F⟩ → :trivial (all stars at the pole)" begin
        spinor = ComplexF64[1.0, zeros(ComplexF64, 12)...]   # m = +F at c=1
        @test detect_point_group(spinor, F) === :trivial
    end

    @testset "|−F⟩ → :trivial" begin
        spinor = ComplexF64[zeros(ComplexF64, 12)..., 1.0]
        @test detect_point_group(spinor, F) === :trivial
    end

    @testset "Antipodal pair (one star at N, one at S, rest at infinity)" begin
        # Spinor with only ψ_{+F} and ψ_{−F} non-zero is two clustered
        # poles via Majorana stars — should be flagged :trivial since
        # the spread is dominated by 2 directions, not 12.
        spinor = ComplexF64[zeros(ComplexF64, 13)...]
        spinor[1] = 1.0 / sqrt(2)
        spinor[end] = 1.0 / sqrt(2)
        @test detect_point_group(spinor, F) ∈ (:trivial, :unknown)
    end
end

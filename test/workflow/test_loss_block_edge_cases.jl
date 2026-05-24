# Loss-block YAML parsing edge cases.
#
# `_parse_loss_params` accepts six input shapes (false/0/null, scalar,
# K3_cubic, K3_per_m_cubic, K3_per_m_si, L3_per_m) and routes between
# linear-in-n vs quadratic-in-n loss kernels. A single mis-routing
# silently changes the EdH density-spike rate by 2-10× without throwing
# (memory: `gotcha_K3_routing_pre_2026_05_13.md` fix 6bfe9d9). Pin each
# routing boundary so a regression points to one specific guard.

using Test
using SpinorBEC
using SpinorBEC: _parse_loss_params

@testset "Loss-block parsing edge cases" begin
    rb87 = AtomSpecies("Rb87", 1.443e-25, 1, 0.0, 0.0, 0.0)

    @testset "Scalar / null / false / 0 shapes" begin
        @test _parse_loss_params(nothing) === nothing
        @test _parse_loss_params(false) === nothing
        @test _parse_loss_params(0) === nothing
        @test _parse_loss_params(0.0) === nothing

        loss = _parse_loss_params(0.05)
        @test loss isa LossParams
        @test loss.gamma_dr == 0.05
    end

    @testset "K3_per_m alias removal raises ArgumentError" begin
        # 2026-05-24 alias removal: `K3_per_m` previously routed dimless
        # values into the canonical K3_per_m_cubic slot, but the name
        # confused users into thinking SI units worked. Removal raises
        # at parse time with a guiding message.
        node = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "K3_per_m" => [0.01, 0.02, 0.05],
        )
        @test_throws ArgumentError _parse_loss_params(node)
    end

    @testset "K3_per_m_cubic rejects string entries" begin
        # Common user mistake: SI-unit strings accidentally placed in the
        # dimensionless slot. Must throw with guidance toward K3_per_m_si.
        node = Dict{String, Any}(
            "K3_per_m_cubic" => ["1e-41 m^6/s", "1e-41 m^6/s"]
        )
        @test_throws ArgumentError _parse_loss_params(node)

        # Mixed numeric + string: still rejected (any single string trips it).
        node_mixed = Dict{String, Any}(
            "K3_per_m_cubic" => [0.1, "1e-41 m^6/s"]
        )
        @test_throws ArgumentError _parse_loss_params(node_mixed)
    end

    @testset "K3_per_m_si requires atom + N_atoms + omega_ref" begin
        node = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "K3_per_m_si" => ["1.5e-30 m^6/s"],
        )

        # No atom → throw.
        @test_throws ArgumentError _parse_loss_params(node;
            N_atoms=10_000, omega_ref=2π * 100.0)

        # No N_atoms → throw.
        @test_throws ArgumentError _parse_loss_params(node;
            atom=rb87, omega_ref=2π * 100.0)

        # No omega_ref → throw.
        @test_throws ArgumentError _parse_loss_params(node;
            atom=rb87, N_atoms=10_000)

        # All three present → succeeds.
        loss = _parse_loss_params(node;
            atom=rb87, N_atoms=10_000, omega_ref=2π * 100.0)
        @test loss isa LossParams
        @test length(loss.K3_per_m_cubic) == 1
        @test loss.K3_per_m_cubic[1] > 0
    end

    @testset "Non-Dict / non-Real / non-Bool loss raises" begin
        # Strings, symbols, arrays at the top level are nonsense.
        @test_throws ArgumentError _parse_loss_params("loss")
        @test_throws ArgumentError _parse_loss_params([1.0, 2.0])
    end

    @testset "L3_per_m stays in legacy linear-in-n slot" begin
        # Legacy 2-body shape (linear in n) — must NOT pollute K3_per_m_cubic.
        # The 2026-05 routing bug had K3 inputs land in this slot, silently
        # changing the EdH loss rate by 2× at n=2n0.
        node = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "L3_per_m" => [0.01, 0.02, 0.03],
        )
        loss = _parse_loss_params(node)
        @test loss.L3_per_m == [0.01, 0.02, 0.03]
        @test isempty(loss.K3_per_m_cubic)
    end

    @testset "K3_per_m_cubic + K3_per_m_si: SI overrides" begin
        # If both are given, the SI form populates K3_per_m_cubic (last write
        # wins in the parser). Pin the precedence so a re-ordering refactor
        # cannot silently flip it.
        node = Dict{String, Any}(
            "gamma_dr" => 0.0,
            "K3_per_m_cubic" => [0.5, 0.5, 0.5],
            "K3_per_m_si" => ["1.0e-30 m^6/s"],
        )
        loss = _parse_loss_params(node;
            atom=rb87, N_atoms=10_000, omega_ref=2π * 100.0)
        # SI path runs LAST in the parser body → overrides the dimless input.
        @test length(loss.K3_per_m_cubic) == 1
    end
end

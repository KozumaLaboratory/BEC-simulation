# Gates for the unified Zeeman field B(r,t) — the general time-dependent spatial
# arm (`spatiotemporal_zeeman_field`) plus the converter's exclusivity / GPU /
# spin-rotating-frame rejections. The uniform and static-spatial arms are
# already gated by test_spatial_zeeman / test_zeeman_* / the oracle suite; this
# file covers the previously-uncovered functional B(r,t) path.

using SpinorBEC
using SpinorBEC: field_arrays_at, is_uniform, spin_density_vector, split_step!
using Statistics: std
using Test

@testset "Zeeman B(r,t) (unified field)" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    sm = spin_matrices(1)
    atom = Rb87
    ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    trap = HarmonicTrap((1.0, 1.0, 1.0))

    @testset "general static arm ≡ separable static arm" begin
        g = 0.3
        sep = zeeman_field(grid; bz=(x, y, z) -> g * x)
        gen = spatiotemporal_zeeman_field(grid; bz=(x, y, z, t) -> g * x)
        asep = field_arrays_at(sep, 0.0)
        agen = field_arrays_at(gen, 0.0)
        @test agen[3] ≈ asep[3]
        @test all(agen[1] .≈ 0.0) && all(agen[2] .≈ 0.0) && all(agen[4] .≈ 0.0)
    end

    @testset "general arm tracks time (separable in this case)" begin
        gen = spatiotemporal_zeeman_field(grid; bz=(x, y, z, t) -> 0.5 * x * sin(t))
        # field_arrays_at reuses scratch each call (fine in the propagator, which
        # materialises once per step), so copy before sampling a second time.
        a_on = copy(field_arrays_at(gen, π / 2)[3])   # sin = 1
        a_off = copy(field_arrays_at(gen, 0.0)[3])    # sin = 0
        @test maximum(abs, a_on) > 0.1
        @test all(a_off .≈ 0.0)
    end

    @testset "B(r,t) dynamics: unitary + structured texture" begin
        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false)
        gen = spatiotemporal_zeeman_field(grid; bz=(x, y, z, t) -> 0.8 * x * sin(2.0 * t))
        ws = make_workspace(; grid, atom, interactions=ip, potential=trap,
            sim_params=sp, zeeman=gen)
        @test !is_uniform(ws.zeeman)
        # transverse spin-coherent so the B(r,t)·F rotation produces a texture
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 2)
        copyto!(ws.state.psi, psi)
        dV = cell_volume(grid)
        n0 = sum(abs2, ws.state.psi) * dV
        for _ in 1:20
            ws.state.t += sp.dt
            split_step!(ws)
        end
        @test sum(abs2, ws.state.psi) * dV ≈ n0 rtol = 1e-6   # unitary
        _, _, fz = spin_density_vector(Array(ws.state.psi), sm, 3)
        @test std(vec(fz)) > 1e-6                              # B(r,t) imprinted a texture
    end

    @testset "spatial / general arm rejects GPU + spin-rotating frame" begin
        sp = SimParams(; dt=0.005, n_steps=1)
        gen = spatiotemporal_zeeman_field(grid; bz=(x, y, z, t) -> 0.3 * x)
        kw = (; grid, atom, interactions=ip, potential=trap, sim_params=sp, zeeman=gen)
        @test !is_uniform(make_workspace(; kw...).zeeman)
        @test_throws ArgumentError make_workspace(; kw..., backend=CUDABackend())
        sp_rf = SimParams(; dt=0.005, n_steps=1, spin_rotating_frame_omega=0.2)
        @test_throws ArgumentError make_workspace(;
            grid, atom, interactions=ip, potential=trap, sim_params=sp_rf, zeeman=gen)
    end

    @testset "uniform + spatial inputs are mutually exclusive (v1)" begin
        sp = SimParams(; dt=0.005, n_steps=1)
        sz = quadrupole_field(grid; gradient=0.4)
        @test_throws ArgumentError make_workspace(; grid, atom, interactions=ip,
            potential=trap, sim_params=sp, zeeman=ZeemanParams(0.5, 0.0), spatial_zeeman=sz)
    end
end

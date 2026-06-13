# Gates for the unified Zeeman field B(r,t) — the general time-dependent spatial
# arm (`spatiotemporal_zeeman_field`) plus the converter's exclusivity / GPU /
# spin-rotating-frame rejections. The uniform and static-spatial arms are
# already gated by test_spatial_zeeman / test_zeeman_* / the oracle suite; this
# file covers the previously-uncovered functional B(r,t) path.

using SpinorBEC
using SpinorBEC: field_arrays_at, is_uniform, spin_density_vector, split_step!,
    ConstantWaveform
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
            split_step!(ws)   # advances ws.state.t internally
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

    # Helper: evolve a state under `zf` for `nsteps` Strang steps of `dt`.
    # split_step! advances ws.state.t internally, so the loop must NOT.
    function _evolve(zf, nsteps, dt; theta=π / 2)
        sp = SimParams(; dt=dt, n_steps=1, imaginary_time=false)
        ws = make_workspace(; grid, atom, interactions=ip, potential=trap,
            sim_params=sp, zeeman=zf)
        copyto!(ws.state.psi, init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=theta))
        ws.state.t = 0.0
        for _ in 1:nsteps
            split_step!(ws)
        end
        Array(ws.state.psi)
    end

    @testset "separable time-dependent spatial arm (profile × envelope)" begin
        sep_static = zeeman_field(grid; bz=(x, y, z) -> 0.5 * x)
        sep_td = zeeman_field(grid; bz=(x, y, z) -> 0.5 * x, bz_wf=ConstantWaveform(0.6))
        base = copy(field_arrays_at(sep_static, 0.0)[3])
        scaled = copy(field_arrays_at(sep_td, 0.0)[3])
        @test scaled ≈ 0.6 .* base
        # separable (profile × const envelope) ≡ general with the scale baked in
        gen = spatiotemporal_zeeman_field(grid; bz=(x, y, z, t) -> 0.5 * x * 0.6)
        @test copy(field_arrays_at(sep_td, 1.0)[3]) ≈ copy(field_arrays_at(gen, 1.0)[3])
        # dynamics smoke: unitary
        dV = cell_volume(grid)
        ψ = _evolve(sep_td, 10, 0.005)
        @test sum(abs2, ψ) * dV ≈ 1.0 rtol = 1e-6
    end

    @testset "constant-in-time general field ≡ static spatial field (multi-step)" begin
        # The general functional arm at a frozen t reduces to the audited static
        # kernel; a constant-in-t field must reproduce the static separable field
        # bit-for-bit over a multi-step run. This anchors the general-arm physics
        # to the independently-gated static path.
        gen = spatiotemporal_zeeman_field(grid;
            bz=(x, y, z, t) -> 0.6 * x, bx=(x, y, z, t) -> 0.2 * y)
        stat = zeeman_field(grid; bz=(x, y, z) -> 0.6 * x, bx=(x, y, z) -> 0.2 * y)
        @test _evolve(gen, 15, 0.004) ≈ _evolve(stat, 15, 0.004) rtol = 1e-12
    end

    @testset "moving B(r,t): O(dt²) Strang convergence" begin
        # Richardson: ‖ψ_n − ψ_2n‖ / ‖ψ_2n − ψ_4n‖ ≈ 4 for a 2nd-order scheme.
        T = 0.2
        movefield() = spatiotemporal_zeeman_field(grid; bz=(x, y, z, t) -> 0.7 * x * sin(3.0 * t))
        p1 = _evolve(movefield(), 20, T / 20)
        p2 = _evolve(movefield(), 40, T / 40)
        p4 = _evolve(movefield(), 80, T / 80)
        e12 = sqrt(sum(abs2, p1 .- p2))
        e24 = sqrt(sum(abs2, p2 .- p4))
        ratio = e12 / max(e24, 1e-30)
        @test 3.0 < ratio < 5.0
    end
end

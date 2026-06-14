# Larmor precession — quantitative physics gate for the unified ZeemanField
# transverse arm.
#
# A uniform transverse field b = (b_x, 0, 0) drives the operator H = -(b·F)
# (q = 0). A stretched spin-coherent state |m = +F⟩_z (⟨F⟩ = (0,0,F)) stays
# coherent and precesses about x at the LARMOR frequency ω_L = |b_x|:
#
#     ⟨F_z⟩(t) = F·cos(ω_L t),   ⟨F_y⟩(t) = F·sin(ω_L t),   ⟨F_x⟩(t) = 0.
#
# This complements the existing F=1 DIAGONAL precession test
# (test_physics_level3.jl) by exercising the TRANSVERSE Euler-rotation path of
# the unified field at general F — including the production case F=6 (D=13).
# With a spatially-uniform state, zero interactions and no potential, the only
# active term is the Zeeman rotation, which the propagator applies exactly per
# step (q = 0 ⇒ no Strang split), so the precession is tight to round-off ×
# checkpoint resolution. Verification type: B (physics agreement).

using Test
using SpinorBEC
using LinearAlgebra

# Build a normalised, spatially-uniform |m = +F⟩_z spinor on a 1D grid.
function _uniform_stretched_z(grid, L, D)
    n = grid.config.n_points[1]
    psi = zeros(ComplexF64, n, D)
    @views psi[:, 1] .= 1 / √L          # c = 1 ↦ m = +F; ∫|ψ|² dV = 1
    psi
end

@testset "Larmor precession (transverse field, general F)" begin
    ω_L = 1.0          # b_x ≡ Larmor frequency (internal units)
    dt = 0.002
    L = 10.0
    checkpoints = [π / 4, π / 2, π, 3π / 2, 2π]   # ω_L·t

    for (F, label) in ((1, "F=1"), (6, "F=6 (Eu-like)"))
        @testset "$label: ⟨F_z⟩=F·cos(ω_L t), ⟨F_y⟩=F·sin(ω_L t)" begin
            D = 2F + 1
            sm = spin_matrices(F)
            grid = make_grid(GridConfig((32,), (L,)))
            dV = cell_volume(grid)
            atom = AtomSpecies("test_spin$(F)", 1.0, F, 0.0, 0.0)

            cp_steps = [round(Int, t / (ω_L * dt)) for t in checkpoints]
            sp = SimParams(; dt, n_steps=cp_steps[end], imaginary_time=false)
            ws = make_workspace(;
                grid, atom,
                interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
                zeeman=zeeman_field(; bx=ω_L),          # uniform transverse arm
                potential=NoPotential(),
                sim_params=sp,
                psi_init=_uniform_stretched_z(grid, L, D),
            )

            # sanity: start fully stretched along +z
            fx0, fy0, fz0 = spin_density_vector(ws.state.psi, sm, 1)
            @test sum(fz0) * dV ≈ F atol = 1e-9
            @test abs(sum(fx0) * dV) < 1e-9
            @test abs(sum(fy0) * dV) < 1e-9

            cp = 1
            for s in 1:cp_steps[end]
                split_step!(ws)
                if cp <= length(cp_steps) && s == cp_steps[cp]
                    t = s * dt
                    fx, fy, fz = spin_density_vector(ws.state.psi, sm, 1)
                    Fz, Fy, Fx = sum(fz) * dV, sum(fy) * dV, sum(fx) * dV
                    @test Fz / F ≈ cos(ω_L * t) atol = 2e-3
                    @test Fy / F ≈ sin(ω_L * t) atol = 2e-3
                    @test abs(Fx) < 2e-3            # precession stays in the y–z plane
                    cp += 1
                end
            end
        end
    end
end

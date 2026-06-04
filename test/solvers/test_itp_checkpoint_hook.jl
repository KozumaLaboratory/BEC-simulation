# test/solvers/test_itp_checkpoint_hook.jl
#
# Verifies that `find_ground_state(...; checkpoint=Checkpoint(...),
# checkpoint_every=N)` auto-snapshots the ITP state every N steps to
# the keyed store, and that the snapshot is usable as a `fork!`
# source for branching or resumption.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: Checkpoint, fork!, load_checkpoint, has_checkpoint, ancestry

@testset "find_ground_state auto-snapshot via Checkpoint primitive" begin
    @testset "checkpoint_every=N saves snapshots during ITP" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=200, tol=1e-12,
                checkpoint=cp, checkpoint_key="run1", checkpoint_every=50,
                verbose=false,
            )
            # Snapshot exists
            @test has_checkpoint(cp, "run1")
            snap = load_checkpoint(cp, "run1")
            @test snap.psi isa Array{ComplexF64, 2}
            @test size(snap.psi) == (16, 3)
            @test snap.step > 0
            @test snap.step % 50 == 0  # saved on a multiple of checkpoint_every
        end
    end

    @testset "Snapshot psi matches workspace psi at save time" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=100, tol=1e-12,
                checkpoint=cp, checkpoint_key="match", checkpoint_every=100,
                verbose=false,
            )
            snap = load_checkpoint(cp, "match")
            # checkpoint_every=100 with n_steps=100 → save fires at step 100
            # which is the FINAL state, so snap.psi == ws.state.psi
            @test snap.psi ≈ Array(r.workspace.state.psi)
            @test isapprox(snap.E, r.energy; rtol=1e-10)
        end
    end

    @testset "Branching from intermediate ITP snapshot" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            # First run: save warm state
            ip_warm = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            find_ground_state(;
                grid=grid, atom=atom, interactions=ip_warm,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=100, tol=1e-12,
                checkpoint=cp, checkpoint_key="warm", checkpoint_every=100,
                verbose=false,
            )
            @test has_checkpoint(cp, "warm")

            # Branch: continue ITP from warm state with stronger c0
            fork!(
                cp,
                "warm",
                "branch_strong_c0",
                prev -> begin
                    ip_strong = InteractionParams(Dict(0 => 5.0, 1 => 0.05))
                    r2 = find_ground_state(;
                        grid=grid, atom=atom, interactions=ip_strong,
                        potential=HarmonicTrap((1.0,)),
                        psi_init=prev.psi,
                        dt=0.005, n_steps=100, tol=1e-12,
                        verbose=false,
                    )
                    (; psi=Array(r2.workspace.state.psi), E=r2.energy, c0=5.0)
                end,
            )

            @test has_checkpoint(cp, "branch_strong_c0")
            branch = load_checkpoint(cp, "branch_strong_c0")
            @test branch.c0 == 5.0
            # Branch reached a different (lower) energy: stronger c0 →
            # cloud spreads, but trap dominates so E increases. Either way
            # E_branch ≠ E_warm.
            warm = load_checkpoint(cp, "warm")
            @test branch.E != warm.E

            # Ancestry walks back to warm
            @test ancestry(cp, "branch_strong_c0") == ["warm", "branch_strong_c0"]
        end
    end

    @testset "No checkpoint kwarg → no save (default unchanged)" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=50, tol=1e-12,
                verbose=false,
            )
            # Default: no checkpoint kwarg → no snapshot
            @test !has_checkpoint(cp, "itp_state")
            @test isempty(filter(f -> endswith(f, ".jld2"), readdir(dir)))
        end
    end
end

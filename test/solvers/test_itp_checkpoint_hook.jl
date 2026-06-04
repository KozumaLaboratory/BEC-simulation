# test/solvers/test_itp_checkpoint_hook.jl
#
# Verifies the Checkpoint-primitive integration in find_ground_state.
#
# Semantics:
#   checkpoint=cp                  → ALWAYS save terminal state to key
#                                    (the load-bearing "keep final psi"
#                                    guarantee)
#   checkpoint=cp, save_every=N → also save every N steps
#                                    (enables branching from mid-flight
#                                    via fork! on the same key)
#
# No "snapshot" concept — it's all checkpoints, overwriting the same key.
# Test the unified model + verify fork! ancestry works on intermediates.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: Checkpoint, fork!, load_checkpoint, has_checkpoint, ancestry

@testset "find_ground_state Checkpoint integration" begin
    @testset "save_every=N saves periodically during ITP" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=200, tol=1e-12,
                checkpoint=cp, checkpoint_key="run1", save_every=50,
                verbose=false,
            )
            # Checkpoint exists
            @test has_checkpoint(cp, "run1")
            snap = load_checkpoint(cp, "run1")
            @test snap.psi isa Array{ComplexF64, 2}
            @test size(snap.psi) == (16, 3)
            @test snap.step > 0
            @test snap.step % 50 == 0  # saved on a multiple of save_every
        end
    end

    @testset "Checkpoint psi matches workspace psi at save time" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=100, tol=1e-12,
                checkpoint=cp, checkpoint_key="match", save_every=100,
                verbose=false,
            )
            snap = load_checkpoint(cp, "match")
            # save_every=100 with n_steps=100 → save fires at step 100
            # which is the FINAL state, so snap.psi == ws.state.psi
            @test snap.psi ≈ Array(r.workspace.state.psi)
            @test isapprox(snap.E, r.energy; rtol=1e-10)
        end
    end

    @testset "Branching from intermediate ITP checkpoint" begin
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
                checkpoint=cp, checkpoint_key="warm", save_every=100,
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
            # Default: no checkpoint kwarg → no checkpoint
            @test !has_checkpoint(cp, "itp_state")
            @test isempty(filter(f -> endswith(f, ".jld2"), readdir(dir)))
        end
    end

    @testset "Final state ALWAYS saved (save_every misaligned with n_steps)" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            # save_every=300, n_steps=100 — naive logic would NEVER fire
            # the periodic save (step never reaches 300). The guaranteed
            # final-state save catches this.
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=100, tol=1e-12,
                checkpoint=cp, checkpoint_key="final_save",
                save_every=300,
                verbose=false,
            )
            @test has_checkpoint(cp, "final_save")
            snap = load_checkpoint(cp, "final_save")
            @test snap.psi ≈ Array(r.workspace.state.psi)
            @test snap.step == 100  # actual final step, not 300
        end
    end

    @testset "Final state saved on early convergence break" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            # Easy convergence: weak interactions, large tol → break early
            ip = InteractionParams(Dict(0 => 0.1, 1 => 0.0))
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=5000, tol=1e-4,
                checkpoint=cp, checkpoint_key="early_conv",
                save_every=1000,
                verbose=false,
            )
            @test r.converged
            @test r.last_step < 5000  # broke early
            @test has_checkpoint(cp, "early_conv")
            snap = load_checkpoint(cp, "early_conv")
            # checkpoint.step matches the actual break point, not some
            # save_every multiple before it
            @test snap.step == r.last_step
            @test snap.converged == true
        end
    end

    @testset "No save_every needed for final save (every=0)" begin
        mktempdir() do dir
            cp = Checkpoint(dir)
            grid = make_grid(GridConfig{1}((16,), (8.0,)))
            atom = Rb87
            ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
            # save_every=0 (default) — no periodic saves, but the
            # final state should still land in the checkpoint store.
            r = find_ground_state(;
                grid=grid, atom=atom, interactions=ip,
                potential=HarmonicTrap((1.0,)),
                dt=0.005, n_steps=50, tol=1e-12,
                checkpoint=cp, checkpoint_key="only_final",
                # save_every NOT specified → 0
                verbose=false,
            )
            @test has_checkpoint(cp, "only_final")
            snap = load_checkpoint(cp, "only_final")
            @test snap.psi ≈ Array(r.workspace.state.psi)
        end
    end
end

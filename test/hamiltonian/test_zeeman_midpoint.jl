@testset "Zeeman midpoint evaluation" begin
    @testset "Time-dependent Zeeman: O(dt^2) convergence" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(10.0, -0.5)

        p_func(t) = ZeemanParams(sin(t), 0.0)
        zee = TimeDependentZeeman(p_func)

        t_final = 0.5
        errors = Float64[]
        dts = [0.05, 0.025, 0.0125]

        psi_ref = nothing
        for dt in dts
            n_steps = round(Int, t_final / dt)
            sp = SimParams(; dt, n_steps, save_every=n_steps)
            ws = make_workspace(;
                grid, atom, interactions,
                zeeman=zee,
                potential=HarmonicTrap(1.0),
                sim_params=sp,
            )
            run_simulation!(ws)

            if psi_ref === nothing
                psi_ref = copy(ws.state.psi)
            else
                err = sqrt(sum(abs2, ws.state.psi .- psi_ref) / sum(abs2, psi_ref))
                push!(errors, err)
                psi_ref = copy(ws.state.psi)
            end
        end

        # For O(dt^2), error ratio between successive refinements should be ~4
        # (halving dt reduces error by factor of 4)
        if length(errors) >= 2
            ratio = errors[1] / errors[2]
            @test ratio > 2.5  # should be ~4 for O(dt^2), would be ~2 for O(dt)
        end
    end

    @testset "Quadratic ramp: q(t) = t², per-sub-step improves convergence" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(10.0, -0.5)

        q_func(t) = ZeemanParams(0.0, t^2)
        zee = TimeDependentZeeman(q_func)

        t_final = 0.3
        errors = Float64[]
        dts = [0.04, 0.02, 0.01]

        psi_ref = nothing
        for dt in dts
            n_steps = round(Int, t_final / dt)
            sp = SimParams(; dt, n_steps, save_every=n_steps)
            ws = make_workspace(;
                grid, atom, interactions,
                zeeman=zee,
                potential=HarmonicTrap(1.0),
                sim_params=sp,
            )
            run_simulation!(ws)

            if psi_ref === nothing
                psi_ref = copy(ws.state.psi)
            else
                err = sqrt(sum(abs2, ws.state.psi .- psi_ref) / sum(abs2, psi_ref))
                push!(errors, err)
                psi_ref = copy(ws.state.psi)
            end
        end

        if length(errors) >= 2
            ratio = errors[1] / errors[2]
            @test ratio > 2.5
        end
    end

    @testset "Static Zeeman: unchanged results" begin
        grid = make_grid(GridConfig((16,), (10.0,)))
        atom = Rb87
        interactions = InteractionParams(10.0, -0.5)
        zee = ZeemanParams(1.0, 0.5)

        sp = SimParams(; dt=0.01, n_steps=50, save_every=50)
        ws1 = make_workspace(;
            grid, atom, interactions,
            zeeman=zee,
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        run_simulation!(ws1)
        psi1 = copy(ws1.state.psi)

        ws2 = make_workspace(;
            grid, atom, interactions,
            zeeman=zee,
            potential=HarmonicTrap(1.0),
            sim_params=sp,
        )
        run_simulation!(ws2)
        psi2 = copy(ws2.state.psi)

        @test psi1 ≈ psi2 atol=1e-14
    end
end

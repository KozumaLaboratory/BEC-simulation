@testset "DDI Zero-Padding" begin
    @testset "make_ddi_padded creates correct shapes" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        ctx = make_ddi_padded(grid, Rb87; c_dd=1.0)
        @test ctx.padded_shape == (128,)
        @test size(ctx.Q_xx) == rfft_output_shape((128,))
        @test size(ctx.Fx_pad) == (128,)
    end

    @testset "make_ddi_padded 2D" begin
        config = GridConfig((32, 32), (10.0, 10.0))
        grid = make_grid(config)
        ctx = make_ddi_padded(grid, Rb87; c_dd=1.0)
        @test ctx.padded_shape == (64, 64)
        @test size(ctx.Q_xx) == rfft_output_shape((64, 64))
    end

    @testset "Padded DDI norm conservation (1D)" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=50)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
            enable_ddi=true, c_dd=1.0,
            ddi_padding=true,
        )
        @test ws.ddi_padded !== nothing
        @test ws.ddi_padded isa DDIPaddedContext

        N0 = total_norm(ws.state.psi, ws.grid)
        for _ in 1:50
            split_step!(ws)
        end
        @test total_norm(ws.state.psi, ws.grid) ≈ N0 rtol = 1e-5
    end

    @testset "Padded vs unpadded for localized state (1D)" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.005, n_steps=20)

        ws_pad = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
            enable_ddi=true, c_dd=1.0,
            ddi_padding=true,
        )

        ws_no = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => -0.5)),
            potential=HarmonicTrap(1.0),
            sim_params=sp,
            enable_ddi=true, c_dd=1.0,
            ddi_padding=false,
        )

        for _ in 1:20
            split_step!(ws_pad)
            split_step!(ws_no)
        end

        # Both should preserve norm
        @test total_norm(ws_pad.state.psi, ws_pad.grid) ≈ 1.0 rtol = 1e-4
        @test total_norm(ws_no.state.psi, ws_no.grid) ≈ 1.0 rtol = 1e-4

        # Results should be similar (DDI is weak here) but not identical
        diff = sum(abs2, ws_pad.state.psi .- ws_no.state.psi) / sum(abs2, ws_no.state.psi)
        @test diff < 0.1
    end

    @testset "Padded rotation crops to corner (App. A defect 9, 2D/3D)" begin
        # THE defect-9 regression. The padded convolution returns Φ on
        # the 2×-per-dim grid; the rotation must read psi's [1:n...]
        # corner. The 2026-05-10 batched-gemm rewrite switched to LINEAR
        # indexing, which for ndim ≥ 2 walks full padded columns into the
        # pad region (56/64 voxels wrong at 8×8). Decisive test: rotating
        # with a marker-filled padded Φ must equal rotating with the
        # explicitly-cropped corner. Pre-fix: max|Δ| ≈ 0.25; post-fix 0.
        for (dims, box) in (((8, 8), (4.0, 4.0)), ((4, 4, 4), (4.0, 4.0, 4.0)))
            nd = length(dims)
            grid = make_grid(GridConfig(dims, box))
            sp = SimParams(; dt=0.01, n_steps=1)
            ws = make_workspace(;
                grid, atom=Rb87,
                interactions=InteractionParams(Dict(0 => 0.5, 1 => 0.1)),
                zeeman=ZeemanParams(0.0, 0.0),
                potential=HarmonicTrap(ntuple(_ -> 1.0, nd)),
                sim_params=sp,
            )
            sm = ws.spin_matrices
            D = sm.system.n_components
            pad = ntuple(d -> 2 * dims[d], nd)
            crop = CartesianIndices(dims)

            psi0 = zeros(ComplexF64, dims..., D)
            for I in CartesianIndices(dims), c in 1:D
                psi0[I, c] = cis(0.3 * (sum(Tuple(I)) + c)) * (1.0 + 0.1c)
            end
            # padded fields: marker 7.77 everywhere, physical corner
            # overwritten with a deterministic pattern.
            mkpad(s) = begin
                a = fill(7.77, pad)
                for I in CartesianIndices(dims)
                    a[I] = cos(s * sum(Tuple(I)) + s)
                end
                a
            end
            px, py, pz = mkpad(1.0), mkpad(2.0), mkpad(3.0)
            cx, cy, cz = px[crop], py[crop], pz[crop]   # contiguous corner copies

            @testset "nd=$nd imaginary_time=$it" for it in (false, true)
                A = copy(psi0)
                SpinorBEC._apply_ddi_rotation!(
                    A, px, py, pz, sm, 0.05, nd; imaginary_time=it
                )
                B = copy(psi0)
                SpinorBEC._apply_ddi_rotation!(
                    B, cx, cy, cz, sm, 0.05, nd; imaginary_time=it
                )
                @test maximum(abs, A .- B) < 1e-13
                # the rotation must actually DO something (else 0≡0 is vacuous)
                @test maximum(abs, B .- psi0) > 1e-3
            end
        end
    end

    @testset "Padded DDI step ≡ dumb padded RHS (dt-valley, 2D smooth)" begin
        # Independent-statement physics gate: the production padded
        # propagator step's first-order action must equal the dumb
        # zero-padded DDI RHS (dumb_rhs_ddi_padded, an aperiodic
        # convolution on the doubled box, cropped back). Smooth state ⇒
        # Nyquist power → 0, so the rfft Nyquist/rep convention is
        # invisible and the residual descends as O(dt). Also a second
        # witness to the crop: pre-fix the scrambled rotation plateaus.
        grid = make_grid(GridConfig((16, 16), (12.0, 12.0)))
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(;
            grid, atom=Cr52,
            interactions=InteractionParams(Dict(0 => 0.5, 1 => 0.01)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0)),
            sim_params=sp, enable_ddi=true, c_dd=5.0, secular_ddi=false,
            ddi_padding=true,
        )
        sm = ws.spin_matrices
        D = sm.system.n_components
        psi = zeros(ComplexF64, 16, 16, D)
        for I in CartesianIndices((16, 16))
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            gg = exp(-(x^2 + y^2) / 2)
            for c in 1:D
                psi[I, c] = gg * cis(0.2c)
            end
        end
        psi ./= sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))

        g = SpinorBEC.dumb_rhs_ddi_padded(ws, psi; secular=false)
        ng = sqrt(sum(abs2, g))
        @test ng > 1e-8
        res(dt) = begin
            p = copy(psi)
            SpinorBEC.apply_ddi_step!(
                p, sm, ws.ddi, ws.ddi_bufs, dt, 2, ws.ddi_padded
            )
            sqrt(sum(abs2, (p .- psi) ./ (-im * dt) .- g)) / ng
        end
        r1 = res(1e-3)
        r2 = res(1e-4)
        @test r2 < r1                      # descending (Taylor truncation)
        @test r2 < 5e-2                    # reaches the O(dt) floor
        slope = (log10(r1) - log10(r2)) / (log10(1e-3) - log10(1e-4))
        @test 0.6 < slope < 1.5            # first-order
    end

    @testset "ddi_padding=false gives nothing" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
            enable_ddi=true, c_dd=1.0,
            ddi_padding=false,
        )
        @test ws.ddi_padded === nothing
    end

    @testset "No DDI: padding has no effect" begin
        config = GridConfig(64, 20.0)
        grid = make_grid(config)
        sp = SimParams(; dt=0.01, n_steps=10)
        ws = make_workspace(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
            sim_params=sp,
            ddi_padding=true,
        )
        @test ws.ddi === nothing
        @test ws.ddi_padded === nothing
    end
end

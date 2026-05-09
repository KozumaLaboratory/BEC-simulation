# ---------------------------------------------------------------------------
# Precompile workload — exercises the dashboard's hot read/write paths so the
# first /api/density_bin scrub doesn't pay the ~9 s JIT tax. We don't try to
# precompile the simulator (multi-minute build); only the routes a freshly-
# opened browser session walks through, plus a tiny rotating-basis split_step
# call for both Float64/Float32 to seed the F32 specialisation.
#
# Earlier experiments confirmed that pre-compiling the binary-GP YAML pipeline
# path made package precompile take 10+ minutes — same JIT cascade as runtime,
# moved to build time. We keep that path out of the workload; standalone
# binary tests still cover correctness.
# ---------------------------------------------------------------------------

using PrecompileTools

@setup_workload begin
    @compile_workload begin
        tmpdir = mktempdir()
        path = joinpath(tmpdir, "precompile_smoke.jld2")
        try
            psi_frame = zeros(ComplexF32, 4, 4, 4, 3)  # F=1 spinor on a 4³ grid
            psi_frame[2, 2, 2, 2] = 1.0f0 + 0.0f0im
            JLD2.jldopen(path, "w") do f
                f["dynamics/psi_snapshots_streamed/n_snapshots"] = 1
                f["dynamics/psi_snapshots_streamed/spatial_shape"] = [4, 4, 4]
                f["dynamics/psi_snapshots_streamed/n_components"] = 3
                f["dynamics/psi_snapshots_streamed/frame_00001"] = psi_frame
                f["dynamics/times"] = [0.0, 0.1]
                f["grid_box_size"] = (1.0, 1.0, 1.0)
            end
            cache = Dict{String, Any}()
            tup = _load_psi_cached(path, cache, 1)
            _compute_column_density_binary(tup..., 3, path)
            _compute_phase_slice_binary(tup..., 3, nothing, path)
            # _snapshots_metadata internally invokes
            # _global_density_max_total_sampled, so this single call specialises
            # both the metadata reader and the global-max walk.
            _snapshots_metadata(path)
            # Exercise the binary HTTP-response path; the IOBuffer take! →
            # write(::TCPSocket, ::Vector{UInt8}) chain has its own specialisations.
            iob = IOBuffer()
            write(iob, Int32(1), Int32(1), Int32(4), Int32(4), Int32(3), Int32(1))
            write(iob, Float32[0, 1, 0, 1])
            take!(iob)

            # Rotating-basis specialisation primer: build tiny workspaces for
            # both Float64 and Float32 + exercise one split_step call so the
            # runtime JIT does not have to specialise make_rotating_basis_ws{T,...}
            # and the inner kinetic / diagonal / spin substeps for each T at
            # first use. F=1 D=3 on a 4³ grid keeps the specialisation work tiny.
            for T in (Float64, Float32)
                config_rb = GridConfig((4, 4, 4), (T(2.0), T(2.0), T(2.0)))
                grid_rb = make_grid(config_rb)
                V_rb = zeros(T, 4, 4, 4)
                ws_rb = make_rotating_basis_ws(grid_rb, 1, V_rb;
                    p=T(1.0), q=T(0.0), c0=T(1.0), c1=T(0.0),
                    c_dd=T(0.0), gamma_lhy=T(0.0),
                    theta_func=t -> 0.0, phi_func=t -> 0.0,
                    theta_dot_func=t -> 0.0, phi_dot_func=t -> 0.0,
                    gauge_fix=false)
                normalize_rotating!(ws_rb)
                split_step_rotating!(ws_rb, T(0.01), T(0.0))
            end
        catch
            # Don't break package precompile if the workload trips.
        finally
            try
                rm(tmpdir; recursive=true, force=true)
            catch
            end
        end
    end
end

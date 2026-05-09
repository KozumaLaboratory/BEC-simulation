module SpinorBEC

using LinearAlgebra
using StaticArrays
using FFTW
using JLD2
using CodecZlib: ZlibCompressor, GzipCompressor, transcode
using CodecZstd: ZstdCompressor
using YAML
using Unitful
using TimerOutputs
using Random
using Printf
using Dates
using SHA
using Base64: base64encode
import JSON
using SpecialFunctions: erfcx
using Sockets
# WriteVTK + HTTP are now weak deps (see ext/SpinorBECVTKExt,
# ext/SpinorBECHTTPExt). No top-level `using` statements for them here.

const TIMER = TimerOutput()

# ========================================
# FOUNDATION: Core types, math, backend
# ========================================

# 1. Type definitions (must be first). Files load in dependency order:
# Waveform → Grid → AbstractPotential → spin/atom → interactions+Zeeman →
# SimParams/SimState/FFT → DDI/Loss → integrator → Workspace → results/scan.
# (Topical structs split out 2026-05-02; the old `foundation/types.jl`
# umbrella stub was removed in the 2026-05-09 refactor.)
include("foundation/waveform.jl")
include("foundation/types/grid.jl")              # AbstractBackend, GridConfig, Grid, GridF64
include("foundation/types/potentials.jl")        # AbstractPotential + 12 trap / beam / lattice / gradient subtypes
include("foundation/types/spin_atom.jl")         # SpinSystem, SpinMatrices, AtomSpecies
include("foundation/types/interactions_zeeman.jl") # InteractionParams, ZeemanParams, TimeDependent*, Raman, accessors
include("foundation/types/sim_fft.jl")           # SimParams, SimState, FFTPlans, RFFT, BatchedKineticCache, CoriolisCache, AbsorbingBoundary
include("foundation/types/ddi_loss.jl")          # DDIParams, DDIBuffers, DDIPaddedContext, LossParams, LightShift, TensorInteractionCache
include("foundation/types/integrator.jl")        # AdaptiveDtParams, IntegratorConfig, SimulationResult, TWAConfig, EnsembleResult
include("foundation/types/workspace.jl")         # Workspace + workspace_T (depends on everything above)
include("foundation/types/results.jl")           # TOFParams, BdGResult, InstabilityMap, RotonParams, etc
include("foundation/types/scan.jl")              # OverrideScan, ConstrainedJzScan, ITPCheckpoint

# 2. Mathematical foundation
include("foundation/grid.jl")
include("foundation/fft_utils.jl")
include("foundation/backend.jl")
include("foundation/spin_matrices.jl")
include("foundation/spinor_utils.jl")
include("foundation/clebsch_gordan.jl")
include("foundation/spherical_harmonics.jl")

# ========================================
# HAMILTONIAN: Interactions & Potentials
# ========================================

# 3. Interactions
include("hamiltonian/interactions/interactions.jl")
include("hamiltonian/interactions/spin_mixing.jl")
include("hamiltonian/interactions/nematic.jl")
include("hamiltonian/interactions/tensor_interaction.jl")
include("hamiltonian/interactions/ddi/qtensor.jl")     # k-space + quasi-2D Q-tensor builders
include("hamiltonian/interactions/ddi/convolution.jl") # DDIParams + buffers + 6-FFT convolution
include("hamiltonian/interactions/ddi/rotation.jl")    # Euler 5-stage spinor rotation
include("hamiltonian/interactions/ddi.jl")             # apply_ddi_step! entry point
include("hamiltonian/interactions/ddi_padded.jl")
include("hamiltonian/interactions/lhy/phi_one_reg.jl")        # Petrov-regularised universal LHY function
include("hamiltonian/interactions/lhy/polar_contact.jl")  # F-generic polar contact LHY closed form
include("hamiltonian/interactions/lhy/polar_dipolar.jl")  # polar contact + DDI extension
include("hamiltonian/interactions/lhy/fm_contact.jl")     # FM-phase contact LHY (F=6)
include("hamiltonian/interactions/lhy/fm_dipolar.jl")     # FM contact + Lima-Pelster Q_5 DDI dressing
include("hamiltonian/interactions/lhy/icosahedral.jl")    # F=6 icosahedral (I_h) closed-form contact LHY
include("hamiltonian/interactions/lhy/modes_round45.jl")   # 5 standalone closed forms (F=2 BN, F=3 octa, F=4 cube, F=8 octa, F=10 dodec)
include("dynamics/sinatra_helpers.jl")                     # TWA validity helpers (healing length, k-cutoff)
include("dynamics/utils_resolution_sinatra.jl")            # suggest_grid + sinatra_check (Round-7 utilities)
include("hamiltonian/interactions/lhy/dispatch.jl")
include("hamiltonian/interactions/losses.jl")
include("hamiltonian/interactions/absorbing_boundary.jl")

# 4. Potentials
include("hamiltonian/potentials/potentials.jl")
include("hamiltonian/potentials/zeeman.jl")
include("hamiltonian/potentials/raman.jl")
include("hamiltonian/potentials/optics.jl")  # Must be before laser_potential (defines OpticalBeam)
include("hamiltonian/potentials/laser_potential.jl")
include("hamiltonian/potentials/optical_trap.jl")
include("hamiltonian/potentials/light_shift.jl")

# 5. Propagators
include("hamiltonian/integrator/propagators.jl")          # kinetic/potential primitives
include("hamiltonian/integrator/yoshida.jl")              # adaptive Yoshida driver
include("hamiltonian/integrator/split_step_kernels.jl")    # _apply_coriolis_step!, _apply_1d_shear_batch!, _apply_ddi_step_gpu!
include("hamiltonian/integrator/split_step.jl")            # split_step! + half-potential dispatcher
include("hamiltonian/integrator/split_step_composers.jl")  # Yoshida/Suzuki/Blanes-Moan/Omelyan + core composers

# ========================================
# WORKFLOW: Initialization, I/O, monitoring, experiments
# ========================================

# 6. Units (needed by atoms.jl and others)
include("workflow/io/units.jl")

# 7. Initialization
include("workflow/initialization/atoms.jl")
include("workflow/initialization/state_dispatch.jl")    # init_psi + small helpers
include("workflow/initialization/make_workspace.jl")    # make_workspace + _rebuild_workspace
include("workflow/initialization/thomas_fermi.jl")
include("workflow/initialization/initialization.jl")
include("workflow/initialization/state_zoo.jl")
include("foundation/binary_state.jl")
include("workflow/initialization/thermal_noise.jl")
include("workflow/initialization/vacuum_noise.jl")

# 8. I/O
include("workflow/io/io.jl")
include("workflow/io/unitful_support.jl")
include("workflow/io/save_rotating_result.jl")
include("workflow/io/dashboard/encoding.jl")      # bitshuffle + zstd
include("workflow/io/dashboard/cache.jl")         # PSI_CACHE, JLD handle pool, atlas disk cache
include("workflow/io/dashboard/snapshots.jl")     # _load_psi_cached + sibling result.jld2 redirect
include("workflow/io/dashboard/route_helpers.jl") # _parse_run_file / _parse_run_only / _q_int / _q_float / _q_flag / _q_sym
include("workflow/io/dashboard/routes/density.jl")    # density2d/3d/_bin/_max/_atlas/_rotated handlers (8)
include("workflow/io/dashboard/routes/phase.jl")      # phase2d/_bin/3d_bin handlers (3)
include("workflow/io/dashboard/routes/vortex.jl")     # vortex_lines + vorticity3d_bin (2)
include("workflow/io/dashboard/routes/scan.jl")       # scan_group/_status, physics_summary, synthetic_dispersion (4)
include("workflow/io/dashboard/routes/snapshots.jl")  # snapshots, dynamics_series, ensemble (3)
include("workflow/io/dashboard/routes/lab_live.jl")   # lab_list, live_list, live (3)
include("workflow/io/dashboard/routes/misc.jl")       # data, coherence, vector3d_bin (3)
include("workflow/io/dashboard/server/json.jl")      # _write_json + _json_string (must precede routes that build JSON)
include("workflow/io/dashboard/server/data_export.jl") # generate_dashboard_data + export_dashboard
include("workflow/io/dashboard/server/router.jl")    # serve_dashboard + _route_dashboard
include("workflow/io/dashboard/server/static.jl")    # static asset + HTTP response helpers
include("workflow/io/dashboard/websocket.jl")     # WS handshake + frames + serve
include("workflow/io/dashboard/compute/helpers.jl")  # trilinear upsample + run metadata
include("workflow/io/dashboard/compute/density.jl")  # 3D + column density compute
include("workflow/io/dashboard/compute/phase.jl")    # phase slice compute
include("workflow/io/dashboard/compute/binary.jl")   # binary packers (density/atlas/phase)
include("workflow/io/dashboard/pack3d.jl")        # 3D density/vortex/phase/vector binary packers
include("workflow/io/vtk_export.jl")
include("workflow/io/run_summary.jl")
include("workflow/io/html_report.jl")
include("workflow/io/budget.jl")
include("workflow/io/scan_summary.jl")

# 9. Monitoring system (needed by solvers)
include("workflow/monitoring/ascii_plot.jl")
include("workflow/monitoring/logging.jl")
include("workflow/monitoring/resource_monitor.jl")
include("workflow/monitoring/notifications.jl")
include("workflow/monitoring/progress.jl")
include("workflow/monitoring/live_monitor.jl")

# 10. Experiments (defines config types needed by phases)
include("workflow/experiments/runtime/adaptive_advice.jl")
include("workflow/experiments/schema/config_override.jl")  # OverrideMap + scan expansion
include("workflow/experiments/schema/schema.jl")           # YAML validation
include("workflow/experiments/schema/units_block.jl")      # opt-in `units:` rewrite
include("workflow/experiments/schema/templates_block.jl")  # template + mixin expansion
include("workflow/experiments/schema/auto_defaults.jl")    # accuracy: + auto_grid:
include("workflow/experiments/schema/B_block.jl")          # B: → zeeman + B_hat split
include("workflow/experiments/schema/noise_block.jl")      # noise: → temperature/twa/sgpe split
include("workflow/experiments/schema/schema_defaults.jl")  # auto-inject ddi:{} etc.
include("workflow/experiments/schema/helpers_types.jl")            # ConstantValue, LinearRamp, PotentialConfig
include("workflow/experiments/runtime/runtime_misc.jl")             # scale_interactions_quasi_2d, grid normalise, noise seed
include("workflow/experiments/runtime/runtime_io.jl")               # JLD2 result-file writers
include("workflow/experiments/schema/parsing_units.jl")            # Unit-aware numeric (B-field, freq, time)
include("workflow/experiments/schema/parsing_blocks.jl")           # Per-block YAML parsers (zeeman/ddi/inter/loss/potential/scan)
include("workflow/experiments/schema/builders_potential.jl")       # _build_potential / _build_beam / _parse_and_build_potential
include("workflow/experiments/schema/builders_phase.jl")           # waveforms + zeeman + raman builders
include("workflow/experiments/runtime/zeeman_levels.jl")
include("workflow/experiments/pipeline/pipeline_types.jl")
include("workflow/experiments/analyzers/helpers.jl")        # _phase_diff, _line_through_peak, _fwhm_1d, _rms_width_1d, _max_forward_grad
include("workflow/experiments/analyzers/imaging.jl")        # tomography, faraday, absorption, phase_contrast, sg_tof, momentum_distribution
include("workflow/experiments/analyzers/phase.jl")          # phase_classify[/distance], energy_decomposition, multipole_order, majorana_order
include("workflow/experiments/analyzers/topology.jl")       # winding_map, winding_field, monopole_charge, vortex_detect, skyrmion_density, non_abelian_homotopy
include("workflow/experiments/analyzers/spectroscopy.jl")   # bragg, droplet, correlation_length, defect_density, kibble_zurek_stats, domain_analysis
include("workflow/experiments/analyzers/stability.jl")      # stability, bogoliubov, bogoliubov_dispersion + _run_bogoliubov_analyzer
include("workflow/experiments/analyzers/misc.jl")           # summary_json (only analyzer that needs pipeline_results)
include("workflow/experiments/analyzers/analyzers_large.jl")          # skyrmion_detect, synthetic_dim, bogoliubov_mode, rosensweig_pattern, column_density_movie
include("workflow/experiments/pipeline/pipeline_analyzers.jl")       # _run_analyzer dispatch (delegates to all the above)
include("workflow/experiments/pipeline/pipeline_dispatch.jl")    # save_every / b_hat / dt-from-eps / twa / light_shift parsers
include("workflow/experiments/pipeline/pipeline_callbacks.jl")    # sgpe / projected_gp / photon_scattering / live_monitor callback builders
include("workflow/experiments/pipeline/runner.jl")               # parse_pipeline + run_pipeline + _step_dispatch! + AnalyzeStep
include("workflow/experiments/pipeline/run_step_ground_state.jl") # _run_step(::GroundStateStep) + 5 GS helpers
include("workflow/experiments/pipeline/run_step_dynamics.jl")     # _run_step(::DynamicsStep) + dyn helpers + streaming
include("workflow/experiments/pipeline/run_step_binary.jl")       # _run_step(::Binary*Step) + binary helpers
include("workflow/experiments/pipeline/run_step_rotating.jl")     # _run_step(::RotatingBasis*Step) + chirp helpers
include("workflow/experiments/runtime/pulse_sequence.jl")
include("workflow/experiments/runtime/sta_counter_diabatic.jl")
include("workflow/experiments/runtime/feshbach_ramp.jl")
include("solvers/projected_gp.jl")
include("solvers/photon_heating.jl")
include("solvers/sgpe.jl")
# Klaus-regime support (high p, ω_L ≫ trap): rotating-basis (Option γ)
# + scalar-eGPE adiabatic-elimination alternative. See
# `src/rotating_basis/README.md` for the public API and when to use.
include("rotating_basis/workspace.jl")
include("rotating_basis/propagators.jl")
include("rotating_basis/integrators.jl")
include("rotating_basis/analysis.jl")
include("rotating_basis/analyzers.jl")
include("rotating_basis/scalar_egpe.jl")

# CUDA-graph-accelerated split_step (extended by SpinorBECCUDAExt).
# Default implementation = plain split_step! so CPU workspaces work unchanged.
"""
    split_step_captured!(ws) → Nothing

GPU-accelerated variant of `split_step!` that captures the kernel sequence
into a CUDA Graph on first call, then replays it via a single driver call on
subsequent steps. Eliminates the ~5-10 μs per-kernel launch overhead that
dominates large-D F32 runs.

For CPU workspaces this falls back to plain `split_step!`. Requires
`using CUDA` to load the optimised implementation.
"""
function split_step_captured! end
split_step_captured!(ws::Workspace) = split_step!(ws)

"""
    invalidate_split_step_graph!(ws) → Nothing

Drop the cached CUDA Graph for this workspace. No-op on CPU.
"""
function invalidate_split_step_graph! end
invalidate_split_step_graph!(::Workspace) = nothing
include("workflow/experiments/pipeline/pipeline_api.jl")
include("workflow/experiments/pipeline/pipeline_continuation.jl")
include("workflow/experiments/pipeline/run_registry.jl")
include("workflow/experiments/calibration.jl")
include("workflow/io/calibration_drift.jl")
include("workflow/experiments/optimization/faraday_fit.jl")
include("workflow/experiments/optimization/bayesian_opt.jl")
include("workflow/experiments/optimization/bayesian_opt_mf.jl")    # 2-tier multi-fidelity BO
include("workflow/experiments/optimization/bayesian_opt_yaml.jl")
include("workflow/experiments/optimization/active_learning.jl")    # entropy-uncertainty AL for phase scan

# ========================================
# ANALYSIS: Observables & diagnostics
# ========================================

# 11. Analysis (needed by solvers)
include("analysis/compare.jl")          # generic observed-vs-simulated metric stack
include("analysis/observables.jl")
include("analysis/ensemble.jl")
include("analysis/energy.jl")
include("analysis/currents.jl")
include("analysis/vorticity.jl")
include("analysis/vortex_extraction.jl")
include("analysis/diagnostics.jl")
include("analysis/majorana.jl")
include("analysis/tof.jl")
include("analysis/tomography.jl")
include("analysis/faraday.jl")
include("analysis/imaging.jl")
include("analysis/topology.jl")
include("analysis/synthetic_dimension.jl")
include("analysis/time_resolved.jl")
include("analysis/stability_analysis.jl")
include("analysis/spin_rotation.jl")

# 12. Phase exploration (needs experiments for ScanExperiment)
include("analysis/phases/phase_classification.jl")
include("analysis/phases/phase_boundary.jl")
include("analysis/phases/phase_scan.jl")
include("analysis/phases/bogoliubov.jl")            # spectrum + matrices + roton detect + angular map
include("analysis/phases/bogoliubov/scan.jl")        # instability scan + direction grid + supersolid prediction

# ========================================
# SOLVERS: Ground state & time evolution
# ========================================

# 13. Solvers (depend on observables and monitoring)
include("solvers/ground_state.jl")               # validators + public find_ground_state
include("solvers/ground_state/itp_loop.jl")       # _run_itp_loop! core
include("solvers/ground_state/checkpoint.jl")     # save/load/resume/refine
include("solvers/ground_state/adaptive.jl")       # _find_ground_state_adaptive
include("solvers/ground_state/advanced.jl")       # multistart + Jz-constrained
include("solvers/simulation.jl")
include("solvers/adaptive.jl")
include("solvers/embedded_adaptive.jl")
include("solvers/lbfgs/energy_gradient.jl")          # E[ψ] + ∇E + constraint projection
include("solvers/lbfgs/helpers.jl")                  # Sobolev preconditioner + L-BFGS direction + line search
include("solvers/lbfgs/driver.jl")                   # find_ground_state_lbfgs entry
include("solvers/continuation/scan_1d.jl")           # scan_continuation + bidirectional
include("solvers/continuation/scan_2d.jl")           # scan_phase_diagram_2d
include("solvers/continuation/boundary.jl")          # scan_phase_boundary bisection
include("solvers/continuation/pseudo_arclength.jl")   # trace_phase_boundary 2D arclength continuation
include("solvers/continuation/triple_point.jl")        # AL × continuation: triple-point hunting
include("solvers/twa.jl")
include("solvers/binary_simulation.jl")

# Foundation types, grid utilities, atom species, spin matrices, backends:
# all `export`ed at their definition sites in src/foundation/.

# Interactions, LHY tables, Sinatra helpers, quasi-2D scaling: exported
# at definition sites under src/hamiltonian/interactions/, src/dynamics/,
# and src/workflow/experiments/runtime/.

# DDI, potentials (trap/zeeman/optical/laser/light-shift): exported at
# definition sites under src/hamiltonian/.

# Propagators, integrator, spin-mixing, nematic, tensor, losses, absorbing
# boundary, raman, split_step!: all `export`ed at their definition sites
# under src/hamiltonian/.

# Analysis (observables, energy, currents, ensemble, vorticity, majorana,
# tof, faraday, imaging, topology, synthetic_dim, time_resolved, tomography,
# stability, spin_rotation, vortex_extraction, phase_classification,
# bogoliubov, diagnostics, compare): exported at definition sites
# under src/analysis/. Thomas-Fermi state initialisers are exported in
# src/workflow/initialization/state_zoo.jl + thomas_fermi.jl.

# Solvers (find_ground_state, find_ground_state_lbfgs, scan_continuation,
# scan_phase_*, trace_phase_boundary, detect_triple_points,
# run_simulation*!, run_twa, add_vacuum_noise, make_workspace, init_psi):
# all exported at definition sites under src/solvers/ and
# src/workflow/initialization/.

# I/O (save_state/load_state, dashboard data + server, run summaries,
# HTML report, budget, VTK export, rotating-basis result writer,
# LiveMonitor): exported at definition sites under src/workflow/io/
# and src/workflow/monitoring/.

# Pipeline API + STA + Feshbach + SGPE/PGP/photon-scattering callbacks +
# YAML config + run registry + summaries + Bayesian / multi-fidelity opt +
# active-learning + calibration: all exported at definition sites under
# src/workflow/experiments/ and src/solvers/.

# CUDA Graph hooks (defined at top-level, replayed by SpinorBECCUDAExt).
export split_step_captured!, invalidate_split_step_graph!
export BinaryCouplings, BinaryState, find_binary_ground_state,
    is_immiscible, droplet_regime_petrov,
    binary_overlap, binary_separation_radius,
    SpinorBinaryCouplings, SpinorBinaryState, find_spinor_binary_ground_state,
    BinarySimulation, make_binary_simulation, binary_split_step!,
    run_binary_simulation!, binary_norms, binary_total_energy
export init_psi_polar, init_psi_m_plus_F, init_psi_m_minus_F,
    # Legacy aliases (resolve to init_psi_m_plus_F / init_psi_m_minus_F)
    init_psi_ferromagnetic, init_psi_ferromagnetic_min,
    init_psi_uniform, init_psi_antiferromagnetic, init_psi_random,
    init_psi_spin_coherent, init_psi_fl_vortex, init_psi_spin_helix,
    init_psi_cyclic, init_psi_biaxial_nematic, init_psi_polar_core_vortex,
    init_psi_bright_soliton, init_psi_dark_soliton, init_psi_skyrmion,
    init_psi_wavepacket, init_psi_domain_wall, init_psi_two_packets,
    init_psi_chiral_spin_vortex, init_psi_magnetic_domain,
    init_psi_vortex_lattice, init_psi_skyrmion_lattice
export apply_override!, apply_overrides, expand_scan_points, parse_override_map
export OverrideScan, ConstrainedJzScan
export PotentialConfig, ConstantValue, LinearRamp, interpolate_value
export validate_pipeline!, validate_config!
export scan_summary, scan_energy_comparison, print_scan_summary

# Units
export Units

# Tracing
export TIMER, enable_tracing!, disable_tracing!, reset_tracing!

function enable_tracing!()
    TimerOutputs.enable_debug_timings(SpinorBEC)
    enable_timer!(TIMER)
end

function disable_tracing!()
    disable_timer!(TIMER)
end

function reset_tracing!()
    TimerOutputs.reset_timer!(TIMER)
end

# Visualization (defined in Makie extension, exported here for discoverability)
function plot_density end
function plot_spinor end
function plot_spin_texture end
function animate_dynamics end
export plot_density, plot_spinor, plot_spin_texture, animate_dynamics

# ---------------------------------------------------------------------------
# Precompile workload — exercises the dashboard's hot read/write paths so
# the first /api/density_bin scrub doesn't pay the ~9 s JIT tax. We don't
# try to precompile the simulator (multi-minute build); only the routes a
# freshly-opened browser session walks through.
# ---------------------------------------------------------------------------
using PrecompileTools

@setup_workload begin
    @compile_workload begin
        # Tiny synthetic snapshot file mirroring the
        # `dynamics/psi_snapshots_streamed/frame_NNNNN` layout.
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
            # _global_density_max_total_sampled, so this single call
            # specialises both the metadata reader and the global-max walk.
            _snapshots_metadata(path)
            # Exercise the binary HTTP-response path too; the IOBuffer
            # take! → write(::TCPSocket, ::Vector{UInt8}) chain has its
            # own specialisations.
            iob = IOBuffer()
            write(iob, Int32(1), Int32(1), Int32(4), Int32(4), Int32(3), Int32(1))
            write(iob, Float32[0, 1, 0, 1])
            take!(iob)
            # NOTE: Pre-compiling the binary-GP YAML pipeline path was
            # tried here and made package precompile take 10+ minutes —
            # the same JIT cascade that hits the runtime call simply
            # moves to build time. Standalone solver path still works
            # via test/test_binary_simulation.jl; YAML wiring remains a
            # known slow-first-call limitation tracked in the test
            # guards (_SKIP_HEAVY_YAML_INFRA / _SKIP_HEAVY_YAML_ZEEMAN).

            # Rotating-basis specialisation primer: build tiny workspaces
            # for both Float64 and Float32 + exercise one split_step call,
            # so the runtime JIT does not have to specialise
            # `make_rotating_basis_ws{T,...}` and the inner kinetic /
            # diagonal / spin substeps for each T at first use. F=1 D=3
            # on a 4³ grid keeps the specialisation work tiny.
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
                ;
                rm(tmpdir; recursive=true, force=true);
            catch
                ;
            end
        end
    end
end

function __init__()
    __init_templates__()
end

end # module

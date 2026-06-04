#!/usr/bin/env julia
# scripts/m1_sweep_golden_export.jl
#
# Convert M1 sweep partial.jld2 files into SweepResult and emit golden
# per-cell tables (JSON) for `to_viewspec` regression gating. NO image
# output here — the golden = resolved per-cell hex + dominant-m + decision
# gap + clip values is the load-bearing artefact (per the design
# discussion: image renderers differ in AA / font metrics / tick layout
# so gating on PNG is brittle; gating on the per-cell value table is
# both stricter and more meaningful).
#
# Run: julia --project=. scripts/m1_sweep_golden_export.jl
#
# Writes:
#   runs/sprint5_M1_*/golden/per_cell_table.json   (one per M1 run)

using SpinorBEC
using SpinorBEC: SweepAxis, SweepObservable, SweepResult,
    ModelSpec, Hypothesis,
    write_golden_per_cell_table, write_viewspec
using JLD2
using JSON
using Dates
using Printf

const M1_RUNS = [
    ("runs/sprint5_M1_ITP_omega_sweep", "m1_itp_sweep.jld2", "partial.jld2"),
    ("runs/sprint5_M1_ITP_omega_sweep_polished", "partial.jld2", nothing),
    ("runs/sprint5_M1_ITP_cpu_scout", "partial.jld2", nothing),
    ("runs/sprint5_M1_ITP_omega_sweep_converged", "partial.jld2", nothing),
]

function load_partial(run_dir::String, preferred::String,
    fallback::Union{Nothing, String})
    for name in (preferred, fallback)
        name === nothing && continue
        path = joinpath(run_dir, name)
        isfile(path) || continue
        d = JLD2.load(path)
        for key in ("partial", "snapshot")
            haskey(d, key) && return d[key]
        end
    end
    return nothing
end

function build_m1_sweep_result(partial::Vector)
    # Axes — unique sorted B_nT / omega across cells.
    omegas = sort(unique(get(c, "omega", 0.0) for c in partial))
    B_vals = sort(unique(get(c, "B_nT", 0.0) for c in partial))

    axes = SweepAxis[
        SweepAxis(:B_nT, "nT", :log, collect(Float64.(B_vals))),
        SweepAxis(:omega, "ω_⊥", :linear, collect(Float64.(omegas))),
    ]

    observables = [
        # No `oracle` here anymore — predictions live on the Hypothesis,
        # not the observable. `fz_total` is just "z magnetization"; what
        # we expect from it depends on the sweep's regime.
        SweepObservable(; key=:fz_total, label="⟨F_z⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:Lz, label="⟨L_z⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:fx_total, label="⟨F_x⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:fy_total, label="⟨F_y⟩", kind=:signed, center=0.0),
        SweepObservable(; key=:E, label="Energy", kind=:positive, scale=:linear),
        SweepObservable(; key=:grad_norm, label="‖∇E‖", kind=:wide,
            scale=:log, role=:quality),
        SweepObservable(; key=:f_max, label="|F|_max", kind=:positive),
        SweepObservable(; key=:m_dist, label="|c_m|²", kind=:spectrum, index=:m),
    ]

    # Tidy rows
    data = Vector{Dict{Symbol, Any}}()
    for c in partial
        row = Dict{Symbol, Any}()
        row[:B_nT] = Float64(get(c, "B_nT", 0.0))
        row[:omega] = Float64(get(c, "omega", 0.0))
        row[:fz_total] = Float64(get(c, "fz_total", NaN))
        row[:Lz] = Float64(get(c, "Lz", NaN))
        row[:fx_total] = Float64(get(c, "fx_total", NaN))
        row[:fy_total] = Float64(get(c, "fy_total", NaN))
        row[:E] = Float64(get(c, "E", NaN))
        row[:grad_norm] = Float64(get(c, "grad_norm", NaN))
        row[:f_max] = Float64(get(c, "f_max", NaN))
        row[:m_dist] = collect(Float64, get(c, "m_dist", Float64[]))
        row[:conv] = Bool(get(c, "conv_lbfgs",
            get(c, "conv_itp", get(c, "conv", false))))
        row[:seed] = string(get(c, "seed", "default"))
        push!(data, row)
    end

    meta = Dict{Symbol, Any}(
        :conv_column => :conv,
        :run_kind => "rotating_frame_barnett_sweep",
        :exported_at => string(now()),
        # Narrative + Hypothesis: the sweep's question and the
        # theoretical apparatus that tests it. For rotating-frame
        # Barnett, the model is ⟨F_z⟩_pred = F·Ω·ℏω_ref / (g_F μ_B B).
        # Prefactor calibrated so that fn(B=100 nT, Ω=0.6) ≈ 0.24
        # (consistent with the prior oracle).
        #
        # We pick `:collapse` as the inference instrument: plot ⟨F_z⟩
        # vs the dimensionless Barnett/Zeeman ratio. If all 30 cells
        # land on one curve, the ratio is the supporting parameter; if
        # the theory band is wide in collapse coords, the chosen
        # variable doesn't factor the model.
        :narrative => Dict{Symbol, Any}(
            :title => "Rotating-frame Barnett effect · Eu-151 (F=6)",
            :question =>
                "Does ⟨F_z⟩ collapse onto x_BZ ≡ Ω·ℏω_ref / (g_F μ_B B)? " *
                "Theory: ⟨F_z⟩_pred = F·x_BZ (Barnett/Zeeman limit).",
            :hypothesis => Hypothesis(;
                question=
                "⟨F_z⟩ vs x_BZ ≡ Ω·ℏω_ref/(g_F μ_B B) — does data " *
                "collapse onto y = F·x?",
                relation=:collapse,
                primary_obs=:fz_total,
                # NOTE — model is the **small-x linear approximation**.
                # The real Barnett/Zeeman saturates at the spin projection
                # bound |⟨F_z⟩| ≤ F, so `F·x` only matches the rotating-
                # frame result for x ≪ 1. Prior unconverged data showed
                # ⟨F_z⟩ peak ~0.75·F → we sit close to the breakdown.
                #
                # WHEN THE PREFACTOR IS RECALIBRATED to the physical
                # value (`g_F μ_B / ℏω_ref` in our unit system, replacing
                # the placeholder 0.0667):
                #   1. Compute x_max = max(collapse_var_fn) over the
                #      swept (B_nT, Ω) grid.
                #   2. If x_max ≪ 1  → linear F·x is fine, leave as is.
                #   3. If x_max ≳ 1  → REPLACE `fn` with a saturating form
                #      that matches F·x at small x and asymptotes to F at
                #      large x (the exact rotating-frame closed form
                #      respects the |⟨F_z⟩| ≤ F bound). Without this fix
                #      the theory envelope at large-x is wrong by O(F),
                #      and any "data falls below theory" reading will
                #      misdiagnose the expected saturation as missing
                #      physics.
                # IMPORTANT: F·x is the NON-INTERACTING upper bound, not
                # the prediction. Eu is AFM/polar (c_1 > 0); spin–spin
                # interactions suppress ⟨F_z⟩ below this bound. Data
                # falling **below** the theory band in the collapse plot
                # is CORRECT physics (legitimate c_1 suppression), NOT
                # "missing physics". The reading "data > theory band"
                # is the failure mode to flag (the prior ⟨F_z⟩ = 4.5
                # artifact). See oracle gate in
                # sprint5_M1_ITP_omega_sweep_converged.jl (one-sided).
                models=Dict(
                    :fz_total => ModelSpec(;
                        # PLACEHOLDER 0.0667 — calibrated only so that
                        # fn(B=100 nT, Ω=0.6) = 6·0.6·0.0667/1 = 0.24
                        # (matches the prior oracle within the linear
                        # regime). Replace with the real `g_F μ_B/ℏω_ref`.
                        fn=(ax) -> 6.0 * ax.omega * 0.0667 / ax.B_nT,
                        label="F · Ω · ℏω_ref / (g_F μ_B B)  " *
                              "[non-interacting UPPER BOUND; AFM c_1 suppresses below]",
                        collapse_var_fn=
                        (ax) -> ax.omega * 0.0667 / ax.B_nT,
                        collapse_var_label="x_BZ ≡ Ω·ℏω_ref / (g_F μ_B B)",
                    ),
                ),
            ),
        ),
    )
    return SweepResult(axes, observables, data; meta=meta)
end

function main()
    for (run_dir, preferred, fallback) in M1_RUNS
        if !isdir(run_dir)
            println("skip $run_dir — directory missing")
            continue
        end
        partial = load_partial(run_dir, preferred, fallback)
        if partial === nothing
            println("skip $run_dir — no $preferred/$fallback")
            continue
        end
        if isempty(partial)
            println("skip $run_dir — empty partial")
            continue
        end
        result = build_m1_sweep_result(partial)
        golden_out = joinpath(run_dir, "golden", "per_cell_table.json")
        write_golden_per_cell_table(golden_out, result;
            signed_clip=Dict(),         # default ±F (=±6)
            positive_clip=Dict(),       # auto via converged-only p05/p95
            spectrum_margin=0.1,
            F=6)
        # The viewspec is the same dispatcher's output that the React +
        # Makie renderers paint. Emit alongside the golden table; the
        # dashboard `/api/sweep/<run>` route reads viewspec.json directly.
        viewspec_out = joinpath(run_dir, "viewspec.json")
        write_viewspec(viewspec_out, result;
            signed_clip=Dict(),
            positive_clip=Dict(),
            spectrum_margin=0.1,
            F=6,
            quality_threshold=1e-5,
            quality_dynamic_range_decades=4.0)
        n_cells = length(partial)
        n_conv = count(r -> r[:conv], result.data)
        @printf "wrote %s + viewspec.json  (%d cells, %d converged, %d B × %d Ω)\n" golden_out n_cells n_conv (
            length(result.axes[1].values)
        ) length(result.axes[2].values)
    end
    println("\nDone.")
end

main()

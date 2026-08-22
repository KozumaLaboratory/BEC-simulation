# Generate the static-trap ω_eff scan for the EdH quench.
#
# WHY THIS EXISTS
#
# §9.3 of `docs/campaign/edh_quench_polarisation_decision.md` established that the
# "rotation-assisted" enhancement is CENTRIFUGAL: a static radial trap weakened to
# ω_eff = √(ω_⊥² − Ω²) reproduces the whole effect to 0.06 % across the range. So
# the scan variable is ω_⊥,eff and not Ω, and the arms carry no rotation at all —
# `rotating_frame_omega: 0.0` everywhere, with the hold step overriding
# `potential:` instead.
#
# The 34 arms of §10 and the 20 arms of §11 were run this way and **never
# committed**: PR #403 landed two documents and no configs, so the evidence behind
# its headline reads `evidence_status = absent` in `docs/campaign/claims.toml`.
# Re-deriving it was therefore a re-derivation and not a re-run. This generator
# closes that: from here the arms are in the tree, and the ledger row can say
# `in_tree` and mean it.
#
# `potential` is a per-dynamics-step field, so the override is clean — it changes
# the hold and nothing else. The control that this is not silently ignored is
# built in: at ω_eff = 1.0 the arm must return the unweakened baseline, and if the
# override were dropped every arm would return that same value.
#
# USE
#
#   julia --project=. scripts/validation/klaus_weff_scan_gen.jl \
#       --field-nt 10.4 --out runs/klaus_quench_weff
#
# Defaults reproduce the 5.2 nT 20-point grid of §11.

using Printf

const OMEGA_REF = 691.1504      # rad/s, the protocol's ω_⊥
const OMEGA_Z = 1.181818        # ω_z / ω_⊥, unchanged by the scan
const GAUSS_PER_NT = 1e-5       # 1 G = 1e5 nT

"""
    weff_grid(kind) -> Vector{Float64}

`:dense52` — the 20 points of §11 at 5.2 nT, verbatim, so the committed arms
reproduce the published table rather than a nearby grid.

`:probe104` — the 10.4 nT arm of the registered prediction. Wider at the low end
than `:dense52`: if the dip is a resonance between the Zeeman splitting and the
radial mode spacing, doubling the field again moves it, and the direction is not
predicted — only that it moves. A grid that only covered the 5.2 nT dip position
could confirm "no dip here" while the dip sat outside the window, which is the
same shape as the seven-point scan §10.2 could not resolve.
"""
function weff_grid(kind::Symbol)
    kind === :dense52 && return [0.420, 0.450, 0.480, 0.500, 0.520, 0.550, 0.570,
        0.600, 0.620, 0.650, 0.680, 0.714, 0.750, 0.770, 0.800, 0.830, 0.850,
        0.900, 0.950, 1.000]
    kind === :probe104 && return [0.350, 0.380, 0.410, 0.440, 0.470, 0.500, 0.530,
        0.560, 0.590, 0.620, 0.650, 0.680, 0.714, 0.750, 0.790, 0.830, 0.870,
        0.910, 0.955, 1.000]
    throw(ArgumentError("unknown grid $kind"))
end

_tag(w) = replace(@sprintf("%.3f", w), "." => "p")

function config_text(; weff::Float64, field_nt::Float64, n::Int, hold_scale::Float64=1.0)
    bhold = field_nt * GAUSS_PER_NT
    box = 12.0
    hold = 5.5292 * hold_scale
    """
    # Static-trap ω_eff scan @ canonical EdH protocol (hold_only, delay=2 ms,
    # B_hold = $(field_nt) nT, m=+F).  ω_⊥,eff / ω_⊥ = $(@sprintf("%.3f", weff))
    # Source: scripts/validation/klaus_weff_scan_gen.jl
    #
    # anti-aligned-seed: the EdH cascade only runs from the Zeeman-HIGHEST stretched
    #   state. Measured 2026-08-19 (#343): rotation contrast +16.5 % anti-aligned
    #   against -0.45 % aligned. Authority:
    #   docs/campaign/edh_quench_polarisation_decision.md
    #
    # NO ROTATION ANYWHERE. The enhancement is centrifugal, not Coriolis (§9.3): a
    #   static radial trap at ω_eff reproduces the rotating result to 0.06 % across
    #   the range. `rotating_frame_omega` is 0.0 in every step; the hold step
    #   overrides `potential:` instead.
    #
    # Built-in control: at ω_eff = 1.000 this must return the unweakened baseline.
    #   If the per-step `potential:` override were silently ignored, EVERY arm would
    #   return that same value — so a flat scan is a plumbing failure, not a null.
    #
    # hold_scale = $(hold_scale). At 1.0 the peak of peak-P_adj lands on the LAST
    #   streamed frame for much of the scan, which is a truncation and not a peak:
    #   the published 5.2 nT dip compares a resolved maximum (frame 38/42) against
    #   boundary values (42/42). Arms with hold_scale > 1 exist to show whether the
    #   structure survives once both sides peak inside the window.

    defaults:
      kind: spinor
      backend: cpu
      interactions: {N_atoms: 10000, omega_ref: $(OMEGA_REF)}

    pipeline:
      - ground_state:
          atom: Eu151
          grid: {n: [$n, $n, $n], box: [$box, $box, $box]}
          potential: {type: harmonic, omega: [1.0, 1.0, $(OMEGA_Z)]}
          interactions:
            N_atoms: 10000
            omega_ref: $(OMEGA_REF)
            c1_ratio: 0.02778
          ddi: {enabled: true, secular: true}
          lhy: {kind: none}
          B: {Bz: "0.01 Gauss", theta: 0.0, phi: 0.0}
          gauge_fix: false
          initial_state: m_plus_F
          init_sigma: 1.5
          dt: 0.005
          n_steps: 3000
          tol: 1.0e-9

      - dynamics:   # rotation_prep (hold-only: no rotation)
          duration: 6.9115
          dt: 0.005
          rotating_frame_omega: 0.0
          B: {Bz: "0.01 Gauss", theta: 0.0, phi: 0.0}
          ddi: {enabled: true, secular: false}
          lhy: {kind: none}
          seed_amplitude: 1.0e-6
          seed_k_cut: 2.5
          save: {every: 100, psi: true, precision: f64}

      - dynamics:   # B_quench
          duration: 0.69115
          dt: 0.001
          rotating_frame_omega: 0.0
          B: {Bz: {from: 0.01, to: $(bhold), duration: 0.6911504}, theta: 0.0, phi: 0.0}
          ddi: {enabled: true, secular: false}
          lhy: {kind: none}
          save: {every: 50, psi: true, precision: f64}

      - dynamics:   # hold pre-delay (unweakened trap, 2 ms)
          duration: 1.3823
          dt: 0.005
          rotating_frame_omega: 0.0
          B: {Bz: "$(bhold) Gauss", theta: 0.0, phi: 0.0}
          ddi: {enabled: true, secular: false}
          lhy: {kind: none}
          save: {every: 50, psi: true, precision: f64}

      - dynamics:   # hold with the RADIALLY WEAKENED static trap ($(round(8 * hold_scale; digits=1)) ms)
          duration: $(hold)
          dt: 0.005
          rotating_frame_omega: 0.0
          potential: {type: harmonic, omega: [$(@sprintf("%.4f", weff)), $(@sprintf("%.4f", weff)), $(OMEGA_Z)]}
          B: {Bz: "$(bhold) Gauss", theta: 0.0, phi: 0.0}
          ddi: {enabled: true, secular: false}
          lhy: {kind: none}
          save: {every: 100, psi: true, precision: f64}

      - analyze:
          - phase_classify: {}
          - winding_map: {}
          - energy_decomposition: {}
    """
end

function main(args)
    field_nt = 5.2
    grid = :dense52
    n = 32
    out = "runs/klaus_quench_weff"
    hold_scale = 1.0
    weffs = Float64[]
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--field-nt"
            field_nt = parse(Float64, args[i + 1]); i += 2
        elseif a == "--grid"
            grid = Symbol(args[i + 1]); i += 2
        elseif a == "--n"
            n = parse(Int, args[i + 1]); i += 2
        elseif a == "--out"
            out = args[i + 1]; i += 2
        elseif a == "--hold-scale"
            hold_scale = parse(Float64, args[i + 1]); i += 2
        elseif a == "--weff"
            weffs = parse.(Float64, split(args[i + 1], ",")); i += 2
        else
            error("unknown argument $a")
        end
    end
    mkpath(out)
    written = String[]
    for w in (isempty(weffs) ? weff_grid(grid) : weffs)
        name = "klaus_weff$(_tag(w))_B$(replace(string(field_nt), "." => "p"))nT" *
               (n == 32 ? "" : "_n$(n)") *
               (hold_scale == 1.0 ? "" : "_hold$(replace(string(hold_scale), "." => "p"))x") *
               ".yaml"
        path = joinpath(out, name)
        write(path, config_text(; weff=w, field_nt, n, hold_scale))
        push!(written, path)
    end
    println("wrote $(length(written)) configs to $out (B = $field_nt nT, n = $n, hold_scale = $hold_scale)")
    written
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end

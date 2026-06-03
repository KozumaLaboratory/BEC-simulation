#!/usr/bin/env julia
# scripts/m2_barnett_window_analyze.jl
#
# Read `runs/m2_barnett_window_postfix_2026_06_04.jld2` (produced by
# `scripts/m2_barnett_window_scan.jl`) and produce three text heatmaps:
#
#   ⟨F_z⟩(Bz, Ω)       — spin response
#   ⟨L_z⟩(Bz, Ω)       — orbital response
#   ⟨F_z⟩·⟨L_z⟩ sign   — EdH oracle (must be ≥ 0 everywhere with Ω > 0)
#
# Plus per-row diagnostics: ‖P_⊥∇E‖ convergence, fraction-converged.
#
# Run: julia --project=. scripts/m2_barnett_window_analyze.jl

using JLD2
using Printf

const INPUT_JLD2 = "runs/m2_barnett_window_postfix_2026_06_04.jld2"

function heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, col::Int, title::String)
    println("--- $title ---")
    @printf "%6s " "Bz \\ Ω"
    for Ω in OMEGA_GRID
        @printf "%12.2f " Ω
    end
    println()
    for B in BZ_NT_GRID
        @printf "%6.1f " B
        for Ω in OMEGA_GRID
            cell = findfirst(r -> r[1] == B && r[2] == Ω, rows)
            if cell === nothing
                @printf "%12s " "—"
            else
                v = rows[cell][col]
                if v isa Bool
                    @printf "%12s " (v ? "✓" : "✗")
                else
                    @printf "%+12.3e " Float64(v)
                end
            end
        end
        println()
    end
    println()
end

function main()
    isfile(INPUT_JLD2) || error("Missing $INPUT_JLD2 — run scan first.")
    d = JLD2.load(INPUT_JLD2)
    rows = d["rows"]
    BZ_NT_GRID = d["BZ_NT_GRID"]
    OMEGA_GRID = d["OMEGA_GRID"]
    println("=== M2 Barnett window — analysis ===")
    @printf "%d cells from %s\n" length(rows) INPUT_JLD2
    println("Row columns: (Bz_nT, Ω, E_rot, ⟨F_z⟩, ⟨L_z⟩, gain=⟨F_z⟩/Ω, ‖∇‖, conv, last_step)")
    println()

    heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, 4, "⟨F_z⟩(Bz, Ω)")
    heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, 5, "⟨L_z⟩(Bz, Ω)")
    heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, 6, "Barnett gain ⟨F_z⟩/Ω(Bz, Ω)")
    heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, 3, "E_rot(Bz, Ω)")
    heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, 7, "‖P_⊥∇E‖(Bz, Ω) — converged ≲ 1e−3")
    heatmap_table(rows, BZ_NT_GRID, OMEGA_GRID, 8, "LBFGS converged flag")

    println("=== EdH oracle: ⟨F_z⟩ · ⟨L_z⟩ > 0 at every Ω > 0 cell ===")
    fails = filter(r -> r[2] > 0 && r[4] * r[5] <= 0, rows)
    if isempty(fails)
        println("✓ All co-aligned.")
    else
        @printf "✗ %d violations:\n" length(fails)
        for r in fails
            @printf "  Bz=%.1f Ω=%.2f  ⟨F_z⟩=%+.3e  ⟨L_z⟩=%+.3e\n" r[1] r[2] r[4] r[5]
        end
    end

    n_conv = count(r -> r[8] == true, rows)
    @printf "\nConvergence: %d / %d cells reached tol\n" n_conv length(rows)
    @printf "Median ‖P_⊥∇E‖: %.3e\n" sort([Float64(r[7]) for r in rows])[(length(rows)+1) ÷ 2]
end

main()

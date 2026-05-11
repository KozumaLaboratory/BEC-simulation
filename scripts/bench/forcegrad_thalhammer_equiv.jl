using SpinorBEC
using Printf

# Track B Phase -1 Step 1.3 verification: Thalhammer eq 22 = Chin-Krotscheck 2005 4A
# for J=1 scalar GPE.
#
# Both `split_step_forcegrad!` and `split_step_thalhammer!` (alias)
# should produce bit-exact identical ψ when applied to the same state.
#
# Setup: 1D Rb87 (F=1, D=3) harmonic + cubic c0 NLS. Same as forcegrad_smoke.jl.
#
# Run:
#   julia --project=. scripts/bench/forcegrad_thalhammer_equiv.jl

const N1D = 64
const ATOM = Rb87

function _build_ws(dt::Float64, c0::Float64)
    grid = make_grid(GridConfig(N1D, 8.0))
    sp = SimParams(; dt=dt, n_steps=1)
    ws = make_workspace(;
        grid, atom=ATOM,
        interactions=InteractionParams(c0, 0.0),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0),
        sim_params=sp,
        enable_ddi=false,
        backend=CPUBackend(),
    )
    psi = ws.state.psi
    D = size(psi, 2)
    @inbounds for i in 1:N1D
        x = grid.x[1][i]
        g = exp(-x * x / 2)
        for c in 1:D
            psi[i, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(psi, ws.grid, D, 1)
    ws
end

@printf("=== Track B Phase -1 Step 1.3: Thalhammer ≡ Chin-Krotscheck verify ===\n")
@printf("1D Rb87 F=1, c0=50, dt=4e-3, 10 outer steps, n_picard ∈ {1, 2, 4}\n\n")

for n_picard in (1, 2, 4)
    ws_fg = _build_ws(4e-3, 50.0)
    ws_th = _build_ws(4e-3, 50.0)

    psi_fg_initial = copy(ws_fg.state.psi)
    psi_th_initial = copy(ws_th.state.psi)
    initial_diff = sqrt(sum(abs2, psi_fg_initial - psi_th_initial))

    for step in 1:10
        SpinorBEC.split_step_forcegrad!(ws_fg; n_picard=n_picard)
        SpinorBEC.split_step_thalhammer!(ws_th; n_picard=n_picard)
    end

    final_diff = sqrt(sum(abs2, ws_fg.state.psi - ws_th.state.psi))
    @printf("  n_picard = %d: initial ‖Δψ‖ = %.3e  final ‖Δψ‖ = %.3e",
        n_picard, initial_diff, final_diff)
    if final_diff < 1e-14
        @printf("  ✓ BIT-EXACT EQUIVALENT\n")
    else
        @printf("  ✗ DIVERGED (alias broken or implementation drift)\n")
    end
end

@printf("\nPhase -1 self-check (iii.a): scalar reduction ϑ=0\n")
@printf("Thalhammer J=1 G formula (paper eq 20 with ϑ=0):\n")
@printf("  G(Ψ) = 2i·∇_α V·∇V·Ψ\n")
@printf("With α=−1/2 (Schrödinger): ∇_α V·∇V = −½|∇V|² → G = −i|∇V|²·Ψ\n")
@printf("Chin-Krotscheck 4A correction (real time):\n")
@printf("  Ṽ = V − (τ²/48)|∇V|²\n")
@printf("Stage 4 phase: e^{−i(2τ/3)Ṽ} = e^{−i(2τ/3)V}·e^{+i(τ³/72)|∇V|²}\n")
@printf("Thalhammer stage 4 (c₂τ²G at b₂=2/3):\n")
@printf("  e^{−i(2τ/3)V}·e^{+i(τ³/72)|∇V|²}  (after substituting G = −i|∇V|² Ψ)\n")
@printf("→ IDENTICAL phase factor at all orders of τ. QED.\n")

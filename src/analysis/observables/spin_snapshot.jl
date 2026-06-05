# --- Spin snapshot: one-pass observable bundle ---
#
# Roll up the recurring per-cell extraction pattern
#   (fx_total, fy_total, fz_total, f_max, m_dist, Lz)
# into a single call. Promoted from `scripts/lib/polished_sweep.jl`'s
# private `_gather_observables`; replaces the ~40-line copy-paste block
# in every M1/M2/sprint sweep script.

export extract_spin_snapshot

"""
    extract_spin_snapshot(ws::Workspace) → NamedTuple

Bundle of integrated spinor observables read off the current
`ws.state.psi`. Field shape:

  * `fx_total`, `fy_total`, `fz_total` — ∫ F_α(r) dV
  * `f_max`                            — max_r |F(r)| (point spin maximum)
  * `m_dist`                           — `Vector{Float64}` of length D,
                                          per-component population
                                          `∫ |ψ_c|² dV`
  * `Lz`                               — orbital ⟨L_z⟩ (0.0 in 1D)

GPU-safe: pulls ψ to host once, then uses the existing CPU observable
kernels (`spin_density_vector`, `orbital_angular_momentum` — the
latter builds its own CPU FFT plans, so a GPU `Workspace` does not
trigger implicit device transfers).
"""
function extract_spin_snapshot(ws::Workspace{N}) where {N}
    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    dV = cell_volume(ws.grid)

    fx, fy, fz = spin_density_vector(psi, sm, N)
    fx_total = sum(fx) * dV
    fy_total = sum(fy) * dV
    fz_total = sum(fz) * dV
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))

    D = size(psi, N + 1)
    m_dist = zeros(Float64, D)
    for c in 1:D
        slice = ntuple(d -> d == N + 1 ? c : Colon(), N + 1)
        m_dist[c] = sum(abs2, view(psi, slice...)) * dV
    end

    Lz = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)

    return (
        fx_total=fx_total, fy_total=fy_total, fz_total=fz_total,
        f_max=f_max, m_dist=m_dist, Lz=Lz,
    )
end

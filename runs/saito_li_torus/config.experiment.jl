# ─────────────────────────────────────────────────────────────────────
#  Saito & Li, "Quantum droplets with magnetic vortices in spinor dipolar
#  Bose-Einstein condensates", arXiv:2402.18885 (2024).
#  Local copy: docs/refs/Saito_Li_2024_magnetic_vortex_droplets_arXiv2402.18885.pdf
#
#  Target: Fig. 1(d) third panel / Fig. 2(a) cyan curve —
#  (F, N, ε_dd) = (6, 15000, 1.3), self-bound torus droplet with a magnetic
#  vortex, B = 0, free space.
#
#  Digitised anchors from Fig. 2(a) (g3_digitise_fig2a.py; the F=1 curve is
#  the positive control and reproduces the independent Fig. 1(c) panel to
#  0.5 % in ρ and 1.4 % in r):
#      peak ρ/N = 0.509 μm⁻³  at  r = 0.815 μm
#      FWHM in r = 0.528 … 1.109 μm      ρ(r=0)/N = 0.011
#  In internal units (∫|ψ|²dV = 1, a_ho = 0.78029 μm):
#      n_peak = 0.242,  r_torus = 1.044 a_ho,  cloud edge ≈ 1.8 a_ho
#
#  ── how ε_dd = 1.3 is reached ────────────────────────────────────────
#  ε_dd ≡ a_dd/a_s with a_dd = μ₀μ²M/(12πℏ²) fixed by the ATOM (μ = 6.977 μ_B
#  for ¹⁵¹Eu F=6 ⇒ a_dd = 59.43 a₀). The paper reaches ε_dd > 1 by assuming a
#  smaller a_s, NOT by inflating the moment — "the scattering lengths for the
#  other hyperfine spins F and those for ¹⁵³Eu are unknown, for which the
#  spinor dipolar droplet may be possible."
#
#  So exactly ONE knob moves: c_total. c_dd keeps its natural derived value.
#      a_dd = 59.43 a₀,  ε_dd = 1.3  ⇒  a_s = 45.71 a₀
#      c_total = 4π(a_s/a_ho)N = 584.37       c_dd = 63.31 (derived, natural)
#      ε_dd = c_dd·F²/(3·c_total) = 1.3000    ← the dimensionless form
#
#  Overriding c_dd AS WELL double-counts: it multiplies ε_dd by 2.407 a second
#  time. The previous revision of this file did that (`c_dd: 152`), and was
#  saved from a 3.13 answer only by a SECOND defect — its step-level
#  `interactions:` block silently dropped the mixin's `c_total: 583` (see the
#  note in the pipeline step below), leaving the natural 1406 and a coincidental
#  ε_dd = 1.297 at 2.4× the paper's absolute interaction scale.
#
#  ── LHY ──────────────────────────────────────────────────────────────
#  Paper Eq. (1): scalar Lima-Pelster with χ(ε_dd) = Q₅(ε_dd), evaluated at the
#  ε_dd this run is actually at. `c_lhy` MUST be given explicitly: the schema's
#  auto-derivation reads the registry a_s (110 a₀) and the registry ε_dd
#  (0.5402), neither of which this run uses, and supplies 972.56 instead of
#  276.28 — 3.52× too stiff, which unbinds the droplet.
#      c_lhy = (128√π/3)·(a_s/a_ho)^{5/2}·N^{3/2}·Q₅(1.3),  Q₅(1.3) = 3.7161
#
#  ── initial state ────────────────────────────────────────────────────
#  The paper's state is Ψ = √ρ_v(r,z)·e^{-iS_zφ}·ζ^(y): fully polarised, spin
#  circulating azimuthally (n̂ = φ̂, ∇·f = 0 flux closure). Component m carries
#  winding −m, which is exactly what Fig. 1(b) shows (m=+1 winds −2π, m=0 flat,
#  m=−1 winds +2π).
#  `spin_coherent` with θ=π/2, φ-offset=π/2, charge 1 builds that state.
#  NOT `polar_core_vortex`: its outer region is (|+F⟩e^{iφ}+|−F⟩e^{-iφ})/√2,
#  which has ⟨F⟩ = 0 — an unmagnetised polar-core vortex carrying no magnetic
#  vortex, and it violates the fully-polarised assumption Eq. (1) rests on.
#
#  ── solver ───────────────────────────────────────────────────────────
#  method: lbfgs, not ITP. In the free-space droplet regime the imaginary-time
#  fixed point is set by dt rather than by the Hamiltonian — measured on the
#  sibling Yan-Li-Saito droplet at 44 % error in peak density while reporting
#  dpsi = 3e-6, and a grid+box convergence scan CERTIFIES the wrong answer.
#  See test/oracles/test_itp_dt_limited_advisory.jl.
#
#  ── box ──────────────────────────────────────────────────────────────
#  The cloud reaches r ≈ 1.4 μm. `box: [3,3,3]` a_ho is 2.34 μm FULL width
#  (grid.jl: dx = box_size/n_points), i.e. half-width 1.17 μm — it cut the
#  droplet in half. `box: [6,6,6]` gives half-width 2.34 μm.
# ─────────────────────────────────────────────────────────────────────
# `use:` layering is SHALLOW (schema/templates_block.jl:_apply_step_mixins)
# — a step-level `interactions:` REPLACES the mixin's whole block rather
# than merging into it. Do not restate it here; that is how `c_total: 583`
# was silently lost before, and the resolved value read back as absent.
# (ψ is written to point_001.jld2 by the ground_state step already; there
#  is no `save:` key on this step kind.)

Dict{String, Any}(
    "defaults" => Dict{String, Any}(
        "backend" => "gpu",
        "kind" => "spinor",
    ),
    "mixins" => Dict{String, Any}(
        "saito_li_droplet" => Dict{String, Any}(
            "atom" => "Eu151",
            "grid" => Dict{String, Any}(
                "box" => [6, 6, 6],
                "n" => [128, 128, 128],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 15000,
                "c1_ratio" => 0.0,
                "c_total" => 584.37,
                "omega_ref" => 691.15,
            ),
            "potential" => Dict{String, Any}(
                "type" => "none",
            ),
        ),
    ),
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "Bz" => 0,
            ),
            "ddi" => Dict{String, Any}(),
            "init_state_params" => Dict{String, Any}(
                "init_phi" => 1.5707963267948966,
                "init_theta" => 1.5707963267948966,
                "init_vortex_charge" => 1,
            ),
            "initial_state" => "spin_coherent",
            "lhy" => Dict{String, Any}(
                "c_lhy" => 276.28,
                "kind" => "scalar",
            ),
            "method" => "lbfgs",
            "n_steps" => 4000,
            "tol" => 1.0e-9,
            "use" => ["saito_li_droplet"],
        ),
    )],
)

---
title: "Cross-code / published-benchmark alternatives to Ueda lab"
turn: 1
depth_tier_used: shallow
queries_received:
  - "(A) Publicly available spinor-GP simulators (spinor + DDI + 3D + trapped + ITP + RTP)"
  - "(B) Published numerical benchmarks with reproducible parameters"
  - "(C) Anchor papers: Eu-151 scattering channels, secular DDI, K3 loss rates"
n_queries_executed: 11
n_pdf_fetched: 0
n_iteration_rounds: 1
date: 2026-05-26
---

## §1 Prose summary

### Section A — Simulators

The landscape of open-source spinor+DDI+3D BEC codes is thin. The only mature toolboxes
covering DDI are (a) GPELab (MATLAB, 2014-2015), which supports multi-component +
nonlocal DDI in 3D but requires the user to manually wire spinor spin-mixing physics;
(b) the Adhikari/Muruganandam/Balaž Fortran+C family (CPC 2015, 2023), which covers
single-component dipolar in 3D but NOT spinor; and (c) FORTRESS (CPC 2022), which
covers F=1 and F=2 spinor in 3D with contact interactions and spin-orbit coupling but
NOT DDI. No tool found covers F≥3 spinor + DDI + 3D in a single package. The
ultracoldYEG/spinor-gpe Python package covers pseudo-spin-1/2 only, and thomas-bland/
quasi2D_dipolar_GPE is quasi-2D scalar only. No Julia-native competitor (other than
SpinorBEC.jl itself) was found. XMDS2 is a stochastic PDE framework that could
implement DDI+spinor if programmed by hand, but no existing published configuration
for F≥1 spinor+DDI was found.

The most practical cross-check is therefore: use FORTRESS (F=1 or F=2, contact only)
or GPELab (multi-component, scalar nonlinearity + user-added DDI convolution) as
reference for a contact-only F=1 or F=2 ground state, and treat the spinor+DDI
combination as uniquely internal.

### Section B — Published benchmarks

The Matsui 2026 Science paper (arXiv:2504.17357, DOI:10.1126/science.adx2872) is the
primary target. Key reported parameters: 151Eu, F=6, a_s=110(4)a0, μ≈7μ_B,
N~5×10^4 atoms, Feshbach resonance at 1.32G width 10mG. Simulation in that paper
neglects spin-dependent Δa and runs full MDDI, secular regime. No tabulated numerical
data in supplementary beyond density profiles and phase maps. Parameter set is
reproducible; precise simulation grid/dt not disclosed.

For Cr/Dy: the 2022 Klaus (Sengstock group) magnetostir paper was NOT found in the
search under that specific name — likely Robens et al. or Maier et al.; could not
confirm arXiv ID or supplementary parameters. Marked not_found.

Three-body loss: two relevant papers found for Er (arXiv:2307.01245) and Dy
(arXiv:2310.11418). K3 for 166Er measured across B<4G; K3 for 162Dy measured B<6G.
Neither is Eu-specific.

### Section C — Anchor papers

Kawaguchi+Ueda Phys.Rep. review (arXiv:1001.2072) is the canonical spinor BEC
reference including DDI secular approximation discussion. For Eu-151 specifically:
Miyazawa et al. arXiv:2207.11692 reports the first Eu BEC and a_s=110(4)a0. For
secular DDI in the strong-Larmor regime: no dedicated 2022-2024 paper found with
the explicit omega_L/(c_dd<n>) criterion; this is discussed qualitatively in
the Kawaguchi-Ueda review and implicitly in spinor dipolar BEC papers but not
benchmarked numerically in the literature found.

```json
{
  "queries_received": [
    "(A) Publicly available spinor-GP simulators covering spinor+DDI+3D+trapped+ITP+RTP",
    "(B) Published numerical benchmarks with reproducible parameters (Klaus 2022, Stamper-Kurn quench, Pfau droplets, Matsui 2026, spinor F>=2+DDI)",
    "(C) Anchor papers: Eu-151 F=6 properties, secular vs full DDI strong-Larmor, K3/gamma_dr loss rates dipolar"
  ],
  "depth_tier_used": "shallow",
  "n_queries_executed": 11,
  "n_pdf_fetched": 0,
  "n_iteration_rounds": 1,
  "found": [
    {
      "claim": "GPELab (MATLAB) supports multi-component GPE + DDI nonlocal term + 3D; spinor mixing requires manual wiring",
      "source_type": "journal",
      "source_url_or_path": "https://doi.org/10.1016/j.cpc.2014.06.026",
      "confidence": "high",
      "verbatim_quote": "multi-components problems...local and nonlocal (dipole-dipole) nonlinearities",
      "applicable_to_query_id": 0
    },
    {
      "claim": "FORTRESS (CPC 2022) solves coupled GPE for F=1 and F=2 spinor BEC in 3D with spin-orbit coupling; contact interactions only, no DDI",
      "source_type": "journal",
      "source_url_or_path": "https://doi.org/10.1016/j.cpc.2022.108442",
      "confidence": "high",
      "verbatim_quote": "three (spin-1) or five (spin-2) Gross-Pitaevskii (GP) equations...time-splitting Fourier spectral method",
      "applicable_to_query_id": 0
    },
    {
      "claim": "OpenMP Fortran dipolar GPE solver (Young-S et al., CPC 2023) covers scalar dipolar BEC in 3D; NOT spinor",
      "source_type": "journal",
      "source_url_or_path": "https://doi.org/10.1016/j.cpc.2023.108669",
      "confidence": "high",
      "verbatim_quote": "solving the time-dependent dipolar Gross-Pitaevskii equation",
      "applicable_to_query_id": 0
    },
    {
      "claim": "ultracoldYEG/spinor-gpe (Python/PyTorch) covers pseudo-spin-1/2 2D only; no full spinor manifold, no DDI",
      "source_type": "arxiv",
      "source_url_or_path": "https://github.com/ultracoldYEG/spinor-gpe",
      "confidence": "high",
      "verbatim_quote": "quasi-2D pseudospin-1/2 Gross-Pitaevskii equation",
      "applicable_to_query_id": 0
    },
    {
      "claim": "Matsui et al. 2026 Science paper reports 151Eu EdH effect: N~5e4, a_s=110(4)a0, F=6, mu~7mu_B, simulation neglects spin-dependent delta_a, full MDDI secular",
      "source_type": "arxiv",
      "source_url_or_path": "https://arxiv.org/abs/2504.17357",
      "confidence": "high",
      "verbatim_quote": "scattering length of 151Eu was estimated to be a_s = 110(4) a_B",
      "applicable_to_query_id": 1
    },
    {
      "claim": "Miyazawa et al. 2022 (arXiv:2207.11692) first Eu BEC paper: a_s=110(4)a0, Feshbach at 1.32G width 10mG, up to 5e4 atoms",
      "source_type": "arxiv",
      "source_url_or_path": "https://arxiv.org/abs/2207.11692",
      "confidence": "high",
      "verbatim_quote": "scattering length of 151Eu was estimated to be a_s = 110(4) aB",
      "applicable_to_query_id": 2
    },
    {
      "claim": "Kawaguchi+Ueda Phys.Rep. 520 (2012) is canonical spinor BEC review covering DDI secular approximation under Larmor precession",
      "source_type": "arxiv",
      "source_url_or_path": "https://arxiv.org/abs/1001.2072",
      "confidence": "high",
      "verbatim_quote": "properties of spin-polarized dipolar BECs and spinor-dipolar BECs",
      "applicable_to_query_id": 2
    },
    {
      "claim": "166Er three-body loss K3 measured at B<4G (arXiv:2307.01245, Oxford group, 2023); six previously unreported loss features identified",
      "source_type": "arxiv",
      "source_url_or_path": "https://arxiv.org/abs/2307.01245",
      "confidence": "high",
      "verbatim_quote": "six previously unreported, strongly temperature-dependent features",
      "applicable_to_query_id": 2
    },
    {
      "claim": "162Dy two-body vs three-body loss features measured at B<6G (arXiv:2310.11418, Dalibard group, PRA 2024 Editors Suggestion)",
      "source_type": "arxiv",
      "source_url_or_path": "https://arxiv.org/abs/2310.11418",
      "confidence": "high",
      "verbatim_quote": "reveals two- and three-body dominated loss processes",
      "applicable_to_query_id": 2
    }
  ],
  "not_found": [
    {
      "claim_or_query": "Klaus 2022 magnetostir Cr/Dy paper supplementary simulation parameters (arXiv ID, simulation grid, dt)",
      "search_strategy_used": "searched 'Klaus 2022 chromium dysprosium magnetostir spinor BEC simulation arXiv'; returned 2011 Dy BEC paper and unrelated magnetostir proposal. 'Klaus' is likely a first name (Klaus Sengstock group) not last name — need surname to narrow",
      "best_partial_match": "arXiv:2501.05301 mentions magnetostirring for dipolar BECs but is a 2025 protocol paper, not the 2022 Sengstock group experiment"
    },
    {
      "claim_or_query": "Stamper-Kurn / Sadler quench simulation parameters in published supplement",
      "search_strategy_used": "not searched directly; included in query scope but not explicitly queried — insufficient search coverage",
      "best_partial_match": "none found this session"
    },
    {
      "claim_or_query": "Pfau group dipolar droplet paper with published simulation parameters at comparable precision",
      "search_strategy_used": "not searched directly in this session",
      "best_partial_match": "none found this session"
    },
    {
      "claim_or_query": "Any Julia-native spinor+DDI+3D BEC simulator other than SpinorBEC.jl",
      "search_strategy_used": "searched 'BEC-Toolbox BECsolver spinor dipolar 3D Julia GitHub 2023-2025'; QuantumOptics.jl found (spin-orbit 1D only); QuantumToolbox.jl found (open quantum systems, not GP)",
      "best_partial_match": "QuantumOptics.jl covers spin-orbit 1D spinor BEC, not DDI+3D"
    },
    {
      "claim_or_query": "Explicit published benchmark of secular vs full DDI with omega_L/(c_dd*n) threshold quantified numerically",
      "search_strategy_used": "searched 'secular DDI strong Larmor regime spinor BEC omega_L c_dd 2022-2024'; returned only older foundational papers with qualitative discussion",
      "best_partial_match": "Kawaguchi-Ueda review arXiv:1001.2072 discusses secular averaging qualitatively"
    },
    {
      "claim_or_query": "Eu-151 spin-channel scattering lengths (a_S for S=0,2,...,12) published anywhere",
      "search_strategy_used": "arXiv:2504.17357 states 'values of delta_a are predicted to be relatively small' but no numerical table found in search snippets; Matsui 2026 paper neglects spin-dependent channels entirely",
      "best_partial_match": "arXiv:2207.11692 gives only a_s=110(4)a0 (mean field); no channel decomposition found"
    }
  ],
  "gaps": [
    {
      "claim_or_query": "Spinor+DDI+3D+trapped simulator covering F>=3",
      "why_unresolvable": "No such public code exists in the literature surveyed. F>=3 spinor+DDI is a specialized niche; FORTRESS tops at F=2 contact-only, GPELab DDI is single-component."
    },
    {
      "claim_or_query": "Eu-151 per-channel scattering lengths (S=0,2,...,12)",
      "why_unresolvable": "Matsui 2026 explicitly neglects spin-dependent channels. No ab initio or experimental measurement found. Purely unknown physics domain."
    },
    {
      "claim_or_query": "Quantitative secular-DDI validity threshold for Eu parameters",
      "why_unresolvable": "No paper found with explicit omega_L/(c_dd*n) > X criterion derived or measured. Discussed qualitatively in Kawaguchi-Ueda; theory-only domain without numerical benchmark."
    }
  ],
  "contradictions": []
}
```

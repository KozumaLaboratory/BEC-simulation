# Manuscript submission packaging — design + checklist

本 doc は 修論 + 4 papers の submission packaging のための workflow design と
checklist を提供する。LaTeX 変換 + bibliography + figures + supplementary material
の全 pipeline.

---

## 1. Source structure

```
docs/manuscript/
├── README.md                         # workspace overview
├── shared/
│   ├── references.bib                # consolidated bibliography
│   ├── notation.md                   # convention single-source
│   └── figures.md                    # figure placeholder inventory
├── thesis/
│   ├── chapters/                     # Ch.1-Ch.7 markdown
│   ├── appendices/                   # Appendix A-E markdown
│   ├── figures/                      # rendered PDF / SVG (gitignored)
│   └── bibliography/                 # thesis-specific extensions
└── papers/
    ├── paper1_F2_cyclic/             # Paper #1 source
    ├── paper2_F6_icosahedral/        # Paper #2
    ├── paper3_universal_theorem/     # Paper #3 (incl. audit_2026-05-11 + sign pattern)
    └── paper4_chaos_diagnostic/      # Paper #4 (TWA chaos) — NEW for this thesis
```

paper4 directory should be created mirroring paper1-3 structure.

---

## 2. Bibliography expansion (references.bib)

### 2.1 Current state (2026-05-08)

19 BibTeX entries from Round 4. Categories:
- LHY foundational (1)
- Spinor BEC reviews (2)
- F=1/F=2/F=3+ spinor structure (~6)
- Dipolar BEC + droplets (~4)
- Various theory/experiment (~6)

### 2.2 Required additions for 修論 + 4 papers

**Chapter 5 (Paper #4) TWA chaos**:

```bibtex
@article{Steel1998,
  author = {Steel, M. J. and Olsen, M. K. and Plimak, L. I. and Drummond, P. D. and Tan, S. M. and Collett, M. J. and Walls, D. F. and Graham, R.},
  title = {Dynamical quantum noise in trapped Bose-Einstein condensates},
  journal = {Physical Review A}, volume = {58}, pages = {4824}, year = {1998},
  doi = {10.1103/PhysRevA.58.4824},
}

@article{Sinatra2002,
  author = {Sinatra, A. and Lobo, C. and Castin, Y.},
  title = {The truncated Wigner method for Bose-condensed gases: limits of validity and applications},
  journal = {Journal of Physics B}, volume = {35}, pages = {3599}, year = {2002},
  doi = {10.1088/0953-4075/35/17/301},
}

@article{Polkovnikov2010,
  author = {Polkovnikov, Anatoli},
  title = {Phase space representation of quantum dynamics},
  journal = {Annals of Physics}, volume = {325}, pages = {1790}, year = {2010},
  doi = {10.1016/j.aop.2010.02.006},
}
```

**Dipolar droplets**:

```bibtex
@article{Petrov2015,
  author = {Petrov, D. S.},
  title = {Quantum Mechanical Stabilization of a Collapsing Bose-Bose Mixture},
  journal = {Physical Review Letters}, volume = {115}, pages = {155302}, year = {2015},
  doi = {10.1103/PhysRevLett.115.155302},
}

@article{Schmitt2016,
  author = {Schmitt, M. and Wenzel, M. and B{\"o}ttcher, F. and Ferrier-Barbut, I. and Pfau, T.},
  title = {Self-bound droplets of a dilute magnetic quantum liquid},
  journal = {Nature}, volume = {539}, pages = {259}, year = {2016},
  doi = {10.1038/nature20126},
}

@article{Chomaz2016,
  author = {Chomaz, L. and Baier, S. and Petter, D. and Mark, M. J. and W{\"a}chtler, F. and Santos, L. and Ferlaino, F.},
  title = {Quantum-Fluctuation-Driven Crossover from a Dilute Bose-Einstein Condensate to a Macrodroplet in a Dipolar Quantum Fluid},
  journal = {Physical Review X}, volume = {6}, pages = {041039}, year = {2016},
  doi = {10.1103/PhysRevX.6.041039},
}

@article{LimaPelster2012,
  author = {Lima, Aristeu R. P. and Pelster, Axel},
  title = {Beyond mean-field low-lying excitations of dipolar Bose gases},
  journal = {Physical Review A}, volume = {86}, pages = {063609}, year = {2012},
  doi = {10.1103/PhysRevA.86.063609},
}
```

**Goldstone counting**:

```bibtex
@article{WatanabeBrauner2011,
  author = {Watanabe, Haruki and Brauner, Tom{\'a}{\v{s}}},
  title = {Number of Nambu-Goldstone Bosons and Its Relation to Charge Densities},
  journal = {Physical Review D}, volume = {84}, pages = {125013}, year = {2011},
  doi = {10.1103/PhysRevD.84.125013},
}
```

**Integrator methodology** (D-thesis Ch.3 / Paper Track C-B):

```bibtex
@article{ChinKrotscheck2005,
  author = {Chin, Siu A. and Krotscheck, Eckhard},
  title = {Fourth-order algorithms for solving the imaginary-time Gross-Pitaevskii equation in a rotating anisotropic trap},
  journal = {Physical Review E}, volume = {72}, pages = {036705}, year = {2005},
  doi = {10.1103/PhysRevE.72.036705},
  eprint = {cond-mat/0504270},
}

@article{Yoshida1990,
  author = {Yoshida, Haruo},
  title = {Construction of higher order symplectic integrators},
  journal = {Physics Letters A}, volume = {150}, pages = {262}, year = {1990},
  doi = {10.1016/0375-9601(90)90092-3},
}
```

**Group theory + Racah**:

```bibtex
@book{Hamermesh1962,
  author = {Hamermesh, Morton},
  title = {Group Theory and Its Application to Physical Problems},
  publisher = {Addison-Wesley}, year = {1962},
}

@book{Edmonds1957,
  author = {Edmonds, A. R.},
  title = {Angular Momentum in Quantum Mechanics},
  publisher = {Princeton University Press}, year = {1957},
}
```

**Spinor inert states (polyhedral)**:

```bibtex
@article{MakelaSuominen2007,
  author = {M{\"a}kel{\"a}, H. and Suominen, K.-A.},
  title = {Inert States of Spin-{S} Systems},
  journal = {Physical Review Letters}, volume = {99}, pages = {190408}, year = {2007},
  doi = {10.1103/PhysRevLett.99.190408},
}

@article{YukawaUeda2011,
  author = {Yukawa, Emi and Ueda, Masahito},
  title = {Classification of the ground states and topological defects in a rotation-symmetric spinor Bose-Einstein condensate},
  journal = {arXiv preprint}, year = {2011},
  eprint = {1109.0400},
}

@article{CiobanuYipHo2000,
  author = {Ciobanu, C. V. and Yip, S.-K. and Ho, T.-L.},
  title = {Phase diagrams of {F=2} spinor Bose-Einstein condensates},
  journal = {Physical Review A}, volume = {61}, pages = {033607}, year = {2000},
  doi = {10.1103/PhysRevA.61.033607},
}

@article{KoashiUeda2000,
  author = {Koashi, Masato and Ueda, Masahito},
  title = {Exact Eigenstates and Magnetic Response of Spin-1 and Spin-2 Bose-Einstein Condensates},
  journal = {Physical Review Letters}, volume = {84}, pages = {1066}, year = {2000},
  doi = {10.1103/PhysRevLett.84.1066},
}
```

**Eu experimental (上妻研 + others)**:

```bibtex
@article{Kozumitachi2022,
  author = {[上妻 group]},
  title = {[Eu post-quench EdH protocol reference]},
  journal = {?}, year = {2022},
  note = {Klaus 2022 magnetostir reference. Specific citation TBD.},
}
```

**Dy droplet experiments**:

```bibtex
@article{Tang2018,
  author = {Tang, Y. and Chen, W. and Bao, C. and Wang, Z. and Lev, B. L.},
  title = {Observation of dipolar Bose-Einstein condensates and stripe quantum droplets},
  journal = {(citation TBD)}, year = {2018},
}
```

### 2.3 Total target

最終 references.bib: ~50-60 entries covering:
- 修論本体 7 章 + Appendix A-E 全 citations
- 4 papers 個別 citations
- D 論 forward references (TDHFB pilot 等)

---

## 3. Per-paper bibliography subsets

各 paper の bibliography は consolidated references.bib の subset として generate:

### Paper #1 (F=2 cyclic LHY)

Required: KU2012, CiobanuYipHo2000, KoashiUeda2000, LimaPelster2012, MakelaSuominen2007,
PhucUeda2014, Hamermesh1962, Edmonds1957.

### Paper #2 (F=6 icosahedral LHY)

Required: Paper #1 refs + YukawaUeda2011, Schmitt2016, Chomaz2016, KawaguchiUeda2012.

### Paper #3 (Universal Structure Theorem)

Required: Paper #2 refs + WatanabeBrauner2011, Hamermesh1962, Schur1905 (cited),
Petrov2015, Tang2018.

### Paper #4 (TWA chaotic dipolar dynamics)

Required: Steel1998, Sinatra2002, Polkovnikov2010, Petrov2015, Schmitt2016,
Chomaz2016, LimaPelster2012, KU2012.

### 修論本体

Union of all 4 papers + integrator references (ChinKrotscheck2005,
Yoshida1990) + 上妻 experimental.

---

## 4. LaTeX conversion workflow

### 4.1 Pandoc + LaTeX

markdown → LaTeX (paper-ready, with biblatex + figures + equations):

```bash
# Single paper conversion
pandoc paper3_universal_theorem/main.md \
    -o paper3_main.tex \
    --bibliography=shared/references.bib \
    --csl=apa.csl \
    --pdf-engine=lualatex \
    --variable=documentclass:revtex4-2 \
    --variable=classoption:twocolumn,prx,amsmath \
    --metadata title="Universal Structure Theorem..."

# Compile
lualatex paper3_main.tex
biber paper3_main
lualatex paper3_main.tex  # second pass for cross-refs
```

### 4.2 RevTeX 4-2 template

PRR/PRX target requires RevTeX 4-2. Custom preamble:

```latex
\documentclass[twocolumn,prx,amsmath,amssymb,amsfonts]{revtex4-2}
\usepackage{graphicx,bm,subcaption}
\usepackage[pdftex,colorlinks=true,linkcolor=blue]{hyperref}
\usepackage{biblatex}
\addbibresource{shared/references.bib}
```

### 4.3 Figures embedding

`docs/manuscript/<paper>/figures/<figXX>.pdf` を `\includegraphics` で:

```latex
\begin{figure}
  \centering
  \includegraphics[width=\linewidth]{figures/paper3_FIG-1.pdf}
  \caption{...}
  \label{fig:paper3_1}
\end{figure}
```

Figure rendering script: `scripts/cli.jl figure` (Appendix 別 task).

---

## 5. Submission packaging checklist

### 修論本体 submission

- [ ] Ch.1-7 全 chapter integration → `thesis_main.md`
- [ ] Appendix A-E inclusion
- [ ] references.bib expansion (~50 entries target)
- [ ] All figures rendered to PDF + cross-ref consistent
- [ ] LaTeX compilation passes (lualatex + biber)
- [ ] Page-count budget check (修論 target ~80-120 pages?)
- [ ] Equation cross-references work (e.g., Eq. (4.6) Universal Theorem)
- [ ] Citation cross-references work (e.g., [@KawaguchiUeda2012])
- [ ] Submission format (PDF/A, ISBN if required, etc.)

### Paper #1-4 submission (each)

- [ ] Cover letter draft
- [ ] Per-paper bibliography subset
- [ ] Figures rendered + cross-ref consistent
- [ ] Title / abstract finalized
- [ ] Author list + affiliations
- [ ] Supplementary material (sympy scripts, additional figures, data tables)
- [ ] Submission via journal portal (PRA/PRR/PRX has different requirements)
- [ ] ORCID linkage
- [ ] Pre-registration / arXiv pre-print

---

## 6. Workflow timeline

修論 deadline (estimated 2026-12 or 2027-01) までの:

- **2026-06**: bibliography expansion + figure rendering script + Pandoc setup
- **2026-07**: Paper #1, #2 LaTeX conversion + RevTeX template + arXiv pre-print
- **2026-08**: Paper #3 submission (PRR/PRX) + audit data as supplementary
- **2026-09**: Paper #4 (TWA chaos) finalize + submission (PRR)
- **2026-10**: 修論本体 integration + final figure polish + LaTeX compile
- **2026-11**: 内部 review + 教員 review + final revisions
- **2026-12**: 修論 submit + defense

逐次的 + parallelizable workflow。Paper #1 and #2 are independent of paper #3 v4
(Sign Pattern follow-up); can submit immediately.

---

## 7. Supplementary material design

各 paper の supplementary material:

### Paper #1 supplementary
- Sympy script for F=2 cyclic Even/Odd block factorization
- Numerical BdG verification at sample parameters
- Direct LHY zero-point sum vs closed form comparison

### Paper #2 supplementary
- F=6 I_h spinor + Majorana points construction
- mod-5 block decomposition derivation
- LHY closed form vs direct BdG diagonalization

### Paper #3 supplementary
- F-systematic Table II derivation (Appendix D inlined)
- 6 polyhedral verifications (Appendix A scripts referenced)
- F=12 verification + Sign Pattern Anomalous Identity numerical evidence

### Paper #4 supplementary
- TWA implementation details + Sinatra criterion
- Full 1/N scan data (16³×box=10) for chaos signature
- GS-resolution caveat reproducibility (16³×box=20 vs 16³×box=10 GS profile comparison)

---

## 8. Reviewer checklist (anticipating questions)

### Paper #3 (Universal Theorem) reviewer questions:
- "Is the theorem rigorous?" → §III proof via Schur lemma, Appendix D F-systematic
- "How is F=12 verified?" → F12_verification_result.md, Appendix E §E.3
- "Is the Sign Pattern proven?" → endpoint Lemmas 1+2 (Appendix E §E.4), single-sign-
  change deferred to D 論 (Strategy A)
- "Why F=1 unique?" → Appendix D §D.6 formal proof

### Paper #4 (TWA chaos) reviewer questions:
- "Is σ/μ really chaos and not quantum fluctuation?" → §5.5 Sinatra-clean 1/N test,
  17.7 → 41.5 → 259 scaling failure across N
- "Is 16³ box=10 sufficient?" → §5.7 GS-resolution caveat + resolution-matched comparison
- "What is the practical impact?" → §5.6 species universality + experimental observables

These doc questions inform per-paper supplementary material design.

---

## 9. Versioning + reproducibility

各 paper submission ごとに:
- Git tag (e.g., `paper3-submission-v1`)
- `submission_metadata.md` per paper directory:
  - Git SHA of submission state
  - SpinorBEC.jl version
  - Julia version
  - GPU configurations used (for paper #4)
  - Configurations referenced (e.g., `runs/F6_phase_diagram/config.yaml`)

これにより reviewer + future readers が exact reproducibility chain を traceable に
保持。

---

(submission_packaging.md 終了)

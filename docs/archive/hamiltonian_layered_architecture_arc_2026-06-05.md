<!-- promoted from agent memory `project_hamiltonian_layered_architecture_2026_06_05.md` on 2026-07-31; historical record, not an SSoT -->
<!-- hamiltonian/ redesign arc adopted 2026-06-05 — L0-L3 layered architecture + Stage 0-3 plan; doc at docs/design/hamiltonian_layered_architecture.md; 9 verified live defects pending Stage 0 -->

# Hamiltonian layered architecture arc (adopted 2026-06-05)

Design doc (authoritative): `docs/design/hamiltonian_layered_architecture.md`.
Decisions D1-D7 + Stage 0-3 live there — this entry is the pointer plus
what is NOT in the doc.

**Verdict that started the arc**: trinity real on energy/gradient faces,
fictional on the propagator face (12/14 terms legacy V chain); the entire
trinity oracle suite was unregistered in runtests.jl (dormant gates); GPU
energy still the hand-enumerated ext fork that caused the 2026-06-04 freeze.

**Scope ruling (anko, 2026-06-05)**: main Workspace path only.
rotating_basis / combined_spin_step / force_gradient / scalar-binary GP /
TDHFB = oracle-obligated design boundaries, not registry-driven.

**Flat reoptimization (2026-06-06, anko-driven, FINAL)**: categorical
packaging (catamorphism / initial algebra / optics / declaration-
interpreter) REMOVED on amortization grounds — physics fixed,
thesis-scale, terms added a few times in a lifetime. Every historical
bug was caught by 5 flat disciplines (independent oracle / per-term /
canary / slopes+parity / convergence gate), none by abstraction. Core =
**dumb reference + AD**: blatantly-correct full energy/RHS/propagator
(explicit loops, dense DFT matrix, expm + RK4, tiny grid, pure → AD-able
where production never was) + master oracle (dumb-vs-fast per-term).
"Each term written twice is not a DRY violation — redundancy IS the
oracle; DRY deletes the redundancy that catches bugs." Two hard rules:
discretization pinning (same discrete math, independence in EXPRESSION
only) + day-0 CI gating (reference_rhs rotted because ungated).
Magnitude blind spot (dumb-vs-fast shares θ) → CG oracle SHIPPED
(test_cg_projection_oracle.jl 16/16: literature inverses + KU-vs-6j
cross-route + channel_kernel≡GP at F∈{1,2,3,6}); Fisher identifiability
next (preflight, AD-∂θ consumer). Survives: θ single struct (mask, no
optics; hash stays at spec content_id), Euler 2/d + scaling oracle,
commute-gated conservation (DDI full→J_z only, secular→+F_z, Loss→norm
off), canonical pin + FD valley + driver ×2 + dV pins (all shipped
green). Harness lesson: rejection-sampling alignment guard at d~10³ is
flaky (P(|cos|≥0.05)≈7%/draw) — CONSTRUCT aligned directions
(δ ∝ mix·ĝ + (1−mix)·η̂), don't sample.

**Why staged**: the one prior absorption attempt was reverted for +4%
(fused-kernel scratch loss); anko's elegance-bias norm — bit-identity or
±2% measured gates per stage, never a big-bang rewrite.

**Week-1 bootstrap spec** (anko-authored, polished): `docs/design/term_oracle_bootstrap.md`
— canonical gradient pin (g = δE/δψ̄ per-voxel, dV clause), estimator set
(FD ε-valley engine-free; Enzyme admitted later via its own valley),
operator classes {linear, mean_field, pairing, dissipative} (pairing needs
second-variation symmetry, NOT sesquilinear Hermiticity — root cause of the
four_step_chain step2 mean-field failures), two-argument frozen-field
apply_operator! (day-0 protocol addition), symmetry declarations incl.
TotalZ/J_z (full DDI declares TotalZ only; secular adds SpinZ) and
GlobalPhase (Loss omits it → norm oracle auto-off), independence rule
(FD-of-derived-energy is COEFFICIENT-BLIND for homogeneous terms — every
term needs ≥1 anchor not flowing through apply_operator!).

**Status (2026-06-05)**: week-1 item 1 SHIPPED green (11/11, 6.9s):
test/helpers/{fd_gradient,oracle_fixtures}.jl +
test/oracles/test_term_properties.jl registered in ci tier; fd_valley
3-way classification {exact_floor (quadratic E — central FD exact, no
truncation band), valley (slope≈2), plateau (bug)}. four_step_chain
TimeDependentZeeman comment-label inversion VERIFIED and fixed (values
fine, labels lied; field order is (p,q,bx,by) per
interactions_zeeman.jl:121). Remaining 5 trinity-oracle files stay
unregistered until their fixes land (each registration must land green).
Rest of Stage 0 (defect fixes, reference_rhs re-anchor, GPU host-shadow
adapter, padded-DDI verdict, perf baseline) NOT started.
Until Stage 0 ships, the 9 live defects in doc §2 are open — notably:
LHY/Tensor apply_step! call undefined functions; GPU + c2/tensor crashes
on psi_mf kwarg; reference_rhs transverse Zeeman sign is opposite to
production (Level-10 void for transverse); ω_R≠0 makes LBFGS optimize a
different H than is propagated; ITP excludes MG while the gradient
includes it.

**Ruling closed + frozen (2026-06-06)**: CLAUDE.md commitment #3 amended
(guarantee preserved: zero silent drift; mechanism: day-0 gated
redundancy — forced by the runtime-speed target). Design FROZEN:
changes require bug or measurement. Commit af21de5f.

**Measured baseline (2026-06-06, bench/baseline_hamiltonian_faces.jl,
Eu 24³×D=13 secular DDI RT)**: energy_decomposition CPU 9.5ms/16.3MB
alloc, GPU 7.9ms (host-copy fork — barely beats CPU);
energy_gradient! CPU 25.4ms/33.9MB (static ~2.9MB×12 estimate
CONFIRMED), GPU 13.0ms; split_step! CPU 32.3ms/3.4KB (legacy
propagator alloc-clean), GPU 8.4ms (launch-bound, util-memo
consistent). Perf design: docs/design/gpu_performance_architecture.md
— P0 layout CONFIRMED spatial-first (FFT batch + single-GEMM uniform
spin + coalesced per-site + trailing N_cells; D=13 register pressure
→ F32/shared-mem staging), priority P1 (LBFGS alloc tax, M1-critical)
→ P2 (device-resident energy) → P3 (N_cells batching).

**Defects 1-3 FIXED (2026-06-06)**: LHYTerm.apply_step! implemented via
production _lhy_V (was UndefVarError); TensorTerm.apply_step! real
kernel signatures; RamanTerm energy resolves raman_at. +8 regressions
in test_term_properties.jl (27/27). Remaining open: defects 4-9
(reference_rhs transverse sign, ω_R frame split, MG ITP exclusion,
GPU shape divergence, zeeman_at collapse, padded-DDI suspect).

**Repo sweep T1 complete (2026-06-06)**: 45a2e9d4 (batch-1: 25 dead
units −1,631 incl. dead monitoring subsystem ×5 files + GPU ~180MB
dead scratch fields + Fisher dedup + InteractiveUtils test-target fix —
the canonical Pkg.test ci tier had NEVER run green on this machine
state; now 14,560/0) + Group A staged (−1,550: force_gradient,
embedded chain + error_mode:"embedded" silent-config BUG FIX,
spinor-binary scaffold, trap-step w/ AVF essay preserved at
docs/design/integrator_trap_avf_note.md, scan_summary/time_resolved
islands; ci re-green 14,560/0 — identical count = zero coverage
confirmed; commit via /tmp/commit_msg_groupA.txt). PENDING: Group B
keeps (research surface), Group C wiring (DDI/PULSE schema validation
gap, reference_l3 test), redundancy 19 clusters → T2 (P4/Stage 3),
incl. phase-winding convention mismatch (physics-relevant) + canonical
polyhedral data dual-statement.

**terms/ merge (2026-06-06, 228e9ef5, anko-prompted)**: interactions/ +
potentials/ merged into per-term terms/<term>/ (face + engine cohesion).
Shared machinery EXPLICIT: hamiltonian/coefficients.jl (c↔g algebra,
TDHFB/Bogoliubov-shared), hamiltonian/shared/{rotation,spin_rotation}.jl
(DDI+spin_mixing cache borrow; apply_uniform_spin_rotation! split out of
raman.jl — its biggest client was TransverseZeeman, not Raman),
hamiltonian/optics/ (builders), absorbing_boundary → integrator/. Pure
git-mv, include order preserved exactly, 19 suites green incl. GPU 133.
Safe BECAUSE master oracle demoted body-location to cohesion. The 3×
"unify" discussion settled: declaration-unification rejected (speed +
B1 self-reference lesson), gate-unification done, FILE-unification =
this commit. CLAUDE.md structure rows updated; "adding a term" now
also requires a dumb statement slot (meta-test enforced).

**Dead-code prune (2026-06-06, 3d7efe5c, anko-prompted "他にも不要?")**:
deleted (caller-verified): 4 dead ONE-LINE decorations, is_kinetic_term,
total_energy_via_registry, strang_step_via_registry! + its parity test
(post-B3 near-self-comparison), per_term + propagator_face +
ad_consistency test scaffolding (absorbed by master oracle + dt-valleys).
preflight testset 8 rewired to split_step!-vs-dumb_rhs_total residual
(strictly stronger). fused_face REGISTERED (the fused==unfused gate
dt-valleys don't reach). Net −1121 lines. LESSON: a `head -5`-truncated
caller grep missed the preflight caller of strang_step_via_registry! —
never truncate caller greps before deletion. P1 speedup mechanism
(anko asked): faces are memory-bandwidth-bound; derived pattern paid
4-5 grid-array passes/term + full-array work for 5 inactive terms +
per-term recompute of n/f densities; direct accumulation = 1 fused
pass + shared ctx + gates; GC retirement secondary. Pending anko OK:
~12 untracked *.jl.24028.mem --track-allocation artifacts.

**add_gradient! DELETED (2026-06-06, 819bb305, anko-prompted)**:
consolidated into ACCUMULATING apply_operator! (out .+= H·ψ, gate-first,
no internal fill!; ctx overload carries former ctx bodies). Was the
same math object; P1 had begun re-duplicating coefficients across the
two faces. Protocol = 3 faces + sign_oracle. Net −385 lines.
four_step_chain DELETED (absorbed: step0 monotone heuristic was
roundoff-fragile for exactly-quadratic E — valley :exact_floor
supersedes; step2 blanket Hermiticity wrong for mean-field; linear-face
Hermiticity absorbed into master oracle +6). Dormant orphans
registry_gradient_parity + ad_consistency now REGISTERED ci. OPEN:
mean-field second-variation symmetry (dumb FD-Hessian), registry-wide
mutant canary table (§7), per_term/propagator_face absorption.
Fisher SHIPPED (2d1e1611, 24/24): fd_jacobian + identifiability_report;
degenerate-protocol detection + channel-space chain via T-CG map.

**Ω>0 floor DIAGNOSED: NUMERICAL not physical (2026-06-08, 5e3d8da3)**.
measure-before-launch applied to the FORK (before committing to a heavy
arc). gate-2 Lanczos λ_min on CONVERGED cells straddling the boundary
(M1_CLASS=converged_single; BdG only valid at stationary ψ → use
converged neighbours not unconv cells): λ_min stays GAPPED ~2.3-4.1 at
ALL converged cells, all Ω, NO downward trend — B=100 full-Ω row flat
(3.2-4.1), B=5/10 boundary-straddling gapped (~2.5-2.6). No mode→0 ⇒
NUMERICAL (large condition number, 1st-order LBFGS crawls), NOT a
physical Ω_c degeneracy. This REFUTED the soft-mode-preconditioner
premise (NO low-k soft mode — diagnose saved building wrong fix 2nd
time). REVISED FIX (doc renamed m1_omega_conditioning_floor.md):
matrix-free 2nd-order method on the anchored Hessian = trust-region
Newton-CG (inner CG = HvP = gate-2/test_bdg_fd_hessian operator; inner
precond = existing Sobolev IS right for kinetic spread; continuation =
warm-start). Anchored Hessian pays off 3×: gate-2 + diagnosis +
Newton-CG. LIMIT: unconv transition cells unmeasurable directly; cell
still stuck after Newton-CG = candidate-physical (its BdG = "what goes
soft at Ω_c" half-2 result). NEXT (impl unit): Newton-CG on 1 Ω>0 cell
→ ‖∇E‖→1e-5 where Sobolev-LBFGS plateaus + no Ω=0 regression → full
continuation sweep w/ Newton-CG. SUPERSEDED: soft-mode preconditioner
design (premise refuted).

**Soft-mode preconditioner arc STARTED — design committed (2026-06-08)**.
Ω>0 Barnett map BLOCKED: continuation warm-start smoke (B=1/Ω=0.1 from
converged Ω=0) ran >54min no early-stop → conditioning-LIMITED not
step-limited (more steps/TSUBAME won't fix). DIAGNOSIS (grounded in
existing precond): _sobolev_precondition! (lbfgs/helpers.jl) = (1+α(−∇²))⁻¹
damps HIGH-k kinetic but ≈1 at LOW-k; Ω=0 well-conditioned (gate-2
λ_min~2.4) but Ω>0 floor = LOW-k symmetry-generator soft modes Sobolev
can't see — Coriolis −Ω·L̂_z softens rotation Goldstone L̂_z·ψ + spin
Goldstones F̂_α·ψ. DESIGN (docs/design/m1_soft_mode_preconditioner.md):
Noether/natural-grad precond rescaling grad along {L̂_z,F̂_x,F̂_y,F̂_z}·ψ
by inverse curvature κ_G=Re⟨g_G,H·g_G⟩/Re⟨g_G,g_G⟩ — THE ANCHORED
FD-HESSIAN makes κ_G computable (1 HvP/gen) + trustworthy (operator pays
off twice: gate-2 + precond metric). Plug-in lbfgs/driver.jl:137,207
after Sobolev, opt-in noether_generators kwarg. NEXT (implementation
unit): (1) confirm small κ_{L_z} at Ω>0 cell (reuse gate-2), (2) impl in
driver, (3) one Ω>0 cell converges where Sobolev plateaus + no Ω=0
regression, (4) full continuation sweep (script committed, blocked on
this). continuation script sprint5_M1_continuation_sweep.jl committed
but warm-start alone doesn't converge.

**STATIC Eu PHASE DIAGRAM FULLY GATED — North Star half-1 (2026-06-08,
9ec4eeaf)**. Gate-2 (scripts/m1_gate2_stability.jl): lowest constrained-
Hessian eigenvalue via hand-rolled fully-reorth Lanczos on the anchored
FD-Hessian HvP. Constrained op P(H−2μ)P (P removes complex-ψ0 norm+phase
gauge; μ=Re⟨ψ0,g⟩/2‖ψ0‖²). Method validated: μ=12.67, ‖g−2μψ0‖/‖g‖=4e-7,
phase mode H·iψ0=2μ·iψ0 (the 2μ eigvec — NOT null; zeroed by H−2μ + proj
— corrected my 2nd wrong analytic guess this arc). ALL 6 converged Ω=0
cells = MINIMA (λ_min∈[2.3,3.7], strictly+, no neg mode). +λ_min at B=0
physical: Eu DDI gaps the would-be spin Goldstones. RESULT (gate-1 +
⟨L_z⟩=0 + gate-2 all pass): **polar (B≤2.6nT) → antiferromagnetic (B=5)
→ coreless texture (B≥10)**, all energetic minima, all ⟨L_z⟩=⟨F_z⟩=0
legitimate non-rotating GS. This is the gated answer to "what is Eu's
ground-state phase". NEXT: Ω>0 Barnett map (continuation warm-start from
converged neighbours for the 18 unconv cells) + DDI k-structure in BdG
anchor (finite-k FD-Hessian). The verification→physics pivot produced a
FULLY-GATED physics result — the whole arc's payoff.

**⟨L_z⟩ flag → Ω=0 PCV is LEGITIMATE (2026-06-08, ffbb6be6)**. Extended
m1_groundstate_audit.jl with per-atom ⟨L_z⟩, ⟨F_z⟩. RESOLVES the
non-trivial Q (why does PCV win at Ω=0?): EVERY converged Ω=0 cell has
⟨L_z⟩=0 AND ⟨F_z⟩=0 incl B≥10 PCV → coreless spin texture (Mermin-Ho,
zero net circ), NOT mass-circulation vortex → legitimate non-rotating
GS. The suspicious ⟨L_z⟩≠0 branch does NOT occur. STATIC Eu phase
diagram (Ω=0): polar (B≤2.6) → antiferromagnetic (B=5) → coreless
texture (B≥10), all ⟨L_z⟩=⟨F_z⟩=0 — clean non-rotating sequence (seed
labels; identity pending gate 2). Ω>0 ⟨L_z⟩ ramps with Ω (Barnett
response) but unconverged/single-seed (untrustworthy). REMAINING for
the gated static phase diagram: gate-2 minimum-vs-saddle via Lanczos on
the anchored FD-Hessian HvP (constrained: project complex-ψ0, shift
−2μ, μ=Re⟨ψ0,g⟩/2‖ψ0‖²; lowest eigenvalue ≥0 → minimum). No KrylovKit
in deps → hand-roll Lanczos. cell "stability" field = "ambiguous" (sweep
punted → gate-2 genuinely needed).

**FD-Hessian BdG anchor — gate-2 operator (2026-06-08, 61bdd1ae)**. test_bdg_fd_hessian.jl:
the central-diff Hessian of the gated energy_gradient! reproduces BOTH
blocks of the hand-built BdG EXACTLY (‖L_op−2·h_mf‖=0, ‖M_op−M_anom‖=0)
at F=1 polar/FM, F=2, F=3, F=6 Eu. v/iv extraction
(L_op[:,c]=(D_{e_c}g−i·D_{i e_c}g)/4) carries the anomalous block (where
PCV-onset/conditioning-floor soft modes live). Red-checked (scale
hand-built M → M_op assertion reds all F). So BdG doubly anchored:
spectrum (F=1 analytic, test_bogoliubov_anchor) + matrix (FD-of-gated-
grad, F-swept). KEYSTONE measurement that grounded it: probe showed my
naive {0,2c0,2c1} expectation WRONG (raw Hessian eigvals [2,2,2,2.8,2.8,6]
— no μ projection); pivoted to anchor vs hand-built bogoliubov matrices
(master-oracle pattern) not analytic guesses → exact. GOTCHA: F=2 needs
Rb85 (atom sets F, not the loop var). conventions: energy_gradient!
returns 2δE/δψ̄; BdG L=2n0·h_mf+diag(εk−μ+zee), M=n0·M_anom. full ci
15,579/0. REMAINING for gate-2: DDI k-structure (Q(0)=0 → k=0 matrix
anchor blind to it; finite-k FD-Hessian follow-on). NEXT: gate-2 APPLY
(Lanczos on trapped-cell HvP → min vs saddle) on Ω=0 column + ⟨L_z⟩ for
PCV cells (legit-texture vs net-circulation, the user's physics flag) →
stability-gated static Eu phase diagram (North Star half-1).

**Gate-(1) ground-state audit — FIRST PHYSICS RESULT (2026-06-08,
80fac76f)** — scripts/m1_groundstate_audit.jl on the on-disk 30-cell
sweep (runs/sprint5_M1_multistart_groundstate/, B×Ω). FINDINGS:
(1) save-bug ABSENT — ‖∇E‖_disk ≈ ‖∇E‖_fresh everywhere → spine-G
atomic fix (3c3c3887) WORKED, disk values authoritative for this sweep.
(2) **Ω=0 static phase diagram SOLID**: 6/6 converged (5 GS_confident
multi-seed-reproduced + 1 B=0 Goldstone), winner progresses **polar
(B≤2.6) → antiferromagnetic (B=5, 6-seed) → polar-core-vortex (B≥10)**
with in-plane field. Phase IDENTITY needs gates 2-3 (labels = winning
seed). (3) **Ω>0 Barnett map BLOCKED**: 18/30 unconverged (‖∇E‖~1-4,
vortex-soft-mode conditioning floor) — needs preconditioning
(Riemannian/Noether spine C/D), NOT extractable. Partition: GS_conf 5 /
conv_single 6 / goldstone 1 / unconv 18. doc:
docs/research_notes/m1_groundstate_audit_2026-06-08.md. NEXT: gates 2-3
on the Ω=0 column → stability+resolution-gated static Eu phase diagram
(North Star half 1, EXTRACTABLE now). Gate-2 (saddle-reject) on F=6+DDI
needs the FD-Hessian BdG anchor first (analytic anchor covers F=1
contact only). Tripwire HELD: this commit is a phys-gated table, not
infra.

**BdG/linearize functor anchored (2026-06-08, f2585f2e)** — the
PHYSICS-PIVOT begins. Verifier framework: the phase verdict from the
on-disk 30-cell M1 sweep (runs/sprint5_M1_multistart_groundstate/,
B×Ω) needs its OWN physics-gates, not just gated gradients: (1)
ground-state-ness (lowest-E basin = global? from disk: #starts,
basin-reproducibility, gap to next), (2) saddle-rejection validity
(rides on BdG), (3) vortex resolution (monopole lesson: noise-sign on
unresolved cores). Answered the keystone Q "is BdG anchored?": NO — a
single hand-built CG-sum (_bdg_normal/anomalous_matrix), tests were
structural/smoke only. But MEASURED correct (reproduces Ueda F=1 polar
density √(εk(εk+2c0n))+2×spin √(εk(εk+2c1n)) and FM density
√(εk(εk+2(c0+c1)n))+free-particle magnon EXACTLY) → correct-but-ungated
→ saddle-rejection WAS reliable but ungated. Anchored:
test_bogoliubov_anchor.jl (declaration-independent, red-checked: ×2 on
anomalous M reds polar). Gate caught my own incomplete FM model (gapped
FM mode exceeds density at small k) — asserted only unambiguous forms.
NEXT (load-bearing for Eu verdict): FD-Hessian anchor for F=6+DDI (the
sweep's actual operator, not covered by F=1 analytic) = L(k=0) = FD of
the GATED energy_gradient! on uniform grid (chains-off-gated-gradient).
THEN gated extraction from disk (re-eval winners + anchored
saddle-reject + vortex resolution). SCOPE: user accepted option-3
(gated Eu extraction = main act, consolidation parallel; tooling
rebuild = atomic-return/batched-kernel REFUSED). Tripwire: next physics
commit must be a (B,Ω) phys-GATED table, not bare (bare table = physics
aggregate-green) nor more infra. CORRECTION recorded: SpinC1 zero-blast
for the SWEEP but LOAD-BEARING for SBI (c1 is varied there). full ci
15,559/0.

**Coefficient-source closure + ledger adjudication (2026-06-07)** —
verifier follow-up. LEDGER NOW TRULY CLOSED via provenance (not
assumed): (1) absorbing-boundary blast radius = ZERO — NO runs/ config
enables it; matsui_edh "absorbing" mentions are an analytic
master-equation spin-ladder terminal (turn_15 m=−6), EdH prose
(turn_24), and the schema validator's key-LIST in error messages from
runs that FAILED config validation (turn_74/t81, no jld2). My earlier
"Matsui-EdH runs configured an absorber" commit claim was an
OVERSTATEMENT (grepped "absorbing", assumed spatial) — corrected in
App. A. (2) SpinC1 blast radius = ZERO — registry.jl:102 + legacy
energy path always construct SpinC1Term(ws.interactions[1]); two
sources equal in EVERY production path → gradient always read right
value. MECHANISM (record): FD-valley sees energy↔grad consistency at
the test point (green where sources agree); self-canary sees
responsiveness to the canonical source (flip term.c1 ⇒ must propagate).
Single-source violation with agreeing sources = FD-invisible,
canary-visible. CG oracle hardened (Parts 4-5): first-principles
λ_S=spec(F̂₁·F̂₂) by explicit diagonalization (anchors c₁ channel
MAGNITUDE absolutely at F=1..6, the SBI blind spot the sign-canary
can't see) + wigner_6j j6=0 closed-form anchor (the k≥2 primitive).
Self-canary made explicit CLASS guard (was instance): every active
numeric-field term must get source-responsiveness mutant, pinned by
name per fixture incl spin_c1; Coriolis ws-locked exempt; fieldless =
single ws source. dt-valley slope wording fixed: order is order-1 BY
CONSTRUCTION (same first-order substep), slope is consistency check
only. SCOPE CORRECTIONS (resume): F32 measurement/gate are CPU — P2's
GPU reduction (tree vs atomic, orders different) must be measured
on-device under c0=200 stress, NOT inherited; Stage 3 defer rationale
is detection-not-prevention (SpinC1 IS its motivating bug), not "no
bug". GOTCHA recorded: `find -name basename` clobbers duplicate
basenames (2× rotating_basis.jl, 2× topology.jl) — restore by PATH /
git restore. STOPPED here (user: freeze discipline correct). 541/541
across the 3 touched oracles; closure commit STAGED (1Password ×2 fail,
msg /tmp/commit_msg_closure.txt).

**5 drift-risk gates SHIPPED (2026-06-07)** — user-priority ④, audit
follow-up DONE. test_redundancy_gates.jl gates the 5 ungated clusters,
all directional/parity, all red-checked (flip source → gate red): (a)
extract_vortex_lines_per_m charge sign (line = NamedTuple{charge,points},
out[key]=flat Vector), (b) monopole_charge_3d handedness — KEY FINDING:
pure hedgehog n̂=r̂ puts charge at unresolved core so sum(q)≈0 at ALL
res; gate via smooth charge-neutral n̂∝(sx,±sy,1+sz) central-block sign
(~±0.03), (c) paper3_canonical_states==canonical_polyhedral_spinor SSoT
fidelity (F=2..12), (d) init_psi F=6 cyclic/biaxial==polyhedral_candidate_spinors
fidelity, (e) spin_texture_xy Fx/Fy orientation (real phase→Fx>0, i
phase→Fy>0). GOTCHA (caught + fixed): red-check restore via
`find src -name basename` CLOBBERED 2 unrelated files — there are TWO
rotating_basis.jl and TWO topology.jl; basename collision copied wrong
backups over src/workflow/experiments/analyzers/rotating_basis.jl + analyzers/topology.jl;
`git restore` fixed (they were committed); ALWAYS check git status after
bulk restore, never restore by bare basename. All 4 verifier follow-ups
(i-iv) complete; "構造的根絶" now airtight (coverage path-unit + beam
canary) AND the audit drift-risks closed.

**dt-valley band measured + tightened (2026-06-07)** — user-priority ③.
MEASURED full-band slope per term (scripts, fixtures A/B/DDI/RF):
CONFIRMED claimed order=1 for all, no order-2 masquerade. Fitted slope
is (term×fixture)-dependent (NOT per-term): stiff/large-coef ≈1.0
(kinetic/trap/ddi/raman/… 0.98-1.00), small-coef higher (spin_c1 1.51,
lhy 1.84, RF zeeman_z 1.46 — p_eff=p−ω_R=0.1 small). dt² admixture
weight ∝ 1/leading-coef. Per-term band split FAILED on RF zeeman_z
(0.98 in A, 1.46 in R) — proved per-term is wrong model. Settled:
single (0.7,2.2) band (was over-cautious 2.6), brackets max 1.84+margin.
Sign/missing-op bug PLATEAUS (kind≠:valley), NOT a slope shift — band
guards order-drift only. GOTCHA: asymptotic (near-floor) slope is
NOISY (roundoff), full-band is the clean measure — opposite of my
hypothesis. NEXT: ④ gate the 5 audit drift-risks (vortex_extraction
sign, monopole_charge_3d sign, manuscript canonical_states copy,
init_psi cyclic/biaxial, spin_texture_xy Fx/Fy).

**Master-oracle self-canary SHIPPED (2026-06-07)** — user-priority ②
done. test_master_oracle.jl "self-canary: the comparison has teeth":
per active term, the SAME isapprox(dumb,prod;rtol) the oracle uses must
REJECT (1) a source-faithful construction mutant (`_sign_mutant` =
term rebuilt with all numeric fields negated, real production faces)
and (2) value-perturbation (−prod, 2·prod). CoriolisTerm skipped from
(1): apply_operator! ASSERTS term.Ω == ws's Ω (cache ws-bound) → mutant
rejected by design; value-perturbation gives its teeth. DEFINITIVE
red-check (user's literal ask): flipping `_diag_coef` LinearZeeman sign
`-term.p*m`→`+term.p*m` in src → master oracle RED on ALL 8
fixture×state (A/A′/B/R × coherent/random), energy face (L88) AND RHS
face (L100). REAL DEFECT FOUND BY THE CANARY + fixed: SpinC1Term energy
used term.c1 but gradient `_grad_c1_spin!` read ws.interactions[1] —
single-source violation, coincided in registry path so no live bug, but
broke for any term with c1≠ws.c1. Now `_grad_c1_spin!(…, c1, …)` takes
c1 explicitly; both apply_operator! overloads pass term.c1. 433/433.
GOTCHA: piping a failing test run through `tail`/`grep` truncates the
per-failure messages — capture full output to a file to diagnose. NEXT:
③ dt-valley band tighten (per-term (0.7,2.6)→~(0.7,1.4)) → ④ 5
drift-risks.

**Coverage meta-test SHIPPED (2026-06-07)** — user-priority ① done.
test/oracles/test_path_coverage.jl: coverage now counted in (term ×
config), not per term. Two MECHANICAL invariants, both faithfully
red-checked (revert → RED): (A) every src file with `.step += 1`
(real-time step loop) must call `apply_rt_dissipation!` or be in
_EXCUSED_STEP_LOOPS (itp_loop/tdhfb×2/binary_simulation) — deleting
yoshida's helper line flags yoshida.jl (the absorbing-bug shape); (B)
every value of LHY kind (live SpinorBEC.LHY_SCHEMA["kind"].enum) +
DDI {secular,padded} Bools must have a manifest entry whose gate is a
real tier-registered test (file exists + in runtests tier list + LHY
mentions the kind). GOTCHA found writing the red-check: sed-COMMENTING
the helper call left the substring → file-scan still counted it as a
driver (substring-based); must DELETE the line for a faithful A
red-check. FINDING: quasi_2d LHY kind has NO distinct term path —
auto-derives c_lhy → scalar LHYTerm (quasi_2d DDI kernel is a separate
axis); gated at config layer (test_dynamics_lhy_plumbing). Honest
limits in header: invariant A file-level (not per-fn); axis LIST manual
(new VALUES caught, new AXIS needs human). NEXT (user order): ②
master-oracle self-canary → ③ dt-valley band tighten → ④ 5 drift-risks.

**Redundancy audit + absorbing-boundary bug (2026-06-07)** — 24-agent
read-only workflow over 4 domains (phase-winding / Strang-epilogue /
polyhedral-dual / broad-sweep), adversarial verify. 20 candidates → 6
upheld ungated. **1 LIVE BUG FIXED**: absorbing-boundary mask was dead
on ALL RTP driver paths — apply_absorbing_boundary! had 3 call sites
(split_step!/midpoint/combined) but the 4 driver loops (leapfrog in
run_loops, yoshida, adaptive×2) hand-wrote the epilogue with loss but
NO absorbing. run_simulation! → leapfrog, so production
`dynamics:{absorbing_boundary}` built the mask and discarded it
(Matsui-EdH loop runs affected). Invisible: every absorbing test drove
split_step! directly. ROOT FIX: `apply_rt_dissipation!(ws,dt,n_comp,N)`
(absorbing_boundary.jl) binds loss+absorbing inseparably; all 7 sites
route through it. Gates red-checked (disable absorbing → all driver
gates RED). **5 OPEN DRIFT-RISKS (need day-0 gates, future units)**:
(a) vortex_extraction.jl plaquette vortex-charge sign (dashboard-only,
ungated) (b) monopole_charge_3d hedgehog sign (uniform-texture test
can't catch flip) (c) canonical polyhedral spinors — manuscript
figures/canonical_states.jl is an ungated bit-identical copy of
analysis/canonical_polyhedral_states.jl SSoT (d) init_psi cyclic/
biaxial vs polyhedral classifier candidates (ungated members) (e)
spin_texture_xy analyzer hand-rebuilds Fx/Fy (thesis Fig 3, ungated).

**VERIFIER LESSON (user, 2026-06-07) — "構造的根絶" was overclaim.**
Class-closure needs BOTH (i) coverage in (term × config-PATH) not per
term, and (ii) the BEAM's own canary. Neither done. (i) set-equivalence
meta-test counts H_TERMS_CANONICAL_ORDER slots = TERMS; padded/secular/
GPU/ω_R/absorbing are term-INTERNAL path variants it doesn't count —
that's why defect 9 (padded) AND absorbing both escaped ~1 month each.
`dumb_ddi_potential_padded` exists but is NOT in master oracle (only in
test_ddi_padded dt-valley). FIX = meta-test enumerates production
config-branches, asserts each has a dumb-vs-production gate. (ii) NO
master-oracle self-canary: test_term_properties canary tests the
valley_scan HELPER, not that flipping a covered term's sign turns the
master oracle RED. NEXT UNITS (user order): coverage meta-test
(term×config) FIRST, then master-oracle self-canary, then dt-valley
band tighten (per-term is (0.7,2.6), claimed order=1 → should be
~(0.7,1.4); Strang is (1.6,2.4) tight), then gate the 5 drift-risks.
Redundancy consolidation must NEVER reduce a physics statement's
independent implementations below 2 (dumb-vs-production independence is
the #3 oracle); only scaffold/plumbing dups may be merged — absorbing
epilogue qualified (plumbing).

**Defect 9 CLOSED (2026-06-07)** — App. A ledger now 1-9 ALL fixed.
Padded-DDI 2D/3D crop CONFIRMED (10-agent numeric workflow: dispatch
proof + blast radius + marker probe + 2 adversarial refutations, both
refuted=false). Cause: fc937c69 (2026-05-10 batched-gemm) replaced
`for I in CartesianIndices(n_pts)` with linear `phi_x[i]` in
_ddi_compute_angles!; CPU propagator read the first N_spatial LINEAR
elements of the 2×-padded Φ → full padded columns into the pad region
for ndim≥2 (2D err 0.255, 3D 0.264; 1D accidentally correct; GPU +
padded-energy face crop correctly via Cartesian views). Root fix:
`_ddi_crop_phi` (rotation.jl) crops Φ to [1:n...] corner pre-angle-loop,
ZERO-COPY when size==n_pts (hot unpadded path byte-identical). Method-2
latent CPU-scalar branch → crop views. Gates (red-checked): 2D/3D
marker-parity (padded-Φ rotation ≡ cropped-Φ, real+imag) +
dumb-padded dt-valley (new dumb_ddi_potential_padded /
dumb_rhs_ddi_padded share _dumb_ddi_kernel; refactor bit-preserving,
master oracle still 1e-10). SCOPED KNOWN-LIMIT (documented, not
silently wrong): ddi_padding reaches only the propagator; energy/grad
faces stay unpadded; split_step_combined! now REFUSES padded loudly.
Blast radius ZERO (no YAML key, default false, no runs/ enables it).
GOTCHA for future: smooth-state padded-vs-unpadded DDI differ by ~9%
(genuine aperiodic-vs-periodic long-range tail) — can't gate padded by
comparing to unpadded; gate vs an independent padded statement.

**Defects 4-6, 8 CLOSED (2026-06-06)**: all four fixed WITH day-0
gates, 453/453 + combined 9/9 green. (4) reference transverse Zeeman
sign +b·F→−b·F — triply unseen: bx=by=0 test defaults AND
reference_total_energy summed diag-only AND stale file header; all
three closed (total now routes reference_zeeman_energy combined).
(5) registry/dumb both apply the RF model independently
(p_eff=p−ω_R, (bx,by) rotated at t); gates = fixture R in master
oracle + RF dt-valleys + END-TO-END split_step! one-step residual vs
dumb_rhs_total at dt=1e-4 (pre-fix plateaus ~3e-2; the dt-valley alone
does NOT gate the production propagator — both its faces were
lab-frame pre-fix, so it passed). (6) ITP wrappers mg_active=true;
gate = ITP displacement regression (control centered, MG tilts −x).
(8) combined path transverse was structurally dead (zeeman_at
collapses TimeDependentZeeman → transverse_b(zee,t)≡(0,0)); now reads
ws.zeeman; gate = directional d⟨Fy⟩/dt=bx⟨Fz⟩>0 from m=+F, RED-CHECK
measured (temporary pre-fix revert → gate fails). None of 5/6/8 hit
any runs/ config (latent); 4 was reference-side only.

**P1 SHIPPED (2026-06-06, c439e61e)**: registry-face alloc tax
16-26× down (CPU: energy 9.5ms/16.3MB→5.5ms/0.99MB; gradient
25.4ms/33.9MB→10.8ms/1.28MB; LBFGS iter ~35→~16ms = M1 critical path).
Mechanism: derived bodies → fused Array specializations + direct
broadcast accumulation, LEGITIMISED by master oracle (the flat-regime
dividend); device-generic AbstractArray bodies retained (GPU parity
133/133). Gate-before-allocate everywhere. EnergyContext revived
(struct was latently broken — psi_host typed at spatial dims; zero
callers hid it). DEFECT 7 FIXED incidentally (GPU shape :loss) — every
GPU run of the parity gate had been failing its shape assert, which
masked a LinearAlgebra.I import bug in the test (unreachable code);
parity expanded 98→133. Residual ~1MB/call (registry rebuild +
Coriolis/LHY non-ctx) noted; ≤100KB target stands. Remaining queue:
Fisher preflight (last non-retrofittable) → padded DDI + defect 9 →
defects 4-6, 8 → P2 (device-resident energy).

**Dumb DDI LIVE (2026-06-06, c3a8c73e)**: 14/14 slot coverage complete
(master oracle 267/267; propagator refs 48/48 incl. DDI dt-valleys
secular+full + DDI-active Strang slope). FINDING: production rfft
convolution's effective kernel is Q∘rep (Q at the stored rfft
representative) — Nyquist index self-mirrors, so Nyquist planes break
full k-evenness in off-diagonal Q. Convention not bug (resolved states
immune; random n=6 states put ~42% power on Nyquist planes → O(1)
energy shifts). Pinned exactly (1e-17 on Φ); secular kernel
Nyquist-immune. ddi_secular passed explicitly (never read from baked
Q — that's what's under test). Remaining: padded variant + defect-9
crop verdict. Unit queue next: P1 (alloc tax) under master-oracle
gates → Fisher preflight.

**Propagator references LIVE (2026-06-06, commit 7ca9a6c0)**: per-term dt-valleys (12 slots, slope≈1; plateau
= face generates a different operator than the variational gradient) +
Strang order slope ≈2 vs dumb RK4 (dumb_rhs_total + dumb_rk4_evolve).
39/39. FINDINGS: (a) singlet pair step VERIFIED variational (the
exp(−ic₂|A|²dt) docstring paraphrase misleads; the implementation
generates the conjugate-linear gradient flow correctly); (b) Coriolis
3-shear passes vs dumb L_z; (c) large-spectral-radius terms (kinetic
k²/2~33) need dt down to 1e-8 — descending valley misclassified as
plateau at fixed health threshold is a harness trap; (d) valley_scan
extracted as shared classifier. Unit queue: dumb DDI (+physics
anchors) → P1 (alloc tax, master-oracle-gated) → Fisher preflight.

**Master oracle LIVE (2026-06-06, commit 31e17f0f)**: dumb reference
(src/validation/dumb_reference.jl — 13/14 slots energy+RHS, no FFTW,
own spin matrices, index-form DFT, direct field resolution) vs
production registry per term at 1e-10, 172/172 ci tier. Gaps asserted
both sides (raman/tensor RHS production-nil ∧ dumb non-nil).
LightShift/MG/Raman energies got their FIRST independent witness.
Finding: spin-coherent states are exactly singlet-free (F=1:
2ψ₊ψ₋−ψ₀²≡0) — pairing valleys need generic states + signal
precondition. Remaining for the dumb unit: dense expm/RK4 propagator
references (dt-valley), dumb DDI (own unit + physics anchors), AD dep
decision (ForwardDiff test-only — Project.toml has no AD dep).

**Audit provenance**: 8-facet workflow map (10 agents, 2.28M tokens),
raw JSON at /tmp (session-lifetime; load-bearing claims distilled into
the doc with file:line, top-4 critical claims re-verified first-hand).

Related: [[spine_operator_trinity_A_2026_06_05]] (the trinity spec this
arc completes), `memory/feedback_hamiltonian_sign_oracle_discipline.md`,
`memory/lever1_batched_cell_sweep_design_2026_06_05.md` (N_cells is a Stage 1
signature constraint).

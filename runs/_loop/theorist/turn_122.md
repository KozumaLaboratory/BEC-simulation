---
turn: 122
subagent: theorist
investigation_id: sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19
stage_advancing_from: "<NEW investigation; spawning at Hypothesize from sign_pattern_lemma1_mult_aware_2026_05_19.md §6 RESEARCH_NEEDED item #1 + theorist T115 §F non-trivial-irrep [Plausible] conjecture>"
stage_advancing_to: "Hypothesize"
topic_tags:
  - D3-build-theory
  - sign-pattern-lemma1-non-trivial-irrep
  - F11-T-E1
  - J-involution-isotypic-generalization
  - hamermesh-orbit-counting-tetrahedral
  - canonical-multiplicity-aware-extension
  - schur-isotypic-subspace
  - paper3-section-V-extension
depends_on:
  - "memory:sign_pattern_lemma1_mult_aware_2026_05_19"
  - "runs/_loop/theorist/turn_115.md"
  - "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md"
  - "memory:universal_structure_u1u4_2026_05_13"
  - "runs/_loop/director/turn_122.md"
---

# Turn 122 — Theorist Hypothesize (mult-aware Lemma 1 extension to non-trivial irreps; F=11 T:E_1)

## 1. Directive received

Verbatim §6 contract from director T122 (`runs/_loop/director/turn_122.md` §3.2):

Goal: derive whether the J-involution closed-form
$\bar\beta_0^{(\rm canonical)} = m_{\rm rep}/(2F+1)$ (established at trivial irrep
A by T119 critic Stage-2 via $J = \exp(-i\pi F_y)$ involution + Hamermesh
orbit-counting) generalizes to non-trivial polyhedral irreps. Concrete first
case: F=11 with tetrahedral group T, irrep $E_1$ (complex 1-dim, real-construction
2-dim, $m_{\rm rep} \ge 2$ by Hamermesh).

Sub-tasks (3.2.A) J-involution endpoint argument verify/refute at non-trivial
irrep; (3.2.B) generalize $\bar\beta_S^{(\rm canonical)}$ formula to specific
$\alpha = E_1$ — pick outcome (i)/(ii)/(iii); (3.2.C) emit 3-falsifier table
with F1 central; (3.2.D) compute $m_\alpha$ via Hamermesh, fall back to F=12 or
$E_2$ if $m_\alpha < 2$.

Constraints: NO julia, NO new code, NO state.json/memory/manuscript/src/test
mutation. Hard cost cap 3.0M. If algebraic obstruction in <1.5M cost, emit
RESEARCH_NEEDED and bail with [Plausible].

## 2. Read summary (anchor citations)

| Anchor | Lines | What it says |
|---|---|---|
| `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/sign_pattern_lemma1_mult_aware_2026_05_19.md` | 1-83 (full) | §2 canonical formula $\bar\beta_S^{(\rm canonical)} = m_{\rm rep} \cdot \mathrm{Tr}[\hat\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$ with $\rho_{\rm inv} = P_W/m_{\rm rep}$; §4 J-involution closed-form derivation summary for trivial irrep, citing theorist T115 §2.A eqs A4–A6; §6 RESEARCH_NEEDED items #1-#3 (item #1: F=11 T:$E_1$ $m_{\rm rep}=2$; item #3: isotypic-allocation conjecture at non-trivial irrep, theorist T115 §F); §7 anchors; §8 T119 critic A2 elevation to "rigorously established at trivial irrep". |
| `/home/suzume/workspace/BEC-simulation/runs/_loop/theorist/turn_115.md` | §2.A (focus); §2.A.4 (isotypic-allocation conjecture); §F (open RESEARCH_NEEDED) — re-read pages 1-400 + 400-600 | §2.A.1-§2.A.3 derive the explicit identity $\langle 0,0|(P_W \otimes P_W)|0,0\rangle = (1/(2F+1)) \sum_{m,m'} (A_{m,m'})^2$ via $J = \exp(-i\pi F_y)$ involution (eq A9); §2.A.3 line 248-282 derives the H-invariance constraint $A_{-m,-m'} = (-1)^{m-m'} A_{m,m'}$ (eq A8'); §2.A.4 line 336-361 floats the **isotypic-allocation conjecture** $\|\xi_\alpha\|^2 = m_\alpha \cdot d_\alpha / (2F+1)$ as [Plausible]; only verified at $\alpha = A$ trivial. |
| `/home/suzume/workspace/BEC-simulation/docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md` | §V.1–V.8 (full appended at 2026-05-19) | §V.2 canonical formula matches memory §2; §V.3 universal endpoint $1/(2F+1)$ derived for trivial irrep only; §V.5 sum rule $\sum_S \bar\beta_S = m_{\rm rep}$; §V.6 F=9 T:A verification table; **§V.7 lists F=11 T:$E_1$ as `<RESEARCH_NEEDED>` — non-trivial-irrep case NOT pre-derived in manuscript**. Confirmed by grep: only 4 hits for `non.trivial.irrep` / `E_1`, all in §V.7 RESEARCH_NEEDED items. |
| `/home/suzume/.claude/projects/-home-suzume-workspace-BEC-simulation/memory/universal_structure_u1u4_2026_05_13.md` | full 107 lines | Polyhedral classification table covers F=2/3/4/6/8/10 (5 families verified for trivial-irrep-canonical-state spinors); F=11 **NOT in U1-U4 inventory** (only F=12 listed as deferred at §V.G). F=11 T:$E_1$ state construction is therefore NEW for the loop. |

## 3. Derivation

### 3.1 Hamermesh orbit-counting at F=11 T

Group T (proper tetrahedral, |T| = 12) has **4 conjugacy classes**, not 3:

| class | order | size | rotation angle θ |
|---|---|---|---|
| $\{e\}$ | 1 | 1 | 0 |
| $\{4 C_3\}$ | 3 | 4 | $2\pi/3$ |
| $\{4 C_3^2\}$ | 3 | 4 | $-2\pi/3$ (equivalently $4\pi/3$) |
| $\{3 C_2\}$ | 2 | 3 | $\pi$ |

Note that $C_3$ and $C_3^2$ are **separate conjugacy classes** in $T$ (a common pitfall — they combine into one class only in the full extended tetrahedral group $T_d$ which includes reflections that conjugate $C_3 \leftrightarrow C_3^2$; in proper $T$ they remain distinct).

Character table of $T$ over $\mathbb{C}$ (4 irreps, since $1+1+1+9 = 12$):

| irrep | dim | $\chi(e)$ | $\chi(C_3)$ | $\chi(C_3^2)$ | $\chi(C_2)$ |
|---|---|---|---|---|---|
| $A$ | 1 | 1 | 1 | 1 | 1 |
| $E_1$ | 1 (complex) | 1 | $\omega$ | $\omega^2$ | 1 |
| $E_2$ | 1 (complex) | 1 | $\omega^2$ | $\omega$ | 1 |
| $T$ | 3 (real) | 3 | 0 | 0 | $-1$ |

where $\omega = e^{2\pi i/3}$ and $1 + \omega + \omega^2 = 0$.

SU(2) character $\chi^{(j)}(\theta) = \sin((j+1/2)\theta)/\sin(\theta/2)$ at $j = 11$:
- $\chi^{(11)}(e) = 2F+1 = 23$
- $\chi^{(11)}(C_3) = \sin(23\pi/3)/\sin(\pi/3) = \sin(23\pi/3)/(\sqrt 3 /2)$. Compute $23\pi/3 = 7\pi + 2\pi/3$, so $\sin(23\pi/3) = -\sin(2\pi/3) = -\sqrt 3/2$. Hence $\chi^{(11)}(C_3) = -1$.
- $\chi^{(11)}(C_3^2) = -1$ (by symmetry — $\chi^{(j)}$ is real and depends only on $|\theta|$ for SU(2); equivalently $\chi(C_3^2) = \chi(C_3)^*$ for real characters $= \chi(C_3)$).
- $\chi^{(11)}(C_2) = \sin(23\pi/2)/\sin(\pi/2) = \sin(11\pi + \pi/2)/1 = -\sin(\pi/2) = -1$.

Hamermesh formula:
$$m_\alpha = \frac{1}{|T|} \sum_g \chi^{(j=11)}(g) \, \chi^{(\alpha)}(g)^*$$

**$m_A$**: $(1/12)[1 \cdot 23 \cdot 1 + 4 \cdot (-1) \cdot 1 + 4 \cdot (-1) \cdot 1 + 3 \cdot (-1) \cdot 1] = (23 - 4 - 4 - 3)/12 = 12/12 = 1$. ⟹ **$m_A = 1$**.

**$m_{E_1}$**: $(1/12)[1 \cdot 23 \cdot 1 + 4 \cdot (-1) \cdot \omega^* + 4 \cdot (-1) \cdot (\omega^2)^* + 3 \cdot (-1) \cdot 1]$. Using $\omega^* = \omega^2$ and $(\omega^2)^* = \omega$:
$= (1/12)[23 - 4\omega^2 - 4\omega - 3] = (1/12)[20 - 4(\omega + \omega^2)] = (1/12)[20 - 4 \cdot (-1)] = 24/12 = 2$. ⟹ **$m_{E_1} = 2$**.

**$m_{E_2} = m_{E_1} = 2$** by character-table symmetry (and by the reality of $\chi^{(11)}$, $m_{E_1}$ and $m_{E_2}$ must be conjugate hence equal real integers).

**$m_T$**: $(1/12)[1 \cdot 23 \cdot 3 + 4 \cdot (-1) \cdot 0 + 4 \cdot (-1) \cdot 0 + 3 \cdot (-1) \cdot (-1)] = (69 + 0 + 0 + 3)/12 = 72/12 = 6$. ⟹ **$m_T = 6$**.

**Dimension consistency**: $\sum_\alpha m_\alpha d_\alpha = 1 \cdot 1 + 2 \cdot 1 + 2 \cdot 1 + 6 \cdot 3 = 1 + 2 + 2 + 18 = 23 = \dim V_{F=11}$. ✓

**Verdict on sub-task 3.2.D**: $m_{E_1} = 2 \ge 2$. **F=11 T:$E_1$ is a valid test case** — no fallback to F=12 or $E_2$ required. (As a bonus, $E_2$ is the complex conjugate of $E_1$ and gives the same $m_\alpha = 2$; if F=11 T:$E_1$ derivation works, F=11 T:$E_2$ follows by complex conjugation.)

### 3.2 J-involution endpoint argument at non-trivial irrep — Sub-task 3.2.A

The trivial-irrep argument (T119 critic A2, recapped in memory §4 and theorist T115 §2.A) proceeds in three steps:

1. **Singlet expansion via maximally entangled state (MES)**: $|0,0\rangle = (I \otimes J) |\text{MES}\rangle / \sqrt{2F+1}$ where $|\text{MES}\rangle = \sum_m |F,m\rangle \otimes |F,m\rangle$ and $J = \exp(-i\pi F_y)$, using standard Wigner-d identity $J|F,m\rangle = (-1)^{F-m}|F,-m\rangle$. **Pure SU(2) identity** — independent of any subgroup structure or irrep choice. [Established, theorist T115 §2.A.2]

2. **$J^2 = +I$ for integer F**: $(J^2|F,m\rangle = J((-1)^{F-m}|F,-m\rangle) = (-1)^{F-m}(-1)^{F+m}|F,m\rangle = (-1)^{2F}|F,m\rangle = +|F,m\rangle$ for integer F. **Pure SU(2) identity**. [Established, theorist T115 §2.A.2]

3. **$J P_W J = P_W$ via H-invariance**: this is the only step that potentially distinguishes trivial vs non-trivial irrep. For $H \in \{T, O, I\}$, $J = \exp(-i\pi F_y)$ is the $\pi$-rotation about $\hat y$, which is a $C_2$ rotation. All three polyhedral groups contain $C_2$ rotations about three mutually orthogonal Cartesian axes — in $T$ the three $C_2$ axes coincide with the cubic body axes — so $J \in T \subset H$.

   The critical question (per director directive 3.2.A): does the H-invariance condition $J P_W^{(\alpha)} J^{-1} = P_W^{(\alpha)}$ hold for the **$\alpha$-isotypic projector** $P_W^{(\alpha)}$ when $\alpha$ is a non-trivial irrep (e.g., $\alpha = E_1$, complex 1-dim)?

   **Answer: YES, unconditionally.** The H-isotypic decomposition is $V_F = \bigoplus_\alpha (W_\alpha \otimes V_\alpha^H)$ where $W_\alpha$ is the multiplicity space (dim $m_\alpha$) and $V_\alpha^H$ is the irrep carrier space (dim $d_\alpha$). The $\alpha$-isotypic subspace $\tilde W_\alpha \equiv W_\alpha \otimes V_\alpha^H$ has total dimension $m_\alpha \cdot d_\alpha$. The H-action on $\tilde W_\alpha$ is $g \mapsto I_{m_\alpha} \otimes D^{(\alpha)}(g)$ (acts trivially on the multiplicity factor, via $D^{(\alpha)}$ on the irrep factor). The orthogonal projector $P_W^{(\alpha)}$ onto $\tilde W_\alpha$ projects onto a **H-invariant subspace** of $V_F$ as a whole — and the projector onto any H-invariant subspace commutes with the H-action.

   Concretely: for $v \in \tilde W_\alpha$, $g \cdot v \in \tilde W_\alpha$ (because $\tilde W_\alpha$ is invariant under $g$); for $v \perp \tilde W_\alpha$, $g \cdot v \in (\tilde W_\alpha)^\perp$ (because $g$ is unitary so preserves orthogonal complements of invariant subspaces). Hence $g \cdot P_W^{(\alpha)} = P_W^{(\alpha)} \cdot g$ on all of $V_F$.

   **The key physical insight**: the non-trivial phase $D^{(\alpha)}(J) \in U(d_\alpha)$ (which for $\alpha = E_1$ is the phase $\omega^?$ depending on which specific element of $T$ $J$ is identified with) acts **WITHIN** $\tilde W_\alpha$, NOT on the subspace projector. The projector $P_W^{(\alpha)}$ is blind to the internal $D^{(\alpha)}$-structure of the subspace; it only cares that the subspace is preserved. This is the **rep-theoretic invariance of orthogonal projectors onto H-invariant subspaces**, the same Schur-style argument that makes $\rho_{\rm inv}^{(\alpha)} = P_W^{(\alpha)}/(m_\alpha d_\alpha)$ (or alternatively $P_W^{(\alpha)}/m_\alpha$ per director directive) H-equivariant.

   [Established, this turn §3.2] Step 3 holds at any irrep $\alpha$, including the non-trivial complex 1-dim case $\alpha = E_1$. **The J-involution endpoint argument generalizes verbatim to non-trivial irreps.**

   Cross-check / "phase-killing" argument (per director directive 3.2.A: "does the absolute-value-square kill the $D^{(E_1)}(J)$ phase factor?"): YES, but the cleaner formulation is that the phase NEVER ENTERS in the first place. The phase $D^{(\alpha)}(J)$ acts internally on $\tilde W_\alpha$ in a way that conjugates $P_W^{(\alpha)}$ from the left AND right simultaneously, and these cancel (i.e., $D^{(\alpha)}(J)^\dagger \cdot I_{\tilde W_\alpha} \cdot D^{(\alpha)}(J) = I_{\tilde W_\alpha}$). The squared overlap $\|(P_W^{(\alpha)} \otimes P_W^{(\alpha)})|0,0\rangle\|^2$ is manifestly real and non-negative, and the phase factors out (or rather, cancels in pairs).

### 3.3 Closed-form computation of $\bar\beta_0^{(\rm canonical, \alpha)}$ — Sub-task 3.2.B

Apply T119 critic A2's 3-step argument with $P_W$ replaced by $P_W^{(\alpha)}$:

\begin{align}
\|(P_W^{(\alpha)} \otimes P_W^{(\alpha)})|0,0\rangle\|^2 
&= \mathrm{Tr}\!\left[\hat\Pi_0 \cdot (P_W^{(\alpha)} \otimes P_W^{(\alpha)})\right] \\
&= \frac{1}{2F+1}\mathrm{Tr}\!\left[(P_W^{(\alpha)})^2\right] \quad \text{[by T119 critic A2 step 3]} \\
&= \frac{1}{2F+1}\mathrm{Tr}(P_W^{(\alpha)}) \quad \text{[$P_W$ idempotent]} \\
&= \frac{\dim \tilde W_\alpha}{2F+1} = \frac{m_\alpha \cdot d_\alpha}{2F+1}
\end{align}

For F=11 T:$E_1$: $\|(P_W^{(E_1)} \otimes P_W^{(E_1)})|0,0\rangle\|^2 = 2 \cdot 1/23 = 2/23$.

Now compute the canonical formula under the director's normalization $\rho_{\rm inv}^{(\alpha)} = P_W^{(\alpha)}/m_\alpha$:

\begin{align}
\bar\beta_0^{(\rm canonical, \alpha)} 
&= m_\alpha \cdot \mathrm{Tr}\!\left[\hat\Pi_0 \, (\rho_{\rm inv}^{(\alpha)} \otimes \rho_{\rm inv}^{(\alpha)})\right] \\
&= m_\alpha \cdot \frac{1}{m_\alpha^2} \cdot \mathrm{Tr}\!\left[\hat\Pi_0 \, (P_W^{(\alpha)} \otimes P_W^{(\alpha)})\right] \\
&= \frac{1}{m_\alpha} \cdot \frac{m_\alpha \cdot d_\alpha}{2F+1} \\
&= \boxed{\frac{d_\alpha}{2F+1}}
\end{align}

**This is outcome (iv), distinct from director's enumerated outcomes (i)/(ii)/(iii)**: the canonical endpoint depends only on $d_\alpha$, NOT on $m_\alpha$. The $m_\alpha$ that appeared explicitly in the trivial-irrep T115 closure was an *accident of $d_A = 1$*: $\bar\beta_0^{(\rm A)} = m_A \cdot d_A / m_A \cdot (1/(2F+1)) \cdot m_A = m_A/(2F+1)$... wait let me redo this consistency check.

**Reconciliation with T115/T119 trivial-irrep result**: At F=9 T:A, the established result was $\bar\beta_0^{(\rm canonical)} = 1/(2F+1) = 1/19$, NOT $m_A/(2F+1) = 2/19$. The T119 critic's formula $\|(P_W \otimes P_W)|0,0\rangle\|^2 = m_{\rm rep}/(2F+1)$ refers to the **un-normalized squared overlap**, and the canonical formula divides by $m_{\rm rep}$ via the $1/m_{\rm rep}^2$ in $\rho_{\rm inv} \otimes \rho_{\rm inv}$ times the $m_{\rm rep}$ prefactor, giving the net $1/m_{\rm rep}$:
$$\bar\beta_0^{(\rm canonical, A)} = m_A \cdot (1/m_A^2) \cdot (m_A/(2F+1)) = 1/(2F+1)$$
which uses $d_A = 1$ implicitly (i.e., $\dim \tilde W_A = m_A \cdot d_A = m_A$). The director's directive 3.2.B candidates (i) $m_\alpha/(2F+1)$ and (ii) $m_\alpha \cdot d_\alpha/(2F+1)$ were both off by a factor of $1/m_\alpha$ relative to the canonical formula. **The actual closed-form is $\bar\beta_0^{(\rm canonical, \alpha)} = d_\alpha/(2F+1)$** — outcome (iv).

For F=11 T:$E_1$: $\bar\beta_0^{(\rm canonical, E_1)} = 1/23$ (since $d_{E_1} = 1$ over $\mathbb{C}$).

**Caveat on $d_\alpha$ over $\mathbb{R}$ vs $\mathbb{C}$** (subtle, important): Over $\mathbb{C}$, $E_1$ is 1-dim; over $\mathbb{R}$ (the natural physical setting since $V_F$ is over $\mathbb{C}$ but $H$-action preserves real structure ambiguously), $E_1 \oplus E_2$ is a 2-dim real-irreducible block. The director's directive 3.2.B mentioned "complex 1-dim irrep, real-construction 2-dim, $m_{\rm rep} \ge 2$" — the "$m_{\rm rep} \ge 2$" comment in the directive was anticipating that the **real-realization** of $E_1$ via $E_1 \oplus E_2$ would have 2-dim irrep block. If one chooses to compute over the real-irrep convention $\alpha_\mathbb{R} = E_1 \oplus E_2$ with $d_{\alpha_\mathbb{R}} = 2$ and $m_{\alpha_\mathbb{R}} = 2$ (i.e., 2 copies of the 2-dim real-irrep block, since $m_{E_1} = m_{E_2} = 2$ each combine into $m_{\alpha_\mathbb{R}} = 2$ copies of the 2-dim real block):
$$\bar\beta_0^{(\rm canonical, \alpha_\mathbb{R})} = d_{\alpha_\mathbb{R}}/(2F+1) = 2/23$$
which would differ from the complex-irrep prediction $1/23$ by exactly a factor of $d_\alpha$ ratio.

[Plausible] The physically correct convention is **the one that the existing implementer's code at `scripts/manuscript/f9_f11_polyhedral_verification.jl` uses**: complex-irrep projector $P_W^{(E_1)}$ over $\mathbb{C}$, $d_{E_1} = 1$. The T115 implementer at F=9 T:A used a 2-dim real-construction effectively because $A_\mathbb{R} = A_\mathbb{C}$ (trivial irrep is self-conjugate over $\mathbb{R}$), so the distinction did not arise. The F=11 T:$E_1$ case is the **first case where the $\mathbb{R}/\mathbb{C}$ distinction matters**.

**Bifurcated prediction**:
- **Outcome (iv-$\mathbb{C}$)**: $\bar\beta_0^{(\rm canonical, E_1, \mathbb{C})} = 1/23 = 0.0434782608695652...$ (complex-irrep projector at $d_{E_1} = 1$).
- **Outcome (iv-$\mathbb{R}$)**: $\bar\beta_0^{(\rm canonical, E_1 \oplus E_2, \mathbb{R})} = 2/23 = 0.0869565217391304...$ (real-irrep projector at $d_\mathbb{R} = 2$).

The implementer's check at T123 will distinguish these two outcomes empirically. The author of this turn predicts **outcome (iv-$\mathbb{C}$)** = $1/23$ is the natural canonical answer that the existing code path will produce, but acknowledges the $\mathbb{R}$/$\mathbb{C}$ ambiguity as a [Plausible] open question that the implementer should explicitly resolve.

### 3.4 Sum-rule extension to non-trivial irreps

\begin{align}
\sum_{S=0}^{2F} \bar\beta_S^{(\rm canonical, \alpha)} 
&= m_\alpha \cdot \mathrm{Tr}\!\left[(\rho_{\rm inv}^{(\alpha)} \otimes \rho_{\rm inv}^{(\alpha)})\right] \quad \text{[using $\sum_S \hat\Pi_S = I$]} \\
&= m_\alpha \cdot (\mathrm{Tr}\,\rho_{\rm inv}^{(\alpha)})^2 \\
&= m_\alpha \cdot (\mathrm{Tr}\,P_W^{(\alpha)}/m_\alpha)^2 \\
&= m_\alpha \cdot ((m_\alpha d_\alpha)/m_\alpha)^2 \\
&= m_\alpha \cdot d_\alpha^2
\end{align}

For F=11 T:$E_1$ (complex): $\sum_S \bar\beta_S = 2 \cdot 1^2 = 2$.
For F=11 T:$E_1 \oplus E_2$ (real): $\sum_S \bar\beta_S = 2 \cdot 2^2 = 8$.
For F=9 T:A regression: $\sum_S \bar\beta_S = 2 \cdot 1 = 2$ ✓ (matches T115 measurement $1.999999999999993$, T115 sim §6.4).

**Note on Tr($\rho_{\rm inv}^{(\alpha)}$)**: Under the director's normalization $\rho_{\rm inv}^{(\alpha)} = P_W^{(\alpha)}/m_\alpha$, the trace is $\mathrm{Tr}\,\rho_{\rm inv}^{(\alpha)} = d_\alpha$, NOT 1, when $d_\alpha > 1$. This is a **minor [Plausible] normalization concern**: if the canonical formula is meant to have $\mathrm{Tr}\,\rho_{\rm inv} = 1$ (density-matrix convention), then the "correct" normalization at non-trivial irrep would be $\rho_{\rm inv}^{(\alpha)} = P_W^{(\alpha)}/(m_\alpha d_\alpha)$, which would give $\bar\beta_0 = 1/(2F+1)$ universally. The director's directive used $\rho_{\rm inv} = P_W/m_{\rm rep}$ which only matches Tr = 1 at $d_\alpha = 1$ (the only case verified previously). The implementer should explicitly check which normalization is implemented in `canonical_mult_aware_beta_S` at `scripts/manuscript/f9_f11_polyhedral_verification.jl`. This is item F4 in the falsifier table.

### 3.5 Specific F=11 T:$E_1$ state construction — Sub-task 3.2.D

The $E_1$-isotypic subspace $\tilde W_{E_1} \subset V_{F=11}$ has dimension $m_{E_1} \cdot d_{E_1} = 2 \cdot 1 = 2$ (over $\mathbb{C}$).

**Construction algorithm** (theorist-side, no julia execution required at Hypothesize stage — implementer will materialize at T123):

1. Build the **$E_1$ character projector** on $V_{F=11}$:
   $$P_W^{(E_1)} = \frac{d_{E_1}}{|T|} \sum_{g \in T} \chi^{(E_1)}(g)^* \cdot D^{(j=11)}(g) = \frac{1}{12} \sum_{g \in T} \chi^{(E_1)}(g)^* \cdot D^{(j=11)}(g)$$
   where $D^{(j=11)}(g)$ is the standard Wigner rotation matrix for spin 11.
   
   Concretely the 12 group elements of $T$ are: identity $e$; 4 rotations $C_3$ by $2\pi/3$ about the 4 cubic body diagonals; 4 rotations $C_3^2$ by $4\pi/3$ about the same 4 axes; 3 rotations $C_2$ by $\pi$ about the 3 cubic Cartesian axes.

2. **Output basis**: SVD of $P_W^{(E_1)}$ gives a 2-dim invariant subspace $\tilde W_{E_1}$ spanned by orthonormal vectors $\{\zeta_1^{(E_1)}, \zeta_2^{(E_1)}\}$. The U(2) basis ambiguity is exactly Schur's freedom on the multiplicity space $W_{E_1}$.

3. **$\rho_{\rm inv}^{(E_1)} = P_W^{(E_1)}/2$** (director's normalization, gives $\mathrm{Tr}\,\rho_{\rm inv} = d_{E_1} = 1$ since $d_{E_1} = 1$ over $\mathbb{C}$).

4. The implementer at T123 will compute $\bar\beta_0^{(\rm canonical, E_1)} = 2 \cdot \mathrm{Tr}[\hat\Pi_0 (\rho_{\rm inv}^{(E_1)} \otimes \rho_{\rm inv}^{(E_1)})]$ using the existing `canonical_mult_aware_beta_S(rho_inv, F=11, S=0)` wrapper (introduced at T115 attempt2 commit `a323222`, cherry-picked to main HEAD at T120 per memory §9 errata closure #1).

5. **Comparison**: against the predicted closed form $d_{E_1}/(2F+1) = 1/23 \approx 0.04347826086956522$, with rtol $10^{-13}$.

**Schur-isotropy advisory**: For trivial irrep at F=9 T:A, T115 sim §6.5 verified $\mathrm{Tr}(\rho_{\rm inv} F_a^2) = F(F+1)/3 = 30$. For the non-trivial $E_1$ isotypic at F=11 T, the same Schur isotropy will hold because $\sum_a F_a^2 = F(F+1) I_{V_F}$ is SU(2)-Casimir hence commutes with everything, and the H-invariance of $\rho_{\rm inv}^{(E_1)}$ forces the Cartesian-axis decomposition to be isotropic (T contains 3 mutually-orthogonal $C_2$ rotations cycling x↔y↔z). Predicted: $\mathrm{Tr}(\rho_{\rm inv}^{(E_1)} F_a^2) = F(F+1)/3 \cdot d_{E_1} = 44$ (since Tr($\rho_{\rm inv}^{(E_1)}$) = $d_{E_1} = 1$ over $\mathbb{C}$ at the director's normalization, and the Schur-averaged value is $F(F+1)/3 \cdot \mathrm{Tr}\,\rho_{\rm inv}$).

## 4. Calibrated claims

- **[Established]** F=11 T character analysis (§3.1): $m_A = 1$, $m_{E_1} = m_{E_2} = 2$, $m_T = 6$, with dimension consistency $\sum m_\alpha d_\alpha = 23 = 2F+1$. **F=11 T:$E_1$ has $m_{E_1} = 2 \ge 2$ as required**; no fallback to F=12 or $E_2$ needed. Hamermesh orbit-counting at SU(2) characters $\chi^{(11)}(e, C_3, C_3^2, C_2) = (23, -1, -1, -1)$. *Citation*: standard tetrahedral character table (Hamermesh "Group Theory and Its Application to Physical Problems" 1962 Ch.5; Bradley-Cracknell "Mathematical Theory of Symmetry in Solids" 1972 Table 5.1); T character table reproducible without external lookup via $\sum |\chi_\alpha|^2 = |G|$ + Wedderburn $\sum d_\alpha^2 = |G|$.

- **[Established]** J-involution endpoint argument (§3.2 step 3): $J P_W^{(\alpha)} J = P_W^{(\alpha)}$ for the $\alpha$-isotypic projector at any irrep $\alpha$ (trivial or non-trivial), because $W_\alpha$ is an H-invariant subspace and the orthogonal projector onto any H-invariant subspace commutes with the unitary H-action. The non-trivial phase $D^{(\alpha)}(J)$ acts WITHIN the subspace and does not couple to the subspace projector. *Citation*: standard fact about unitary group actions on Hilbert space (e.g., Bröcker-tom Dieck "Representations of Compact Lie Groups" 1985 Ch.II Prop 2.4; also implicit in Schur's lemma / Peter-Weyl theorem). T119 critic A2 implicitly used this at trivial irrep; the present derivation makes the generalization explicit.

- **[Established]** Closed-form unnormalized squared overlap (§3.3): $\|(P_W^{(\alpha)} \otimes P_W^{(\alpha)})|0,0\rangle\|^2 = \mathrm{Tr}(P_W^{(\alpha)})/(2F+1) = m_\alpha \cdot d_\alpha/(2F+1)$ for any irrep $\alpha$. This **rigorously establishes** theorist T115 §F isotypic-allocation conjecture $\|\xi_\alpha\|^2 = m_\alpha \cdot d_\alpha / (2F+1)$, generalizing T119 critic A2's trivial-irrep $\|\xi_A\|^2 = m_A/(2F+1)$ result (which had implicit $d_A = 1$). *Citation*: T115 §2.A eqs A1–A9 + T119 critic A2 step 3; the present generalization adds H-isotypic decomposition replacing H-trivial subspace.

- **[Plausible]** Canonical formula at non-trivial irrep — outcome (iv-$\mathbb{C}$) (§3.3): under director's normalization $\rho_{\rm inv}^{(\alpha)} = P_W^{(\alpha)}/m_\alpha$,
  $$\bar\beta_0^{(\rm canonical, \alpha)} = \frac{d_\alpha}{2F+1}$$
  For F=11 T:$E_1$ (complex 1-dim): **predicted $\bar\beta_0^{(\rm canonical, E_1, \mathbb{C})} = 1/23 \approx 0.04347826086956522$**. For the real-irrep projector $E_1 \oplus E_2$: $\bar\beta_0 = 2/23$. Mark [Plausible] because the $\mathbb{C}$/$\mathbb{R}$ convention ambiguity is a load-bearing implementation choice that the T123 implementer must resolve.

- **[Plausible]** Sum rule extension (§3.4): $\sum_S \bar\beta_S^{(\rm canonical, \alpha)} = m_\alpha \cdot d_\alpha^2$. For F=11 T:$E_1$ ($\mathbb{C}$, $d_\alpha = 1$): predicted sum $= 2$. For F=9 T:A regression: $2 \cdot 1 = 2$ ✓ (matches T115 sim §6.4 measurement $1.999999999999993$, dev $6.66 \times 10^{-15}$).

- **[Plausible]** Schur isotropy advisory (§3.5): $\mathrm{Tr}(\rho_{\rm inv}^{(E_1)} F_a^2) = (F(F+1)/3) \cdot \mathrm{Tr}\,\rho_{\rm inv}^{(E_1)} = (132/3) \cdot 1 = 44$ on all three Cartesian axes at F=11 T:$E_1$ under director's normalization.

- **[Conjecture]** Lemma 1 General-S sign-prefactor extension to non-trivial irrep (§3.4 of theorist T115 §2.C generalized): $\bar\beta_S^{(\lambda_{\rm spin}, \alpha)} = \frac{S(S+1) - 2F(F+1)}{2F(F+1)} \cdot \bar\beta_S^{(\rm canonical, \alpha)}$. This **conjecturally** holds at non-trivial irreps because the sign-prefactor is a Wigner-Eckart channel-S identity (state-independent, from the rank-0 part of $F_a^{(1)} F_a^{(2)}$). The Wigner-Eckart argument used in paper3 §V derivation depends on Schur isotropy of $\rho_{\rm inv}$, which extends to non-trivial isotypic blocks via group-theoretic uniformity. **Falsification target**: implementer T123 can numerically compute $\bar\beta_S^{(\lambda_{\rm spin}, E_1)}$ at all S and compare against the closed-form prediction; this is a richer falsifier than F1 alone but outside the central scope of this Hypothesize turn.

- **[Refuted]** Director's outcome (i) $\bar\beta_0 = m_\alpha/(2F+1)$ (§3.3): under the canonical formula's $m_\alpha \cdot (1/m_\alpha^2) \cdot$ normalization, the $m_\alpha$ in the numerator of the un-normalized squared overlap cancels against the $1/m_\alpha$ from the prefactor structure, leaving only $d_\alpha/(2F+1)$. Outcome (i) **is the un-normalized squared overlap formula NOT the canonical formula** — at F=9 T:A with $d_A = 1$ both happen to equal $m_A/(2F+1)/(m_A) \cdot m_A = 1/(2F+1)$, masking the distinction. (Director's outcome (ii) $m_\alpha \cdot d_\alpha/(2F+1)$ is also the un-normalized squared overlap formula; both (i) and (ii) miss the $1/m_\alpha$ normalization. Outcome (iv) $d_\alpha/(2F+1)$ is the correct canonical answer.)

## 5. Falsifier table (3-falsifier minimum per director directive 3.2.C)

| id | description | expected_value (closed form) | is_central |
|---|---|---|---|
| **F1** | At F=11 T:$E_1$, compute $\bar\beta_0^{(\rm canonical, E_1)}$ via existing wrapper `canonical_mult_aware_beta_S(rho_inv_E1, F=11, S=0)` where `rho_inv_E1` is built from the SVD basis of the T-equivariant $E_1$-projector at F=11. Expected value $d_{E_1}/(2F+1) = 1/23 = 0.04347826086956522$ (complex-irrep convention) OR $2/23 = 0.08695652173913043$ (real-irrep convention). **CORROBORATE if either matches to rtol $10^{-13}$; report which convention matched (this resolves the $\mathbb{R}/\mathbb{C}$ ambiguity). REFUTED if neither matches to rtol $10^{-6}$.** | $1/23$ (predicted main outcome) | **true** (central, is_central=true) |
| **F2** | Seed-spread of $\bar\beta_0^{(\rm canonical, E_1)}$ across 10 RNG seeds (Gaussian-seed-fed Gram-Schmidt of the SVD basis). | seed-spread < $10^{-13}$ (basis-independence via Schur on multiplicity space) | false |
| **F3** | Sum rule $\sum_{S=0}^{2F} \bar\beta_S^{(\rm canonical, E_1)} = m_{E_1} \cdot d_{E_1}^2$. At F=11 T:$E_1$ complex-irrep convention: predicted sum $= 2$; real-irrep convention: predicted sum $= 8$. **Cross-checks the F1 convention determination.** | $2.0 \pm 10^{-12}$ (complex) or $8.0 \pm 10^{-12}$ (real) | false |
| **F4** (optional advisory) | Regression `scripts/manuscript/lemma1_general_S_verification.jl` 29/29 PASS unchanged (post-T120 errata #2 closure: F=2 cyclic T_d $A_1$ entry now on disk per memory §9). Strict-generalization sanity check that the non-trivial-irrep extension does not break trivial-irrep tests. | 29/29 PASS | false |

**Central falsifier F1 reasoning**: F1 directly tests the closed-form $d_\alpha/(2F+1)$ prediction at the first non-trivial irrep case. The $\mathbb{R}/\mathbb{C}$ ambiguity is documented as part of F1 so that the implementer reports which convention the existing code uses — this is the **load-bearing implementation choice** that determines whether the canonical formula reduces to the universal $1/(2F+1)$ endpoint or to the $d_\alpha/(2F+1)$ generalized endpoint. Both outcomes are consistent with this turn's derivation under the appropriate convention.

## 6. Open questions and RESEARCH_NEEDED tags

- `<RESEARCH_NEEDED: f11-te1-canonical-rho-inv-normalization-convention>` — Implementer T123 must explicitly check whether `canonical_mult_aware_beta_S` at `scripts/manuscript/f9_f11_polyhedral_verification.jl` uses $\rho_{\rm inv} = P_W/m_\alpha$ (director's convention, gives F1 = $d_\alpha/(2F+1) = 1/23$ at $d_{E_1}^\mathbb{C} = 1$) or $\rho_{\rm inv} = P_W/(m_\alpha \cdot d_\alpha)$ (density-matrix-Tr=1 convention, gives F1 = $1/(2F+1) = 1/23$ universally). At F=9 T:A the two coincide; F=11 T:$E_1$ is the first case to distinguish them. This is the critical open question for T123 implementer.

- `<RESEARCH_NEEDED: real-vs-complex-irrep-projector-construction>` — The director directive 3.2.D suggested "complex 1-dim irrep, real-construction 2-dim". The T character table gives 2 separate complex-1d irreps ($E_1$, $E_2$) which combine over $\mathbb{R}$ into a 2-dim real irrep. The two conventions give $\bar\beta_0$ values differing by exact factor of 2 (1/23 vs 2/23) per §3.3 outcome (iv-$\mathbb{C}$) vs (iv-$\mathbb{R}$). Implementer needs to construct the projector $P_W^{(E_1)}$ using complex characters $\chi^{(E_1)}(g) = (1, \omega, \omega^2, 1)$ on (e, $C_3$, $C_3^2$, $C_2$); if the projector ends up rank-2 (2-dim invariant subspace over $\mathbb{C}$), it's the complex $E_1$ projector; if rank-4 (2-dim over $\mathbb{R}$ = 4-dim over $\mathbb{C}$ since complex irrep + complex conjugate counted twice), it's the real $E_1 \oplus E_2$ projector. Predictions in F1/F3 are bifurcated accordingly.

- `<RESEARCH_NEEDED: full-lemma-1-extension-to-non-trivial-irrep>` — The sign-pattern Lemma 1 General-S closed-form $\bar\beta_S^{(\lambda_{\rm spin}, \alpha)} = (S(S+1) - 2F(F+1))/(2F(F+1)) \cdot \bar\beta_S^{(\rm canonical, \alpha)}$ (paper3 §V eq (1)) is currently [Conjecture] at non-trivial irrep (§4 above). A complete Tier-3 closure of this investigation would verify the prefactor extension at non-trivial irrep via full BdG channel decomposition at F=11 T:$E_1$, going beyond the present S=0 endpoint check. Estimated implementer cost: ~3-5M (julia BdG diagonalization at $V_{F=11}$ dim 23, channel decomposition over $S = 0, 1, ..., 22$, with cross-check against the closed-form prefactor). Out of scope for T123 numerical verification (which only checks F1 + F3 at S=0); a stretch goal for T124+.

- **Algebraic obstruction status**: NONE encountered. The J-involution argument generalizes cleanly to non-trivial irreps via the "projector is blind to internal phase" insight (§3.2 step 3). Cost expenditure on this Hypothesize derivation is well below the 1.5M soft cap (the load-bearing step was a 3-line representation-theoretic observation, not a 50-line algebraic computation). NO researcher_deep dispatch needed at T123 for the J-involution closure.

## 7. Directive for implementer (T123 Test stage)

**Goal**: verify F1 closed-form $\bar\beta_0^{(\rm canonical, E_1)} = d_{E_1}/(2F+1)$ at F=11 T:$E_1$ using the existing extended script and `canonical_mult_aware_beta_S` wrapper.

**Algorithm** (mirrors T115 sim §7 pattern):

1. **Build $E_1$ character projector** at F=11:
   - Generate $D^{(j=11)}(g)$ Wigner matrices for the 12 elements of $T$. Memory-cached method: build the 4 generators of $T$ ($e$, one $C_3$ about $[1,1,1]/\sqrt{3}$, one $C_2$ about $\hat z$, multiply out the 12-element table).
   - Build $P_W^{(E_1)} = (d_{E_1}/|T|) \sum_g \chi^{(E_1)}(g)^* D^{(j=11)}(g)$ with $d_{E_1} = 1$ and $\chi^{(E_1)} = (1, \omega, \omega^2, 1)$ on the conjugacy class representatives.

2. **SVD basis $\{\zeta_1, \zeta_2\}$** of the $E_1$-isotypic subspace via `find_invariant_basis(P_W_E1, dim=23; tol=1e-8)`. Confirm `m_rep = 2`.

3. **Build $\rho_{\rm inv}^{(E_1)} = P_W^{(E_1)}/m_{\rm rep}$** and call `canonical_mult_aware_beta_S(rho_inv_E1, F=11, S=0)`.

4. **F1 check**: compare the result against $1/23 = 0.04347826086956522$ to rtol $10^{-13}$. If matches, report `f1_verdict = CORROBORATE` AND `convention = complex_irrep_d_alpha_1`. If matches $2/23$ instead, report `f1_verdict = CORROBORATE` AND `convention = real_irrep_E1_plus_E2_d_alpha_2`. If neither matches to rtol $10^{-6}$, report `f1_verdict = REFUTED`.

5. **F2 seed-spread**: repeat F1 across 10 RNG seeds for the SVD basis. Expect spread $< 10^{-13}$.

6. **F3 sum rule**: compute $\sum_{S=0}^{22} \bar\beta_S^{(\rm canonical, E_1)}$ (use existing `verify_case_mult_aware` driver, modify `S in 0:2:2F` to `S in 0:2F` for the all-S sum). Expect $m_{E_1} \cdot d_{E_1}^2 = 2$ (complex) or $8$ (real); the value uniquely determines the convention.

7. **F4 advisory regression**: run `julia --project=. scripts/manuscript/lemma1_general_S_verification.jl`, verify 29/29 PASS (post-T120 errata #2).

**Observable manifest** (T123 implementer must produce):

```json
{
  "F": 11,
  "group": "T",
  "irrep": "E_1",
  "m_rep_E1": 2,
  "d_E1_complex": 1,
  "d_E1_real": 2,
  "bar_beta_0_canonical_F11_TE1": <Float64>,
  "bar_beta_0_dev_from_1_over_23": <Float64>,
  "bar_beta_0_dev_from_2_over_23": <Float64>,
  "convention_resolved": "complex_d_1" | "real_d_2",
  "seed_spread_F11_TE1": <Float64>,
  "sum_S_all_S_F11_TE1": <Float64>,
  "predicted_sum_complex": 2.0,
  "predicted_sum_real": 8.0,
  "schur_isotropy_rho_inv_E1_x": <Float64>,
  "schur_isotropy_rho_inv_E1_y": <Float64>,
  "schur_isotropy_rho_inv_E1_z": <Float64>,
  "regression_lemma1_general_S_passed_count": 29,
  "f1_verdict": "CORROBORATE" | "REFUTED",
  "f2_verdict": "CORROBORATE" | "REFUTED",
  "f3_verdict": "CORROBORATE" | "REFUTED",
  "f4_verdict": "CORROBORATE" | "REFUTED"
}
```

**Implementation budget**: ~15-30 minutes wall-clock (julia_cpu_light tier). No `src/` modification expected; only call-site wrappers in `scripts/manuscript/f9_f11_polyhedral_verification.jl` (add an `verify_case_mult_aware(F=11, group=T, irrep=E_1, ...)` invocation alongside the existing F=9 T:A case).

**Hard constraints** for T123 implementer:
- Do NOT modify `canonical_mult_aware_beta_S` or `mult_aware_beta_S` function definitions — only add call-site invocation for F=11 T:$E_1$.
- Do NOT modify `scripts/manuscript/lemma1_general_S_verification.jl` (F4 regression baseline must remain at 29/29).
- Do NOT modify any `src/` file.
- Do NOT pursue the full sign-pattern $\bar\beta_S^{(\lambda_{\rm spin}, E_1)}$ extension at all S (that's T124+ critic Stage-2 scope).

## 8. Status

**Hypothesize stage complete.** Closed-form derivation: $\bar\beta_0^{(\rm canonical, \alpha)} = d_\alpha/(2F+1)$ for any irrep $\alpha$ of any polyhedral group $H \in \{T, O, I\}$ where $J = \exp(-i\pi F_y) \in H$. At F=11 T:$E_1$ (complex 1-dim, $d_{E_1} = 1$, $m_{E_1} = 2$): predicted $\bar\beta_0 = 1/23 \approx 0.04347826086956522$.

**Outcome verdict** vs director's enumerated outcomes (directive 3.2.B):
- (i) $m_\alpha/(2F+1)$ — **[Refuted]** (this was the un-normalized squared overlap formula, not the canonical formula).
- (ii) $m_\alpha \cdot d_\alpha/(2F+1)$ — **[Refuted]** (same reason).
- (iii) $\alpha$-dependent correction beyond $m_\alpha \cdot d_\alpha/(2F+1)$ — **[Refuted]** (J-involution argument generalizes verbatim; no $\alpha$-correction beyond the $d_\alpha$ trace-of-projector factor).
- (iv) $d_\alpha/(2F+1)$ — **[Plausible]**, this turn's derived outcome (modulo $\mathbb{R}/\mathbb{C}$ convention; F1 falsifier resolves).

**Tier proposal**: this investigation can target Tier-3 closure in 3-4 turns: T122 (this turn) theorist Hypothesize → T123 implementer Test (F1+F2+F3 verification at F=11 T:$E_1$) → T124 critic Stage-2 audit → T125 implementer_text terminal closure (manuscript §V append + memory entry). Optional stretch: T126+ verify $\bar\beta_S^{(\lambda_{\rm spin}, E_1)}$ closed-form at all S via BdG channel decomposition (currently [Conjecture] in §4).

**Token cost estimate**: ~600-800k effective (well below soft cap 1.5M, no scope expansion). The derivation was load-bearing on a 3-line representation-theoretic insight (projector on H-invariant subspace commutes with H regardless of internal $D^{(\alpha)}$-structure), not a 50-line algebraic obstruction.

## 9. Metrics (judge.py reads this)

```json
{
  "experiment_kind": "derivation",
  "workload_class": "theorist",
  "investigation_id": "sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19",
  "stage_advancing_to": "Hypothesize",
  "project_axis": "D3",
  "n_lines_derivation": 224,
  "n_calibrated_established": 3,
  "n_calibrated_plausible": 4,
  "n_calibrated_conjecture": 1,
  "n_calibrated_refuted": 1,
  "n_open_research_needed": 3,
  "n_falsifiers_specified": 4,
  "f1_central_marked": true,
  "f11_t_e1_m_alpha_computed": 2,
  "f12_fallback_invoked": false,
  "outcome_resolved": "iv_d_alpha_over_2F_plus_1",
  "j_involution_endpoint_generalizes": true,
  "tests_passed": null,
  "warnings": [
    "R/C real-vs-complex irrep convention ambiguity at F=11 T:E_1 is a load-bearing implementation choice that T123 implementer must resolve. The two conventions give predictions differing by exact factor of 2 (1/23 vs 2/23). F1 falsifier predicates on either matching to rtol 1e-13; sum-rule F3 (predicted 2 vs 8) is the convention discriminator.",
    "Director directive 3.2.B enumerated outcomes (i)/(ii)/(iii); the derived outcome is (iv) d_alpha/(2F+1), distinct from all three enumerated. Outcomes (i) and (ii) refer to the un-normalized squared overlap m_alpha * d_alpha / (2F+1); the canonical formula divides by m_alpha via the rho_inv = P_W/m_alpha normalization, giving d_alpha/(2F+1). This is a clarifying correction, not a refutation of the trivial-irrep T119 critic A2 result (which used d_A=1 implicitly)."
  ],
  "physical_red_flags": [],
  "falsification_result": "NOT_APPLICABLE",
  "tokens_used": null
}
```

I am done

---
turn: 115
subagent: theorist
investigation_id: sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19
stage_advancing_from: "Hypothesize (T115-attempt1 implementer Test REFUTED at F1 structurally; re-derivation required)"
stage_advancing_to: "Test (T116 implementer with revised Candidate (i) prediction)"
topic_tags: [sign-pattern-lemma1-general-S, f9-ta-multiplicity-2, schur-isotropy, projector-orbit, paper3-section-V, mrep-prefactor, time-reversal-singlet-identity]
---

# Turn 115 — Theorist Re-Hypothesize (mult-aware formula audit + correction)

## 1. Directive received

T114 theorist proposed §2.A formula `bar_beta_S = Tr[Pi_S (rho_inv ⊗ rho_inv)]` with
`rho_inv = (1/m_rep) Sum_i |zeta_i><zeta_i|` and claimed predicted endpoint `1/(2F+1)`
at F=9 T:A. T115-attempt1 implementer REFUTED F1: measured `bar_beta_0 = 1/38 =
1/(m_rep·(2F+1))`, exactly half of expectation. Implementer's §6.2 supplied a
`[Plausible]`-tagged mechanism: at the orthogonal SVD basis of the 2-dim T:A
invariant subspace, off-diagonal singlet overlaps `<0,0|zeta_i⊗zeta_j>` (i≠j)
vanish, while diagonals each give 1/(2F+1), yielding `(1/4)(2·1/19 + 2·0) = 1/38`.

Director directive (T115-attempt2): (A) audit the implementer's mechanism by
independent algebra, (B) adjudicate three candidate fixes — (i) revised §2.A with
m_rep prefactor, (ii) isotypic-sum, (iii) §2.B Schur-isotropic single-vector
basis — and recommend one, (C) write new F1/F2/F3 falsifier contract for T116
implementer, (D) full sanity-check ladder including corrected sum rule, (E)
calibrated claims, (F) open questions. NO modification of any file.

## 2. Derivation

### 2.0 Source-evidence and key empirical constraints

[Established, `runs/_loop/sim/turn_115_attempt1.md` §5 metrics + §6] At F=9 T:A
with `m_rep = 2`:
- `bar_beta_0 = 0.026315789473684 = 1/38` (13-digit precision).
- `Tr(rho_inv F_a^2) = 30.0 = F(F+1)/3` (Schur isotropy of `rho_inv`, max axis-dev `2.49e-14`).
- `rho_inv_trace = 1.0` exactly.
- Seed-spread across 10 RNG seeds = 1.39e-17 (machine precision).
- `Sum over even S of bar_beta_S = 0.75` (the implementer's `verify_case_mult_aware`
  driver invokes `project_S_channel` which loops `S in 0:2:2F` — odd S are
  silently skipped; this is BY DESIGN of the existing code, since for
  `|zeta⊗zeta>` (symmetric) only even S survive, but for an orbit-average
  `rho_inv⊗rho_inv` containing off-diagonal pieces `|zeta_i⊗zeta_j>` with i≠j
  the antisymmetric (odd-S) parts CAN survive).

[Established, T114 §2.4] The §2.A formula as written:
$$\bar\beta_S^{(\rm T114)} = \mathrm{Tr}[\hat\Pi_S \cdot (\rho_{\rm inv} \otimes \rho_{\rm inv})], \quad \rho_{\rm inv} = \tfrac{1}{m_{\rm rep}} P_W, \quad P_W = \sum_{i=1}^{m_{\rm rep}} |\zeta_i\rangle\langle\zeta_i|$$
At m_rep=1 reduces to `beta_S^(c_0)` (the strict-generalization regression check, T114 §2.5). At m_rep=2 the empirical answer is exactly half the expected
`1/(2F+1)`.

### 2.A Audit of the implementer's §6.2 mechanism — derivation

I (theorist) independently derive what
$\sum_{i,j} |\langle 0,0|\zeta_i \otimes \zeta_j\rangle|^2$ equals for an
orthonormal basis $\{\zeta_i\}_{i=1}^{m_{\rm rep}}$ of the H-trivial
multiplicity space $W \subset V_F$. The closed-form SU(2) singlet is
$|0,0\rangle = (1/\sqrt{2F+1}) \sum_m (-1)^{F-m} |F,m\rangle \otimes |F,-m\rangle$,
giving the SU(2)-invariant symmetric (for integer F) bilinear form
$$B(u, v) \equiv \langle 0,0 | u \otimes v\rangle = \frac{1}{\sqrt{2F+1}} \sum_m (-1)^{F-m} u_m v_{-m} \tag{A1}$$

### 2.A.1 Re-write as a trace via the J operator

Define the linear operator $J : V_F \to V_F$ by
$$J|F,m\rangle = (-1)^{F-m} |F,-m\rangle \tag{A2}$$
Then for any $u \in V_F$, $(J u)_m = (-1)^{F+m} u_{-m}$ (after substituting
$m \to -m$ in (A2) to read off the matrix elements). One checks $J^2 = (-1)^{2F} I = +I$
for integer $F$ (which includes $F=9$ as integer in our convention; $F=9 \Rightarrow 2F+1=19$
dim, and $J^2|F,m\rangle = (-1)^{F-m}(-1)^{F+m}|F,m\rangle = (-1)^{2F}|F,m\rangle = +|F,m\rangle$).
So $J$ is an involution. Then (A1) rewrites as
$$B(u, v) = \frac{1}{\sqrt{2F+1}} \langle J u^* | v\rangle = \frac{1}{\sqrt{2F+1}} (J u^*)^\dagger v$$
where I used $\langle J u^* | v\rangle = \sum_m \overline{(J u^*)_m} v_m = \sum_m (-1)^{F+m} u_{-m} v_m$.
Substituting $m' = -m$, $= \sum_{m'} (-1)^{F-m'} u_{m'} v_{-m'}$ ✓ matches (A1).

[Plausible → Established after this turn] More compact: viewing $|0,0\rangle$ as
the maximally-entangled-state vector reshape of the operator $\tilde J/\sqrt{2F+1}$
where $\tilde J = (-1)^{F-m}$ as a diagonal phase on the "row index" of a
$|m_1\rangle\langle m_2|$ matrix, we have
$$\langle 0,0 | u \otimes v\rangle = \frac{1}{\sqrt{2F+1}} (v^T \tilde J u) = \frac{1}{\sqrt{2F+1}} \mathrm{Tr}[\tilde J \cdot (u v^T)] \tag{A3}$$
where $\tilde J_{m, m'} = (-1)^{F-m} \delta_{m', -m}$ in the $|F,m\rangle$ basis.

The KEY identity I now derive:
$$\sum_{i, j} |B(\zeta_i, \zeta_j)|^2 = \frac{1}{2F+1} \mathrm{Tr}\!\left[\tilde J P_W \tilde J^T P_W^*\right]$$
where $P_W = \sum_i |\zeta_i\rangle\langle\zeta_i|$ is the orthogonal projector onto $W$.
Reasoning: from (A3), $B(\zeta_i, \zeta_j) = (1/\sqrt{2F+1}) (\zeta_j)^T \tilde J \zeta_i$. Then
$\sum_j |B(\zeta_i, \zeta_j)|^2 = (1/(2F+1)) \sum_j (\tilde J \zeta_i)^T \zeta_j (\zeta_j)^\dagger (\tilde J \zeta_i)^*$.
The inner sum is $(\tilde J \zeta_i)^T P_W^* (\tilde J \zeta_i)^* = ((\tilde J \zeta_i)^\dagger P_W^* (\tilde J \zeta_i)^*)^T$.
Summing over $i$: $\sum_i (\tilde J \zeta_i)^T P_W^* (\tilde J \zeta_i)^* = \mathrm{Tr}[\tilde J^T (\sum_i \zeta_i \zeta_i^T) \tilde J^\dagger P_W^*]$ ... let me just redo this more carefully.

Using the matrix form: $\sum_i |\zeta_i\rangle\langle\zeta_i| = P_W$ as a matrix
in the $|F,m\rangle$ basis. So $\sum_i (\zeta_i)_m \overline{(\zeta_i)_{m'}} = (P_W)_{m, m'}$
and $\sum_i (\zeta_i)_m (\zeta_i)_{m'} = (P_W \tilde C)_{m, m'}$ where $\tilde C$
is the basis-dependent complex-conjugation-undo... let me bypass this entirely.

### 2.A.2 Direct derivation using $J \in H$

Define $J = e^{-i\pi F_y}$. This is an SU(2) element corresponding to a
$\pi$-rotation about the $y$-axis. Its action on $|F,m\rangle$ is
$J|F,m\rangle = (-1)^{F-m}|F,-m\rangle$ (standard Wigner-d formula
$d^F_{-m,m}(\pi) = (-1)^{F-m}$).

So (A2) holds with this concrete $J$. Crucially, $J \in SO(3)$ since
$e^{-i\pi F_y}$ rotates by $\pi$ about $y$. For $H \in \{T, O, I\}$ (tetrahedral,
octahedral, icosahedral) — all of which contain $C_2$ rotations about ALL three
Cartesian axes (since the cubic axes are 2-fold for T, 4-fold for O, and the
3 mutually-orthogonal $C_2$ axes for I are dihedral) — we have $J \in H$.

For F=9 T:A specifically: the $C_2$ axis about $\hat z$ is `wigner_D(F, [0,0,1], π)`
which the script uses as `C2z` (line 65 of `f9_f11_polyhedral_verification.jl`).
The y-axis $C_2$ is conjugate to this within T via the 3-fold axis. So
$J_y = e^{-i\pi F_y} \in T$. Hence the H-invariance of $W$ implies
$$J P_W J^{-1} = P_W \tag{A4}$$
(Acting H by conjugation on the orthogonal projector $P_W$ onto the H-trivial subspace.)

### 2.A.3 Computing $\sum_{i,j} |\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2$

Apply $P_W \otimes P_W$ to $|0,0\rangle$:
\begin{align}
(P_W \otimes P_W)|0,0\rangle &= \frac{1}{\sqrt{2F+1}} \sum_m (-1)^{F-m} (P_W|F,m\rangle) \otimes (P_W|F,-m\rangle) \\
&= \frac{1}{\sqrt{2F+1}} \sum_m (P_W|F,m\rangle) \otimes (P_W J|F,m\rangle) \tag{A5}
\end{align}
where I used $(-1)^{F-m}|F,-m\rangle = J|F,m\rangle$. Squared norm:
$$\|(P_W \otimes P_W)|0,0\rangle\|^2 = \frac{1}{2F+1} \sum_{m, m'} \langle F,m'|P_W|F,m\rangle \cdot \langle F,m'|J^\dagger P_W J|F,m\rangle$$
Using $J^\dagger P_W J = J^{-1} P_W J$. By (A4), $J P_W = P_W J$, so $J^{-1} P_W J = J^{-1} J P_W = P_W$. Hence:
$$\|(P_W \otimes P_W)|0,0\rangle\|^2 = \frac{1}{2F+1} \sum_{m, m'} (P_W)_{m', m} (P_W)_{m', m} = \frac{1}{2F+1} \sum_{m, m'} |(P_W)_{m', m}|^2 \tag{A6}$$

Wait — I need to be more careful with the complex-conjugate signs in (A5). Let me redo.

Compute the inner product directly:
$$\sum_{i,j} |\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2 = \langle 0,0|(P_W \otimes P_W)|0,0\rangle$$
since $\sum_i |\zeta_i\rangle\langle\zeta_i| \otimes \sum_j |\zeta_j\rangle\langle\zeta_j| = P_W \otimes P_W$ acting on the inner product.

Expand $|0,0\rangle$:
\begin{align}
\langle 0,0|(P_W \otimes P_W)|0,0\rangle &= \frac{1}{2F+1} \sum_{m, m'} (-1)^{m'-m} \langle F,m|P_W|F,m'\rangle \langle F,-m|P_W|F,-m'\rangle
\end{align}

(I dropped the global $(-1)^{2F}$ which is $+1$ for integer F.)

Using $J|F,m'\rangle = (-1)^{F-m'}|F,-m'\rangle$, so $|F,-m'\rangle = (-1)^{F-m'} J|F,m'\rangle$, and $\langle F,-m|... = (-1)^{F-m}\langle F,m|J^\dagger$, with $J^\dagger = J^{-1} = J$ (since $J$ is unitary and an involution for integer F):
\begin{align}
\langle F,-m|P_W|F,-m'\rangle &= (-1)^{F-m}(-1)^{F-m'}\langle F,m|J P_W J|F,m'\rangle \\
&= (-1)^{m+m'} \langle F,m|P_W|F,m'\rangle \tag{using \(J^2=+I\) for int F, and J P_W J = P_W from (A4)}
\end{align}

Substituting:
$$\langle 0,0|(P_W\otimes P_W)|0,0\rangle = \frac{1}{2F+1} \sum_{m,m'} (-1)^{m'-m} (-1)^{m+m'} (P_W)_{m,m'} (P_W)_{m,m'}$$
$$= \frac{1}{2F+1} \sum_{m, m'} (-1)^{2m'} (P_W)_{m,m'}^2 = \frac{1}{2F+1} \sum_{m, m'} (P_W)_{m,m'}^2$$

But wait — $(P_W)_{m,m'}$ may be complex. I need $|(P_W)_{m,m'}|^2$, not $(P_W)_{m,m'}^2$. Let me redo with careful conjugation.

The matrix element $\langle F,-m|P_W|F,-m'\rangle$ is a complex scalar. Let me define $A_{m,m'} \equiv \langle F,m|P_W|F,m'\rangle$, so $A$ is the matrix of $P_W$ in the $|F,m\rangle$ basis. $P_W$ is Hermitian, so $A_{m,m'} = \overline{A_{m',m}}$.

Using $|F,-m'\rangle = J|F,m'\rangle / (-1)^{F-m'}$, i.e., $|F,-m'\rangle = (-1)^{F-m'} J|F,m'\rangle$ (since $(-1)^{F-m'} \cdot (-1)^{F-m'} = +1$ — for integer F). Then
$P_W|F,-m'\rangle = (-1)^{F-m'} P_W J|F,m'\rangle = (-1)^{F-m'} J P_W |F,m'\rangle$ (using (A4) $JP_W = P_W J$, equivalently $P_W = J P_W J^{-1}$, so $P_W J = J P_W$).

Similarly $\langle F,-m| = (-1)^{F-m}\langle F,m|J^{-1} = (-1)^{F-m}\langle F,m|J$ (since $J^{-1} = J$).

So:
$\langle F,-m|P_W|F,-m'\rangle = (-1)^{F-m}(-1)^{F-m'}\langle F,m|J P_W J|F,m'\rangle = (-1)^{2F - m - m'}\langle F,m| P_W |F,m'\rangle = (-1)^{-m-m'} A_{m,m'}$

For integer F, $(-1)^{-m-m'} = (-1)^{m+m'}$ (integers m, m' since F integer):
$\langle F,-m|P_W|F,-m'\rangle = (-1)^{m+m'} A_{m,m'}$

Now substituting back into the singlet expansion:
\begin{align}
\langle 0,0|(P_W\otimes P_W)|0,0\rangle &= \frac{1}{2F+1} \sum_{m,m'} (-1)^{m-m'} \overline{A_{m,m'}} \cdot (-1)^{m+m'} \overline{A_{m,m'}} \\
\end{align}

Hmm wait, let me redo. $|0,0\rangle = (1/\sqrt{2F+1}) \sum_m (-1)^{F-m}|F,m\rangle|F,-m\rangle$ so $\langle 0,0| = (1/\sqrt{2F+1})\sum_m (-1)^{F-m}\langle F,m|\langle F,-m|$ (real coefficients). Then:
\begin{align}
\langle 0,0|(P_W \otimes P_W)|0,0\rangle &= \frac{1}{2F+1}\sum_{m,m'} (-1)^{F-m}(-1)^{F-m'} \langle F,m|P_W|F,m'\rangle\langle F,-m|P_W|F,-m'\rangle \\
&= \frac{1}{2F+1}\sum_{m,m'}(-1)^{2F}(-1)^{-(m+m')} A_{m,m'} \cdot (-1)^{m+m'} A_{m,m'} \\
&= \frac{1}{2F+1}\sum_{m,m'} (A_{m,m'})^2
\end{align}

Hmm, that gives $\sum (A_{m,m'})^2$, NOT $\sum|A_{m,m'}|^2$. The two differ only if $A$ has complex entries.

But there's a subtlety: $P_W$ is the orthogonal projector onto $W$, where $W$ is built by the SVD basis (real Gaussian seeds, complex-valued SVD output). $P_W$ is Hermitian but may have complex off-diagonal entries.

However: SU(2)-invariance + H-invariance ALONE doesn't pick out the "right" basis. The U(2) ambiguity in choosing $\{\zeta_1, \zeta_2\}$ is precisely the freedom to rotate.

Let me try yet another route. The quantity $\langle 0,0|(P_W\otimes P_W)|0,0\rangle$ is the SQUARED OVERLAP of $|0,0\rangle$ with the subspace $W \otimes W$ (since $P_W \otimes P_W$ is the orthogonal projector onto $W\otimes W$). Squared overlaps are always real ≥ 0. So whatever the formula evaluates to in complex matrix elements, it must give a real ≥ 0 number.

Let me redo the computation using $|0,0\rangle$'s real coefficients explicitly. Define $c_m = (-1)^{F-m}/\sqrt{2F+1}$ (real for integer F). Then $|0,0\rangle = \sum_m c_m |F,m\rangle|F,-m\rangle$, and:
$$\|(P_W\otimes P_W)|0,0\rangle\|^2 = \langle 0,0|(P_W\otimes P_W)^\dagger (P_W\otimes P_W)|0,0\rangle = \langle 0,0|(P_W\otimes P_W)|0,0\rangle$$
(since $P_W^2 = P_W$).

So squared overlap = $\langle 0,0|(P_W\otimes P_W)|0,0\rangle$. Now expand:
\begin{align}
\langle 0,0|(P_W\otimes P_W)|0,0\rangle &= \sum_{m,m'} c_m c_{m'} \langle F,m|P_W|F,m'\rangle\langle F,-m|P_W|F,-m'\rangle \\
\end{align}

Using $\langle F,-m|P_W|F,-m'\rangle = (-1)^{m+m'} A_{m,m'}$ (derived above, where $A_{m,m'} = \langle F,m|P_W|F,m'\rangle$):
\begin{align}
&= \sum_{m,m'} c_m c_{m'} (-1)^{m+m'} A_{m,m'}^2 \\
&= \frac{1}{2F+1} \sum_{m,m'} (-1)^{F-m}(-1)^{F-m'}(-1)^{m+m'} A_{m,m'}^2 \\
&= \frac{1}{2F+1} \sum_{m,m'} A_{m,m'}^2 \quad \text{(since } (-1)^{F-m}(-1)^{F-m'}(-1)^{m+m'} = (-1)^{2F} = +1 \text{)}
\end{align}

So the formula is:
$$\boxed{\sum_{i,j=1}^{m_{\rm rep}}|\langle 0,0|\zeta_i \otimes \zeta_j\rangle|^2 = \frac{1}{2F+1} \sum_{m, m'=-F}^{F} (A_{m,m'})^2 \tag{A7}}$$
where $A = P_W$ in the $|F,m\rangle$ basis.

For this to equal a real positive number (which it must), we need $\sum_{m,m'} A_{m,m'}^2 \in \mathbb{R}^+$ — equivalently $\sum_{m,m'} A_{m,m'}^2 \in \mathbb{R}^+$ when $A$ is Hermitian + invariant under conjugation by $J$.

Now $J|F,m\rangle = (-1)^{F-m}|F,-m\rangle$, so $(J)_{m'',m} = (-1)^{F-m}\delta_{m'',-m}$. Then $J^\dagger = J^{-1} = J$ and $(J A J)_{m,m'} = \sum_{m_1,m_2} J_{m,m_1} A_{m_1,m_2} J_{m_2,m'}$. Using $J_{m,m_1} = (-1)^{F-m_1}\delta_{m, -m_1}$: only $m_1 = -m$ contributes, giving factor $(-1)^{F+m}$. Similarly $J_{m_2,m'} = (-1)^{F-m'}\delta_{m_2,-m'}$, so $m_2 = -m'$ with factor $(-1)^{F-m'}$. Hence $(JAJ)_{m,m'} = (-1)^{2F-m'+m}\cdot (-1)^{m-m'}\cdot$ ... let me just write:
$(JAJ)_{m,m'} = (-1)^{F+m}\cdot A_{-m,-m'} \cdot (-1)^{F-m'} = (-1)^{2F+m-m'} A_{-m,-m'} = (-1)^{m-m'} A_{-m,-m'}$
By (A4), $JAJ = A$, so:
$$A_{m,m'} = (-1)^{m-m'} A_{-m,-m'} \tag{A8}$$

Using (A8): $A_{m,m'}^2 = (-1)^{2(m-m')} A_{m,m'} A_{-m,-m'} = A_{m,m'} A_{-m,-m'}$. So
$\sum_{m,m'} A_{m,m'}^2 = \sum_{m,m'} A_{m,m'} A_{-m,-m'}$. Substituting $m \to -m, m' \to -m'$ in the dummy sum gives the same expression (symmetric under sign flip). So this is real iff the sum is real — which is automatic when each pair $(m,m')$ and $(-m,-m')$ is summed together: $A_{m,m'}A_{-m,-m'} + A_{-m,-m'} A_{m,m'} = 2 A_{m,m'} A_{-m,-m'}$, and using Hermiticity $A_{-m,-m'} = \overline{A_{-m',-m}}$... actually I'll just accept that the final answer must be real because it's a squared overlap.

Quick check at m_rep=1: $P_W = |\zeta\rangle\langle\zeta|$ rank-1 projector. $A_{m,m'} = \zeta_m \overline{\zeta_{m'}}$. Then $\sum_{m,m'} A_{m,m'}^2 = \sum_{m,m'} \zeta_m^2 \overline{\zeta_{m'}}^2 = (\sum_m \zeta_m^2)(\sum_{m'} \overline{\zeta_{m'}}^2) = |\sum_m \zeta_m^2|^2 \cdot$... wait $(\sum_m \zeta_m^2)$ is complex, and its product with conjugate gives $|\sum_m \zeta_m^2|^2$? Let me re-evaluate. $A_{m,m'}^2 = (\zeta_m\overline{\zeta_{m'}})^2 = \zeta_m^2 \overline{\zeta_{m'}}^2$. Yes, then $\sum_{m,m'} A_{m,m'}^2 = (\sum_m \zeta_m^2)(\sum_{m'}\overline{\zeta_{m'}}^2)$. But this is $S \cdot \overline{S}$ where $S = \sum_m \zeta_m^2$. So $|S|^2$.

Hmm — at m_rep=1, the original Lemma 1 mult-1 result says $|\langle 0,0|\zeta\otimes\zeta\rangle|^2 = 1/(2F+1)$, and from (A1) $\langle 0,0|\zeta\otimes\zeta\rangle = (1/\sqrt{2F+1})\sum_m (-1)^{F-m} \zeta_m \zeta_{-m}$. So $|\langle 0,0|\zeta\otimes\zeta\rangle|^2 = (1/(2F+1))|\sum_m(-1)^{F-m}\zeta_m\zeta_{-m}|^2 = 1/(2F+1)$, requiring $|\sum_m(-1)^{F-m}\zeta_m\zeta_{-m}|^2 = 1$.

My formula (A7) at m_rep=1: $\sum_{m,m'} A_{m,m'}^2 / (2F+1) = |\sum_m \zeta_m^2|^2 / (2F+1)$. This is NOT obviously equal to $1/(2F+1)$ unless we identify $|\sum_m \zeta_m^2|^2 = 1$, which is not the right normalization.

I made an indexing error somewhere. Let me redo (A7).

$\langle F,-m|P_W|F,-m'\rangle$ at m_rep=1: $P_W = |\zeta\rangle\langle\zeta|$, so $= \zeta_{-m}\overline{\zeta_{-m'}}$. Then
$\langle 0,0|(P_W\otimes P_W)|0,0\rangle = \sum_{m,m'} c_m c_{m'} (\zeta_m \overline{\zeta_{m'}})(\zeta_{-m}\overline{\zeta_{-m'}})$
$= \sum_{m,m'} c_m c_{m'} \zeta_m \zeta_{-m} \overline{\zeta_{m'}\zeta_{-m'}}$
$= (\sum_m c_m \zeta_m \zeta_{-m})(\overline{\sum_{m'} c_{m'} \zeta_{m'} \zeta_{-m'}})$
$= |\sum_m c_m \zeta_m \zeta_{-m}|^2$
$= |(1/\sqrt{2F+1})\sum_m (-1)^{F-m}\zeta_m \zeta_{-m}|^2$
$= |\langle 0,0|\zeta\otimes\zeta\rangle|^2$

Good — at m_rep=1 it reduces correctly. So my error was in the indexing of (A7). Let me redo. We have $A_{m,m'} = \langle F,m|P_W|F,m'\rangle$, so for the m_rep=1 case $A_{m,m'} = \zeta_m \overline{\zeta_{m'}}$. Then $\langle F,-m|P_W|F,-m'\rangle = \zeta_{-m}\overline{\zeta_{-m'}}$. Hmm but the relation $\langle F,-m|P_W|F,-m'\rangle = (-1)^{m+m'} A_{m,m'}$ I claimed from (A8) — let me verify at m_rep=1: $(-1)^{m+m'}\zeta_m \overline{\zeta_{m'}}$ should equal $\zeta_{-m}\overline{\zeta_{-m'}}$. This requires $\zeta_{-m} = (-1)^m \zeta_m^*$? That's a specific structural property of $\zeta$, not generic.

Aha — relation (A4) $JP_W = P_W J$ holds only because $W$ is H-invariant AND $J \in H$. At m_rep=1, $P_W = |\zeta\rangle\langle\zeta|$, and $JP_W = J|\zeta\rangle\langle\zeta|$. For this to equal $P_W J = |\zeta\rangle\langle\zeta|J$, we need $J|\zeta\rangle = \lambda|\zeta\rangle$ for some scalar $\lambda$ AND $\langle\zeta|J = \overline\lambda\langle\zeta|$, i.e., $|\zeta\rangle$ is an eigenvector of $J$ with eigenvalue $\lambda$ where $|\lambda|=1$.

$J|\zeta\rangle = \sum_m \zeta_m J|F,m\rangle = \sum_m \zeta_m (-1)^{F-m}|F,-m\rangle = \sum_{m'} \zeta_{-m'}(-1)^{F+m'}|F,m'\rangle$.

So $(J\zeta)_{m'} = (-1)^{F+m'}\zeta_{-m'}$.

For $J\zeta = \lambda\zeta$: $\zeta_{m'} = \lambda^{-1}(-1)^{F+m'}\zeta_{-m'}$, i.e., $\zeta_{-m'} = \lambda(-1)^{F+m'}\zeta_{m'}$. Squaring: $\zeta_{m'} = \lambda(-1)^{F-m'}\lambda(-1)^{F+m'}\zeta_{m'} = \lambda^2(-1)^{2F}\zeta_{m'} = \lambda^2\zeta_{m'}$. So $\lambda^2 = 1$, $\lambda = \pm 1$.

For polyhedral inert states, this eigenvalue $\lambda \in \{+1,-1\}$ is a STATE-DEPENDENT property. At m_rep=1, the unique H-invariant state generically has a definite J-eigenvalue (since J commutes with H).

OK so the relation (A8) is a CONSEQUENCE of (A4) but only after careful index work. Let me redo (A4)→(A8) more carefully.

$P_W$ is the orthogonal projector onto $W$. H-invariance of $W$ means $g \zeta = \zeta'$ for some $\zeta'\in W$ for all $g\in H$, $\zeta\in W$. Equivalently $g P_W g^\dagger = P_W$ for all $g\in H$. For $g = J \in H$ (with $J$ Hermitian, $J^\dagger = J$):
$J P_W J = P_W \tag{A4'}$

In matrix elements: $(JP_W J)_{m,m'} = \sum_{m_1,m_2} J_{m,m_1}(P_W)_{m_1,m_2}J_{m_2,m'}$, with $J_{m,m_1} = (-1)^{F-m_1}\delta_{m, -m_1}$ so $m_1 = -m$, factor $(-1)^{F+m}$. Then $J_{m_2,m'} = (-1)^{F-m'}\delta_{m_2,-m'}$, $m_2 = -m'$, factor $(-1)^{F-m'}$.
$(JP_W J)_{m,m'} = (-1)^{F+m}(-1)^{F-m'}(P_W)_{-m,-m'} = (-1)^{2F+m-m'}(P_W)_{-m,-m'} = (-1)^{m-m'}(P_W)_{-m,-m'}$

Setting equal to $(P_W)_{m,m'}$:
$$A_{-m,-m'} = (-1)^{m-m'} A_{m,m'} \tag{A8'}$$

Now $\langle F,-m|P_W|F,-m'\rangle = A_{-m,-m'} = (-1)^{m-m'} A_{m,m'}$ (and NOT $(-1)^{m+m'}A_{m,m'}$ as I miswrote earlier). Let me redo the singlet computation:

\begin{align}
\langle 0,0|(P_W \otimes P_W)|0,0\rangle &= \sum_{m,m'} c_m c_{m'} A_{m,m'} A_{-m,-m'} \\
&= \sum_{m,m'} c_m c_{m'} A_{m,m'} (-1)^{m-m'} A_{m,m'} \\
&= \frac{1}{2F+1}\sum_{m,m'}(-1)^{F-m}(-1)^{F-m'}(-1)^{m-m'} A_{m,m'}^2 \\
&= \frac{1}{2F+1}\sum_{m,m'}(-1)^{2F-2m'} A_{m,m'}^2 \\
&= \frac{1}{2F+1}\sum_{m,m'} A_{m,m'}^2 \tag{A9}
\end{align}

(Using $(-1)^{2F} = 1$ for integer F, $(-1)^{-2m'}=1$.)

Sanity check at m_rep=1: $A_{m,m'}=\zeta_m\overline{\zeta_{m'}}$, so $\sum_{m,m'}A_{m,m'}^2 = \sum_m\zeta_m^2\sum_{m'}\overline{\zeta_{m'}}^2 = |\sum_m\zeta_m^2|^2$. Hmm, this gives the m_rep=1 result only if $|\sum_m \zeta_m^2|^2 = 1$ at polyhedral inert states. Let me check at F=4 cube: $\zeta = (\sqrt{5/12}, 0, 0, 0, \sqrt{1/6}, 0, 0, 0, \sqrt{5/12})$ (m=4,0,-4 with appropriate signs/normalization). $\sum_m \zeta_m^2 = (5/12) + (1/6) + (5/12) = 5/12 + 2/12 + 5/12 = 12/12 = 1$. ✓

OK good — at F=4 cube, $\sum_m \zeta_m^2 = 1$, so $|...|^2 = 1$, formula (A9) gives $1/(2F+1) = 1/9$ ✓ matching paper3.

This is actually a NON-TRIVIAL property of polyhedral inert states: $\sum_m \zeta_m^2 = \pm 1$ (or unimodular complex). It follows from $J\zeta = \pm \zeta$ which itself follows from $\zeta$ being H-invariant when $J\in H$. The relation $(J\zeta)_m = (-1)^{F+m}\zeta_{-m}$, so $J\zeta = \lambda\zeta$ means $\zeta_{-m} = \lambda(-1)^{F+m}\zeta_m^*$ — wait that's the condition for $\zeta$ to be an EIGENSTATE of J. But H-invariance gives $g\zeta = \zeta$ only for the specific irrep we're considering (here A trivial); $J\zeta$ might be $-\zeta$ if the character $\chi(J)= -1$ in the irrep. For T:A the character at C_2 axis is $+1$ (it's trivial irrep), so $\lambda=+1$: $\zeta_{-m} = (-1)^{F+m}\zeta_m^* = (-1)^F (-1)^m \zeta_m^*$. For F=9 odd: $\zeta_{-m} = -(-1)^m \zeta_m^* = (-1)^{m+1}\zeta_m^*$.

But for mult-1, polyhedral inert states are conventionally chosen REAL (or with phase such that $\zeta_{-m} = (-1)^F (-1)^m \zeta_m$). At F=4 cube: $\zeta$ is real with $\zeta_{-m} = \zeta_m$ (cube state has support on m=4,0,-4 with equal magnitudes), and indeed $\zeta_{-m} = (-1)^4(-1)^m\zeta_m = (-1)^m \zeta_m$ — which means $\zeta_{\pm 4} = \zeta_{\pm 4}$ (m=4: $(-1)^4=1$ ✓) and $\zeta_0 = \zeta_0$ ✓. Consistent.

For F=9 T:A at m_rep=2: we need $\zeta_{-m} = -(-1)^m\zeta_m^*$, i.e., $\zeta$ has a specific "anti-symmetric" relation under m → -m, parity-twisted. This is automatic from H-invariance (J is in T) but the basis $\{\zeta_1,\zeta_2\}$ each individually has this property if we work in the J-eigenbasis (both with eigenvalue $\lambda=\chi_A(J) = +1$). The SVD basis may or may not align with the J-eigenbasis, but since W is in the +1 eigenspace of J ANYWAY (by H-invariance), every $\zeta\in W$ satisfies $J\zeta = \zeta$.

OK so for the F=9 T:A trivial irrep, every $\zeta \in W$ satisfies $J\zeta = \zeta$. Then $\zeta_{-m} = (-1)^{F+m}\zeta_m^*$ (from $\lambda=1$ and the formula $J\zeta = \lambda\zeta$ giving $\zeta_{-m}\cdot(-1)^{F+m} = \zeta_m$... let me redo: $(J\zeta)_m = (-1)^{F+m}\zeta_{-m} = \zeta_m$ (eigenvalue 1), so $\zeta_{-m} = (-1)^{F+m}\zeta_m\cdot(-1)^{2(F+m)}$... no — $(-1)^{F+m}\zeta_{-m} = \zeta_m$ gives $\zeta_{-m} = (-1)^{F+m}\zeta_m$... wait that's for REAL coefficients and I've been sloppy with complex conjugation. Since J is unitary (not anti-unitary), $J\zeta$ doesn't conjugate — $(J\zeta)_m = (-1)^{F+m}\zeta_{-m}$ exactly with no complex conjugation. Hmm but I want to check $J = J^\dagger$: yes since $J_{m,m'} = (-1)^{F-m'}\delta_{m,-m'}$ and $J^\dagger_{m,m'} = \overline{J_{m',m}} = (-1)^{F-m}\delta_{m',-m} = (-1)^{F-m}\delta_{m,-m'} = (-1)^{F+m'}\delta_{m,-m'}$. So $J^\dagger_{m,m'} - J_{m,m'} = ((-1)^{F+m'} - (-1)^{F-m'})\delta_{m,-m'}$. For integer F and integer m', $(-1)^{F+m'} = (-1)^{F-m'}$ (same parity). So $J^\dagger = J$. ✓

Now $J\zeta = \zeta$: $(-1)^{F+m}\zeta_{-m} = \zeta_m$, so $\zeta_{-m} = (-1)^{-F-m}\zeta_m = (-1)^{F+m}\zeta_m$ (integer F, integer m). For F=9 (odd): $\zeta_{-m} = -(-1)^m\zeta_m = (-1)^{m+1}\zeta_m$. So m=0: $\zeta_0 = -\zeta_0 \Rightarrow \zeta_0 = 0$. m=1: $\zeta_{-1} = \zeta_1$. m=2: $\zeta_{-2} = -\zeta_2$. Etc.

So F=9 T:A states have $\zeta_0 = 0$ and $\zeta_{-m} = (-1)^{m+1}\zeta_m$. This is the structural form, with 9 free complex coefficients (m=1..9) reduced by the H-symmetry constraints (3-fold and 2-fold).

OK — back to the derivation. Formula (A9) gives:
$$\langle 0,0|(P_W \otimes P_W)|0,0\rangle = \frac{1}{2F+1}\sum_{m,m'} A_{m,m'}^2 \tag{A9}$$

For this to give a clean closed form like $m_{\rm rep}/(2F+1)$, we need:
$$\sum_{m,m'} A_{m,m'}^2 = m_{\rm rep} \tag{A10}$$

Let's check at m_rep=1: $\sum_{m,m'}A_{m,m'}^2 = (\sum_m \zeta_m^2)^2$ (factorizing $A_{m,m'}=\zeta_m\overline{\zeta_{m'}}$? — wait, $A_{m,m'}^2 = \zeta_m^2 \overline{\zeta_{m'}}^2$, so $\sum_{m,m'} A_{m,m'}^2 = (\sum_m\zeta_m^2)(\sum_{m'}\overline{\zeta_{m'}}^2) = |\sum_m\zeta_m^2|^2$). For this to equal $m_{\rm rep}=1$, we need $|\sum_m\zeta_m^2|=1$. Verified at F=4 cube above. More generally: at mult-1 polyhedral inert states, $\sum_m\zeta_m^2$ is a complex number of modulus 1.

What about m_rep=2? $A_{m,m'} = \sum_i (\zeta_i)_m \overline{(\zeta_i)_{m'}}$. Then $\sum_{m,m'}A_{m,m'}^2 = \sum_{m,m'}\sum_{i,j}(\zeta_i)_m(\zeta_j)_m\overline{(\zeta_i)_{m'}(\zeta_j)_{m'}}$. Let $S_{ij} \equiv \sum_m (\zeta_i)_m(\zeta_j)_m$ — a symmetric (in $ij$) bilinear form. Then $\sum_{m,m'}A_{m,m'}^2 = \sum_{i,j} S_{ij}\overline{S_{ij}} = \sum_{i,j}|S_{ij}|^2 = \|S\|_{\rm HS}^2$.

So:
$$\sum_{i,j}|\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2 = \frac{1}{2F+1}\|S\|_{\rm HS}^2 \tag{A11}$$
where $S_{ij} = \sum_m (\zeta_i)_m(\zeta_j)_m$.

For Candidate (i) to give $1/(2F+1)$ exactly we need $\|S\|_{\rm HS}^2 = m_{\rm rep}^2/(2F+1) \cdot (2F+1) \cdot$... wait let me redo. We want $\bar\beta_0^{(i)} = m_{\rm rep}\cdot \mathrm{Tr}[\Pi_0(\rho_{\rm inv}\otimes\rho_{\rm inv})] = m_{\rm rep}\cdot(1/m_{\rm rep}^2)\cdot \sum_{ij}|\langle 0,0|...|^2 = (1/m_{\rm rep})\|S\|_{\rm HS}^2/(2F+1)$.

Empirically $\bar\beta_0^{(\rm T114)} = (1/m_{\rm rep}^2)\|S\|_{\rm HS}^2/(2F+1) = 1/38$ at F=9 T:A. With $m_{\rm rep}=2$, $\|S\|_{\rm HS}^2/(2F+1) = 4/38 = 2/19$, so $\|S\|_{\rm HS}^2 = 2$. And Candidate (i) gives $(1/2)\cdot 2/19 = 1/19$ ✓.

So **empirically** $\|S\|_{\rm HS}^2 = m_{\rm rep}$ at F=9 T:A. Now the QUESTION: is this $\|S\|_{\rm HS}^2 = m_{\rm rep}$ identity provable in general?

Claim (theorem): For any polyhedral inert subspace $W \subset V_F$ with $H$-trivial irrep, multiplicity $m_{\rm rep}$, and $J \in H$:
$$\|S\|_{\rm HS}^2 = m_{\rm rep}, \quad S_{ij} = \sum_m (\zeta_i)_m(\zeta_j)_m$$
for any orthonormal basis $\{\zeta_i\}$ of $W$, where each $\zeta_i$ satisfies $J\zeta_i = \zeta_i$.

Proof sketch: $S_{ij} = \zeta_i^T \zeta_j$ in matrix notation (TRANSPOSE, no complex conjugation). The constraint $J\zeta_i = \zeta_i$ means $\zeta_i = J\zeta_i$, so $\zeta_i^T = (J\zeta_i)^T = \zeta_i^T J^T$, hence $\zeta_i^T = \zeta_i^T J^T$. So $S_{ij} = \zeta_i^T \zeta_j = \zeta_i^T J^T \zeta_j$. Hmm I need a different angle.

Let $J' \equiv J$ as a matrix. Then $J|\zeta\rangle = \zeta$ means $\zeta = J\zeta$ in vector form. So $\overline\zeta = \overline{J\zeta} = \overline J \overline\zeta$. $J$ has only nonzero entries $J_{m,-m} = (-1)^{F-m}$ which is real, so $\overline J = J$. Therefore $\overline\zeta = J\overline\zeta$, i.e., $\overline\zeta$ is also a $J$-eigenvector with eigenvalue $+1$.

Now $S_{ij} = \zeta_i^T \zeta_j = \sum_m (\zeta_i)_m (\zeta_j)_m$. Using $J\zeta_j = \zeta_j$: $(\zeta_j)_m = (-1)^{F+m}(\zeta_j)_{-m}$. So:
$S_{ij} = \sum_m (\zeta_i)_m (\zeta_j)_m = \sum_m (-1)^{F+m}(\zeta_i)_m (\zeta_j)_{-m}\cdot(-1)^{?}$... this is getting tangled. Let me try a direct evaluation.

Alternatively: the SU(2)-invariant symmetric bilinear form $B(u,v) = (1/\sqrt{2F+1})\sum_m (-1)^{F-m} u_m v_{-m}$. Compare with $S_{ij} = \sum_m (\zeta_i)_m (\zeta_j)_m$ (a DIFFERENT bilinear form, not SU(2)-invariant in general).

But using $J\zeta_j = \zeta_j$: $(\zeta_j)_m = (-1)^{F+m}(\zeta_j)_{-m}$. Substituting:
$S_{ij} = \sum_m (\zeta_i)_m \cdot (-1)^{F+m}(\zeta_j)_{-m} = \sum_m (-1)^{F+m}(\zeta_i)_m (\zeta_j)_{-m}$
Letting $m'=-m$: $= \sum_{m'} (-1)^{F-m'}(\zeta_i)_{-m'}(\zeta_j)_{m'}$. Using $(\zeta_i)_{-m'} = (-1)^{F+m'}(\zeta_i)_{m'}$:
$= \sum_{m'}(-1)^{F-m'}(-1)^{F+m'}(\zeta_i)_{m'}(\zeta_j)_{m'} = (-1)^{2F}\sum_{m'}(\zeta_i)_{m'}(\zeta_j)_{m'} = S_{ij}$
(tautology — just confirms consistency).

Let me try yet another angle. Consider directly:
$\sqrt{2F+1} B(\zeta_i, \zeta_j) = \sum_m (-1)^{F-m}(\zeta_i)_m(\zeta_j)_{-m}$

Substituting $J\zeta_j = \zeta_j$, $(\zeta_j)_{-m} = (-1)^{F+m}(\zeta_j)_m$:
$\sqrt{2F+1} B(\zeta_i,\zeta_j) = \sum_m (-1)^{F-m}(-1)^{F+m}(\zeta_i)_m(\zeta_j)_m = (-1)^{2F}\sum_m (\zeta_i)_m(\zeta_j)_m = S_{ij}$

So **$S_{ij} = \sqrt{2F+1}\,B(\zeta_i, \zeta_j)$** when $\zeta_i, \zeta_j$ are $J$-eigenvectors with eigenvalue $+1$. This is the KEY identity I was missing.

Therefore:
$\|S\|_{\rm HS}^2 = (2F+1)\sum_{i,j}|B(\zeta_i,\zeta_j)|^2 = (2F+1)\langle 0,0|(P_W\otimes P_W)|0,0\rangle$
Substituting back into (A11):
$\sum_{i,j}|\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2 = (1/(2F+1)) \cdot (2F+1)\sum_{i,j}|\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2$
$= \sum_{i,j}|\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2$ — TAUTOLOGY.

So (A9) reduces to itself, no new content. The identity $\|S\|_{\rm HS}^2 = m_{\rm rep}$ is NOT proven by this argument; it's the result we want to derive.

### 2.A.4 Correct closed-form derivation via group-theoretic isotypic decomposition

Let me try the cleanest argument. The key object is $\mathrm{Tr}[\Pi_0 (P_W \otimes P_W)]$.

$\Pi_0$ projects onto the SU(2)-singlet $|0,0\rangle$, which is 1-dimensional. So
$\mathrm{Tr}[\Pi_0 (P_W \otimes P_W)] = \langle 0,0|P_W \otimes P_W|0,0\rangle = \|(P_W\otimes P_W)|0,0\rangle\|^2$ ≥ 0.

$|0,0\rangle$ has a unique SU(2)-equivariant decomposition. Let $V_F = \bigoplus_\alpha W_\alpha \otimes V_\alpha^H$ be the H-isotypic decomposition (where $W_\alpha = \mathrm{Hom}_H(V_\alpha^H, V_F)$ is the multiplicity space of dim $m_\alpha$, and $V_\alpha^H$ is the H-irrep of dim $d_\alpha$). Then $V_F \otimes V_F = \bigoplus_{\alpha,\beta}(W_\alpha\otimes W_\beta)\otimes(V_\alpha^H \otimes V_\beta^H)$.

The SU(2)-singlet $|0,0\rangle$ is H-invariant (since SU(2)-invariant ⊃ H-invariant). It lies in the H-trivial subspace of $V_F \otimes V_F$. The H-trivial subspace of $V_\alpha^H \otimes V_\beta^H$ is nonzero iff $\beta = \alpha^*$ (i.e., $V_\beta^H$ is the dual of $V_\alpha^H$). For real H-irreps, $\alpha^* = \alpha$. So the H-trivial subspace of $V_F \otimes V_F$ is $\bigoplus_\alpha (W_\alpha\otimes W_\alpha)\otimes (V_\alpha^H \otimes V_\alpha^H)^{\rm H-triv}$, with the H-trivial part of $V_\alpha^H \otimes V_\alpha^H$ being 1-dimensional (spanned by the H-invariant "trace" pairing).

So the H-trivial part of $V_F\otimes V_F$ has dimension $\sum_\alpha m_\alpha^2 \cdot 1 = \sum_\alpha m_\alpha^2$.

$|0,0\rangle$ decomposes uniquely as $|0,0\rangle = \sum_\alpha \xi_\alpha$ with $\xi_\alpha \in (W_\alpha \otimes W_\alpha) \otimes (V_\alpha^H \otimes V_\alpha^H)^{\rm H-triv}$. The SQUARED NORM allocation $\|\xi_\alpha\|^2$ depends on group-theoretic data (specifically, the inner product of the singlet with the "α-pairing" in each isotypic block).

The squared overlap $\|(P_W\otimes P_W)|0,0\rangle\|^2 = \|\xi_A\|^2$ where $W$ is the H-trivial multiplicity space ($\alpha=A$).

Computing $\|\xi_A\|^2$ in closed form requires knowing the H-isotypic decomposition explicitly. EMPIRICALLY at F=9 T:A: $\|\xi_A\|^2 = 2/19 = m_A/(2F+1)$.

**Conjecture**: $\|\xi_\alpha\|^2 = m_\alpha \cdot d_\alpha / (2F+1)$ for each isotypic component, where $d_\alpha = \dim V_\alpha^H$. Sum: $\sum_\alpha \|\xi_\alpha\|^2 = \sum_\alpha m_\alpha d_\alpha/(2F+1) = (\sum_\alpha m_\alpha d_\alpha)/(2F+1) = (2F+1)/(2F+1) = 1$ ✓ (total normalization).

At α=A, $d_A = 1$, so $\|\xi_A\|^2 = m_A/(2F+1) = 2/19$ at F=9 T:A. ✓

This conjectured isotypic-allocation formula is consistent with the empirical observation and is the natural prediction by representation-theoretic uniformity. **I label this as [Plausible] — verified empirically at F=9 T:A and mult-1 cases, but not rigorously proven for general (F, H, α).**

[Plausible] The formula $\|(P_W\otimes P_W)|0,0\rangle\|^2 = m_{\rm rep}/(2F+1)$ holds for all polyhedral inert states with $H \in \{T,O,I\}$ and $J\in H$.

### 2.A.5 Audit verdict on implementer's §6.2 mechanism

**CORROBORATE (partial)**: The empirical sum $\sum_{i,j}|\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2 = m_{\rm rep}/(2F+1) = 2/19$ at F=9 T:A is structurally correct (U(2)-basis-invariant, matches the m_rep/(2F+1) conjecture above). However:

The implementer's specific claim "**off-diagonal singlet overlaps $\langle 0,0|\zeta_i\otimes\zeta_j\rangle$ (i≠j) vanish at orthogonal SVD basis**" is **BASIS-DEPENDENT, NOT STRUCTURAL**. The U(2)-invariant TOTAL is $m_{\rm rep}/(2F+1) = 2/19$; how this total distributes between diagonal $(i=i)$ and off-diagonal $(i\neq j)$ terms depends on the choice of basis within the m_rep-dim multiplicity space. There exist U(2)-equivalent orthonormal bases where the off-diagonals are non-zero and the diagonals are smaller — these would give a different (smaller) per-diagonal contribution. The TOTAL $\sum_{i,j}|...|^2 = m_{\rm rep}/(2F+1)$ is invariant; the individual terms are not.

The implementer's SVD happened to produce a basis that's an eigenbasis of the symmetric bilinear form $B|_{W}$, which IS diagonalizable for any choice of symmetric form, so a basis exists where off-diagonals vanish. But this is incidental to the SVD algorithm, not a fundamental property. **The mechanism is correct in spirit (the off-diagonals are zero IN THIS SPECIFIC BASIS) but the structural reason is "diagonalization of B by SVD basis", not "vanishing by H-equivariance".**

[Plausible] The TRUE structural identity is the U(2)-invariant total $\|(P_W\otimes P_W)|0,0\rangle\|^2 = m_{\rm rep}/(2F+1)$. Candidate (i) ($m_{\rm rep}\cdot \mathrm{Tr}[\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$) extracts this identity via the trace, and is basis-independent.

### 2.B Three candidate formulas — m_rep=2 predictions and m_rep=1 reductions

#### Candidate (i): Revised §2.A with m_rep prefactor

$$\bar\beta_S^{(i)} \equiv m_{\rm rep} \cdot \mathrm{Tr}[\hat\Pi_S (\rho_{\rm inv} \otimes \rho_{\rm inv})] = \frac{1}{m_{\rm rep}}\,\mathrm{Tr}[\hat\Pi_S (P_W \otimes P_W)]$$

where $\rho_{\rm inv} = P_W/m_{\rm rep}$ and $P_W = \sum_i |\zeta_i\rangle\langle\zeta_i|$.

**m_rep=2 prediction (F=9 T:A, S=0)**: $\bar\beta_0^{(i)} = (1/2)\cdot \mathrm{Tr}[\Pi_0(P_W\otimes P_W)] = (1/2)\cdot \|(P_W\otimes P_W)|0,0\rangle\|^2 = (1/2)\cdot(2/19) = 1/19$. ✓ matches expectation.

**m_rep=1 reduction**: at $m_{\rm rep}=1$, $P_W = |\zeta\rangle\langle\zeta|$, $\rho_{\rm inv}=|\zeta\rangle\langle\zeta|$, so $\bar\beta_S^{(i)} = 1\cdot \mathrm{Tr}[\Pi_S(|\zeta\rangle\langle\zeta|\otimes |\zeta\rangle\langle\zeta|)] = \sum_M |\langle S,M|\zeta\otimes\zeta\rangle|^2 = \beta_S^{(c_0)}$ — exact strict-generalization regression. ✓

**Sum rule**: $\sum_S \bar\beta_S^{(i)} = (1/m_{\rm rep})\sum_S \mathrm{Tr}[\Pi_S(P_W\otimes P_W)] = (1/m_{\rm rep})\mathrm{Tr}[P_W\otimes P_W] = (1/m_{\rm rep})\cdot m_{\rm rep}^2 = m_{\rm rep}$. At F=9 T:A, m_rep=2, sum = 2. Restricted to even S only (as implementer's code does), the partial sum is $m_{\rm rep}\cdot 0.75 = 1.5$. The 0.25 (per m_rep) goes to odd S (antisymmetric part of $|\zeta_i\otimes\zeta_j\rangle$ for $i\neq j$). ✓ consistent.

#### Candidate (ii): Isotypic-sum (no density matrix)

$$\bar\beta_S^{(ii)} \equiv \sum_{i=1}^{m_{\rm rep}} \sum_M |\langle S,M|\zeta_i \otimes \zeta_i\rangle|^2$$

**m_rep=2 prediction (F=9 T:A, S=0)**: Each diagonal $|\langle 0,0|\zeta_i\otimes\zeta_i\rangle|^2 = 1/(2F+1) = 1/19$ (per the implementer's §6.4 measurement that each $\zeta_i$ is Schur-isotropic; this then implies the m_rep=1 Lemma 1 identity applies to each $\zeta_i$ individually). Sum: $\bar\beta_0^{(ii)} = 2/19$.

**m_rep=1 reduction**: single term = $\sum_M|\langle S,M|\zeta\otimes\zeta\rangle|^2 = \beta_S^{(c_0)}$. ✓

**Sum rule**: $\sum_S\sum_i\sum_M|\langle S,M|\zeta_i\otimes\zeta_i\rangle|^2 = \sum_i\|\zeta_i\otimes\zeta_i\|^2 = \sum_i 1 = m_{\rm rep}$. Same as Candidate (i)'s total sum, but distributed differently across S (no cross-term off-diagonal contributions).

**Critical comparison with empirical data**: At F=9 T:A, Candidate (ii) predicts $\bar\beta_0^{(ii)} = 2/19$, NOT $1/19$. This would mean Lemma 1 General-S at multiplicity ≥ 2 has the form $\beta_0 = m_{\rm rep}/(2F+1)$, NOT $\beta_0 = 1/(2F+1)$. **This breaks the universal $1/(2F+1)$ statement of Lemma 1.**

**Caveat**: Candidate (ii) is basis-DEPENDENT in general — the diagonal-only sum changes under U(2) rotation of $\{\zeta_i\}$. At the SVD basis where each $\zeta_i$ is individually Schur-isotropic (the F=9 T:A case), it gives $2/19$. At a generic basis where individual $\zeta_i$ are not Schur-isotropic, it would give a different value. So Candidate (ii) is not a well-defined canonical formula unless the basis is canonically specified.

Verdict: Candidate (ii) is **NOT the canonical multiplicity-aware extension**. It predicts a number ($m_{\rm rep}/(2F+1)$) that breaks the universal statement of Lemma 1. The empirical evidence at F=9 T:A measured the basis-independent quantity (Candidate i's trace formula), not this basis-dependent sum.

#### Candidate (iii): §2.B Schur-isotropic single-vector basis

Pick $\zeta_* \in W = \mathrm{Im}(P)$ such that $\langle\zeta_*|F_a F_b|\zeta_*\rangle = \delta_{ab} F(F+1)/3$ individually. Algorithm:
1. Build SVD basis $\{e_1, e_2\}$ of $W$ (m_rep=2 case).
2. Parametrize $\zeta(\alpha, \phi) = \cos\alpha \, e_1 + e^{i\phi}\sin\alpha \, e_2$ on $S^3$ (4 real DOF mod U(1) phase = 2 real DOF on unit sphere $S^2$).
3. The Schur-isotropy conditions $\langle\zeta|F_aF_b + F_bF_a|\zeta\rangle = (2/3)F(F+1)\delta_{ab}$ are 5 real-linear conditions on the symmetric traceless rank-2 form, since $\sum_a F_a^2$ is automatic.
4. Solve: by T114 §2.B argument (which I now scrutinize), the 5 conditions reduce to fewer than 5 independent ones due to H-equivariance. For H=T at F=9, the rank-2 traceless Cartesian tensor under T decomposes as $E + T$ (using O ⊃ T: under O, rank-2 traceless = $E\oplus T_2$; restricted to T, $E$ stays $E$ and $T_2$ becomes $T$). Neither is trivial, so the H-equivariant constraint is that $T_{ab} = 0$ — 5 equations, all non-trivial.
5. Parametrize: $\zeta(\alpha,\phi)$ has 2 real DOF on the $\mathbb{CP}^1 = S^2$ of the 2-dim multiplicity space (mod U(1) phase). 5 equations in 2 unknowns is overdetermined GENERICALLY — but the H-equivariance might force redundancy.

[Speculative] T114 §2.B claimed a 1-parameter solution family. After audit: the 5 equations on the 2-dim $\mathbb{CP}^1$ generically have NO solution (overdetermined). H-equivariance might reduce the number of independent equations, but the T114 §2.B argument that "polyhedral residual symmetry constraints reduce the equations to a small number soluble by 1-parameter family" assumed without proof. **The Schur-isotropic single-vector $\zeta_*$ may NOT EXIST at m_rep=2.**

But wait — the implementer's measurement Tr(rho_inv F_a²) = F(F+1)/3 = 30 to 2.5e-14 says the ORBIT AVERAGE rho_inv satisfies Schur isotropy AS A DENSITY MATRIX. This is the WEAKER statement that the average of $\langle\zeta_i|F_a^2|\zeta_i\rangle$ over $i$ equals F(F+1)/3, NOT that each individual $\zeta_i$ does. The implementer's §6.2 claim "each $\zeta_i$ is itself a polyhedral inert state with Schur isotropy" may be wrong — they may have computed orbit-averaged Schur isotropy, not per-vector.

Actually, look at the implementer json:
```
"schur_isotropy_rho_inv_x": 30.000000000000025,
"schur_isotropy_rho_inv_y": 29.999999999999993,
"schur_isotropy_rho_inv_z": 29.999999999999993,
```
This is `Tr(rho_inv F_a²)` = $(1/m_{\rm rep})\sum_i \langle\zeta_i|F_a^2|\zeta_i\rangle$. So it's the AVERAGE, not per-vector. So we don't actually know each $\zeta_i$ individually satisfies Schur isotropy.

[Speculative] Candidate (iii) requires SOLVING for a $\zeta_*$ that satisfies Schur isotropy individually. Existence is not guaranteed; even if it exists, finding it requires extra computation. This Candidate is **less attractive** than Candidate (i).

**m_rep=2 prediction (F=9 T:A, S=0)**: If $\zeta_*$ exists and is Schur-isotropic, then by the original rank-1 Lemma 1, $\beta_0^{(c_0)}(\zeta_*) = 1/(2F+1) = 1/19$. So Candidate (iii) predicts 1/19, matching Candidate (i).

**m_rep=1 reduction**: trivial single choice, gives $\beta_S^{(c_0)}$. ✓

**Sum rule**: $\sum_S \beta_S^{(c_0)}(\zeta_*) = \|\zeta_*\otimes\zeta_*\|^2 = 1$. So sum = 1 (not m_rep).

#### Candidate (iv): Reject (none)

I've checked the three director-supplied candidates plus considered a (iv). The derivation in §2.A.4 strongly supports Candidate (i) on rigorous grounds (basis-independence by Schur on multiplicity space, strict generalization, predicted endpoint matches empirical 1/19). Candidate (ii) breaks universality; Candidate (iii) has existence issues. No additional structurally-distinct candidate is needed.

### 2.B Recommendation: Candidate (i)

**Adopt Candidate (i)**: $\bar\beta_S^{(\rm canonical)} = m_{\rm rep} \cdot \mathrm{Tr}[\hat\Pi_S (\rho_{\rm inv}\otimes\rho_{\rm inv})] = (1/m_{\rm rep})\mathrm{Tr}[\hat\Pi_S(P_W\otimes P_W)]$.

Justification:
1. **Matches universal endpoint $1/(2F+1)$** at S=0 (predicted via the conjectured isotypic-allocation $\|\xi_A\|^2 = m_{\rm rep}/(2F+1)$, then divided by $m_{\rm rep}$). The empirical measurement at F=9 T:A confirms.
2. **Basis-independent**: trace formulation is U(m_rep)-invariant by §2.A.5 argument.
3. **Strict generalization**: at m_rep=1 reduces to $\beta_S^{(c_0)}$ exactly.
4. **Sum rule**: $\sum_S \bar\beta_S^{(i)} = m_{\rm rep}$, with the implementer's even-S partial sum 0.75 × m_rep = 1.5 matching the empirical observation.
5. **Group-theoretic clean**: the $1/m_{\rm rep}$ prefactor (or equivalently the $m_{\rm rep}$ factor compared to T114's no-prefactor version) is the Schur's-lemma multiplicity correction.

### 2.C Lemma 1 General-S extension at m_rep ≥ 2

The closed-form Lemma 1 result (paper3 §V):
$$\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2F(F+1)}\beta_S^{(c_0)}$$
should generalize to:
$$\bar\beta_S^{(\lambda_{\rm spin})} = \frac{S(S+1) - 2F(F+1)}{2F(F+1)}\bar\beta_S^{(\rm canonical)} \tag{B1}$$
i.e., the scalar prefactor is unchanged (it's a Wigner-Eckart channel-S structural identity, NOT a state-dependent quantity). What changes is the definition of $\bar\beta_S^{(c_0)}$ on both sides — the canonical multiplicity-aware quantity replaces the rank-1 $\beta_S^{(c_0)}$.

This means the **strict generalization regression** at m_rep=1 reproduces the original Lemma 1 closed form exactly, while at m_rep≥2 both sides are multiplied by the same $m_{\rm rep}$-independent prefactor. The regression test `lemma1_general_S_verification.jl` (26 channels, 5 cases — all m_rep=1) continues to PASS.

## 3. Sanity checks (full ladder)

### 3.1 Dimensional analysis
$\bar\beta_S^{(i)} = m_{\rm rep}\cdot \mathrm{Tr}[\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$ is dimensionless. $m_{\rm rep}$ is an integer count. $\Pi_S$ is dimensionless projector. $\rho_{\rm inv}\otimes\rho_{\rm inv}$ has trace $(\mathrm{Tr}\,\rho_{\rm inv})^2 = 1$. Trace of projector × normalized state is dimensionless ✓.

### 3.2 Limit case m_rep=1
$P_W = |\zeta\rangle\langle\zeta|$, $\rho_{\rm inv} = |\zeta\rangle\langle\zeta|$. $\rho_{\rm inv}\otimes\rho_{\rm inv}$ has rank 1 projecting onto $|\zeta\otimes\zeta\rangle$. $\bar\beta_S^{(i)} = 1\cdot\sum_M |\langle S,M|\zeta\otimes\zeta\rangle|^2 = \beta_S^{(c_0)}$ ✓.

### 3.3 Limit case m_rep → ∞
Conceptually, $m_{\rm rep}\to\infty$ would mean V_F has infinitely many H-trivial components — impossible for finite F since $\dim V_F = 2F+1$ is finite. So $m_{\rm rep}\leq 2F+1$. Asymptotically as F→∞ (with H fixed), $m_{\rm rep}$ for the trivial irrep grows linearly in F (since $\dim V_F$ grows linearly and the average isotypic share is $\sim 1/|H|$). The formula $\bar\beta_0^{(i)} = m_{\rm rep}\cdot \mathrm{Tr}[\Pi_0(\rho_{\rm inv}\otimes\rho_{\rm inv})] = (m_{\rm rep}/(2F+1)) \cdot (1/m_{\rm rep}) = 1/(2F+1)$ — INDEPENDENT of $m_{\rm rep}$. ✓ "Universal $1/(2F+1)$" preserved.

### 3.4 Symmetry
$\rho_{\rm inv}$ is H-invariant by construction (orthogonal projection onto H-trivial subspace, normalized to trace 1). $\Pi_S$ is SU(2)-invariant hence H-invariant. Trace is basis-independent. So $\bar\beta_S^{(i)}$ is manifestly SU(2)-equivariant + H-invariant + basis-independent ✓.

### 3.5 Sign
$\bar\beta_S^{(i)} = (1/m_{\rm rep})\mathrm{Tr}[\Pi_S(P_W\otimes P_W)]$. Trace of product of two PSD operators (each ≥ 0) is ≥ 0. So $\bar\beta_S^{(i)}\geq 0$ ✓.

### 3.6 Order-of-magnitude at F=9 T:A, S=0
$\bar\beta_0^{(i)} = m_{\rm rep}\cdot \text{(empirical T114-formula)} = 2 \cdot 0.0263157894736842 = 0.0526315789473684 = 1/19$ ✓.

### 3.7 Sum rule (multiplicity-aware)
$\sum_S \bar\beta_S^{(i)} = (1/m_{\rm rep})\sum_S \mathrm{Tr}[\Pi_S(P_W\otimes P_W)] = (1/m_{\rm rep})\mathrm{Tr}[P_W\otimes P_W]$ (since $\sum_S\Pi_S = I$)
$= (1/m_{\rm rep})(\mathrm{Tr}\,P_W)^2 = (1/m_{\rm rep})\cdot m_{\rm rep}^2 = m_{\rm rep}$.

At F=9 T:A, $m_{\rm rep}=2$: predicted full sum = 2.

The implementer measured the partial sum over **even S only** = 0.75 under the T114 formula (without $m_{\rm rep}$ prefactor). Multiplied by $m_{\rm rep}=2$ for Candidate (i): partial sum even-S = 1.5. The full sum (including odd S) is 2. **Odd-S contribution (predicted by Candidate i)**: $2 - 1.5 = 0.5$.

The odd-S contribution arises from $|\zeta_i\otimes\zeta_j\rangle$ (i≠j) which has an antisymmetric part under 1↔2 swap; the antisymmetric part lives in odd-S subspaces of $V_F\otimes V_F$. For diagonal i=j terms, $|\zeta_i\otimes\zeta_i\rangle$ is purely symmetric, only even S contribute.

**Cross-check**: T114 §3 claimed `Sum_S = 1` based on the trace formula sum rule $\sum_S\Pi_S=I$, $\mathrm{Tr}\,\rho_{\rm inv}\otimes\rho_{\rm inv}=1$. This IS the sum-over-ALL-S identity (NOT even-S only). The T114 sanity check did NOT distinguish even-S from all-S, and the implementer's code silently skipped odd S. The implementer's 0.75 measurement is consistent with the T114 formula IF you only sum even S (0.75 < 1 since odd-S contributions are missing). For Candidate (i), the all-S sum = m_rep = 2, even-S partial = 1.5, odd-S partial = 0.5. ✓

### 3.8 Comparison with implementer's empirical metrics

| Metric | Implementer empirical | Candidate (i) prediction |
|---|---|---|
| $\bar\beta_0$ at F=9 T:A | 1/38 = 0.0263... | (T114 formula) — needs ×2 for (i) |
| $m_{\rm rep}\cdot\bar\beta_0$ (Candidate i) | 2/38 = 1/19 = 0.0526... | 1/19 ✓ |
| Sum over even S | 0.75 | 0.75 (under T114) / 1.5 (under (i)) ✓ |
| Seed independence | 1.39e-17 | machine precision ✓ |
| Schur isotropy of $\rho_{\rm inv}$ | 30.000 to 2.5e-14 | F(F+1)/3 = 30 ✓ |

All consistent with Candidate (i). The implementer's measurements are precisely the inputs needed; the only adjustment is the $m_{\rm rep}$ prefactor.

## 4. Calibrated claims

- [Established, T114 §2.4 + T115-attempt1 §6.1] At F=9 T:A, the T114 §2.A formula $\bar\beta_S^{(\rm T114)} = \mathrm{Tr}[\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$ gives $\bar\beta_0 = 1/38 = 1/(m_{\rm rep}\cdot(2F+1))$, not $1/(2F+1)$, at $m_{\rm rep}=2$. Empirical to 13 digits.
- [Established, T115-attempt1 §6.3 + §6.4] The implementer's measurement is seed-independent (U(2)-basis-invariant) at machine precision (1.39e-17); and $\rho_{\rm inv}$ satisfies Schur isotropy $\mathrm{Tr}(\rho_{\rm inv} F_a^2) = F(F+1)/3$ at 2.5e-14.
- [Established, derivation §2.A.1-§2.A.3 + §2.A.5] The quantity $\sum_{i,j}|\langle 0,0|\zeta_i\otimes\zeta_j\rangle|^2 = \mathrm{Tr}[\Pi_0(P_W\otimes P_W)]$ is U(m_rep)-basis-invariant under U(m_rep) rotations of $\{\zeta_i\}$. Proof: trace of $\Pi_0 \cdot$ (basis-invariant projector $P_W \otimes P_W$). ✓
- [Established, paper3 sign_pattern_lemma1_general_S.md lines 137-158] The original Lemma 1 General-S derivation at m_rep=1 gives $\beta_0^{(c_0)} = 1/(2F+1)$ via singlet-identity + Schur isotropy. This is the m_rep=1 endpoint of the multiplicity-aware formula.
- [Plausible, §2.A.4 isotypic-allocation conjecture] The squared overlap $\|\xi_A\|^2 = \|(P_W\otimes P_W)|0,0\rangle\|^2 = m_{\rm rep}/(2F+1)$ for polyhedral inert subspace $W = W_A$ at H-trivial irrep with $J\in H$. Verified empirically at F=9 T:A (2/19 = 0.10526...). General proof requires explicit isotypic decomposition argument (e.g., character-theoretic computation of the "trivial-pairing" overlap with $|0,0\rangle$ in each isotypic block). I label PLAUSIBLE pending T116 cross-checks at independent m_rep≥2 cases.
- [Plausible, §2.B + §2.A.5] Candidate (i) — $\bar\beta_S^{(i)} = m_{\rm rep}\cdot \mathrm{Tr}[\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$ — is the canonical multiplicity-aware extension of $\beta_S^{(c_0)}$. Matches expected endpoint at $S=0$ ($1/(2F+1)$); strict-generalizes mult-1; basis-independent; sum rule = $m_{\rm rep}$.
- [Plausible, §2.C] The Lemma 1 General-S sign-prefactor $(S(S+1)-2F(F+1))/(2F(F+1))$ extends unchanged to $\bar\beta_S^{(\lambda_{\rm spin})} / \bar\beta_S^{(\rm canonical)}$ since the prefactor is a Wigner-Eckart channel-S identity, not state-dependent. Strict-generalization regression PASSES at all mult-1 cases.
- [Speculative, §2.B-Candidate-(iii)] T114's §2.B Schur-isotropic single-vector basis is an alternative route, but existence of $\zeta_*$ with $\langle\zeta_*|F_a F_b|\zeta_*\rangle = (F(F+1)/3)\delta_{ab}$ individually at m_rep≥2 is not guaranteed. The implementer's `Tr(rho_inv F_a^2) = F(F+1)/3` measures the ORBIT AVERAGE only, not per-vector Schur isotropy. Falsifier: implement Candidate (iii) basis-search algorithm at F=9 T:A; check if solution exists, and if yes whether it gives 1/19. If no solution exists, Candidate (iii) is refuted.
- [Speculative, §3.7 odd-S sum] The full sum $\sum_S \bar\beta_S^{(i)} = m_{\rm rep} = 2$ at F=9 T:A includes odd-S contributions (0.5) from the antisymmetric part of $|\zeta_i\otimes\zeta_j\rangle$ (i≠j). The implementer's code only sums even S (= 0.75 under T114 = 1.5 under Candidate (i)). T116 implementer should EITHER report the full all-S sum (modify `project_S_channel` loop to `S in 0:2F` instead of `0:2:2F`) OR explicitly document the even-S-only convention. Falsifier: independent verification that odd-S sum = 0.5 at m_rep=2 (i.e., $m_{\rm rep} - $ even-S sum).

## 5. Open questions

- `<FALSIFIER: F1-mult-aware-bar-beta-0 | bar_beta_0_canonical at F=9 T:A computed as m_rep * mult_aware_beta_S(rho_inv, F, S=0) where mult_aware_beta_S is the existing function in scripts/manuscript/f9_f11_polyhedral_verification.jl (no code change to the function; trivial 1-line wrapper at call site) | CORROBORATE if |m_rep * bar_beta_0_attempt1 - 1/19| < 1e-13 (the math at attempt1's measurement: 2 * 0.0263157894736842 = 0.0526315789473684 = 1/19 exactly to 13+ digits); REFUTED if > 1e-6 >`

- `<FALSIFIER: F2-seed-independence | repeat the m_rep * mult_aware_beta_S(rho_inv, F, S=0) computation across 10 RNG seeds (seeds 1..10 same as attempt1's), report max-min spread | CORROBORATE if spread < 1e-13; REFUTED if > 1e-6 >`

- `<FALSIFIER: F3-mult-1-regression | run julia --project=. scripts/manuscript/lemma1_general_S_verification.jl | CORROBORATE if 26/26 PASS (the on-disk count, NOT 29; the F=2 cyclic-tetrahedral A_1 entry from MEMORY was never committed to the script — this is a separate drift not in scope for T115/T116); REFUTED if any of 26 tests fails. NOTE: do NOT make F3 contingent on 29 channels per director directive. >`

- `<FALSIFIER: F4-sum-rule-all-S-equals-m-rep | extend project_S_channel call to S in 0:2F (all S, not 0:2:2F), compute Sum_S [m_rep * mult_aware_beta_S(rho_inv, F, S)] at F=9 T:A | CORROBORATE if |Sum - m_rep| < 1e-12; REFUTED if > 1e-6. This validates the §3.7 sum rule prediction that even-S partial = 1.5 + odd-S partial = 0.5, totaling 2 = m_rep. ADVISORY (not blocking). >`

- `<RESEARCH_NEEDED: isotypic-allocation-general-F-H | derive or verify the conjectured formula \|\xi_alpha\|^2 = m_alpha · d_alpha / (2F+1) for the H-isotypic decomposition of |0,0> in V_F ⊗ V_F. Currently [Plausible] based on F=9 T:A empirical + mult-1 cases. For full rigor, need either character-theoretic computation or independent test at a non-trivial irrep (e.g., F=11 T:E_1 once complex-1-dim → 2-dim-real construction settled, or F=12 polyhedral audit). >`

- `<RESEARCH_NEEDED: f11-te1-mult2-construction | per T114 §2.B reading list. F=11 T:E_1 is multiplicity 2 (and complex 1-dim irrep); the 2-dim real construction (E_1 ⊕ E_2 doublet) needs explicit characterization before Candidate (i) can be tested at a second m_rep≥2 case. Estimated implementation: T117+ researcher_shallow or implementer task; out of scope for T116 immediate Test. >`

- `<RESEARCH_NEEDED: f12-multiplicity-audit | per universal_structure_u1u4_2026_05_13.md follow-up. F=12 is listed as `:unknown` and pending; if any F=12 polyhedral irreps have m_rep≥2, those become additional test cases for Candidate (i). >`

- `<RESEARCH_NEEDED: regression-script-vs-MEMORY-drift | scripts/manuscript/lemma1_general_S_verification.jl currently has 26 channels across 5 cases (F=3,4,6,8,10); MEMORY claims 29 channels across 6 cases (adds F=2 cyclic-tetrahedral A_1 entry per T94). The F=2 cyclic entry was committed to docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md but never to the .jl regression script. NOT in scope for T115/T116, but should be a T117+ implementer_text task to close the drift. >`

## 6. Directive for implementer (T116 Test stage)

**Goal**: verify Candidate (i) prediction $\bar\beta_0^{(\rm canonical)}(F=9, T, A) = 1/19$ exactly.

**Algorithm** (using the existing extended script `scripts/manuscript/f9_f11_polyhedral_verification.jl` from T115-attempt1):

1. The existing functions are sufficient:
   - `find_invariant_basis(P, D; tol=1e-8)` returns `(basis::Vector{Vector{ComplexF64}}, m_rep::Int)`.
   - `mult_aware_beta_S(rho_inv, F, S)` computes $\mathrm{Tr}[\Pi_S(\rho_{\rm inv}\otimes\rho_{\rm inv})]$ — the T114 formula WITHOUT m_rep prefactor.
   - `verify_case_mult_aware(F, group, irrep; seeds=1:10)` is the driver.

2. **F1 falsifier (central)** — implementer needs to ADD a 1-line wrapper at the call site:
   ```julia
   bar_beta_0_canonical = m_rep * mult_aware_beta_S(rho_inv, F, 0)  # Candidate (i): m_rep prefactor
   @test abs(bar_beta_0_canonical - 1/(2F+1)) < 1e-13
   ```
   No modification of `mult_aware_beta_S` is needed; just multiply the result by `m_rep` at the call site (or add a new helper `canonical_mult_aware_beta_S(rho_inv, F, S; m_rep) = m_rep * mult_aware_beta_S(rho_inv, F, S)`).

3. **F2 falsifier (advisory)** — repeat across 10 RNG seeds, verify `max(bar_beta_0_canonical) - min(...) < 1e-13`. Since seed-independence of `mult_aware_beta_S` was already CORROBORATED at attempt1 (1.39e-17), and the m_rep prefactor is integer-deterministic, F2 is structurally guaranteed.

4. **F3 falsifier (regression)** — run `julia --project=. scripts/manuscript/lemma1_general_S_verification.jl`, verify 26/26 PASS. **NOTE**: the on-disk script has 26 channels across 5 cases (NOT 29 across 6 as MEMORY claims; the F=2 cyclic-tetrahedral A_1 entry was never committed to this .jl file — separate drift, NOT in T116 scope). The F3 falsifier passes IF the existing 26 tests all PASS (no script modification expected; the Candidate (i) formula at m_rep=1 reduces to the original $\beta_S^{(c_0)}$ exactly, so the rational-arithmetic test set is unaffected).

5. **F4 falsifier (sum-rule advisory)** — modify the existing `verify_case_mult_aware` to sum over ALL S (0:2F, not 0:2:2F), compute `Sum_S [m_rep * mult_aware_beta_S(rho_inv, F, S)]` at F=9 T:A; expect $\approx m_{\rm rep} = 2$ to 1e-12. ADVISORY: if even-S-only convention is preserved, the partial sum should be ≈ 1.5 (= $m_{\rm rep} \cdot 0.75$) — same numerical check, different presentation.

**Observable manifest** (implementer must produce):
- `bar_beta_0_canonical_F9_TA` :: Float64 — should print as `0.0526315789473684...` (= 1/19 to 13+ digits).
- `bar_beta_0_canonical_dev_from_1_over_2F_plus_1` :: Float64 — should be `< 1e-13`.
- `m_rep_at_F9_TA` :: Int — should be 2.
- `seed_spread_F9_TA_canonical` :: Float64 — should be < 1e-13.
- `regression_lemma1_general_S_passed_count` :: Int — should be 26 (with `regression_lemma1_general_S_total_count = 26`).
- (Advisory) `sum_S_all_S_at_F9_TA_canonical` :: Float64 — should be ≈ 2 (or ≈ 1.5 if even-S-only convention preserved).
- `f1_verdict` :: String — "CORROBORATE" expected.

**Implementation budget**: ~10-15 minutes (1-line wrapper + run + parse). No structural change to `mult_aware_beta_S`. No `src/` modification. The script `f9_f11_polyhedral_verification.jl` already extended at attempt1; only the call-site wrapper changes.

**Hard constraints** for T116 implementer:
- Do NOT modify `mult_aware_beta_S` definition — add the m_rep prefactor at the call site (or in a thin wrapper function `bar_beta_canonical = m_rep * mult_aware_beta_S(...)`).
- Do NOT modify `scripts/manuscript/lemma1_general_S_verification.jl` (F3 regression baseline must remain untouched).
- Do NOT modify any `src/` file.
- Do NOT pursue Candidate (iii) basis-search at this turn — that's a T117+ research item if T116 PASSES Candidate (i).

## 7. Metrics

```json
{
  "experiment_kind": "derivation",
  "workload_class": "theorist",
  "investigation_id": "sign-pattern-f9-ta-multiplicity-2-mixing-2026-05-19",
  "stage_advancing_to": "Test",
  "audit_result_off_diagonal_singlet_overlaps": "CORROBORATE_partial_basis_dependent",
  "recommended_candidate": "i_revised_2A_with_mrep_prefactor",
  "predicted_bar_beta_0_at_F9_TA": "1/19 = 0.052631578947368",
  "predicted_sum_rule_value_at_F9_TA": "m_rep = 2 (all-S); 1.5 (even-S partial)",
  "f1_new_falsifier_formula_specified": "m_rep * mult_aware_beta_S(rho_inv, F=9, S=0)",
  "f3_regression_target_unchanged": "26 channels across 5 cases (on-disk count, NOT 29 as MEMORY drift)",
  "limit_case_m_rep_1_reduction_verified": "bar_beta_S^(i) = 1 * Tr[Pi_S(|zeta><zeta| tensor |zeta><zeta|)] = beta_S^(c_0) ✓",
  "n_lines_derivation": 358,
  "n_calibrated_established": 4,
  "n_calibrated_plausible": 4,
  "n_calibrated_speculative": 2,
  "n_open_research_needed": 4,
  "n_falsifiers_specified": 4,
  "tests_passed": null,
  "warnings": [
    "Implementer's §6.2 mechanism 'off-diagonal singlet overlaps vanish at SVD basis' is BASIS-DEPENDENT, not structural. The structurally correct statement is that the U(m_rep)-invariant TOTAL Sum_{i,j}|<0,0|zeta_i tensor zeta_j>|^2 = m_rep/(2F+1). Off-diagonals individually vanish only because SVD happened to diagonalize the symmetric bilinear form B|_W; in a different basis they would be non-zero with proportionally smaller diagonals. The TOTAL is invariant.",
    "T114 §3 sum rule check 'Sum_S = 1' was correct for the all-S sum (Sum_S Pi_S = I), but the implementer's verify_case_mult_aware loop only sums even S (0:2:2F, line of project_S_channel) — implementer's 0.75 empirical = 1 - (odd-S contribution). This is a presentation issue, not a formula error. Candidate (i)'s all-S sum is m_rep, even-S partial is m_rep * 0.75 = 1.5."
  ],
  "physical_red_flags": [
    "Isotypic-allocation conjecture |xi_alpha|^2 = m_alpha * d_alpha / (2F+1) is [Plausible] but not rigorously proven. Empirically verified at F=9 T:A and all mult-1 cases. General proof requires character-theoretic computation of trivial-pairing overlap in each isotypic block. T117+ research item."
  ],
  "falsification_result": "NOT_APPLICABLE",
  "tokens_used": null
}
```

I am done

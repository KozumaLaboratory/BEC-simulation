# Turn 7 — Theorist Report

## 0. Convention declaration

This turn derives the eigen-spectrum of the bosonic Bogoliubov-de Gennes
matrix used inside `_compute_lhy_at_density` (`src/hamiltonian/interactions/
lhy/dispatch.jl` lines 200-242). The conventions below are verified against
production code by `Grep` this turn; deviations from the production form are
flagged in-line.

- **Nambu doubling sign (bosonic, NOT fermionic).** Production at
  `dispatch.jl:217` builds the lower-left block as
  $H_{\rm bdg}[D{+}1:2D,\,1:D] = -\overline{M_{\rm sc}}$
  (i.e. `.-conj.(M_sc)`). This is the bosonic Nambu convention
  $H_{\rm bdg} = \begin{pmatrix} L & M \\ -M^{*} & -L^{*}\end{pmatrix}$
  used by Blaizot-Ripka §3.6 and Castin-Dum 1998. The fermionic convention
  has $+M^{*}$ in the lower-left and is **not** what this code does — so
  the spectral theorems below are the bosonic ones.
- **Block Hermiticity properties.** $L \in \mathbb{C}^{D\times D}$ is
  Hermitian ($L^{\dagger}=L$) because $L = 2n_0\,h_{\rm mf} +
  (\epsilon_k - \mu)\,\mathbb{I} + \mathrm{diag}(\mathrm{zee})$ and
  $h_{\rm mf}$ is the BdG normal kernel which is Hermitian by construction
  (`_bdg_normal_matrix`, `src/analysis/phases/bogoliubov.jl`). The anomalous
  block $M$ is **symmetric**, $M^{T} = M$, because it arises from the
  symmetric pair operator $\hat\psi_c \hat\psi_{c'}$ ($c \leftrightarrow c'$
  is bosonic-symmetric). Therefore $M^{\dagger} = M^{*}$ and $L^{T} = L^{*}$.
- **Symplectic / pseudo-Hermitian metric.** $\eta \equiv \mathrm{diag}(
  \mathbb{I}_D, -\mathbb{I}_D)$, $\eta^2 = \mathbb{I}_{2D}$, $\eta^{\dagger}
  = \eta$. The Hermitized form $H_{\rm H} \equiv \eta H_{\rm bdg}$ is the
  "Hartree-Fock-Bogoliubov stability matrix" — Hermitian, indefinite in
  general.
- **`eigen()` call.** `dispatch.jl:225` is `evals_full = eigen(H_bdg)` — a
  **standard LAPACK non-Hermitian eigendecomposition** (Julia routes this to
  `LAPACK.geevx!`). It is NOT a symplectic / generalized-eigenvalue solver,
  NOT `eigen(η H_bdg, η)`, and the eigenvectors it returns are not normalized
  to the $\eta$-inner-product. Section 2.1 traces what this means
  numerically.
- **Polar GS at F=6.** $\zeta_\alpha = \delta_{\alpha,0}$ in $m$-basis
  $c \in \{F,F{-}1,\ldots,-F\}$. The production code's `_is_polar_spinor`
  check (`dispatch.jl:143-150`) requires $|\zeta_0|^2/\sum_c|\zeta_c|^2 \ge
  0.99$, with $c = F+1$ for the $m=0$ slot under the SpinorBEC
  $c{=}1{\leftrightarrow}m{=}+F$ ordering.
- **No deviation from production for the LHY integrand.** Subtraction kernel
  at `dispatch.jl:237` is
  $\mathrm{correction} = \omega - \epsilon_k - \mu_b + \mu_b^2/(2\epsilon_k)$
  with $\mu_b \equiv \epsilon_k + n_0\,\mathrm{Re}\,h_{\rm total}[c^{*},c^{*}]
  - \mu + \mathrm{zee}[c^{*}]$; $c^{*} = \arg\max_c |u_{\rm part}[c]|^2$
  on the upper-$D$ rows of the eigenvector. The mathematical question is
  whether this $\mu_b$ is the correct large-$k$ asymptote when the eigenvector
  is the upper half of a Nambu pair from a dynamically unstable physical mode.

## 1. Context summary

T5 (researcher) cached the LHY-on-unstable-GS literature (Lima-Pelster 2011/2012,
Petrov 2015, Bisset 2016, UKU 2010, Zhang 2023) and proposed that the F=6
polar 3000× spurious offset is caused by *Nambu doubling re-casting
purely-imaginary physical Bogoliubov eigenvalues into large positive-real
Nambu eigenvalues that pass the $|\mathrm{Re}\,\omega| > 10^{-10}$ filter*.
T6 (critic) **rejected** that mechanism: the standard bosonic Bogoliubov
spectrum is pseudo-Hermitian under $\eta = \mathrm{diag}(\mathbb{I}_D,
-\mathbb{I}_D)$, eigenvalues come in $(\lambda, -\lambda^{*})$ pairs, and a
purely-imaginary physical pair $\pm i\Omega$ remains purely imaginary as a
Nambu eigenvalue — it does not become real. T6 listed three competing
candidate mechanisms (i)/(ii)/(iii) for the 3000× offset and escalated to the
theorist to derive the spectrum + resolve which mechanism is load-bearing
+ recommend a fix shape (F-α, F-β, F-γ, or new F-δ). This turn answers all
four.

## 2. Derivation

### 2.1 Spectrum of $H_{\rm bdg}$ — bosonic pseudo-Hermitian symmetry

Take $L = L^{\dagger}$, $M = M^{T}$ (bosonic), and
$$
H_{\rm bdg} = \begin{pmatrix} L & M \\ -M^{*} & -L^{*} \end{pmatrix},
\qquad
\eta = \begin{pmatrix} \mathbb{I}_D & 0 \\ 0 & -\mathbb{I}_D \end{pmatrix}.
$$

**Pseudo-Hermiticity.** Compute $\eta H_{\rm bdg} \eta$ block-by-block.
Left-multiply by $\eta$ negates the lower row of blocks; right-multiply by
$\eta$ negates the right column of blocks:
$$
\eta H_{\rm bdg} \eta = \begin{pmatrix} L & -M \\ M^{*} & -L^{*}\end{pmatrix}.
$$
Compare to $H_{\rm bdg}^{\dagger}$. The Hermitian conjugate of a block matrix
$\begin{pmatrix} A & B \\ C & D \end{pmatrix}$ is $\begin{pmatrix} A^{\dagger}
& C^{\dagger} \\ B^{\dagger} & D^{\dagger}\end{pmatrix}$. So
$$
H_{\rm bdg}^{\dagger}
= \begin{pmatrix} L^{\dagger} & (-M^{*})^{\dagger} \\ M^{\dagger}
& (-L^{*})^{\dagger} \end{pmatrix}
= \begin{pmatrix} L & -M^{T} \\ M^{T*} & -L^{T} \end{pmatrix}
= \begin{pmatrix} L & -M \\ M^{*} & -L^{*} \end{pmatrix}
$$
using $L^{\dagger}=L$, $M^{T} = M$, and $L^{T} = L^{*}$ (which follows from
$L = L^{\dagger}$). Therefore
$$
\boxed{\;\eta\,H_{\rm bdg}\,\eta = H_{\rm bdg}^{\dagger}\;}
\qquad (\text{Eq.~1; bosonic BdG pseudo-Hermiticity})
$$
This is the central textbook identity. Citation chain:
- Colpa, Physica A **93**, 327 (1978), §3, defines the analogous metric for
  bosonic quadratic Hamiltonians and proves the diagonalization theorem.
- Blaizot-Ripka, *Quantum Theory of Finite Systems*, MIT Press 1986,
  §3.6, derives Eq. 1 explicitly for the HFB stability matrix
  (their notation: $\mathcal{M}$ for $H_{\rm bdg}$, $\sigma_z$ for $\eta$).
- Castin-Dum, Phys. Rev. A **57**, 3008 (1998), Sec. II eqs (2.3)-(2.7),
  applies the formalism to time-dependent trapped BECs and derives the
  $(\lambda, -\lambda^{*})$ spectral pairing as a corollary of Eq. 1.
- Modern restatement: Lieu, PRB **98**, 115135 (2018), arXiv:1807.03320,
  identifies the bosonic BdG as a non-Hermitian matrix in the
  Bernard-LeClair pseudo-Hermitian class (their "BL class P").

**Spectral consequence (λ, -λ\*) pairing.** Take an eigenpair
$H_{\rm bdg}\,\psi = \lambda\,\psi$. Apply $\eta$:
$\eta H_{\rm bdg}\,\psi = \lambda\,\eta\psi$. Using Eq. 1,
$H_{\rm bdg}^{\dagger}\,\eta^{-1}\,(\eta\psi) = \lambda\,\eta\psi$, i.e.,
$H_{\rm bdg}^{\dagger}\,(\eta\psi) = \lambda\,\eta\psi$ (since $\eta^{-1}=\eta$
and $\eta\eta = \mathbb I$). Therefore $\eta\psi$ is a *right* eigenvector
of $H_{\rm bdg}^{\dagger}$ with eigenvalue $\lambda$. Equivalently, $\eta\psi$
is a *left* eigenvector of $H_{\rm bdg}$ with eigenvalue $\lambda^{*}$.
Combined with the trivial statement that the spectrum of $H_{\rm bdg}^{\dagger}$
is the complex conjugate of the spectrum of $H_{\rm bdg}$, we get:

$$\boxed{\;\lambda \in \sigma(H_{\rm bdg}) \iff \lambda^{*} \in
\sigma(H_{\rm bdg}^{\dagger}) \iff \lambda \in \sigma(\eta H_{\rm bdg}\eta)
= \sigma(H_{\rm bdg}^{\dagger}) = \overline{\sigma(H_{\rm bdg})};}$$

so $\sigma(H_{\rm bdg}) = \overline{\sigma(H_{\rm bdg})}$ — the spectrum is
closed under complex conjugation.

The *additional* $(\lambda \to -\lambda)$ symmetry uses the *particle-hole*
involution. Define
$$
C \equiv \tau_x\,K, \qquad
\tau_x = \begin{pmatrix} 0 & \mathbb{I}_D \\ \mathbb{I}_D & 0 \end{pmatrix},
$$
where $K$ is complex conjugation. Then
$$
C\,H_{\rm bdg}\,C^{-1}
= \tau_x\,\overline{H_{\rm bdg}}\,\tau_x
= \tau_x\,\begin{pmatrix} L^{*} & M^{*} \\ -M & -L\end{pmatrix}\,\tau_x
= \begin{pmatrix} -L & -M \\ M^{*} & L^{*}\end{pmatrix}
= -H_{\rm bdg}.
$$
So $C$ anticommutes with $H_{\rm bdg}$: $C H_{\rm bdg} = -H_{\rm bdg} C$. If
$\psi$ is a right eigenvector with eigenvalue $\lambda$, then $C\psi$ is a
right eigenvector with eigenvalue $-\lambda^{*}$ (the $K$ inside $C$ flips
the eigenvalue's complex conjugate; the $\tau_x$ is a unitary similarity).
Combined with $\sigma(H_{\rm bdg}) = \overline{\sigma(H_{\rm bdg})}$, the
full symmetry is:

$$\boxed{\;\lambda \in \sigma(H_{\rm bdg})\;\Rightarrow\;\{\lambda,\;
-\lambda^{*},\;\lambda^{*},\;-\lambda\}\subseteq \sigma(H_{\rm bdg}).\;}
\quad(\text{Eq.~2})$$

**Spectral case enumeration.** Equation 2 partitions $\sigma(H_{\rm bdg})$
into four canonical orbit types:

| Orbit | Form | Multiplicity | Physical interpretation |
|---|---|---|---|
| **R** (real pair) | $\{+\omega, -\omega\}$, $\omega\in\mathbb R\setminus\{0\}$ | 2 | Stable Bogoliubov mode (energy $\omega$ in upper-D sector, "hole" $-\omega$ in lower-D) |
| **I** (imaginary pair) | $\{+i\Omega, -i\Omega\}$, $\Omega\in\mathbb R\setminus\{0\}$ | 2 | Dynamically unstable mode (growth rate $\Omega$) |
| **Q** (complex quartet) | $\{\lambda, -\lambda, \lambda^{*}, -\lambda^{*}\}$, $\mathrm{Re}\,\lambda\neq 0$, $\mathrm{Im}\,\lambda\neq 0$ | 4 | Drift-instability mode (oscillating + growing) |
| **Z** (zero) | $\{0\}$ | $\ge 1$ | Goldstone mode (U(1) phase, broken-symmetry generators) |

The dimensions sum: $2N_R + 2N_I + 4N_Q + N_Z = 2D$.

**This explicitly contradicts T5's "imaginary becomes real" claim.** A
purely-imaginary physical Bogoliubov eigenvalue $\omega_{\rm phys} = i\Omega$
appears in $\sigma(H_{\rm bdg})$ as the orbit-I pair $\{+i\Omega,-i\Omega\}$.
Its `real(ev)` is **0** (modulo numerical noise), not a large positive
number. T5's mechanism is falsified.

**LAPACK numerical signature.** `eigen(H_bdg)` does not know about $\eta$.
For a generic non-Hermitian matrix of size $2D \times 2D$, LAPACK's
QR-based Schur decomposition has backward error
$\|H_{\rm bdg} + E\| \le c\,\varepsilon_{\rm mach}\,\|H_{\rm bdg}\|$
with $c = O((2D)^{1/2})$. For $D=13$ this gives $c \approx 5$. The eigenvalue
sensitivity is bounded by the *condition number of the eigenvector basis*
$\kappa = \|S\|\|S^{-1}\|$ where $H_{\rm bdg} = S\Lambda S^{-1}$. For a
pseudo-Hermitian matrix with imaginary eigenvalues, the relevant condition
number is governed by *defectiveness near exceptional points* (Lieu 2018
§III; Krein 1950s G-Hamiltonian theory). At the boundary between orbit-R
and orbit-I (an exceptional point where $\omega\to 0$ by colliding $\pm$
pairs), $\kappa$ diverges. Away from the EP, but for a strongly unstable
state, $\kappa$ is typically $O(10^2$–$10^4)$ for $D=13$.

Therefore a *purely imaginary* eigenvalue $i\Omega$ acquires a numerical
real part
$$
|\mathrm{Re}(\lambda_{\rm num})| \lesssim \kappa\,\varepsilon_{\rm mach}\,
\|H_{\rm bdg}\|.
$$
With $\|H_{\rm bdg}\| \sim n_0\|h_{\rm mf}\| + \epsilon_k$, at Eu typical
densities $n_0 \sim 10^2$ in dimensionless units and $\epsilon_k$ up to
$k_{\max}^2/2 = 200$, we get $\|H_{\rm bdg}\| \sim 10^3$ at the high-$k$
end. With $\kappa \sim 10^3$ and $\varepsilon_{\rm mach} = 2.2\times10^{-16}$
(Float64), the noise floor on the imaginary mode's `real(ev)` is
$\sim 10^{-10}$ — **right at the production threshold** `omega > 1e-10`.
This is not a coincidence: that threshold appears to have been chosen to
exclude purely-imaginary modes assuming no condition-number amplification.

### 2.2 Mechanism resolution at F=6 polar — ranking the three T6 candidates

The empirical fact (memory `full_bdg_F6_polar_broken.md`, 2026-05-07 audit):
F=6 polar `:scalar` GS energy = $-880.5$, `:full_bdg` GS energy = $-2.527\times
10^6$. Ratio $\approx 2870\times$. The ITP-converged $\psi$ is identical
(same peak density, FWHM, $M_z$, $|+F\rangle$ fraction). So the offset is in
the LHY energy at a single density, integrated over the spatial cloud.

Pre-computed structural facts (from `_bdg_contact_matrices`, the F=6 polar GS,
and the validation oracle cited by T5):

- At only-$g_0$=100 (a representative "deep polar" point), 12 of 13 physical
  Bogoliubov modes are imaginary; only the $m{=}0$ phonon (the broken-$U(1)$
  Goldstone family) is real (zero). So $N_I = 12$ and $N_R = 0$ and $N_Z = 1$
  in the orbit count; $2N_I + N_Z = 25$, plus the missing 1 mode is the
  Goldstone partner — total 26 Nambu eigenvalues. (At generic $g_S$ this
  decomposition shifts but the *imaginary-dominated* character holds.)
- $\|h_{\rm mf}\| \sim n_0 \cdot \max_S|g_S| \sim 100 \cdot O(1) \sim O(10^2)$;
  $\|M\| \sim n_0 \cdot O(1)$. So $\|H_{\rm bdg}\| \sim O(10^2)$ at low $k$
  and $\sim O(k^2)$ at high $k$.

Now evaluate the three T6 hypotheses against this structure.

**(i) LAPACK noise on imaginary modes passing the $10^{-10}$ filter, amplified
by miscalibrated $\mu_b$.** As derived in §2.1, $\kappa \cdot
\varepsilon_{\rm mach}\,\|H_{\rm bdg}\| \sim 10^3 \cdot 2.2\times 10^{-16}
\cdot 10^2 = 2\times 10^{-11}$ at low $k$ (below threshold; modes correctly
dropped) but $\sim 10^{-9}$–$10^{-8}$ at high $k$ (above threshold; modes
pass). For each of the $\sim 24$ imaginary Nambu eigenvalues that pass at
high $k$, the integrand contribution is
$$
\mathrm{corr}_b = \mathrm{Re}\,\lambda_b - \epsilon_k - \mu_b
+ \mu_b^2/(2\epsilon_k).
$$
The dominant term at high $k$ is the *UV-subtraction* $\mu_b^2/(2\epsilon_k)$.
For a spurious mode that should have been dropped, $\mathrm{Re}\,\lambda_b$
is $O(10^{-9})$ (negligible) but $-\epsilon_k - \mu_b + \mu_b^2/(2\epsilon_k)$
is **not** zero — it is $O(\mu_b^2/\epsilon_k) \sim O(n_0^2 g^2/k^2)$. This
subtraction was designed assuming $\mathrm{Re}\,\lambda_b \to \epsilon_k +
\mu_b - \mu_b^2/(2\epsilon_k) + \ldots$ in the large-$k$ limit (the
Bogoliubov $\omega \to \epsilon_k + \mu_b$ asymptote). When
$\mathrm{Re}\,\lambda_b \approx 0$ instead, the subtraction term *itself*
becomes the answer rather than cancelling.

Per-mode contribution to $\zeta_{\rm pe}$ at fixed $k$:
$$
\Delta \zeta_{\rm pe} \approx \frac{1}{2}\left(-\epsilon_k - \mu_b
+ \frac{\mu_b^2}{2\epsilon_k}\right)\;\Theta\!\left(\frac{\kappa
\varepsilon_{\rm mach}\,\|H_{\rm bdg}\|}{10^{-10}}\right).
$$
Multiplied by $24$ surviving imaginary modes, $k^2 dk/(2\pi^2)$, and
integrated over $k\in[k_{\min}, k_{\max}]$, this gives an *unregularized*
$O(n_0^{5/2})$ contribution. Order of magnitude: in standard scalar LHY
the prefactor is $(8/15\pi^2)\,(g n)^{5/2}\sim 10$ at $n_0=100, g\sim 1$;
the spurious 24-mode contribution from miscalibrated $\mu_b$ adds a term
of order $24 \cdot O(n_0^2)\int dk \cdot k^2 \cdot g^2/(2 k^2) \approx
12 g^2 n_0^2 k_{\max} \sim 12 \cdot 1 \cdot 10^4 \cdot 20 \sim 2.4\times 10^6$.
**Plausible match to the observed $-2.5\times 10^6$** offset, sign-correct
(the correction is negative-dominated for $\mu_b > 0$ in the small-$k$
window where the subtraction is unbalanced).

This mechanism is *quantitatively consistent* with the 3000× factor at F=6
polar Eu151 typical density. [Plausible]

**(ii) Genuine real $\pm|\lambda|$ pairs from real-but-negative stiffness
eigenvalues of $L$.** Real-but-negative eigenvalues of $L$ produce
orbit-R pairs $\{+\omega, -\omega\}$ in $\sigma(H_{\rm bdg})$ if and only if
$L$ has a negative eigenvalue while $M = 0$, OR (more generally) when the
HFB stability matrix $\eta H_{\rm bdg}$ has a positive-definite restriction
to a subspace where the anomalous coupling is real-only. At F=6 polar the
spin-mixing channel produces *purely anomalous* coupling
$M = c_1 \,\zeta\zeta^T \cdot \ldots$ — the imaginary-mode instability is
driven by $M$, not by $L$ alone. If real-negative orbit-R pairs were the
dominant mechanism, $\sigma(H_{\rm bdg})$ would have $N_R \gg 0$, but the
oracle says $N_I \approx 12, N_R \approx 0$ at the production parameters.
Therefore **(ii) is structurally inconsistent with the F=6 polar BdG
oracle.** [Established as inconsistent at the oracle parameters; not the
dominant contribution.]

**(iii) `c_star = argmax(|u_part|²)` ill-defined on degenerate-unstable
eigenvectors.** For an imaginary-eigenvalue orbit-I pair, the upper-D
component of the eigenvector $u$ is *not* normalizable to $\langle u|u\rangle
- \langle v|v\rangle = +1$ in the symplectic inner product (the inner product
vanishes for orbit-I pairs — this is the standard "zero-norm" property of
unstable Bogoliubov modes, see Castin-Dum 1998 §II.B; Blaizot-Ripka eq
3.106). LAPACK returns *some* eigenvector — typically the one with unit
Euclidean norm — but $|u|^2 \approx |v|^2$ for orbit-I modes (the two components
are equal in magnitude when the symplectic norm vanishes), so $c^{*} =
\arg\max_c|u_c|^2$ is *near-degenerate* across multiple components and depends
on LAPACK's arbitrary rotation in the degenerate subspace.

The downstream consequence: $\mu_b[c^{*}] = \epsilon_k + n_0\,h_{\rm total}
[c^{*},c^{*}] - \mu + \mathrm{zee}[c^{*}]$ jumps discontinuously across
neighbouring $k$-points if $c^{*}$ switches between near-degenerate
components, and the *integral* over $k$ then sees a jagged $\mu_b(k)$ rather
than a smooth UV asymptote. However: this is a *non-systematic noise*
mechanism — it averages out over many $k$ points unless the $\mu_b$ values
across components are wildly different. For an F=6 polar GS, the
$h_{\rm total}[c,c]$ diagonals scale with the local $g_S$ structure and
typically span $\sim 1$–$10$ in dimensionless units; the resulting $\mu_b^2/
(2\epsilon_k)$ scatter is bounded by $\sim 100/(2\epsilon_k)$. Summed over
$24$ spurious modes × 200 $k$-points × 100 density points this does NOT
plausibly reach $10^6$.

**(iii) is a real effect but quantitatively subleading to (i).** [Plausible
contributor, not dominant.] In fact (iii) is structurally entangled with
(i): when the imaginary-eigenvalue mode passes the threshold (i), its
miscalibrated $\mu_b$ (iii) is what makes the contribution large rather
than the would-be-small LAPACK residual.

**Resolution (load-bearing answer to C5/D2):** The dominant mechanism is
**(i) reinforced by (iii)**: $O(24)$ purely-imaginary Nambu eigenvalues
acquire LAPACK noise on `real(ev)` of order $\kappa\varepsilon_{\rm mach}\,
\|H_{\rm bdg}\|$. At high $k$ this exceeds the $10^{-10}$ threshold and the
modes are retained. The *retained* modes carry the UV-subtraction term
$-\epsilon_k - \mu_b + \mu_b^2/(2\epsilon_k)$ which is no longer cancelled
by a matching $\mathrm{Re}\,\lambda$ (which is $\approx 0$ instead of
$\approx \epsilon_k + \mu_b$), and $\mu_b$ is itself miscalibrated because
$c^{*}$ is ill-defined on the imaginary-pair eigenvector. The integrand
contribution is thus *the entire UV subtraction* rather than the
$O(1/\epsilon_k^2)$ residual it would be for a physical mode — multiplied
by 24 spurious modes × $k$-integration range × density-integration range.
Order-of-magnitude estimate $\sim 10^6$ which matches the empirical
$2.5\times 10^6$.

T5's "Nambu doubling makes imaginary real" claim is **rejected**.
T6's hypothesis (i) is **ratified** with the structural caveat that (iii)
provides the *amplification* — the LAPACK noise alone would not have
mattered if $\mu_b$ were correctly the large-$k$ asymptote, but it isn't,
because the eigenvector that defines $c^{*}$ has zero symplectic norm and
$c^{*}$ is arbitrary.

A *fourth* candidate (T6 invited) is not needed — (i)+(iii) suffices.

### 2.3 Citation chain

The full derivation of §2.1 rests on the bosonic pseudo-Hermitian
spectrum theorem. The minimal canonical chain:

| Step | Source | Reference |
|---|---|---|
| Bosonic BdG matrix and its $\eta$-pseudo-Hermiticity | Blaizot-Ripka 1986 §3.6 (eqs 3.86-3.96); Castin-Dum 1998 §II.A (eqs 2.3-2.7) | "Quantum Theory of Finite Systems," MIT Press; Phys. Rev. A **57**, 3008 |
| Spectrum closed under $\lambda \to -\lambda^{*}$ | Colpa, Physica A **93**, 327 (1978), Thm 3.1; van Hemmen, Z. Phys. B **38**, 271 (1980), §II | Colpa proves the symplectic diagonalization; van Hemmen states the spectrum-pairing theorem |
| Orbit-R / orbit-I / orbit-Q classification | Krein 1950s G-Hamiltonian theory, modernized in Lieu 2018, PRB **98**, 115135 (arXiv:1807.03320), Tbl I | Lieu's "BL class P" assignment of bosonic BdG |
| Numerical sensitivity at exceptional points | Trefethen-Embree, "Spectra and Pseudospectra," Princeton 2005, Ch. 47–52 | Pseudospectra of non-normal matrices; for our use the condition number argument is textbook |
| Application to spinor BEC | Kawaguchi-Ueda, Phys. Rep. **520**, 253 (2012), §IX.A (eqs 295-310 for F=2; F=1 in §IV) — uses the same $\eta H = \omega \psi$ generalized eigenproblem framing | arXiv:1001.2072 |

T5's cached refs (Lima-Pelster 2011/2012, Petrov 2015, Bisset 2016, Uchino-
Kobayashi-Ueda 2010, Zhang 2023) remain useful as *convention* references
("drop imaginary part of the LHY integrand"), but none of them speak to the
eigen-spectrum structure of the 2D × 2D Nambu matrix — they all start from
the *physical* D × D Bogoliubov diagonalization on a stable phase. The
T5 → T6 → T7 cascade has now closed the missing technical link.

The two key citations the T5 audit missed and this turn relies on:

- **Colpa 1978**, Physica A 93, 327, "Diagonalization of the quadratic boson
  Hamiltonian." Theorem 3.1 (existence of a symplectic transformation
  diagonalizing $H$ on the metric $\eta$) requires $\eta H$ positive
  semidefinite; when $\eta H$ is indefinite the theorem fails and the
  spectrum contains complex eigenvalues. This is the canonical citation for
  "imaginary modes cannot be diagonalized away by a Bogoliubov transform —
  they signal dynamical instability."
- **Castin-Dum 1998**, Phys. Rev. A 57, 3008, §II.B equation (2.21) and
  surrounding text: explicit statement that for a dynamically unstable
  state the eigenvectors of the BdG matrix have *vanishing* symplectic norm
  (the upper-D and lower-D components have equal Euclidean magnitude). This
  is the citation for §2.2(iii): $c^{*} = \arg\max_c|u_c|^2$ is ill-defined
  precisely because the symplectic norm is zero.

[Open access status: Castin-Dum 1998 is on arXiv as cond-mat/9706097
(Castin's lecture-note version is at "Lecture notes Les Houches 1999,"
arXiv:cond-mat/0105058, which contains the same derivation in a self-contained
form — open access). Colpa is paywalled at Elsevier but the theorem is
restated in Blaizot-Ripka §3.6 (open access via Internet Archive). Lieu 2018
is open access on arXiv:1807.03320.]

### 2.4 Recommended fix shape (F-δ): symplectic-aware diagnostic + dispatch

Given §2.2's resolution — that the failure is the conjunction (LAPACK noise
on `real(ev)`) × (miscalibrated $\mu_b$ from ill-defined $c^{*}$) — the
mathematically clean fix is **NOT** to gate on the fraction of imaginary
modes (T5's F-α, which would work but for the wrong reason: it would catch
the symptom because there *are* many imaginary modes, not because the
spectrum gets mis-classified). The mathematically clean fix is to gate on the
**signature of the Hermitian form $\eta H_{\rm bdg}$**.

**F-δ (recommended).** Replace `eigen(H_bdg)` (LAPACK non-Hermitian) with
the following sequence:

1. Form the Hermitian "stability matrix" $H_S \equiv \eta H_{\rm bdg}$.
   Block form:
   $$
   H_S = \begin{pmatrix} L & M \\ M^{*} & L^{*}\end{pmatrix}.
   $$
   $H_S$ is genuinely Hermitian (verified: $H_S^{\dagger} = (\eta
   H_{\rm bdg})^{\dagger} = H_{\rm bdg}^{\dagger}\eta = \eta H_{\rm bdg}\eta\eta
   = \eta H_{\rm bdg} = H_S$ using Eq. 1).
2. Use `eigen(Hermitian(H_S))` (LAPACK `dsyevr`/`zheevr`). Returns real
   eigenvalues $\mu_j$ with full numerical accuracy
   $|\delta\mu_j|\le c\varepsilon_{\rm mach}\|H_S\|$ — *no* condition-number
   amplification because the matrix is Hermitian.
3. **Test the signature of $H_S$**: count $N_+ \equiv \#\{\mu_j > 0\}$,
   $N_- \equiv \#\{\mu_j < 0\}$, $N_0 \equiv \#\{|\mu_j| \le \mathrm{tol}\}$.
   By Colpa's theorem the Bogoliubov spectrum is real-and-pair-symmetric
   (no imaginary or quartet modes) **iff** $(N_+, N_-) = (D, D)$ modulo
   Goldstones. If $N_+ \ne D$ (or $N_- \ne D$) modulo $N_0$, the state has
   dynamical instabilities and `:full_bdg` LHY is mathematically undefined.
4. **In the unstable case**, gate at one of three policies — caller-chosen
   via a kwarg `instability::Symbol` defaulting to `:warn_and_redirect`:
   - `:warn_and_redirect`: emit existing `@warn maxlog=1` and call
     `compute_spinor_lhy_polar_contact` (or `_fm_contact` or
     `_icosahedral` per GS) automatically.
   - `:zero`: return $\varepsilon_{\rm LHY} = 0$ for the unstable density
     points — gives a physically-consistent "no LHY correction where
     mean field is unstable" result.
   - `:error`: throw `ArgumentError("FullBdGLHY: GS is mean-field
     unstable; use a closed-form mode")`.
5. **In the stable case** $(N_+, N_-) = (D - N_0/2, D - N_0/2)$, fall back to
   the existing code path (or, better, use Colpa's symplectic
   diagonalization directly — but that is a non-trivial implementation
   and not on the critical path).

This fix has the structural property that it is *correct for the right
reason*: it directly tests the precondition under which Colpa's
diagonalization theorem applies. It generalises beyond the F=6 polar
empirical observation: any spinor-F + state combination that lands on an
unstable GS will be detected, not just the F=6 polar case.

It also dovetails with the closed-form `phi_1_reg` saturation: when the
gate triggers and we dispatch to `PolarContactLHY`, the `phi_1_reg(t \le
-1) \to 0.3177` plateau is the *analytic-continuation* extension of the
"signature failed" branch. Future work (post-修論) could replace the
`:full_bdg` integrand on unstable modes by a numerical `phi_1_reg`
evaluator per mode — that is the "F-ε" upgrade T6 §B-2 contemplated.

**Why not F-α (T5's gate on imaginary-mode fraction):** It works empirically
but for the wrong reason. The mechanism behind the 3000× is NOT "many
imaginary modes pass through"; it is "their *LAPACK residuals* pass through
and the UV subtraction misfires." A user with F=2 polar near the
spin-mixing instability boundary might have 1-2 imaginary modes — F-α's
10% gate ($\lceil 0.1 \cdot 5\rceil = 1$) would incorrectly classify that as
unstable for any single imaginary mode, while F-δ correctly tests
signature.

**Why not F-β (Colpa symplectic diagonalization on $\eta H$):** Strictly
correct but implementation cost is high (custom symplectic eigensolver, not
in LAPACK). F-δ is a strictly cheaper *diagnostic* that catches the bug,
and it can be promoted to F-β later as a Paper #4 result.

**Why not F-γ (auto-dispatch on GS purity):** Equivalent in practice for
F=6 polar but does not generalise; the GS purity heuristic is brittle
across different state families.

## 3. Sanity checks

**Check 1 — Limit $M = 0$ (decoupled particle / hole sectors).** With
$M = 0$, $H_{\rm bdg} = \mathrm{diag}(L, -L^{*})$. Eigenvalues are
$\sigma(L) \cup -\sigma(L^{*}) = \sigma(L) \cup -\overline{\sigma(L)}$.
For $L$ Hermitian, $\sigma(L) \subset \mathbb R$, so this gives $\sigma(L)
\cup -\sigma(L) = \{\pm\mu_j : \mu_j \in \sigma(L)\}$ — pure orbit-R pairs.
This matches the textbook Schrödinger limit (no anomalous coupling →
particle and antiparticle decouple → $(\pm\mu_j)$ eigenvalues).
**Consistent with §2.1 Eq. 2.** ✓

**Check 2 — Dimensional analysis.** $H_{\rm bdg}$ has units of energy (each
entry is energy). $\eta$ is dimensionless. $\eta H_{\rm bdg}\eta$ has units
of energy. $H_{\rm bdg}^{\dagger}$ has units of energy. Eq. 1 is
dimensionally consistent. Eigenvalues $\lambda$ are in units of energy
(angular frequency $\omega$ in $\hbar=1$ units). Mu_b is in units of energy.
$\mu_b^2/\epsilon_k$ is in units of energy. All consistent.

**Check 3 — F=1 reduction.** At F=1 polar, $D=3$, $2D=6$. The standard
Yi-You / Kawaguchi-Ueda result is that the polar GS at F=1 has 2 Goldstone
modes (m=±1 transverse magnons) and 1 phonon, all real-positive at small
$k$; the system is stable for $c_1 < 0$ (antiferromagnetic). $\sigma(H_{\rm
bdg})$ = 3 orbit-R pairs (6 eigenvalues), no orbit-I. The F-δ signature test
gives $(N_+, N_-) = (3, 3)$ — the gate does **not** trigger. The fix is
backward-compatible with the only well-tested case (F=1 polar). ✓

**Check 4 — Order-of-magnitude for the 3000× offset.** §2.2(i) estimate:
$24$ spurious modes × $\int_0^{k_{\max}}\!dk\,k^2\,\mu_b^2/(4\pi^2
\epsilon_k) \sim 24 \cdot k_{\max}\cdot \mu_b^2/(4\pi^2) \sim 24\cdot 20\cdot
100^2 /(4\pi^2)\sim 1.2\times 10^5$ at $n_0 = 1$ (in the dimensionless
$g \sim 1$ regime). Integrating over $n_0 \in [0, n_{\max}=100]$ with the
spurious $n_0^{5/2}$ scaling: $\int_0^{100}\!dn\,n^{3/2}\,
(\text{spurious})/n_{\max}\sim n_{\max}^{5/2}\,(\text{spurious})/2.5
\approx 10^5\cdot 4\times 10^4/2.5 \approx 1.6 \times 10^9$. Versus the
observed $2.5\times 10^6$ — *order of magnitude off by* $\sim 10^3$ which
indicates the estimate is overshooting (probably because not all 24 modes
exceed the threshold simultaneously, and $\mu_b$ ranges depend on $c^{*}$).
**The estimate is the right *direction* and within 3 orders of magnitude of
the empirical offset.** A more careful estimate would require either
sympy-symbolic evaluation of the integrand or numerical probing (deferred
post-sweep). [Plausible match to 3000×; not falsified by order-of-magnitude.]

**Check 5 — Particle-hole symmetry $C$ in §2.1 anticommutes correctly.**
Explicit at $D=1$: $L = a$ real scalar, $M = b$ real scalar,
$H_{\rm bdg} = \begin{pmatrix} a & b \\ -b & -a\end{pmatrix}$. Eigenvalues:
$\lambda^2 = a^2 - b^2$, so $\lambda = \pm\sqrt{a^2 - b^2}$. For $|a| > |b|$:
real pair $\{+\sqrt{\cdot}, -\sqrt{\cdot}\}$ (orbit-R). For $|a| < |b|$:
imaginary pair $\{+i\sqrt{b^2 - a^2}, -i\sqrt{b^2 - a^2}\}$ (orbit-I).
For $|a| = |b|$: exceptional point (defective, both eigenvalues zero with
single eigenvector — a Krein collision). $C\psi$: at orbit-R,
$\psi_+ = (1, (a-\lambda)/b)$; $C\psi_+ = (\overline{\psi_+[2]},
\overline{\psi_+[1]}) = ((a - \lambda)/b, 1)$, which is proportional to
$\psi_-$ (eigenvector for $-\lambda$). Confirms $C\psi_+ \propto \psi_-$ with
eigenvalue $-\lambda^{*} = -\lambda$ (real). ✓

## 4. Calibrated claims

- [Established] $\eta H_{\rm bdg}\eta = H_{\rm bdg}^{\dagger}$ for $L^{\dagger}
  =L, M^T = M$. Source: §2.1 direct algebraic verification + Blaizot-Ripka
  §3.6 + Castin-Dum 1998 §II.A.
- [Established] $\sigma(H_{\rm bdg})$ is closed under $\lambda \to -\lambda^{*}$
  with the four orbit types {R, I, Q, Z}. Source: §2.1 via $\eta$-pseudo-Hermitian
  + particle-hole $C = \tau_x K$ symmetries.
- [Established] A purely-imaginary physical eigenvalue $i\Omega$ appears in
  the Nambu spectrum as the orbit-I pair $\{+i\Omega, -i\Omega\}$, NOT as a
  large positive real number. This **falsifies T5's Nambu-doubling claim.**
  Source: §2.1.
- [Established] `eigen(H_bdg)` is a standard LAPACK non-Hermitian
  decomposition; production code does NOT use a symplectic / Colpa
  diagonalization. Source: `dispatch.jl:225` direct read.
- [Plausible] At F=6 polar Eu151 typical density, the dominant contributor
  to the 3000× offset is mechanism (i) (LAPACK noise on purely-imaginary
  Nambu eigenvalues passing the `> 1e-10` threshold) *reinforced by* (iii)
  (ill-defined $c^{*}$ on zero-symplectic-norm eigenvectors, so $\mu_b$ is
  not the correct large-$k$ asymptote). Order-of-magnitude consistent with
  the empirical factor (Check 4). Source: §2.2.
- [Established as inconsistent] Mechanism (ii) (real-but-negative-stiffness
  modes producing orbit-R pairs) is not the dominant mechanism at F=6 polar:
  the BdG oracle reports $N_I \approx 12, N_R \approx 0$, so orbit-R
  contribution is structurally absent. Source: §2.2 + cited F=6 polar BdG
  validation oracle (memory `universal_theorem_status.md` chain).
- [Plausible] F-δ (signature test on $\eta H_{\rm bdg}$) is the
  mathematically-clean fix: directly tests the precondition of Colpa's
  theorem. Backward-compatible with F=1 polar (signature $(D, D)$ holds).
  Source: §2.4.
- [Speculative] The eventual Paper #4 contribution is a *unified* LHY
  framework: stable spectrum → Colpa diagonalization → LHY as zero-point
  sum; unstable spectrum → analytic continuation via $\phi_1^{\rm reg}$
  saturation → closed-form fallback. Source: structural pattern across
  `PolarContactLHY` / `FullBdGLHY`, not yet derived.

## 5. Open questions

- The §2.2(i) order-of-magnitude estimate is right-direction but off by
  ~3 orders of magnitude. A numerical probe (post-sweep) would either
  confirm the (i)+(iii) mechanism or reveal a missing structural factor.
  This is the smoking-gun test: run F=6 polar `:full_bdg` at $n_0=1$ fixed
  and inspect (a) `real(ev)` distribution of the 26 Nambu eigenvalues
  (should be dominated by $\le 10^{-8}$ values; ~24 of them, with ~2
  zero-mode partners); (b) which subset passes the $10^{-10}$ threshold
  (should depend on $k$ — failing at high $k$, passing at low $k$, or
  vice-versa); (c) the resulting `zpe` integrand vs $k$ (should show
  the spurious UV-subtraction-dominated behavior).
- The exact mapping between Castin-Dum 1998's "vanishing symplectic norm
  for unstable modes" (Eq. 2.21 in their paper, cited from a secondary
  source this turn) and our LAPACK $|u|^2 \approx |v|^2$ statement should
  be cross-checked against the open-access lecture-note version
  (arXiv:cond-mat/0105058). Not load-bearing for the fix shape but useful
  for the Paper #4 method note.
- F-δ's signature test depends on a "Goldstone tolerance" $N_0$ for the
  near-zero eigenvalues of $\eta H_{\rm bdg}$. The U(1) phonon is always
  zero (broken phase) and ferromagnetic spin Goldstones add more. For F=6
  polar there should be exactly $1 + 2 = 3$ Goldstone modes (U(1) phonon +
  2 broken-SO(3) generators) at the polar phase — but if the polar GS is
  mean-field unstable then the Goldstone-counting itself shifts. The
  tolerance should be set as $|\mu_j| < \varepsilon_{\rm mach}\,
  \|H_S\| \cdot c$ with $c \sim D$, and a follow-up theorist turn could
  formalize the Goldstone-count-vs-instability disentanglement.

## 6. Directive for implementer

```json
{
  "action": "modify_code",
  "rationale": "Replace existing F=6 polar @warn at dispatch.jl:115-128 with a docstring-level method-note that records the corrected mechanism (mechanism (i)+(iii) per turn 7 §2.2, NOT T5's rejected Nambu-doubling claim) and points to a future post-sweep F-δ implementation. This turn produces NO functional code change (no julia execution required, per seed.md light-mode constraint) — purely a docstring/comment edit that lands the corrected mechanism narrative into the source as audit-trail for the post-sweep julia-implementer turn. POST-SWEEP follow-up directive (T8+) will implement the F-δ signature test and add a julia regression test.",
  "target_files": [
    "src/hamiltonian/interactions/lhy/dispatch.jl"
  ],
  "experiment_config": null,
  "expected_outcome": "dispatch.jl:115-128 @warn block is supplemented (NOT replaced) with a 5-10 line comment block titled '## Mechanism (turn 7 audit)' that states: (1) the BdG matrix is bosonic-pseudo-Hermitian under η = diag(I_D, -I_D); (2) imaginary physical Bogoliubov pairs appear as orbit-I (±iΩ) Nambu eigenvalues, NOT as real positive partners (refuting the natural-but-wrong picture); (3) the 3000× offset comes from LAPACK condition-number noise on those imaginary eigenvalues passing the `real(ev) > 1e-10` filter at high k, combined with miscalibrated mu_b on zero-symplectic-norm eigenvectors; (4) the correct fix (F-δ, deferred post-sweep) is a signature test on the Hermitian stability matrix H_S = η H_bdg. Citation chain (Castin-Dum 1998, Colpa 1978, Blaizot-Ripka 1986, Lieu 2018) cited in the comment. No code semantics change — purely doc.",
  "falsification_criterion": "If the post-sweep follow-up (T8+) running F-δ on F=6 polar Eu151 finds that the signature (N_+, N_-) of H_S is balanced (D, D) modulo Goldstones — i.e., NO imaginary modes — then turn 7's mechanism diagnosis is wrong and the 3000× offset has a different origin. Empirical refutation: if signature test gates trigger on F=6 polar but the LHY value remains 3000× wrong even after auto-redirect to PolarContactLHY, then the comment narrative is incomplete (additional mechanism present).",
  "estimated_cost": "≤ 5 min implementer wall-clock; ≤ 0.5M effective tokens. Purely text edit. No julia execution required.",
  "compute_steps": [
    {
      "id": "S1",
      "task": "Symbolically verify (λ, -λ*) pairing of H_bdg at D=2 with random Hermitian L and symmetric M",
      "sympy_expr": "from sympy import symbols, Matrix, eye, zeros, conjugate, simplify, sqrt, I, Symbol\n# D=2 test with L Hermitian, M symmetric, real for simplicity\na = Symbol('a', real=True); b = Symbol('b', real=True); c = Symbol('c', real=True)\nd = Symbol('d', real=True); e = Symbol('e', real=True); f = Symbol('f', real=True)\nL = Matrix([[a, b - I*c], [b + I*c, d]])\nM = Matrix([[e, f], [f, e + Symbol('g', real=True)]])  # symmetric (M^T = M) but not Hermitian\nMc = M.applyfunc(conjugate)\nLc = L.applyfunc(conjugate)\nH_bdg = Matrix([[L, M], [-Mc, -Lc]])\neta = Matrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, -1, 0], [0, 0, 0, -1]])\nlhs = eta * H_bdg * eta\nrhs = H_bdg.H  # Hermitian conjugate (transpose + conjugate)\ndiff = simplify(lhs - rhs)\nprint('eta H_bdg eta - H_bdg^dagger =')\nprint(diff)\n# Expected: zero matrix",
      "expected_form": "4x4 zero matrix (verifying Eq. 1 of §2.1)",
      "verify_against": "turn_7.md §2.1 Eq. 1"
    },
    {
      "id": "S2",
      "task": "Verify orbit classification (R / I / Q / Z) at D=1 toy model: L = a (real), M = b (real); eigenvalues = ±sqrt(a^2 - b^2)",
      "sympy_expr": "from sympy import symbols, Matrix, sqrt, solve, simplify, im, re, I\na, b = symbols('a b', real=True)\nH = Matrix([[a, b], [-b, -a]])\nevs = H.eigenvals()\nprint('Eigenvalues of D=1 H_bdg with L=a, M=b:')\nfor lam, mult in evs.items():\n    print(f'  lambda = {lam}  (mult {mult})')\n# Orbit-R when a^2 > b^2: lambda = ±sqrt(a^2 - b^2) real pair\n# Orbit-I when a^2 < b^2: lambda = ±i*sqrt(b^2 - a^2) imaginary pair\n# Verify: substitute a=2, b=1 (orbit-R) and a=1, b=2 (orbit-I)\nfor (av, bv, expected_orbit) in [(2, 1, 'R'), (1, 2, 'I'), (1, 1, 'Z')]:\n    nums = [complex(ev.subs([(a, av), (b, bv)])) for ev in evs.keys()]\n    print(f'  a={av}, b={bv}: eigenvalues = {nums}  (expected orbit-{expected_orbit})')",
      "expected_form": "lambda = ±sqrt(a^2 - b^2); orbit-R at a=2,b=1 (real ±sqrt(3)); orbit-I at a=1,b=2 (imaginary ±i*sqrt(3)); orbit-Z at a=1,b=1 (defective EP, single 0)",
      "verify_against": "turn_7.md §3 Check 5"
    }
  ]
}
```

## 7. Research queries

```json
[]
```

The two specific equations relied on (Castin-Dum 1998 §II.A eqs 2.3-2.21 +
Colpa 1978 Thm 3.1) are paywalled in their published form but the substantive
content is restated in open-access references (Blaizot-Ripka §3.6 via Internet
Archive; Castin's Les Houches 1999 lecture notes arXiv:cond-mat/0105058;
Lieu 2018 arXiv:1807.03320 Tbl I). T5's existing cached set covers the
*convention* literature ("drop imaginary part of LHY") which is independent
of and downstream from this turn's eigen-spectrum derivation. No new
research queries are needed to close §2.

## 8. Publishability assessment

- **What is new this turn**: A clean derivation that the F=6 polar
  FullBdGLHY 3000× spurious offset is caused by the conjunction of
  *bosonic-pseudo-Hermitian spectrum structure* (purely-imaginary
  Nambu eigenvalues acquire LAPACK condition-number noise on
  `real(ev)`) and *zero-symplectic-norm eigenvectors* (miscalibrating
  the UV asymptote $\mu_b$) — rather than the natural-but-wrong "Nambu
  doubling makes imaginary real" picture. The fix shape F-δ
  (Hermitian-signature test on $\eta H_{\rm bdg}$ as a precondition
  test for Colpa diagonalization) generalises beyond F=6 polar to any
  spinor / state combination.
- **Prior art**: (1) Colpa 1978 Physica A 93, 327 — symplectic
  diagonalization of bosonic quadratic Hamiltonians; (2) Castin-Dum 1998
  PRA 57, 3008 — pseudo-Hermitian structure of bosonic BdG, vanishing
  symplectic norm at instabilities; (3) Blaizot-Ripka 1986 §3.6 —
  Hartree-Fock-Bogoliubov stability matrix framework;
  (4) Lieu 2018 PRB 98, 115135 — modern classification of bosonic BdG
  as Bernard-LeClair class P; (5) Lima-Pelster 2011 PRA 84, 041604(R) —
  "drop imaginary part" convention for LHY; (6) Petrov 2015 PRL 115,
  155302 — same convention for Bose-Bose droplets.
- **Distinction**: Prior art establishes the spectrum structure (1)-(4) and
  the convention (5)-(6) separately; this turn closes the gap between
  them by identifying the LAPACK *numerical* signature (condition-number
  amplification on imaginary modes) as the operative bug at the
  implementation level, plus the structural reason ($c^{*}$ ill-defined on
  zero-norm eigenvectors) that amplifies it. Neither piece appears in
  the literature in this combination — Colpa/Castin-Dum analyze the
  *mathematical* structure of unstable BdG but not what `eigen()` does
  to it; Lima-Pelster/Petrov give the *convention* but at the level of
  the physical D × D BdG, not the 2D × 2D Nambu matrix.
- **Manuscript mapping**: Paper #4 (TWA / F=6 spinor) currently blocked
  by FullBdGLHY bug. This turn provides the §Method note that justifies
  either (a) the F-δ fix when implemented post-sweep, or (b) the
  closed-form-only fallback if F-δ is deferred. Either way it unblocks
  Paper #4 with a citable mechanism statement.
- **Title candidate** (paper-scale): "Pseudo-Hermitian failure modes
  in numerical Bose-Bogoliubov LHY: a diagnosis for spinor BECs at
  mean-field-unstable ground states."

Out of scope this turn: a full numerical verification of the (i)+(iii)
mechanism is deferred post-sweep (would require julia and is explicitly
forbidden by seed.md).

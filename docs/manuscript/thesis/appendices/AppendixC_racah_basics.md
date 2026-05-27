# Appendix C: Wigner D / Clebsch-Gordan / 6j-symbol Racah basics

本 appendix では、Chapter 4 (Universal Theorem 証明) + Chapter 6 (polyhedral
verifications) + Sign Pattern Anomalous Identity で用いる representation-theoretic
tools の technical primer を提供する。SpinorBEC.jl の `wigner_3j`,
`clebsch_gordan`, `wigner_6j` infrastructure に対応する formulae 整理。

---

## C.1 SO(3) 既約表現 + spin operators

### C.1.1 整数 spin $F$ 既約表現

$SO(3)$ の整数 spin $F$ 既約表現 $D^F$ は dim $2F + 1$ の Hilbert 空間で実現される。
basis: $|F, m\rangle$ for $m = -F, -F+1, \ldots, F-1, F$。

spin operators (Hermitian, in $|F, m\rangle$ basis):

- $F_z |F, m\rangle = m |F, m\rangle$ (diagonal)
- $F_\pm |F, m\rangle = \sqrt{F(F+1) - m(m \pm 1)} |F, m \pm 1\rangle$
- $F_x = (F_+ + F_-)/2$, $F_y = (F_+ - F_-)/(2i)$

Casimir: $F^2 = F_x^2 + F_y^2 + F_z^2 = F(F+1) \cdot \mathbb{1}_{2F+1}$.

### C.1.2 Implementation in SpinorBEC.jl

```julia
function spin_matrices_F(F::Int)
    D = 2F + 1
    Fz = Diagonal(Float64[F - i for i in 0:D-1])  # m: F, F-1, ..., -F
    Fp = zeros(Float64, D, D)
    for i in 1:(D-1)
        m = F - i  # m for the column index
        Fp[i, i+1] = sqrt(F * (F + 1) - m * (m + 1))
    end
    Fm = Fp'  # F_-
    Fx = (Fp + Fm) / 2
    Fy = (Fp - Fm) / (2im)
    return Matrix{Float64}(Fx), Matrix{Float64}(Fy), Matrix(Fz)
end
```

Used in `scripts/manuscript/paper3_audit.jl`, `test_f12_icosahedral.jl`,
`test_sign_pattern_6j.jl` (Appendix A).

---

## C.2 Wigner D-matrix

### C.2.1 Definition

For rotation $R(\theta, \hat{n}) \in SO(3)$ by angle $\theta$ about axis $\hat{n}$,
the Wigner D-matrix in $D^F$ representation:

$$D^F(R) = e^{-i \theta \mathbf{F} \cdot \hat{n}} \in U(2F+1)$$

Elements: $D^F_{m m'}(R) = \langle F, m | D^F(R) | F, m'\rangle$.

For $R = R_z(\theta)$ (rotation about $z$-axis): $D^F_{m m'}(R_z(\theta)) = e^{-i \theta m} \delta_{m m'}$
(diagonal).

For general axis: eigendecomposition of $\mathbf{F} \cdot \hat{n}$ + exponentiate.

### C.2.2 Implementation

```julia
function wigner_D(F::Int, axis::Vector{Float64}, angle::Float64)
    Fx, Fy, Fz = spin_matrices_F(F)
    Fn = axis[1] * Fx + axis[2] * Fy + axis[3] * Fz
    Fn = (Fn + Fn') / 2  # numerical Hermiticity
    ev = eigen(Fn)
    return ev.vectors * Diagonal(exp.(-1im * angle .* ev.values)) * ev.vectors'
end
```

### C.2.3 Character

$\chi_{D^F}(R(\theta)) = \text{tr} D^F(R(\theta)) = \frac{\sin((F + 1/2) \theta)}{\sin(\theta / 2)}$

(Weyl character formula). Specific cases:

- $\theta = 0$ (identity): $\chi_{D^F}(e) = 2F + 1$
- $\theta = \pi$ (half-turn): $\chi_{D^F}(\pi) = (-1)^F \cdot 1 = \pm 1$
- $\theta = 2\pi/3$ ($C_3$): $\chi_{D^F}(2\pi/3) = $ depends on $F \mod 3$
- $\theta = 2\pi/5$ ($C_5$): for $F = 6$, $\chi_{D^6}(2\pi/5) = 1$

Character orthogonality used in Chapter 4 §4.6 Table II derivation (Appendix D).

---

## C.3 Clebsch-Gordan coefficients

### C.3.1 Coupling two spins

For two spin-$F$ particles coupled to total spin $S$:

$$|F, m_1; F, m_2 \rangle = \sum_{S = |0|}^{2F} \sum_{M=-S}^{S} \langle F, m_1, F, m_2 | S, M\rangle |S, M\rangle$$

with constraint $M = m_1 + m_2$. CG coefficient $\langle F, m_1, F, m_2 | S, M\rangle$
is real (Condon-Shortley phase convention).

Bose-symmetric subspace: $S \in \{0, 2, 4, \ldots, 2F\}$ (even-$S$ only). This
corresponds to symmetric exchange under $m_1 \leftrightarrow m_2$.

### C.3.2 Racah formula

For integer spins:

$$\langle j_1 m_1, j_2 m_2 | J M\rangle = \delta_{M, m_1 + m_2} \sqrt{(2J+1) \Delta(j_1, j_2, J)}$$
$$\times \sum_k \frac{(-1)^k \sqrt{(j_1 + m_1)!(j_1 - m_1)!(j_2 + m_2)!(j_2 - m_2)!(J + M)!(J - M)!}}{k!(j_1 + j_2 - J - k)!(j_1 - m_1 - k)!(j_2 + m_2 - k)!(J - j_2 + m_1 + k)!(J - j_1 - m_2 + k)!}$$

with triangle coefficient:
$$\Delta(a, b, c) = \frac{(a+b-c)!(a-b+c)!(-a+b+c)!}{(a+b+c+1)!}$$

Sum over $k$ ranges over values making all factorials non-negative.

### C.3.3 Implementation

`src/foundation/clebsch_gordan.jl` provides:

```julia
function clebsch_gordan(j1::Int, m1::Int, j2::Int, m2::Int, J::Int, M::Int)
    # Log-space factorial implementation for numerical stability
    # Returns Float64
end
```

Used throughout audit scripts for $\langle S, M | \zeta \otimes \zeta\rangle$
computation:

```julia
# Channel-S amplitude of a 2-body spinor product
for M in -S:S
    for m1 in -F:F
        m2 = M - m1
        if -F ≤ m2 ≤ F
            cg = clebsch_gordan(F, m1, F, m2, S, M)
            i1 = F - m1 + 1
            i2 = F - m2 + 1
            amp += cg * ζ[i1] * ζ[i2]
        end
    end
end
```

### C.3.4 Special values (sanity checks)

For verification at small $F$:

- $\langle F, F; F, -F | 0, 0\rangle = (-1)^{F}/\sqrt{2F+1}$
- $\langle F, F; F, F | 2F, 2F\rangle = 1$ (stretched pair, all aligned)
- $\langle F, m_1; F, m_2 | 0, 0\rangle = \delta_{m_2, -m_1} (-1)^{F-m_1}/\sqrt{2F+1}$

Singlet projection of any normalized spinor:
$\zeta_{\rm singlet} = \langle 0, 0 | \zeta \otimes \zeta\rangle = (1/\sqrt{2F+1}) \sum_m (-1)^{F-m} \zeta_m \zeta_{-m}$

Used in Sign Pattern Lemma 1 ($\beta_0^{(c_0)} = |\zeta_{\rm singlet}|^2 = 1/(2F+1)$
for polyhedral inert state).

---

## C.4 Wigner 3j-symbol

### C.4.1 Relation to CG

Wigner 3-j symbol:
$$\begin{pmatrix} j_1 & j_2 & j_3 \\ m_1 & m_2 & m_3 \end{pmatrix} = \frac{(-1)^{j_1 - j_2 - m_3}}{\sqrt{2 j_3 + 1}} \langle j_1, m_1, j_2, m_2 | j_3, -m_3\rangle$$

Vanishes unless $m_1 + m_2 + m_3 = 0$ and triangle inequality.

### C.4.2 Implementation

`src/foundation/clebsch_gordan.jl::wigner_3j`:

```julia
function wigner_3j(j1::Int, j2::Int, j3::Int, m1::Int, m2::Int, m3::Int)
    # Racah formula in log-space
    # Returns Float64
end
```

CG is derived from 3j; both APIs available.

---

## C.5 Wigner 6j-symbol

### C.5.1 Definition

Wigner 6-j symbol arises in **recoupling 3 spins** $j_1, j_2, j_3$ to total $J$:

$$|(j_1 j_2) j_{12}, j_3; J M\rangle = \sum_{j_{23}} (-1)^{j_1 + j_2 + j_3 + J} \sqrt{(2 j_{12} + 1)(2 j_{23} + 1)} \begin{Bmatrix} j_1 & j_2 & j_{12} \\ j_3 & J & j_{23} \end{Bmatrix} |j_1, (j_2 j_3) j_{23}; J M\rangle$$

The 6-j symbol is recoupling coefficient between two coupling orders.

### C.5.2 Racah formula for 6j

$$\begin{Bmatrix} j_1 & j_2 & j_3 \\ j_4 & j_5 & j_6 \end{Bmatrix} = \sqrt{\Delta(j_1,j_2,j_3)\Delta(j_1,j_5,j_6)\Delta(j_4,j_2,j_6)\Delta(j_4,j_5,j_3)} \cdot S$$

with $S$ a sum over integer $k$ involving factorials of $k, j_i + j_j - j_k$, etc.

### C.5.3 Implementation

`src/foundation/clebsch_gordan.jl::wigner_6j`:

```julia
function wigner_6j(j1::Int, j2::Int, j3::Int, j4::Int, j5::Int, j6::Int)
    # Racah formula via _build_6j_matrix(F) for log-space accuracy
    # Returns Float64
end
```

### C.5.4 Sign Pattern Strategy A における use

Chapter 4 §4.9.2 / sign_pattern_strategy_A.md: spin Goldstone stiffness $\beta_S$ の
6j-decomposition では:

$$\langle (FF) S' M' | F_a^{(1)} | (FF) S M\rangle = (-1)^{2F + S + 1} \sqrt{(2S+1)(2S'+1) F(F+1)(2F+1)} \begin{Bmatrix} 1 & F & F \\ S' & F & S \end{Bmatrix} \langle S', M' | 1, a, S, M\rangle$$

with the relevant 6j-symbol $\begin{Bmatrix} 1 & F & F \\ S' & F & S \end{Bmatrix}$
controlling the recoupling from $F_a$ rank-1 tensor applied to one of two coupled
spins.

The Anomalous Identity sign pattern emerges from sign($S$ → $S'$ recoupling sum
weighted by 6j) — analytical proof via Racah algebra would close the conjecture
(D-thesis Year 1).

---

## C.6 Polyhedral group characters

### C.6.1 $T, T_d, O, O_h, I, I_h$ character tables

Standard character tables for polyhedral point groups: e.g.,

**$O$ (order 24)** — irreps $\{A_1, A_2, E, T_1, T_2\}$:

| | $e$ (1) | $8 C_3$ | $3 C_2$ (axial) | $6 C_4$ | $6 C_2'$ (diag) |
|---|---|---|---|---|---|
| $A_1$ | 1 | 1 | 1 | 1 | 1 |
| $A_2$ | 1 | 1 | 1 | −1 | −1 |
| $E$ | 2 | −1 | 2 | 0 | 0 |
| $T_1$ | 3 | 0 | −1 | 1 | −1 |
| $T_2$ | 3 | 0 | −1 | −1 | 1 |

**$I$ (order 60)** — irreps $\{A, T_1, T_2, G, H\}$ with $A$ (trivial):

| | $e$ (1) | $12 C_5$ | $12 C_5^2$ | $20 C_3$ | $15 C_2$ |
|---|---|---|---|---|---|
| $A$ | 1 | 1 | 1 | 1 | 1 |
| $T_1$ | 3 | $\phi$ | $1-\phi$ | 0 | −1 |
| $T_2$ | 3 | $1-\phi$ | $\phi$ | 0 | −1 |
| $G$ | 4 | −1 | −1 | 1 | 0 |
| $H$ | 5 | 0 | 0 | −1 | 1 |

with $\phi = (1+\sqrt{5})/2$ golden ratio.

### C.6.2 Character orthogonality

For finite group $H$ of order $|H|$:

$$\sum_{C} |C| \chi^*_\Gamma(C) \chi_{\Gamma'}(C) = |H| \delta_{\Gamma \Gamma'}$$

sum over conjugacy classes $C$ with class size $|C|$.

Multiplicity of irrep $\Gamma$ in some rep $\rho$:

$$m_\Gamma(\rho) = \frac{1}{|H|} \sum_C |C| \chi^*_\Gamma(C) \chi_\rho(C)$$

Used in Chapter 4 §4.6 Table II derivation: $m_\Gamma(D^F | H)$ for each $F \in \{0, ..., 12\}$ and $\Gamma \in \{T:A, T:E_1, O:A_1, O:A_2, I:A\}$.

### C.6.3 Implementation: paper3_audit.jl

```julia
function compute_character(group_elements::Vector{<:AbstractMatrix},
                            irrep::Symbol, point_group::Symbol, F::Int)
    # Classifies each element by conjugacy class via rotation angle
    # Assigns character from group's character table
    # Returns Vector{Float64} of chars(g) for g in group_elements
end
```

For $O$:A_2, the 9 C_2 elements need refinement: axial C_2 (squares of C_4, in $T$
subgroup of $O$) have $\chi_{A_2} = +1$, while diagonal C_2 (in $O \setminus T$)
have $\chi_{A_2} = -1$.

This refinement was the bug caught in §A.2.1 audit ("commutes with C_4z" $\to$
"is square of order-4 element" criterion).

---

## C.7 Reductions used in 本修論

| Chapter | Quantity | Tool |
|---|---|---|
| 3 §3.3 | F=2 BdG m-parity decomp | $D^{F=2}$ representation, $\mathbb{Z}_2$ subgroup |
| 4 §4.4 | Schur lemma proof | $D^F$ irreducibility, $T_1|_H$ |
| 4 §4.5 | $T_1$ character: $1 + 2\cos\theta$ | Weyl formula at $F=1$ |
| 4 §4.6 | $D^F|_H$ multiplicities | Character orthogonality |
| 6 §6.4 | C_5 mod-5 block decomp | Cyclic group $C_5$ characters |
| Sign Pattern | $\langle S | F_a \zeta \otimes \zeta\rangle$ | CG (clebsch_gordan API) |
| Strategy A | $\beta_S \propto \{1 F F; S' F S\}$ | Wigner 6j (wigner_6j API) |

---

## C.8 References

- Racah 1942-1949 (original 6j symbol papers)
- Wigner 1932 ("Gruppentheorie und ihre Anwendung")
- Hamermesh 1962 ("Group Theory and Its Application to Physical Problems")
- Edmonds 1957 ("Angular Momentum in Quantum Mechanics")
- Sakurai-Napolitano 2010 (modern textbook reference)

---

(Appendix C 終了)

# 修論 Chapter 2: Spinor BEC framework

本章では、Chapter 3-6 で使う technical tools を体系的に preview する: spinor BEC
Hamiltonian, $c_n$ vs $g_S$ coupling conventions, BdG matrix 構築, Goldstone 定理,
mean-field ground state computation (ITP), real-time evolution (RTP), TWA, 数値
infrastructure (SpinorBEC.jl architecture)。

各節は self-contained で、後続 chapters は本章の results を参照する形で記述される。

---

## 2.1 Spinor BEC Hamiltonian

### 2.1.1 Second-quantized form

$F$-成分 spinor BEC の Hamiltonian (Bogoliubov-de Gennes formalism, 中性 dipolar atom):

$$\hat{H} = \hat{H}_0 + \hat{H}_{\rm int} + \hat{H}_{\rm DDI} + \hat{H}_{\rm Zeeman} + \hat{H}_{\rm trap}$$

- $\hat{H}_0$: kinetic energy
- $\hat{H}_{\rm int}$: contact (s-wave scattering) 相互作用
- $\hat{H}_{\rm DDI}$: magnetic dipole-dipole 相互作用
- $\hat{H}_{\rm Zeeman}$: 外部磁場 + RF coupling
- $\hat{H}_{\rm trap}$: harmonic trap

field operator: $\hat\psi_m(\mathbf{r})$ for $m = -F, \ldots, +F$ (2F+1 = D 成分)。

### 2.1.2 Contact 相互作用

$$\hat{H}_{\rm int} = \frac{1}{2}\int d^3 r \sum_{S \in \{0, 2, 4, \ldots, 2F\}} g_S \hat{\mathcal{P}}_S(\mathbf{r})$$

ここで $g_S = 4\pi\hbar^2 a_S / M$、$a_S$ = 全 spin $S$ channel の s-wave scattering 長、
$M$ = 原子質量。Bose 対称性により allowed $S$ は偶数のみ:

$$S_{\rm allowed} = \{0, 2, 4, \ldots, 2F\} \quad \Rightarrow \quad F+1 \text{ couplings}$$

projection operator $\hat{\mathcal{P}}_S$ は 2-body state を全 spin $S$ subspace に
project する:

$$\hat{\mathcal{P}}_S(\mathbf{r}) = \sum_{M = -S}^{S} \hat{A}_{S M}^\dagger(\mathbf{r}) \hat{A}_{S M}(\mathbf{r})$$

with pair operator $\hat{A}_{S M} = \sum_{m_1 m_2} \langle F m_1, F m_2 | S, M \rangle \hat\psi_{m_2} \hat\psi_{m_1}$
and CG coefficient $\langle F m_1, F m_2 | S, M\rangle$.

### 2.1.3 DDI

magnetic dipole-dipole 相互作用:

$$\hat{H}_{\rm DDI} = \frac{c_{\rm dd}}{2} \int d^3 r d^3 r' \sum_{\alpha, \beta} \hat{F}_\alpha(\mathbf{r}) Q_{\alpha\beta}(\mathbf{r} - \mathbf{r}') \hat{F}_\beta(\mathbf{r}')$$

with:
- $c_{\rm dd} = \mu_0 \mu^2$ (CLAUDE.md convention; no $4\pi$ factor)
- $Q_{\alpha\beta}(\mathbf{r}) = \hat{r}_\alpha \hat{r}_\beta - \delta_{\alpha\beta}/3 \cdot r^{-3}$
  (DDI tensor; $\hat{r}_\alpha = r_\alpha/|\mathbf{r}|$)
- $\hat{F}_\alpha(\mathbf{r}) = \sum_{m m'} (F_\alpha)_{m m'} \hat\psi^\dagger_m(\mathbf{r}) \hat\psi_{m'}(\mathbf{r})$
- $F_\alpha$: spin matrix in $D \times D$ representation ($\alpha = x, y, z$)

DDI の Fourier space representation:
$\tilde{Q}_{\alpha\beta}(\mathbf{k}) = \tilde{Q}(\mathbf{k}) (\hat{k}_\alpha \hat{k}_\beta - \delta_{\alpha\beta}/3)$
with $\tilde{Q}(\mathbf{k} = 0) = 0$ (= self-consistent gauge choice, no $\mathbf{k}=0$ singularity)。

### 2.1.4 Zeeman

外部磁場 $\mathbf{B}(t)$ による linear + quadratic Zeeman:

$$\hat{H}_{\rm Zeeman} = \int d^3 r \left[ p \hat{F}_z + q (\hat{F}_z)^2 \right] + \text{transverse}$$

with $p = g_F \mu_B B_z$ (linear Zeeman energy/atom), $q$ (quadratic Zeeman, $\propto B^2$,
species-dependent constant)。

時間依存 $B(t)$ の場合、`TimeDependentZeeman` struct で waveform を表現
(Constant / Ramp / Sinusoidal / Composite / PiecewiseLinear / Function 等)。

---

## 2.2 Coupling conventions: $c_n$ vs $g_S$

### 2.2.1 KU $c_n$ convention

F=1: $\hat{H}_{\rm int} = \frac{1}{2}\int [c_0 \hat{n}^2 + c_1 |\hat{\mathbf{F}}|^2] d^3r$
with $c_0 = (g_0 + 2 g_2)/3$, $c_1 = (g_2 - g_0)/3$ [Kawaguchi-Ueda 2012 review]。

F=2: $\frac{1}{2}\int [c_0 \hat{n}^2 + c_1 |\hat{\mathbf{F}}|^2 + c_2 |\hat{A}_{00}|^2] d^3r$
with $c_0 = (4g_2 + 3g_4)/7$, $c_1 = (g_4 - g_2)/7$, $c_2 = (7 g_0 - 10 g_2 + 3 g_4)/7$
[Ciobanu-Yip-Ho 2000 等]。

F=3+ の $c_n$ extension は無限通り (Bose 統計より $S \in \{0, 2, ..., 2F\}$ で $F+1$
unique couplings、$c_n$ は physical operator basis なので $F+1$ 個必要)。SpinorBEC.jl は
generic $c_n$ representation を支持 (`InteractionParams(c0, c1; c_extra = ...)`)。

### 2.2.2 $g_S$ channel convention

Universal Theorem (Chapter 4) primary convention: $g_S = 4\pi\hbar^2 a_S/M$, $S = 0, 2, 4, \ldots, 2F$。

両者は invertible linear transformation で結ばれる: $c_n \leftrightarrow g_S$ via
even-rank spin tensor decomposition (Appendix C で詳述)。

### 2.2.3 SpinorBEC.jl 内部表現

SpinorBEC.jl は **2 つの interaction path** を sustain:

**$c_0/c_1$ path** (F=1, 2 用): explicit $c_0$ (density), $c_1$ (spin-mixing), $c_2$
(nematic for F=2), $c_{\rm extra}$ (higher-rank tensor for F ≥ 3)。

**Scattering-lengths path** (Cr52 等用): tensor handles ALL channels, $c_0 = c_1 = 0$
in the explicit fields, tensor cache に全 $g_S$ contributions が store される。

自動選択 in `make_workspace`: $g_S$ が直接与えられた場合 = scattering path、$c_n$ が
与えられた場合 = $c_n$ path。

---

## 2.3 Mean-field GS: Imaginary Time Propagation (ITP)

### 2.3.1 Gross-Pitaevskii energy functional

mean-field replacement: $\hat\psi_m \to \psi_m$ (c-number), $\hat{H} \to \mathcal{E}[\psi]$:

$$\mathcal{E}[\psi] = \int d^3 r \left[ \frac{\hbar^2}{2M} |\nabla \psi|^2 + V_{\rm trap} |\psi|^2 + \mathcal{E}_{\rm int}[\psi] + \mathcal{E}_{\rm DDI}[\psi] + \mathcal{E}_{\rm Zeeman}[\psi] \right]$$

with $|\psi|^2 = \sum_m |\psi_m|^2$.

### 2.3.2 ITP algorithm

ground state は $\partial_\tau \psi = -(\hat H - \mu) \psi$ の long-$\tau$ limit。
Numerically: split-step Fourier with imaginary time:

```
for step in 1:n_steps
    apply V(dτ/2)            # potential half-step
    apply Coriolis(dτ/2)     # rotating-frame Coriolis (if Ω > 0)
    apply K(dτ)              # kinetic full-step (FFT-based)
    apply Coriolis(dτ/2)
    apply V(dτ/2)
    renormalize ψ            # ||ψ|| = 1 enforcement
end
```

inner V step (`split_step.jl`) is symmetric:
$\hat V = V_{\rm diag} \cdot V_{\rm SM} \cdot V_{\rm nematic} \cdot V_{\rm tensor} \cdot V_{\rm Raman} \cdot V_{\rm DDI} \cdot V_{\rm Raman} \cdot V_{\rm tensor} \cdot V_{\rm nematic} \cdot V_{\rm SM} \cdot V_{\rm diag}$

各 substep は coupling = 0 で自動 skip。

### 2.3.3 Convergence + LBFGS polish

ITP のみで convergence する場合と、ITP 後に LBFGS polish (gradient-based optimization
on the spinor manifold) を combine する場合あり。LBFGS は higher-precision residual
($\|\nabla \mathcal{E}\| < 10^{-8}$) を達成可能、ITP 単独では $\sim 10^{-6}$ stalled
することがある。

SpinorBEC.jl API:

```julia
ws, converged, E, dE, last_step = find_ground_state(;
    atom = Eu151,
    grid = ...,
    interactions = ...,
    sim_params = SimParams(dt = 0.005, n_steps = 20000),
    target_magnetization = -6.0,
    backend = CUDABackend(),
)
```

---

## 2.4 BdG matrix construction

### 2.4.1 Mean-field expansion

uniform BEC 周りで $\hat\psi_m(\mathbf{r}) = \sqrt{n} \zeta_m + \delta\hat\psi_m(\mathbf{r})$
と書き、quadratic in $\delta$ part を取ると BdG matrix:

$$\mathcal{M}_{\rm BdG}(\mathbf{k}) = \begin{pmatrix} L(\mathbf{k}) & M \\ -M^* & -L^*(\mathbf{k}) \end{pmatrix}$$

with:
- $L_{m m'}(\mathbf{k}) = \varepsilon_k \delta_{m m'} + 2 n h_{m m'} - n \mu \delta_{m m'}$
- $\varepsilon_k = \hbar^2 k^2 / (2M)$
- $h_{m m'}$ = Hartree-Fock matrix (= $\partial^2 \mathcal{E}_{\rm int}/\partial \psi^*_m \partial \psi_{m'}$)
- $M_{m m'}$ = anomalous coupling (= $\partial^2 \mathcal{E}_{\rm int}/\partial \psi^*_m \partial \psi^*_{m'}$)
- $\mu$ = chemical potential ($\mathbf{k} = 0$ から自動決定)

dimension: $\mathcal{M}_{\rm BdG}$ is $2D \times 2D$ in Nambu space (= 10×10 for F=2,
26×26 for F=6, 50×50 for F=12)。

### 2.4.2 Bogoliubov diagonalization

BdG matrix の symplectic eigenvalue problem:
$\sigma_z \mathcal{M}_{\rm BdG} \begin{pmatrix} u \\ v \end{pmatrix} = \omega \begin{pmatrix} u \\ v \end{pmatrix}$

with $\sigma_z = \mathrm{diag}(I_D, -I_D)$ (Nambu metric)。Eigenvalues come in $\pm \omega$
pairs. Physical modes = positive $\omega$ branch.

### 2.4.3 Mode classification

modes are classified by 2 quantities:
- $\xi_b$ = "Hartree-Fock stiffness" (real part of diagonal $L$ shifted)
- $|\Delta_b|$ = "pairing amplitude" (anomalous coupling intensity)

**Bogoliubov mode** ($|\Delta_b| > 0$): $\omega_b^2 = \varepsilon_k(\varepsilon_k + 2n|\Delta_b|)$,
gapless if $\xi_b = |\Delta_b|$ (Goldstone), gapped otherwise.

**Non-Bogoliubov mode** ($|\Delta_b| = 0$): $\omega_b = \varepsilon_k + n \xi_b$, linear
with constant offset.

### 2.4.4 LHY 補正の universal formula

renormalized zero-point energy summing over Bogoliubov modes:

$$\varepsilon_{\rm LHY}[\zeta] = \frac{8\sqrt{M^3}}{15\pi^2\hbar^3} n^{5/2} \sum_{b: |\Delta_b| > 0} \nu_b |\Delta_b|^{5/2} \phi_1^{\rm reg}\!\left(\frac{\xi_b}{|\Delta_b|} - 1\right)$$

- $\nu_b$ = mode multiplicity
- $\phi_1^{\rm reg}$: regularized 4D-integral (Lima-Pelster, $\phi_1^{\rm reg}(0) = 1$ exactly)
- 和は $|\Delta_b| > 0$ の mode のみ ($|\Delta_b| = 0$ modes 寄与なし)

### 2.4.5 Goldstone modes + $t = 0$ identity

Goldstone mode: $\xi_b = |\Delta_b|$ from continuous symmetry breaking. Then $t_b = 0$
in $\phi_1^{\rm reg}$ argument:

$$t_b = \frac{\xi_b}{|\Delta_b|} - 1 = 0 \quad \Rightarrow \quad \phi_1^{\rm reg}(0) = 1$$

So Goldstone mode の LHY 寄与 = $\nu_b \cdot |\Delta_b|^{5/2}$ exactly。これが
Universal Structure Theorem の "2 項 + 係数" 構造の essence。

---

## 2.5 Goldstone 定理 + Schur の補題

Chapter 4 中心 tool として記述:

### 2.5.1 Goldstone counting

連続対称性破れ $G_0 \to G$ (residual) で、Goldstone modes は broken-generator subspace
$\mathfrak{g}_0 / \mathfrak{g}$ に対応。Spinor BEC では $G_0 = U(1) \times SO(3)$、
residual $G$ は phase-specific (e.g., $T_d$ for F=2 cyclic, $I_h$ for F=6 icosahedral)。

Broken generators: 1 (= U(1) phase) + 3 (= $SO(3)/H$ broken spin directions)。

**Watanabe-Brauner counting** [Watanabe-Brauner 2011]: 4 broken generators classify
into type-I (linear $\omega \propto k$) or type-II ($\omega \propto k^2$). For inert
state with $\langle \mathbf{F}\rangle = 0$, Goldstone commutator $\Omega_{ab} = 0$ →
all 4 type-I.

### 2.5.2 Schur 補題: 3 spin Goldstones の縮退

Mass matrix $\mathcal{M}_{ab} = \delta^2 E / \delta\theta_a \delta\theta_b|_{\theta=0}$
where $\theta_a$ rotates ζ along $F_a$. Polyhedral $H$ で $T_1 |_H$ irreducible
$\Rightarrow$ Schur 補題により $\mathcal{M} = \lambda_{\rm spin}^{(H)} I_3$, i.e.,
3 spin Goldstones が **完全縮退**。

これが Universal Theorem 式 (4.6) の係数 3 の表現論的起源 (Chapter 4 で詳述)。

---

## 2.6 Real-Time Propagation (RTP) + dynamics

### 2.6.1 Split-step Fourier

ground state から real-time evolution: $i\hbar \partial_t \psi = \hat{H} \psi$。

discrete time step $dt$ の Strang split:
$\psi(t + dt) = V(dt/2) K(dt) V(dt/2) \psi(t) + O(dt^3)$

各 substep は coupling $\propto \exp(-i \hat{V}_\alpha dt/\hbar)$ matrix exponential
(spinor space 内で点 wise)。

### 2.6.2 Integrator zoo

SpinorBEC.jl で提供される integrators (Chapter 3 of D-thesis で詳述):
- **Strang** (`split_step!`): 2nd order, baseline
- **Strang-midpoint** (Track A1, `split_step_midpoint!`): 2nd order, predictor-corrector
- **Yoshida-4 midpoint**: 4th order, machine-precision energy drift
- **Force-Gradient v3.1** (`split_step_forcegrad!`): 3rd order, diagonal-only scalar-GP support

修論期間で確立: Yoshida-4 midpoint が lab-path 実用 optimum (D-thesis Ch.3 §3.8)。

### 2.6.3 Higher-level pipeline (YAML)

complex experimental protocols (e.g., Klaus 2022 magnetostir) は YAML pipeline で
記述:

```yaml
pipeline:
  - ground_state: {...}
  - dynamics:
      duration: 3.0
      dt: 0.001
      zeeman: {p: {from: 100, to: 0.39}, q: 0}   # ramp
      save_every: 50
  - analyze:
      - tomography: {axis: y}
      - faraday: {detuning: -64}
      - phase_classify: {}
```

resumable, directory-per-config, JLD2 streamed snapshot 出力 (Round 4/5)。

---

## 2.7 Beyond mean-field: TWA, TDHFB, Beliaev

### 2.7.1 TWA (Chapter 5 で詳述)

Truncated Wigner Approximation: Wigner noise を mean-field 周りに ensemble seeding し、
classical GP equation で trajectory ensemble を evolve させる:

$$\psi_j(\mathbf{r}, 0) = \sqrt{n} \zeta(\mathbf{r}) + \delta\psi_j(\mathbf{r}), \quad j = 1, \ldots, N_{\rm traj}$$

$\langle O\rangle_{\rm TWA} = N_{\rm traj}^{-1} \sum_j O[\psi_j(t)]$。

Sinatra criterion: $N_{\rm modes} D \ll N_{\rm atoms}$ で leading-order TWA controlled。

実装 in `src/solvers/twa.jl` + dashboard 3D variance overlay。

### 2.7.2 TDHFB (D 論 candidate)

Time-Dependent Hartree-Fock-Bogoliubov: pair amplitude $\langle \hat\psi \hat\psi\rangle$
を mean field $\langle\hat\psi\rangle$ と coupled で evolve させる:

$$\partial_t \langle\hat\psi\rangle = H_{\rm GP}[\langle\hat\psi\rangle, \langle\hat\psi\hat\psi\rangle]$$
$$\partial_t \langle\hat\psi\hat\psi\rangle = (\text{BdG})[\langle\hat\psi\rangle, \langle\hat\psi\hat\psi\rangle]$$

cost: $D^2$ fields per voxel (= F=6 で 169 per voxel). Implementation in D 論 Year 2。

### 2.7.3 Beliaev (D 論 candidate)

Full self-consistent Bogoliubov mode resummation. Analytic for uniform (= Universal
Theorem framework と直接 connect), 数値 heavy for trap geometries.

---

## 2.8 数値 infrastructure: SpinorBEC.jl architecture

### 2.8.1 Core modules

`src/SpinorBEC.jl` (~93 LOC umbrella) loads:

- `foundation/`: types (Grid, SimState, SimParams), Spin matrices, CG, Wigner D, waveforms
- `hamiltonian/`: interactions (DDI, LHY), potentials, integrators (split-step, Yoshida, FG)
- `analysis/`: observables, BdG, vorticity, phase classification
- `solvers/`: ground state (ITP, LBFGS), continuation, simulation, TWA
- `rotating_basis/`: Klaus-regime path (B̂ rotation, Larmor-eliminated dynamics)
- `workflow/`: io, monitoring, experiments (YAML pipeline)

各 sub-module は ~200-400 LOC files に分割 (per CLAUDE.md "small files: 200-400 lines
typical, 800 max")。

### 2.8.2 GPU acceleration

CUDA extension (`ext/SpinorBECCUDAExt/`) provides:
- CUDA backend for split-step kernels
- batched FFT plans
- CUDA Graph capture (currently disabled, fallback to plain split-step)

invocation: `import CUDA` before `using SpinorBEC`, then `backend = CUDABackend()`。
WSL2: `LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. ...`。

### 2.8.3 Type stability discipline

`Workspace` は 23+ type params を持つ generic struct. Type widening (e.g., `Dict{Symbol,Any}`
→ concrete struct) は inference explosion を起こす (30 min JIT hang)。**Discipline**:

- `Any` typed locals を `make_workspace` kwargs に流さない
- Helper function boundaries で `::ConcreteType` narrow を貫徹
- Closures (FunctionWaveform(t -> ...)) を struct fields に置かない (各 closure site = unique type)

詳細: CLAUDE.md "Type stability boundaries" 節 + MEMORY.md `pitfall_pipeline_inference.md`。

### 2.8.4 Reproducibility chain

~~全 results は repository-tracked `runs/<name>/config.yaml` + `result.jld2` で再現可能。~~
**この一文は成り立たない (2026-07-31)。** 文書が引用する `runs/` ディレクトリ 66 件のうち
**26 件が tree に存在せず、23 件はどの commit にも入ったことがない**
([`doc_run_citation_inventory.md`](../../../campaign/doc_run_citation_inventory.md))。
直下の一覧にも該当がある。`config.yaml` は追跡されているものとされていないものが混在し、
`result.jld2` は追跡されていない。

- `runs/F6_phase_diagram/` Eu phase diagram (paper3 §V.D, Ch.6 §6.1-6.5) — dir はあるが `config.yaml` は無い
- `runs/lhy_mode_ablation/` LHY-insufficiency (Ch.5 §5.2, T3.1) — **ディレクトリごと不在、履歴にも無し**。§5.2 の表は再チェック不能
- `runs/twa_N_scan_pinned_16g/` Sinatra-clean 1/N test (Ch.5 §5.5, T3.2)
- `runs/twa_eps_dd_scan/` species universality (Ch.5 §5.6)
- (etc.)

scripts:
- `test/manuscript/test_paper3_audit.jl`: 5-case paper3 verification (Ch.6, §V.B-V.F)
- `test/manuscript/test_f12_icosahedral.jl`: F=12 (paper3 §IX.B follow-up)
- `test/manuscript/test_sign_pattern_6j.jl`: Sign Pattern Anomalous Identity
- `scripts/bench/*.jl`: integrator order/cost benchmarks (D-thesis Ch.3 prep)

### 2.8.5 Tests + CI

~8451 tests pass at session start (post Phase 0 foundation refactor). Nightly workflow
(`.github/workflows/nightly.yml`) runs heavy YAML infrastructure tests
($SPINORBEC_RUN_HEAVY_YAML=true$) that are gated off in regular CI for runtime
reasons.

Test layout mirrors `src/` structure: `test/test_<module>.jl` for each
`src/<module>/...`。

---

## 2.9 Conventions summary

本修論を通じて貫徹される conventions:

| Quantity | Convention | Reference |
|---|---|---|
| Units | dimensionless ($\hbar = M = \omega_{\rm ref} = 1$) | §1.6.1 |
| Spinor index | $m$ from $+F$ (`c=1`) down to $-F$ (`c=D`) | §1.6.2 |
| Coupling primary | $g_S = 4\pi\hbar^2 a_S/M$, $S$ even | §1.6.3 |
| KU $c_n$ | $c_0, c_1, c_2$ (F=2); $c_0, c_1, c_{\rm extra}$ (F ≥ 3) | §1.6.3 |
| DDI factor | $c_{\rm dd} = \mu_0 \mu^2$ (no $4\pi$) | §1.6.4 |
| DDI tensor | $Q_{\alpha\beta} = \hat{k}_\alpha \hat{k}_\beta - \delta_{\alpha\beta}/3$, $Q(0) = 0$ | §1.6.4 |
| ITP Zeeman shift | subtract min(E_m) (overflow guard) | CLAUDE.md |
| Wavefunction layout | `psi[x, y, z, c]`, spatial dims first, spinor last | CLAUDE.md |

これら conventions は SpinorBEC.jl + Saito-Ueda 系統 + 上妻研実験との consistency
を維持する。

---

## 2.10 章末: Chapter 3-6 で本章 tools の使用箇所

| Chapter | Tool from Chapter 2 | Usage |
|---|---|---|
| 3 (F=2 cyclic) | BdG (§2.4), Goldstone (§2.5), CG (§2.2) | 10×10 BdG block decomp |
| 4 (Universal Theorem) | Schur 補題 (§2.5.2), character orthogonality | 主定理証明 |
| 5 (TWA chaos) | RTP (§2.6), TWA (§2.7.1) | post-quench Eu dynamics |
| 6 (polyhedral) | BdG (§2.4), CG, sympy factorization | 6 cases closed forms |

D-thesis Ch.3 (integrator modernization): RTP integrator zoo (§2.6.2)。

---

(章末)

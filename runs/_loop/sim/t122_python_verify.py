"""
T122 implementer (sign-pattern-lemma1-non-trivial-irrep-F11-Te1-2026-05-19)
Python-only numerical verification of theorist T122 §3.3 closed-form prediction
bar_beta_0^{canonical, E_1} = d_E1 / (2F+1) at F=11 T:E_1.

This script mirrors the julia logic in
`scripts/manuscript/f9_f11_polyhedral_verification.jl` (T122 appended block)
but runs under the sandbox's numpy-only Python (julia binary blocked by
sandbox approval policy — recorded in sim report §7).

Computes:
- F1: bar_beta_0 at F=11 T:E_1 vs 1/23 (complex) and 2/23 (real)
- F2: seed-spread across 10 RNG seeds
- F3: sum_{S=0}^{2F} bar_beta_S — discriminates complex (sum=2) vs real (sum=8)
- Schur isotropy of rho_inv_E1
"""

import math
import json
import numpy as np


# ----------------------------------------------------------------------
# Clebsch-Gordan coefficient via Racah formula
# ----------------------------------------------------------------------

def _factorial(n):
    if n < 0:
        return 0
    return math.factorial(int(n))


def clebsch_gordan(j1, m1, j2, m2, J, M):
    """<j1 m1, j2 m2 | J M> via Racah/Wigner formula (Edmonds 1957 eq 3.6.10)."""
    if abs(m1) > j1 or abs(m2) > j2 or abs(M) > J:
        return 0.0
    if m1 + m2 != M:
        return 0.0
    if J > j1 + j2 or J < abs(j1 - j2):
        return 0.0

    # Triangle prefactor
    pre = math.sqrt(
        (2 * J + 1)
        * _factorial(J + j1 - j2)
        * _factorial(J - j1 + j2)
        * _factorial(j1 + j2 - J)
        / _factorial(j1 + j2 + J + 1)
    )
    pre *= math.sqrt(
        _factorial(J + M)
        * _factorial(J - M)
        * _factorial(j1 - m1)
        * _factorial(j1 + m1)
        * _factorial(j2 - m2)
        * _factorial(j2 + m2)
    )

    # Racah sum
    k_min = max(0, j2 - J - m1, j1 + m2 - J)
    k_max = min(j1 + j2 - J, j1 - m1, j2 + m2)
    s = 0.0
    for k in range(int(k_min), int(k_max) + 1):
        denom = (
            _factorial(k)
            * _factorial(j1 + j2 - J - k)
            * _factorial(j1 - m1 - k)
            * _factorial(j2 + m2 - k)
            * _factorial(J - j2 + m1 + k)
            * _factorial(J - j1 - m2 + k)
        )
        s += ((-1) ** k) / denom
    return pre * s


# ----------------------------------------------------------------------
# Spin-F matrices
# ----------------------------------------------------------------------

def spin_matrices(F):
    """Exact julia-mirror: 0-indexed python, but matching julia's
    Fp[i_julia, i_julia+1] = sqrt(F(F+1) - m(m+1)) with m = F - i_julia,
    where i_julia is 1-indexed. In python, i_python = i_julia - 1, so
    m = F - i_python - 1. Index convention: row/col 0 ↔ m = +F."""
    D = 2 * F + 1
    Fz = np.diag([F - i for i in range(D)]).astype(complex)
    Fp = np.zeros((D, D), dtype=complex)
    for i in range(D - 1):
        m = F - i - 1   # m_col at python col i+1 = F - (i+1) = F - i - 1
        Fp[i, i + 1] = math.sqrt(F * (F + 1) - m * (m + 1))
    Fm = Fp.conj().T
    Fx = (Fp + Fm) / 2
    Fy = (Fp - Fm) / (2j)
    return Fx, Fy, Fz


def wigner_D(F, axis, angle):
    """Build the Wigner rotation matrix D^(F)(axis, angle) = exp(-i*angle*F·axis_hat)."""
    Fx, Fy, Fz = spin_matrices(F)
    ax = np.array(axis, dtype=float)
    ax = ax / np.linalg.norm(ax)
    Fn = ax[0] * Fx + ax[1] * Fy + ax[2] * Fz
    Fn = (Fn + Fn.conj().T) / 2.0
    w, V = np.linalg.eigh(Fn)
    expFn = V @ np.diag(np.exp(-1j * angle * w)) @ V.conj().T
    return expFn


# ----------------------------------------------------------------------
# Group closure
# ----------------------------------------------------------------------

def group_close(generators, tol=1e-6, max_size=200):
    G = [np.eye(generators[0].shape[0], dtype=complex)]
    while len(G) < max_size:
        prev = len(G)
        for g in list(G):
            for h in generators:
                gh = g @ h
                already = any(np.linalg.norm(gh - x) < tol for x in G)
                if not already:
                    G.append(gh)
        if len(G) == prev:
            break
    return G


def _debug_group_orders(G):
    Imat = np.eye(G[0].shape[0], dtype=complex)
    orders = []
    for g in G:
        for k in range(1, 13):
            gk = np.eye(g.shape[0], dtype=complex)
            for _ in range(k):
                gk = gk @ g
            if np.linalg.norm(gk - Imat) < 1e-6:
                orders.append(k)
                break
        else:
            orders.append(-1)
    return orders


def tetrahedral_gen(F):
    C3 = wigner_D(F, [1.0, 1.0, 1.0], 2 * math.pi / 3)
    C2z = wigner_D(F, [0.0, 0.0, 1.0], math.pi)
    return [C3, C2z]


# ----------------------------------------------------------------------
# T-group character for irrep on group elements
# ----------------------------------------------------------------------

def compute_T_character(group_elements, irrep, ref_C3=None):
    """Replicate julia's compute_T_character logic for irrep A and (when ref_C3
    given) also correctly distinguish T's two order-3 conjugacy classes for
    non-trivial irreps E_1, E_2.

    T has 4 classes: {e}, {4 C_3}, {4 C_3^2}, {3 C_2}. Order-3 elements split
    into two classes; the existing julia compute_T_character merges them
    (writing omega for ALL order-3 elements), which is a [latent] bug exposed
    only at non-trivial T irreps (E_1, E_2). For A irrep the merge is harmless
    (char = 1 on both classes), so 29/29 regression at F=9 T:A unaffected.

    Class membership test: an order-3 element g is in class {C_3} iff it is
    conjugate to the chosen ref_C3 via some h in the group. Equivalently we
    can use the cleaner test: pick ref_C3 (the chosen generator of T,
    rotation by +2π/3 about [1,1,1]/√3), then for any order-3 g, check if g
    appears in the conjugacy orbit of ref_C3 (the 4 elements: conjugates of
    ref_C3 under all h in G).
    """
    chars = []
    omega = complex(math.cos(2 * math.pi / 3), math.sin(2 * math.pi / 3))
    D = group_elements[0].shape[0]
    Imat = np.eye(D, dtype=complex)

    # Build class-C_3 orbit if ref_C3 is provided
    class_C3_set = []
    if ref_C3 is not None:
        for h in group_elements:
            try:
                hinv = np.linalg.inv(h)
            except np.linalg.LinAlgError:
                continue
            conj = hinv @ ref_C3 @ h
            if not any(np.linalg.norm(conj - x) < 1e-6 for x in class_C3_set):
                class_C3_set.append(conj)

    for g in group_elements:
        is_I = np.linalg.norm(g - Imat) < 1e-7
        g2 = g @ g
        g3 = g2 @ g
        is_order2 = (np.linalg.norm(g2 - Imat) < 1e-7) and not is_I
        is_order3 = (np.linalg.norm(g3 - Imat) < 1e-7) and (not is_I) and (not is_order2)
        if is_I:
            chars.append(1.0 + 0j)
        elif is_order3:
            if irrep == 'A':
                chars.append(1.0 + 0j)
            elif irrep == 'E_1':
                if ref_C3 is not None:
                    in_class_C3 = any(np.linalg.norm(g - x) < 1e-6 for x in class_C3_set)
                    chars.append(omega if in_class_C3 else np.conj(omega))
                else:
                    # fallback to julia's merged convention (incorrect for E_1)
                    chars.append(omega)
            elif irrep == 'E_2':
                if ref_C3 is not None:
                    in_class_C3 = any(np.linalg.norm(g - x) < 1e-6 for x in class_C3_set)
                    chars.append(np.conj(omega) if in_class_C3 else omega)
                else:
                    chars.append(np.conj(omega))
            else:
                chars.append(0.0 + 0j)
        elif is_order2:
            chars.append(1.0 + 0j)
        else:
            chars.append(0.0 + 0j)
    return chars


def project_onto_irrep(group_elements, chars):
    P = sum(np.conj(chars[i]) * group_elements[i] for i in range(len(group_elements))) / len(group_elements)
    return P


def find_invariant_basis(P, tol=1e-8):
    U, sv, Vh = np.linalg.svd(P)
    m_rep = int(np.sum(sv > tol))
    basis = [U[:, i].copy() for i in range(m_rep)]
    for i in range(m_rep):
        for j in range(i):
            basis[i] -= np.vdot(basis[j], basis[i]) * basis[j]
        nrm = np.linalg.norm(basis[i])
        assert nrm > 0
        basis[i] /= nrm
    return basis, m_rep


# ----------------------------------------------------------------------
# mult_aware_beta_S
# ----------------------------------------------------------------------

def mult_aware_beta_S(rho_inv, F, S):
    """bar_beta_S = sum_M Re tr( A_M^† rho_inv A_M transpose(rho_inv) )
    where A_M[i, j] = CG(F, m_i, F, m_j; S, M) with m_i = F - i, m_j = F - j."""
    D = 2 * F + 1
    total = 0.0
    for M in range(-S, S + 1):
        A = np.zeros((D, D), dtype=complex)
        for m1 in range(-F, F + 1):
            m2 = M - m1
            if -F <= m2 <= F:
                cg = clebsch_gordan(F, m1, F, m2, S, M)
                A[F - m1, F - m2] = complex(cg)
        contrib = np.real(np.trace(A.conj().T @ rho_inv @ A @ rho_inv.T))
        total += contrib
    return total


def canonical_mult_aware_beta_S(rho_inv, F, S, m_rep):
    return m_rep * mult_aware_beta_S(rho_inv, F, S)


# ----------------------------------------------------------------------
# F=11 T:E_1 driver
# ----------------------------------------------------------------------

def main():
    F = 11
    D = 2 * F + 1
    irrep = 'E_1'

    # 1. Group closure (12 elements expected)
    gens = tetrahedral_gen(F)
    G = group_close(gens, tol=1e-6, max_size=200)
    assert len(G) == 12, f"expected |T|=12, got {len(G)}"

    # 2. Character projector for E_1
    #    Use the +2π/3 rotation about [1,1,1]/√3 (the chosen generator) as the
    #    class-{C_3} representative. Characters: χ^{E_1}(e)=1, χ(C_3)=ω,
    #    χ(C_3²)=ω², χ(C_2)=1.
    ref_C3 = gens[0]   # +2π/3 about [1,1,1]/√3 by construction
    chars = compute_T_character(G, irrep, ref_C3=ref_C3)
    P = project_onto_irrep(G, chars)
    P_idempotency_dev = float(np.linalg.norm(P - P @ P))
    sv = np.linalg.svd(P, compute_uv=False)

    # 3. SVD basis
    base_basis, m_rep = find_invariant_basis(P, tol=1e-8)
    assert m_rep == 2, f"expected m_rep=2 (Hamermesh), got {m_rep}"

    def build_rho_inv(basis):
        rho = np.zeros((D, D), dtype=complex)
        for z in basis:
            rho += np.outer(z, z.conj())
        return rho / len(basis)

    rho_inv_E1 = build_rho_inv(base_basis)

    expected_complex = 1.0 / (2 * F + 1)   # 1/23
    expected_real    = 2.0 / (2 * F + 1)   # 2/23

    # ---- F1 ----
    bar_beta_0 = canonical_mult_aware_beta_S(rho_inv_E1, F, 0, m_rep)
    dev_complex = abs(bar_beta_0 - expected_complex)
    dev_real    = abs(bar_beta_0 - expected_real)

    convention = (
        "complex_d_1" if dev_complex < 1e-13 else
        "real_d_2"    if dev_real    < 1e-13 else
        "neither"
    )
    f1_verdict = (
        "CORROBORATE" if (dev_complex < 1e-13 or dev_real < 1e-13) else
        "INCONCLUSIVE" if (dev_complex < 1e-6 or dev_real < 1e-6) else
        "REFUTED"
    )

    # ---- F2: seed-spread (replicates julia seeded_basis pattern) ----
    def seeded_basis(seed):
        rng = np.random.default_rng(seed)
        kicked = [z.copy() for z in base_basis]
        for i in range(m_rep):
            coeffs = (rng.standard_normal(m_rep) + 1j * rng.standard_normal(m_rep))
            mix = np.zeros(D, dtype=complex)
            for j in range(m_rep):
                mix += coeffs[j] * base_basis[j]
            kicked[i] = base_basis[i] + 0.5 * mix
        for i in range(m_rep):
            for j in range(i):
                kicked[i] -= np.vdot(kicked[j], kicked[i]) * kicked[j]
            nrm = np.linalg.norm(kicked[i])
            assert nrm > 0
            kicked[i] /= nrm
        return kicked

    per_seed = []
    for seed in range(1, 11):
        basis_s = seeded_basis(seed)
        rho_s = build_rho_inv(basis_s)
        per_seed.append(canonical_mult_aware_beta_S(rho_s, F, 0, m_rep))
    seed_spread = max(per_seed) - min(per_seed)
    f2_verdict = (
        "CORROBORATE" if seed_spread < 1e-13 else
        "ADVISORY_PASS" if seed_spread < 1e-10 else
        "REFUTED"
    )

    # ---- F3: sum over all S ----
    expected_sum_complex = 2.0
    expected_sum_real    = 8.0
    full_sum = 0.0
    even_sum = 0.0
    per_S = {}
    for S in range(0, 2 * F + 1):
        b = canonical_mult_aware_beta_S(rho_inv_E1, F, S, m_rep)
        per_S[S] = b
        full_sum += b
        if S % 2 == 0:
            even_sum += b
    f3_dev_complex = abs(full_sum - expected_sum_complex)
    f3_dev_real    = abs(full_sum - expected_sum_real)
    f3_verdict = (
        "CORROBORATE" if (f3_dev_complex < 1e-12 or f3_dev_real < 1e-12) else
        "ADVISORY_PASS" if (f3_dev_complex < 1e-6 or f3_dev_real < 1e-6) else
        "REFUTED"
    )
    sum_rule_convention = (
        "complex_d_1" if f3_dev_complex < 1e-12 else
        "real_d_2"    if f3_dev_real    < 1e-12 else
        "neither"
    )

    # ---- Schur isotropy ----
    Fx, Fy, Fz = spin_matrices(F)
    iso_x = np.real(np.trace(rho_inv_E1 @ (Fx @ Fx)))
    iso_y = np.real(np.trace(rho_inv_E1 @ (Fy @ Fy)))
    iso_z = np.real(np.trace(rho_inv_E1 @ (Fz @ Fz)))
    iso_target = F * (F + 1) / 3.0 * np.real(np.trace(rho_inv_E1))

    # ---- Output ----
    manifest = {
        "F": 11,
        "group": "T",
        "irrep": "E_1",
        "m_rep_E1": int(m_rep),
        "d_E1_complex": 1,
        "d_E1_real": 2,
        "bar_beta_0_canonical_F11_TE1": float(bar_beta_0),
        "bar_beta_0_dev_from_1_over_23": float(dev_complex),
        "bar_beta_0_dev_from_2_over_23": float(dev_real),
        "convention_resolved": convention,
        "seed_spread_F11_TE1": float(seed_spread),
        "sum_S_all_S_F11_TE1": float(full_sum),
        "sum_S_even_S_F11_TE1": float(even_sum),
        "predicted_sum_complex": 2.0,
        "predicted_sum_real": 8.0,
        "sum_rule_convention_resolved": sum_rule_convention,
        "f3_dev_complex": float(f3_dev_complex),
        "f3_dev_real": float(f3_dev_real),
        "schur_isotropy_rho_inv_E1_x": float(iso_x),
        "schur_isotropy_rho_inv_E1_y": float(iso_y),
        "schur_isotropy_rho_inv_E1_z": float(iso_z),
        "schur_isotropy_target_F_F_plus_1_over_3_times_Tr_rho_inv": float(iso_target),
        "f1_verdict": f1_verdict,
        "f2_verdict": f2_verdict,
        "f3_verdict": f3_verdict,
        "tr_rho_inv_E1": float(np.real(np.trace(rho_inv_E1))),
        "rho_inv_hermitian_dev": float(np.max(np.abs(rho_inv_E1 - rho_inv_E1.conj().T))),
        "P_idempotency_dev": P_idempotency_dev,
        "top_2_singular_values_of_P": [float(sv[0]), float(sv[1])],
        "3rd_singular_value_of_P": float(sv[2]),
        "per_S_table": {int(S): float(b) for S, b in per_S.items()},
        "per_seed_bar_beta_0": [float(b) for b in per_seed],
        "regression_lemma1_general_S": "ADVISORY: F4 regression (29/29 PASS at lemma1_general_S_verification.jl) is unaffected by F=11 T:E_1 addition — Python verification cannot run the julia regression script; the julia call-site block in scripts/manuscript/f9_f11_polyhedral_verification.jl preserves F4 baseline by appending to (not replacing) prior cases. Julia execution blocked by sandbox approval policy at this turn; see sim report §7.",
    }

    print(json.dumps(manifest, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

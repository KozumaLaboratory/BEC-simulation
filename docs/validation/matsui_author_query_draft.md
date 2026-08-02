# Draft query to Matsui et al. — NOT SENT, AND NO LONGER NEEDED

> **Superseded 2026-08-01.** The question this asks was answered from the
> deposit itself: their published run used `Ntot = 3.5e4`, the value shipped
> in `setup_parameters`, with the output normalised to 5e4 for plotting.
> Given that `N`, our code reproduces Fig. 4B to 1 %. See
> `matsui_residual_root_cause.md`. Kept as a record of what would have been
> asked and of how close the campaign came to needing to ask it.

Everything reachable from the released material has been exhausted (see
`matsui_residual_root_cause.md`). One candidate survives and it is not
falsifiable from what was released: **a parameter in the published run that is
not in the shipped `setup_parameters`.** Two are already known to be in that
category, which is why the question is worth asking.

This is a draft for anko to edit and send. It is deliberately short, states what
we did before asking, and offers something back.

---

**Subject:** Reproducing the Fig. 4B numerics of *Observation of the Einstein–de
Haas Effect in a Bose–Einstein Condensate* — a question about the run parameters

Dear Dr Matsui and colleagues,

Thank you for depositing the simulation code and datasets with the paper — it is
rare and it made the following possible at all.

We have an independent spinor-GPE implementation (arbitrary F, split-step
spectral, GPU) and used your Zenodo deposit to check it against yours. Reading
`time.f90` line by line, our conventions agree with yours everywhere we can
compare: the Zeeman operator including the sign of `ZeemanP·F_z`, the spin
matrices and ladder normalisation, `∫|ψ|² = 1`, and the dipolar kernel — your
`cdd` times your `4π·Q` reduces to our `c_dd·Q` to seven significant figures once
the `aHO = √(ħ/2mω)` factor is taken out. The contact couplings likewise:
`cc0_eff = 0.5` with `cc1_eff = 50` maps exactly onto our `c₁/c₀ = 1/36` under
the `c₀ + F²c₁` constraint.

We reproduce Fig. 4B qualitatively — the dip in `N_{m=−6}`, its negative offset,
and its width — but not quantitatively. Measured on the same field window with
the same metric, we find a dip centre of **−2.14 nT** against your **−2.55 nT**,
and our spin cascade runs about **20 % further** at every field (our `N_{m=−6}`
is 0.78–0.84 of yours across the dip; in Fig. 2C our 90 %, 70 % and 50 %
depletion times are all 0.81–0.84 of yours).

We have excluded, each by direct measurement: grid resolution, box size, running
on your exact 128³ / `dx = 0.4 aHO` grid, time step, the exponential field ramp,
three-body loss, the DDI kernel's image treatment, and your 3-point
finite-difference Laplacian (which we reproduced exactly by substituting the FD
symbol for `|k|²`, and which moves the disagreement the wrong way). Our own DDI
operator agrees with an independent reference implementation to machine
precision. Notably, no single global coupling can bridge the gap: lowering `N`
moves the transfer toward your value but the centre away from it, and the same
holds for `c_dd` and the peak density.

That leaves the run parameters themselves, and here we would be grateful for
help. The shipped `setup_parameters` carries `Ntot = 3.5×10⁴`, while the
published curves total 49999.9, so we assumed `N = 5×10⁴`. `initial.f90` also
ships `cc0_eff = 1, cc1_eff = 0` against `time.f90`'s `0.5 / 50` (this one is
harmless for the polarised initial state, which feels only `c₀ + F²c₁`). Since
two parameters in the release are demonstrably not the ones used, our question is
simply:

**Could you tell us the `setup_parameters` values behind the published Fig. 2 and
Fig. 4 curves — in particular `Ntot`, `cc0_eff`, `cc1_eff`, `omegaX/Y/Z`,
`total_time`, and whether `ZeemanQ = 1.0` Hz was used for the Fig. 4 scan?**

We would of course be happy to share what we have: the convention diff, the
exclusion measurements above, and our own Fig. 4B curve, in whatever form is
useful. If the residual turns out to be on our side we would very much like to
know it.

With thanks and best regards,

---

## Attachments to offer

- `docs/validation/parameter_contract_with_Ueda.md` §0 — the convention diff
- `docs/validation/matsui_residual_root_cause.md` — the exclusion table
- our Fig. 4B curve as CSV, on their field grid

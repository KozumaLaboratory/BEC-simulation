# The LIVE-document set: which files must be TRUE rather than merely DATED.
#
# Lifted out of `test_docs_live_set.jl` on 2026-08-20 when a second gate needed
# it. The list is the tree's only declaration of "this file is maintained", and
# a gate that wants to bind only maintained documents must read THIS, not form a
# second opinion — a private copy is how the two would drift into disagreeing
# about which sheet an experimentalist is allowed to trust.
#
# Consumers: test_docs_live_set.jl (holds the partition honest),
#            test_retracted_numbers_carry_their_replacement.jl (binds retraction
#            gates to maintained documents only).

const LIVE_DOCS = [
    # GENERATED, and gated against the code by
    # `test_state_doc_is_current.jl` — the only LIVE doc whose
    # correctness is machine-checked rather than merely asserted.
    "docs/STATE.md",
    # The SPGPE Kibble-Zurek record: what reproduces, at what sigma, and under
    # which invariance checks. LIVE rather than dated because the ladder continues —
    # step 1 (c1 on) results land here — and freezing a document one is about to
    # update would be a false label.
    "docs/validation/spgpe_kz_reproduction.md",
    "docs/architecture/rotating_basis.md",
    "docs/archive/README.md",
    "docs/campaign/CAMPAIGN.md",
    # Per-claim expansion of CAMPAIGN §5's one-line policy: which live claims the
    # six unmeasured Eu scattering channels can move. LIVE because the claim set
    # it partitions is itself live — new type-C entries and new figures land in
    # registries this file reads (#342).
    "docs/campaign/as_dependency_map.md",
    "docs/campaign/fix_list.toml",
    # The claim ledger: one row per physics claim, with `status` as a FIELD.
    # LIVE, and it is the one entry whose liveness is machine-enforced rather
    # than asserted — `test_retracted_numbers_carry_their_replacement.jl` parses
    # it fail-closed, checks the supersession graph both ways, and hunts every
    # `retired_literal` through the rest of this list. A stale ledger reddens the
    # suite, which is not true of any prose document here.
    "docs/campaign/claims.toml",
    # The single place the EdH-quench polarisation convention is decided (#343).
    # LIVE rather than dated on purpose: a convention document that is allowed to
    # go stale is worse than none, because the thesis reads it as current.
    "docs/campaign/edh_quench_polarisation_decision.md",
    # Which of the three things "Klaus" named is meant where (#344). LIVE
    # because it is a naming rule people are told to follow, and it has its
    # own gate: test/validation/test_klaus_name_disambiguation.jl.
    "docs/conventions/klaus_name_disambiguation.md",
    "docs/conventions/testing_strategy.md",
    "docs/design/hamiltonian_layered_architecture.md",
    "docs/design/research_spec_and_provenance_architecture.md",
    "docs/design/unified_spec_architecture.md",
    "docs/guides/fast_larmor_regime.md",
    # The maintained EdH-quench lab prescription. LIVE because it is what a
    # reader is SENT to: `klaus_protocol_sheet.md` is frozen and its numbered
    # protocol now points here instead of issuing values. A frozen document may
    # be wrong; it may not be the only place an instruction lives.
    "docs/guides/edh_quench_lab_prescription.md",
    "docs/guides/lab_user_tutorial.md",
    # The local counterpart of `tsubame.md`: where a run goes when it is not
    # going to the cluster. LIVE rather than dated because what it states is a
    # SAFETY property — this host cannot be pushed into swap, and an overrun
    # kills rather than hangs — and a stale safety guarantee is worse than an
    # absent one: the reader keeps running under a promise nobody is holding.
    # It also carries the only prose statement of which scheduler rungs have
    # been executed on real hardware (UGE yes, SLURM/PBS no), which is exactly
    # the kind of line that must not silently outlive its measurement.
    "docs/guides/local_run_environment.md",
    "docs/guides/pipeline_cookbook.md",
    "docs/guides/spgpe.md",
    "docs/guides/tsubame.md",
    "docs/index.md",
    "docs/manuscript/latex_templates/pandoc_workflow.sh",
    "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md",
    "docs/reference/dynamics.md",
    "docs/reference/yaml_schema_reference.md",
    "docs/validation/config_metadata_blocks.toml",
    "docs/validation/config_prose_harvest.toml",
    # The #337 answer, and the REPLACEMENT for
    # `docs/validation/full_bdg_scheme_dependence_eu_f6.md`, which was LIVE until
    # 2026-08-19 and is now dated: its headline verdict ("NOT ANSWERABLE with the
    # current machinery") was overturned by measurement and its q-table was
    # computed at 1e-4 of the campaign's field. A document whose main conclusion
    # no longer holds must not advertise itself as maintained — so this is a
    # SWAP, not a +1, and the budget below is unchanged.
    #
    # LIVE because it is what a reader is sent to: the frozen document opens by
    # pointing here, and `spatial.jl` / `potentials.jl` cite its measurements.
    "docs/theory/lhy_scheme_selection_eu_f6.md",
    # The Klaus 2022 reproduction's evidence: published parameters per figure,
    # the systematics, the model-selection numbers, and the pre-registered
    # thresholds. LIVE rather than dated because the gate reads its thresholds
    # and one row of it is an OPEN disagreement — a reader has to know it is
    # maintained.
    "docs/validation/klaus2022_primary_source.md",
    # Arrived with main 2026-08-04. It calls itself the "single entry point for
    # what this campaign established, excluded, and could not close", and
    # matsui_reproduction_status.md now points readers at it — so it is what a
    # reader is sent to, which is the LIVE test.
    "docs/validation/matsui_campaign_report.md",
    "docs/validation/parameter_contract_with_Ueda.md",
    "docs/validation/step6_ueda_reference_state/reference_state.yaml",
    "docs/validation/ueda_status.md"]

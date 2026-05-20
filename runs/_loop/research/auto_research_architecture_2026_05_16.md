# Auto-research loop — optimal architecture (design 2026-05-16)

Anko 2026-05-16: 個別パッチではなく汎用 prompt を作る。既存 auto-research 系を徹底リサーチした上で最適設計を提案。

## 1. リサーチ対象 (sources)

| 系統 | 代表 | 取り入れる pattern |
|---|---|---|
| **科学発見** | AI Scientist v1/v2 (Sakana) [arXiv:2504.08066], grounded autonomous research [arXiv:2604.12198] | Experiment Manager Agent + BFTS tree search; 自律 falsification (HSE prior-flip 事例); Tier 3 = published ground truth match |
| **物理 specific** | PhysGym [arXiv:2507.15550], PhysMaster [arXiv:2512.19799], MCP-SIM [npj AI 2025] | hypothesis flag + confidence; LANDAU = curated literature + validated methodological traces; plan-act-reflect-revise w/ persistent memory |
| **長期 agent** | Anthropic Effective Harnesses (engineering blog), Devin (Cognition), Manus (Meta-acquired) | Initializer + Coder split; progress.md + JSON feature list + git history; 5000+ token prompt は signal/noise 比悪化 |
| **planning + recovery** | LATS [ICML 2024], Reflexion, ReAct, RoT 2024 | 4-phase: Select / Expand+Simulate / Reflect+Evaluate / Backprop; failure recovery via verbal critique; tree search で local minima 脱出 |
| **multi-agent framework** | AutoGen, MetaGPT, CrewAI [comparison 2025] | role-based message pool (MetaGPT); critic loop via multi-turn (AutoGen); manager + specialists (CrewAI hierarchical) |
| **context engineering** | Anthropic blog [effective context], leaked prompts (Cursor/Windsurf/Manus/Devin) | 4 strategy: Write/Select/Compress/Isolate; AGENTS.md + progress.md + episodic memory; tool schema as machine-readable interface; "Ralph Wiggum drift" warning |

## 2. 設計原則 (5 つ、derived from above)

### 原則 1: declarative contract、hardcoded threshold は廃止

**現状の問題**: judge.py に `norm_drift < 1e-8` 等が hardcode。dissipative 系で誤発火、anko の T20 を 3 回 fail させた。

**設計**: director が directive §6 で **success_criteria を declarative に宣言**:

```json
{
  "subagent_type": "implementer",
  "brief": "...",
  "success_criteria": [
    {"id": "delta_in_range", "metric": "delta_cdd0_per_atom",
     "operator": "<=", "value": -3.0,
     "rationale": "M1-dominant predicts Δ ∈ [-6, -3]; outside this is framework error"},
    {"id": "norm_conserved", "metric": "norm_drift",
     "operator": "<", "value": 0.02,
     "rationale": "K3 loss in this config caps drift at ~1%"}
  ],
  "failure_modes": [
    {"if": "delta outside [-6, +6]", "next_action": "critic_audit T19 framework"},
    {"if": "norm_drift > 0.02", "next_action": "implementer redo with smaller dt"},
    {"if": "observables_missing", "next_action": "next-turn rerun with manifest enabled"}
  ],
  "tolerance_overrides": {
    "norm_drift": 0.02,
    "cost_cap_effective": 5000000
  }
}
```

judge は **success_criteria を順次評価**し、failed の id に対応する **failure_modes の next_action を state に書く**。次ターン director がそれを読んで route 決定。判定 logic を judge.py から director.md (= LLM 文脈) に移譲。

→ **AI Scientist v2 の Experiment Manager Agent + LATS の Select 段** に対応。

### 原則 2: pre-flight observable manifest

**現状の問題**: T20 implementer が julia 走らせた後、Lz observable が save されてないと気づく。1 turn 無駄。

**設計**: implementer が **expensive run の前に observable manifest を宣言** + **manifest が config に通るか前検証**:

```yaml
# implementer §X 内
observable_manifest:
  required:
    - psi[m, x, y, z]  # always
    - <F_z>(t)          # spin polarization 
    - <L_z>(t)          # orbital — needed for M1 test
    - m-populations
  precondition_check: |
    julia -e 'cfg = load_config(...); 
              @assert :Lz in cfg.dynamics.observables'
```

precondition_check fail → 即 next-turn dispatch (config fix)、expensive run しない。

→ **MCP-SIM plan-act-reflect-revise** の "reflect before act" 段、Anthropic "Effective Harnesses" の Initializer pattern。

### 原則 3: REFUTED = science success

**現状の問題**: judge.py が falsification REFUTED を `physical_red_flags` に積み、FAIL_PHYSICS 扱い。Popperian には refutation は positive result。

**設計**: judge の verdict 体系を **operational vs scientific** に二分:

| 軸 | enum | 意味 | director 次手 |
|---|---|---|---|
| **operational** | PASS / FAIL | 直接的 fail (timeout, crash, observable missing) | redo or escalate |
| **scientific** | CONFIRMED / REFUTED / INCONCLUSIVE | 仮説検証結果 (どれも valuable) | 別 hypothesis 候補に進む |
| **novelty** | EXPECTED / NOVEL | 外れ値の有無 | NOVEL は critic audit |

operational が PASS なら scientific が REFUTED でも turn 全体は PASS。grounded autonomous research の HSE prior-flip 事例 (agent が自分の予測を refute する論文を unsupervised 出力) は **REFUTED-positive** の典型。

→ **PhysGym hypothesis-confidence flag + Popperian falsifiability framing**。

### 原則 4: Tier-3 validation を明示

**現状の問題**: SpinorBEC.jl の [Established] memory がどれも内部一貫性レベル (Tier 1-2)。**Tier 3 = 外部 group benchmark との一致** がゼロ。Yan-Li-Saito 2026 reproduction が初の Tier 3 候補だが framework 上の位置づけ無し。

**設計**: claim provenance に **tier ラベル**を必須化:

| Tier | 定義 | 信頼度 |
|---|---|---|
| 0 | 一度も falsify 試行なし | lowest |
| 1 | 内部 regression test のみ | low |
| 2 | closed-form / sympy / 独立 implementation で 1 路一致 | medium |
| 3 | 外部 group (Stuttgart Dy / Innsbruck Er / Yan-Li-Saito) 数値一致 | high |

memory entry, [Established] tag, director rationale 等で必ず明示。**grounded autonomous research の "scale (75% within 5% of published)" を Tier 3 metric として目標化**。

### 原則 5: Initializer + Coder + Critic split (Anthropic pattern)

**現状の問題**: director が毎ターン cold-start で state を再読込。重複作業多い。

**設計**: 3 種類の prompt 分離:

| 役割 | prompt 系統 | 持続性 |
|---|---|---|
| **Initializer (= seed.md)** | session 開始時に anko または前 director が書く長期 spec | session 持続、anko が更新 |
| **Coder (= director + subagent)** | per-turn、Initializer の spec を読んで増分実行 | per-turn |
| **Critic (= critic agent)** | 独立 context で audit | per-dispatch |

これは Anthropic Effective Harnesses 直訳 + MetaGPT SOP-driven 風味。leak repo の Devin / Manus も同じ構造。

→ progress.md 相当は既に `state.json + sim/turn_N.md + memory/` でカバー済。**living spec が散らかってる**のが課題、index 化が必要。

## 3. 既存 vs 提案 diff

| 部分 | 現状 | 提案 |
|---|---|---|
| **director §6 schema** | brief + rationale + expected_outcome + if_fails_next_step (自然言語) | + `success_criteria[]`、`failure_modes[]`、`tolerance_overrides`、`observable_manifest`、`budget_split` (machine-readable JSON) |
| **judge.py** | hardcoded thresholds (norm_drift 1e-8, cost 3M, falsification REFUTED → FAIL_PHYSICS) | declarative evaluator: contract から criterion 読み、機械的 PASS/FAIL。defaults はあるが override 優先 |
| **implementer.md** | action-based dispatch (run_experiment / modify_code / analyze_existing) | + pre-flight observable manifest 検証必須、expensive run の前に config check |
| **theorist.md** | derivation + [Established/Plausible/Speculative] tag | + tier 0/1/2/3 明示、REFUTED は scientific success として扱う |
| **critic.md** | T11 mechanism audit pattern | + **director の contract 自体を audit する mode** (success_criteria が妥当か、failure_modes が網羅されてるか) |
| **state.json** | 単一 turn history | + `current_contract` field (director の §6 を最後に書いた contract そのまま)、judge は次ターン用にここを読む |
| **drift_signals.py** | repetition / cost / verdict | + `RETRY_LOOP` シグナル (同じ directive_label が 2 連続 = 即 escalation) |
| **scheduler.py** | window × probe × workload_fit | + `expected_runtime_from_workload_specs` を contract で override 可能 (e.g., implementer_julia_gpu typical 40 min → 設定で 90 min) |

## 4. 実装順 (1-2 hour, 1 セッション)

1. **director.md §6 schema 拡張** (~15 min): 上記 contract JSON 例を追加、§A5 を declarative success_criteria 要求に更新
2. **judge.py refactor** (~30 min):
   - DEFAULT_TOL → DEFAULT_DEFAULTS (rename)
   - `evaluate_contract(contract, metrics)` 関数追加、success_criteria 順次評価
   - 旧 hardcoded path は backward compat のため残す (contract 無し時 fallback)
   - REFUTED → physics_issues 経路廃止 (既に 1 部 fix 済)
3. **implementer.md** (~15 min): action 別に "pre-flight observable manifest" subsection 追加
4. **theorist.md** (~10 min): tier ラベル必須化、REFUTED-positive framing
5. **critic.md** (~10 min): contract-audit mode 追加
6. **state.json schema bump v2** (~10 min): `current_contract` field 追加、schema_version=2
7. **smoke test** (~10 min): 既存 T20 sim を新 judge で再評価、PASS 出るか確認

## 5. 期待効果

| 痛点 | 改善 |
|---|---|
| judge mis-fail (norm tol, REFUTED, etc.) | 全部 director の contract に内包、誤発火激減 |
| 同じ directive を 3 回再 dispatch | failure_modes で next_action が定義済 → 自動 route |
| observable 不足で expensive run 無駄 | pre-flight manifest で防止 |
| Tier 3 が未到達 | 明示 metric、Yan-Li-Saito reproduction で初到達狙う |
| director が毎ターン cold-start | seed.md を Initializer、director を Coder と明示、共有 state を contract に蓄積 |

## 6. 採用しないもの (= リサーチで見たが捨てた)

- **LATS tree search 全面採用**: 5 候補並列展開はコスト 5× で見合わない。director 単一 pick + critic で別候補に振る現方式で十分
- **AutoGen-style 多 agent 会話**: token 浪費、speaker selection bottleneck
- **Devin 流フル autonomy (sandbox + computer use)**: 我々の loop は GPU 共有 + git workflow が確立してるので不要
- **Multi-persona "you are 5 experts"**: 既に subagent split があるので冗長
- **AI Scientist v2 の手書きテンプレ廃止**: 我々は SpinorBEC.jl という特定対象なので template (= seed.md + agents/*.md) ある方が hallucination 防止に効く
- **5000+ token prompt 系**: leak prompts 研究で signal/noise 比悪化と報告、原則 1-3 で短く保つ

## 7. 残るリスク

- contract JSON schema は厳密にすると director が書きにくくなる → middle ground: 必須 field は最小、optional で詳細化
- backward compat: 既存 turn 0-20 は新 schema 持たない、judge は古い path で評価 (両刀対応)
- critic audit-of-contract が新 work-shape、最初は noisy になる可能性 → smoke test 必須

## 8. 決定事項 (anko 承認待ち)

- [ ] 設計方針 5 原則を採用するか
- [ ] §4 実装順で進めるか (~1-2 hour 1 セッション)
- [ ] state.json schema bump v2 を許可するか (既存 v1 と互換性 path 残す)
- [ ] 採用しないもの §6 のどれか拾うものあるか

---

## Sources (15 文献)

- [AI Scientist v2 (Sakana, arXiv:2504.08066)](https://arxiv.org/abs/2504.08066)
- [Towards Grounded Autonomous Research (arXiv:2604.12198)](https://arxiv.org/abs/2604.12198)
- [PhysGym (arXiv:2507.15550)](https://arxiv.org/abs/2507.15550)
- [PhysMaster (arXiv:2512.19799)](https://arxiv.org/abs/2512.19799)
- [MCP-SIM (npj AI 2025)](https://www.nature.com/articles/s44387-025-00057-z)
- [Anthropic — Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic — Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [LATS (Language Agent Tree Search, ICML 2024, arXiv:2310.04406)](https://arxiv.org/abs/2310.04406)
- [Reflexion blog (LangChain)](https://blog.langchain.com/reflection-agents/)
- [Coscientist (Boiko et al., Nature 624 570 2023)](https://www.scientificeuropean.co.uk/technology/artificial-intelligence-ai-systems-conduct-research-in-chemistry-autonomously/)
- [Agentic AI for Scientific Discovery survey (ICLR 2025, arXiv:2503.08979)](https://arxiv.org/abs/2503.08979)
- [Leaked prompts repo (Lucas Valbuena, 28+ tools)](https://www.augmentcode.com/learn/leaked-ai-system-prompts-github)
- [LangGraph vs CrewAI vs AutoGen comparison 2025 (DataCamp)](https://www.datacamp.com/tutorial/crewai-vs-langgraph-vs-autogen)
- [CrewAI vs AutoGen architecture 2025 (sider.ai)](https://sider.ai/blog/ai-tools/crewai-vs-autogen-which-multi-agent-framework-wins-in-2025)
- [Devin / Manus 2026 reality check (calmops.com)](https://calmops.com/ai/ai-coding-agents-devin-2026-complete-guide/)

using YAML
cfg_path = "runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml"
cfg = YAML.load_file(cfg_path)

@assert haskey(cfg, "defaults") "defaults block missing"
@assert haskey(cfg, "pipeline") "pipeline block missing"
@assert length(cfg["pipeline"]) == 2 "expected 2-step pipeline, got $(length(cfg["pipeline"]))"
@assert haskey(cfg["pipeline"][1], "ground_state") "step 1 must be ground_state"
@assert haskey(cfg["pipeline"][2], "dynamics") "step 2 must be dynamics"

gs = cfg["pipeline"][1]["ground_state"]
dyn = cfg["pipeline"][2]["dynamics"]

@assert get(gs, "initial_state", nothing) == "m_minus_F" "P1: initial_state != m_minus_F"
@assert haskey(gs, "ddi") && get(gs["ddi"], "secular", true) == false "P5: gs.ddi.secular != false"
@assert haskey(dyn, "ddi") && get(dyn["ddi"], "secular", true) == false "P5: dyn.ddi.secular != false"
@assert get(cfg["defaults"], "kind", nothing) == "spinor" "P4: defaults.kind != spinor"
@assert get(cfg["defaults"], "backend", nothing) == "gpu" "backend != gpu"

@assert get(dyn, "save_psi_snapshots", false) == true "save_psi_snapshots must be true for F1/F2 extraction"
@assert haskey(dyn, "save") && haskey(dyn["save"], "every") "save.every missing"

Bz_dyn = dyn["B"]["Bz"]
@assert Bz_dyn isa Dict || Bz_dyn isa AbstractDict "dyn.B.Bz must be a ramp dict"
@assert abs(get(Bz_dyn, "to", NaN) - 2.6e-5) < 1e-10 "dyn.B.Bz.to != 2.6e-5 Gauss"
@assert abs(get(Bz_dyn, "from", NaN) - 0.01) < 1e-10 "dyn.B.Bz.from != 0.01 Gauss"

import CUDA
@assert CUDA.functional() "CUDA not functional; check LD_LIBRARY_PATH=/usr/lib/wsl/lib"
@info "GPU available" CUDA.name(CUDA.device()) CUDA.totalmem(CUDA.device()) / 1e9

println("OK_T74_precondition: YAML parses, 5 pitfalls honored, observables present, CUDA functional")

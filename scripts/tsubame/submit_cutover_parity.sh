#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -N parity
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# Does the cutover still produce the same physics?
#
# Twenty commits changed admission, the completion marker, the GS resolution
# path, DDISpec.trunc_radius's type, eleven ambient Refs and resonance_dip's
# vertex formula. 1,050 assertions and a green ci tier say the MACHINERY is
# consistent. None of them says a real config still computes the same numbers:
# every fixture is 8^3 or 16^3 with a few hundred steps.
#
# So: run the SAME configs at the pre-cutover commit and at HEAD, in two
# separate checkouts, and diff the physics. Bit-identical is the expectation —
# nothing in the cutover was supposed to change a number. A difference is a
# finding either way, and a difference we cannot explain is a stop.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
ROOT=/gs/fs/tga-kozuma-kouhi/uk07267
BEFORE=$ROOT/parity_before
AFTER=$ROOT/parity_after

echo "host=$(hostname) date=$(date)"
echo "BEFORE=$BEFORE  AFTER=$AFTER"

for d in "$BEFORE" "$AFTER"; do
    echo "### $d : $(cd $d && git rev-parse --short HEAD) $(cd $d && git log -1 --format=%s | cut -c1-60)"
    (cd "$d" && $JULIA --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -2)
done

# The two DDI configs declare `backend: gpu` EXPLICITLY, and
# SPINORBEC_NO_AUTO_BACKEND only suppresses AUTO-selection — it does not
# override a declared backend. The first attempt (job 8323469) ran on a CPU node
# and both of them died with
#     MethodError: no method matching _to_device(::CUDABackend, ::Array{...})
# identically on both sides, which says nothing about the cutover. So: a GPU
# node, and the CPU-only config keeps NO_AUTO_BACKEND so it stays on the CPU
# path it was compared on before.
#
# A GPU introduces its own nondeterminism, so bit-identity is no longer the
# expectation for the GPU arms — run each side TWICE and compare the
# within-side spread against the across-side difference. A cutover defect looks
# like a difference larger than the run-to-run spread; GPU noise looks like one
# that is not.

run_one () {   # $1 = checkout dir, $2 = config, $3 = tag
    local d=$1 cfg=$2 tag=$3
    echo "### RUN $tag  $cfg"
    (cd "$d" && SPINORBEC_STORE=$ROOT/parity_store_$tag \
        $JULIA --project=. -e '
        # `import CUDA` BEFORE `using SpinorBEC` — the extension supplies
        # _to_device(::CUDABackend, ::Array) (ext/SpinorBECCUDAExt/backend.jl:4).
        # Without it a `backend: gpu` config dies with a MethodError, which is
        # what killed jobs 8323469 and 8324826. Every other GPU submit script in
        # scripts/tsubame/ already does this; this one did not.
        import CUDA
        using SpinorBEC, JLD2, SHA, Printf
        function main(cfg)
            local t
            try
                t = @elapsed run_yaml(cfg; verbose=false)
            catch e
                println("RUN_THREW: ", sprint(showerror, e))
                rethrow()
            end
            # Report every scalar a physics claim would rest on, plus a hash of
            # psi itself — a summary alone can agree while the state differs.
            store = get(ENV, "SPINORBEC_STORE", "runs")
            for (root, _, files) in walkdir(store), f in sort(files)
                endswith(f, ".jld2") || continue
                p = joinpath(root, f)
                d = try JLD2.load(p) catch; continue end
                psi = get(d, "psi", nothing)
                h = psi === nothing ? "-" : bytes2hex(sha256(reinterpret(UInt8, vec(ComplexF64.(psi)))))[1:16]
                @printf("PHYS %-34s E=%.15g conv=%s norm=%.15g psi=%s\n",
                    basename(p), Float64(get(d, "energy", NaN)),
                    string(get(d, "converged", "-")),
                    psi === nothing ? NaN : sum(abs2, psi),
                    h)
            end
            @printf("WALL %s %.1f s\n", cfg, t)
        end
        main(ARGS[1])' "$cfg" 2>&1 | tail -40)   # never filter by form: the first attempt's grep nearly hid the MethodError
}

# CPU arm: unchanged from the run that already came back bit-identical.
export SPINORBEC_NO_AUTO_BACKEND=1
for cfg in runs/validation_level10/L10_F1_smoke.yaml; do
    rm -rf $ROOT/parity_store_before $ROOT/parity_store_after
    run_one "$BEFORE" "$cfg" before
    run_one "$AFTER"  "$cfg" after
done

# GPU arms: the ones that actually exercise DDI, dealias and trunc_radius.
# Twice per side, so run-to-run spread is measured rather than assumed.
unset SPINORBEC_NO_AUTO_BACKEND
nvidia-smi --query-gpu=name --format=csv,noheader 2>&1 | head -1
for cfg in runs/eu_gs_phase_c1_B_kappa/config_smoke.yaml \
           runs/eu_gs_phase_c1_B_kappa/config_c1kappa_preview_B10.yaml; do
    for rep in 1 2; do
        rm -rf $ROOT/parity_store_before $ROOT/parity_store_after
        run_one "$BEFORE" "$cfg" "before_r$rep"
        run_one "$AFTER"  "$cfg" "after_r$rep"
    done
done

echo "ALL DONE $(date)"

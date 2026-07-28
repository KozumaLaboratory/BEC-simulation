# Geometry-probe variant table — the single declaration, sourced by both the
# local runner (probe_leak.sh) and the UGE job script (tsubame_probe.sh).
#
# dx is held at ~0.435 on every axis of every variant, so only the named knob
# moves. Fields: n | box | pad | dt
#
# The table lives here, and the job script looks a variant up by name, because
# `qsub -v` splits its argument on commas: `-v BR_N=64,64,28` reaches the job as
# BR_N=64 and the run dies on a tuple-length error.

declare -A BR_VARIANTS=(
  [base]="64,64,28|28,28,12|0|1.0e-3"    # the 2026-07-28 production geometry, at probe resolution
  [pad]="64,64,28|28,28,12|1|1.0e-3"     # image-free DDI, box unchanged
  [zbox]="64,64,56|28,28,24|0|1.0e-3"    # z half-box 6 -> 12
  [xybox]="92,92,28|40,40,12|0|1.0e-3"   # xy half-box 14 -> 20
  [dtx]="64,64,28|28,28,12|0|5.0e-4"     # dt halved, box unchanged
)

# Export BR_N / BR_BOX / BR_PAD / BR_DT for one variant name.
br_select_variant() {
  local tag=$1
  [[ -n "${BR_VARIANTS[$tag]:-}" ]] || { echo "unknown variant: $tag" >&2; return 1; }
  IFS='|' read -r BR_N BR_BOX BR_PAD BR_DT <<<"${BR_VARIANTS[$tag]}"
  export BR_N BR_BOX BR_PAD BR_DT BR_TAG="_probe_$tag"
}

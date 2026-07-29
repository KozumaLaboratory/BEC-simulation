# Geometry-probe variant table — the single declaration, sourced by both the
# local runner (probe_leak.sh) and the UGE job script (tsubame_probe.sh).
#
# dx is held at ~0.435 on every axis of every variant, so only the named knob
# moves. Fields: n | box | pad | dt
#
# The table lives here, and the job script looks a variant up by name, because
# `qsub -v` splits its argument on commas: `-v BR_N=64,64,28` reaches the job as
# BR_N=64 and the run dies on a tuple-length error.

# Round 1 measured base / pad / dtx and ruled all three explanations out: the
# leak is 736% of the conversion with the edge fraction at 1e-8..1e-6, the
# image-free convolution moves it to 652%, and halving dt reproduces the base
# number to six digits. Round 2 therefore attacks the discretisation itself.
#
# Fields: n | box | pad | dt | trunc      (trunc: NaN = none, 0 = auto radius)
declare -A BR_VARIANTS=(
  [base]="64,64,28|28,28,12|0|1.0e-3|NaN"    # the 2026-07-28 production geometry, at probe resolution
  [pad]="64,64,28|28,28,12|1|1.0e-3|NaN"     # image-free DDI, box unchanged
  [zbox]="64,64,56|28,28,24|0|1.0e-3|NaN"    # z half-box 6 -> 12
  [xybox]="92,92,28|40,40,12|0|1.0e-3|NaN"   # xy half-box 14 -> 20
  [dtx]="64,64,28|28,28,12|0|5.0e-4|NaN"     # dt halved, box unchanged
  [fine]="96,96,42|28,28,12|0|1.0e-3|NaN"    # dx 0.44 -> 0.29 at a FIXED box: resolution, not geometry
  # dx-convergence series at a FIXED box and FIXED stage lengths. The stir
  # output itself is not converged: the same protocol gives Jz(t=10) = 7.75 at
  # dx 0.44 and 12.21 at dx 0.29, a 58% difference in the state that ENTERS the
  # quench. Comparing conversions across resolutions is meaningless until this
  # converges, so `finer` is the third point (dx 0.22, 128x128x56).
  [finer]="128,128,56|28,28,12|0|1.0e-3|NaN"  # dx 0.29 -> 0.22 at a fixed box
  [trunc]="64,64,28|28,28,12|1|1.0e-3|0"     # image-free AND a real-space cutoff on the kernel
)

# PRODUCTION geometries (full stage lengths, unlike the probe entries above).
# The dx-convergence series was measured at stir = 10; at the production stir of
# 30 the same dx = 0.22 leaks 67.7% of the conversion against 15.9% at stir 10,
# so the series does NOT extrapolate and the production resolution is unsettled.
# `prod_dx175` is the same protocol at finer dx to test exactly that.
declare -A BR_PROD_VARIANTS=(
  [prod_dx22]="128,128,80|28.0,28.0,18.0|0|1.0e-3|NaN"    # current production, dx 0.22
  [prod_dx175]="160,160,100|28.0,28.0,18.0|0|1.0e-3|NaN"  # dx 0.175, 2x the cells
  [prod_dx146]="192,192,120|28.0,28.0,18.0|0|1.0e-3|NaN"  # dx 0.146, third convergence point
  # --- residual hunt. The dx series converged the CONVERSION (0.993 -> 1.060 ->
  # 1.066) but left a leak of 0.243 that is no longer scaling away: 0.672 ->
  # 0.286 -> 0.243, i.e. -57% then only -15% for the same 1.2x refinement. Two
  # variables were never tested AT PRODUCTION STAGE LENGTHS -- both were ruled
  # out at stir = 10, where the cloud is far more compact:
  #   xy box  -- edge_x is 2.75e-04 at stir 30, 275x the 1e-6 target. Only z was
  #             ever enlarged. 35/240 = 0.145833 holds dx EXACTLY equal to the
  #             28/192 reference, so this is a one-variable change.
  #   dt      -- the leak grows with the structure the quench injects, and that
  #             is where a time-stepping error would also live.
  [prod_box35]="240,240,120|35.0,35.0,18.0|0|1.0e-3|NaN"   # xy box 28 -> 35 at IDENTICAL dx
  [prod_dt5e4]="192,192,120|28.0,28.0,18.0|0|5.0e-4|NaN"   # dt halved, geometry identical
)

# Export geometry for a PRODUCTION variant. Exists because `qsub -v` splits on
# commas, so a tuple like BR_N=128,128,80 cannot be passed through -v at all --
# it silently becomes several bogus variables. Pass BR_VARIANT=<name> instead.
br_select_prod() {
  local tag=$1
  [[ -n "${BR_PROD_VARIANTS[$tag]:-}" ]] || { echo "unknown prod variant: $tag" >&2; return 1; }
  IFS='|' read -r BR_N BR_BOX BR_PAD BR_DT BR_TRUNC <<<"${BR_PROD_VARIANTS[$tag]}"
  export BR_N BR_BOX BR_PAD BR_DT BR_TRUNC BR_TAG="_$tag"
}

# Export BR_N / BR_BOX / BR_PAD / BR_DT / BR_TRUNC for one variant name.
br_select_variant() {
  local tag=$1
  [[ -n "${BR_VARIANTS[$tag]:-}" ]] || { echo "unknown variant: $tag" >&2; return 1; }
  IFS='|' read -r BR_N BR_BOX BR_PAD BR_DT BR_TRUNC <<<"${BR_VARIANTS[$tag]}"
  export BR_N BR_BOX BR_PAD BR_DT BR_TRUNC BR_TAG="_probe_$tag"
}

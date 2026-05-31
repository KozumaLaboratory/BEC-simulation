# ── Profile recommendation ──────────────────────────────────────────
#
# "Should this spec run on node_q or node_h?" — heuristic answer based
# on grid voxel count × spinor components × bytes-per-complex. Plumbed
# into the dashboard's enqueue preview so the operator sees a hint
# next to the profile selector instead of guessing.
#
# Heuristic floor: psi alone is 16 B (ComplexF64) × n_vox × (2F+1).
# Workspaces (FFT pads, DDI buffers, snapshots) push the live VRAM
# footprint to ~10× psi. We map total VRAM bands to UGE profiles:
#
#   < 4 GB     → gpu_1 (1 H100 on a shared node; cheap)
#   < 20 GB    → node_q (1× H100 + 48 cores, dedicated quarter)
#   < 60 GB    → node_h (2× H100 + 96 cores, half)
#   ≥ 60 GB    → node_f (4× H100 + 192 cores, full)
#
# Bands chosen conservatively — H100 has 80 GB VRAM; we want headroom
# for the multi-snapshot psi save mode and DDI's 2× padded FFT.

export recommend_uge_profile, ProfileRecommendation

"""
    ProfileRecommendation(profile::String, reason::String,
                          est_vram_gb::Float64)

The suggested UGE profile name (lookable in `UGE_PROFILE_DIRECTIVES`),
a one-line operator-readable explanation, and the VRAM estimate the
suggestion was based on so the dashboard tooltip can show it.
"""
struct ProfileRecommendation
    profile::String
    reason::String
    est_vram_gb::Float64
end

"""
    recommend_uge_profile(spec::AbstractDict) -> ProfileRecommendation

Inspect a YAML-loaded spec dict and recommend a TSUBAME UGE profile.
Walks `pipeline[*].ground_state | dynamics.grid.n` to find the largest
voxel count, multiplies by spinor multiplicity inferred from the atom
species, returns the profile that fits with comfortable headroom.

Falls back to "default" (node_q) when the spec can't be parsed —
node_q is the safe single-GPU choice that costs less than the larger
classes.
"""
function recommend_uge_profile(spec::AbstractDict)
    n_vox, F = _largest_grid_and_F(spec)
    if n_vox == 0
        return ProfileRecommendation("default",
            "could not parse grid from spec — defaulting to node_q",
            0.0)
    end
    spinor_mult = 2 * F + 1
    # psi footprint in GB, ×10 fudge for workspace + FFT pads + DDI.
    psi_gb = n_vox * spinor_mult * 16 / 2^30
    est_vram_gb = round(psi_gb * 10; digits=2)

    grid_str = "n_vox=$(n_vox), F=$(F) (×$(spinor_mult)), est ~$(est_vram_gb) GB VRAM"
    if est_vram_gb < 4.0
        ProfileRecommendation("gpu_1",
            "$(grid_str) — fits a shared-node single GPU", est_vram_gb)
    elseif est_vram_gb < 20.0
        ProfileRecommendation("default",
            "$(grid_str) — 1× H100 on a quarter node", est_vram_gb)
    elseif est_vram_gb < 60.0
        ProfileRecommendation("node_h",
            "$(grid_str) — needs 2× H100 (half node)", est_vram_gb)
    else
        ProfileRecommendation("node_f",
            "$(grid_str) — needs full 4× H100 node", est_vram_gb)
    end
end

# ── parsing helpers ──────────────────────────────────────────────────

# Spinor multiplicity by atom name — only a handful are in active use;
# unknown atoms fall back to F=1 which is the safe lower bound for
# scalar VRAM estimation.
const _F_BY_ATOM = Dict{String, Int}(
    "Rb87" => 1, "Na23" => 1, "Cs133" => 1,    # scalar / single-F
    "Cr52" => 3, "Er168" => 6, "Dy164" => 8,
    "Eu151" => 6,
)

function _largest_grid_and_F(spec::AbstractDict)
    pipeline = get(spec, "pipeline", nothing)
    pipeline isa AbstractVector || return (0, 1)
    best_vox = 0
    best_F = 1
    for step in pipeline
        step isa AbstractDict || continue
        for (_, body) in step
            body isa AbstractDict || continue
            grid = get(body, "grid", nothing)
            n = grid isa AbstractDict ? get(grid, "n", nothing) : nothing
            n isa AbstractVector || continue
            voxels = try
                prod(Int.(n))
            catch
                0
            end
            atom = String(get(body, "atom", ""))
            F = get(_F_BY_ATOM, atom, 1)
            # Largest voxel count wins (the dominating VRAM consumer);
            # keep the F that came with it.
            if voxels > best_vox
                best_vox = voxels
                best_F = F
            end
        end
    end
    return (best_vox, best_F)
end

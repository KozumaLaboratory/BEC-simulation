// Resolve a run's human-friendly title for sidebar / page / queue rows.
//
// Run directories come in two shapes:
//   <config_name>_<8hex>         human-authored YAML configs
//   <16hex>                      pure autopilot enqueues, no config name
//
// Showing the raw directory name everywhere leaves the eye chasing 8-16
// hex digits. The autopilot path optionally carries a recipe name (e.g.
// "refine_around_best"), which is the right canonical title when present;
// for human configs the prefix before the trailing hash is already a
// readable slug. Tags stay as a separate, plural pill row — they are
// labels, not the title.

const TRAILING_HASH = /_[0-9a-f]{8,16}$/i
const PURE_HASH = /^[0-9a-f]{16}$/i

export interface DisplayNameOpts {
  /** Recipe name from an autopilot queue entry, when one exists. */
  recipeName?: string | null
}

/** Human-friendly title for `runName`. Falls back: recipe → config prefix → short hash. */
export function displayName(runName: string, opts: DisplayNameOpts = {}): string {
  const recipe = opts.recipeName?.trim()
  if (recipe) return recipe
  if (PURE_HASH.test(runName)) return runName.slice(0, 8) + '…'
  const stripped = runName.replace(TRAILING_HASH, '')
  return stripped || runName
}

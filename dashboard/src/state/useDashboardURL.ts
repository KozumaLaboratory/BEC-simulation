import {
  useQueryStates,
  parseAsBoolean,
  parseAsInteger,
  parseAsString,
  parseAsStringLiteral,
} from 'nuqs'

export const TABS = [
  'overview', 'slice', 'view3d', 'data', 'config', 'queue', 'catalog',
] as const
export type TabId = (typeof TABS)[number]

// URL state for everything that should round-trip across reload / shared
// links. Leva panel values live in localStorage via zustand; they stay
// off the URL so shared links don't inherit private tweaks.
export function useDashboardURL() {
  return useQueryStates(
    {
      run: parseAsString,
      point: parseAsInteger.withDefault(0),
      tab: parseAsStringLiteral(TABS).withDefault('catalog'),
      comp: parseAsInteger.withDefault(0),
      snap: parseAsInteger,
      scan: parseAsString,
      // Transient: SideNav "+ Enqueue" sets this to route to the Queue and
      // pop the dialog; QueuePanel clears it on open (self-clearing flag).
      enqueue: parseAsBoolean.withDefault(false),
    },
    { history: 'replace', shallow: true },
  )
}

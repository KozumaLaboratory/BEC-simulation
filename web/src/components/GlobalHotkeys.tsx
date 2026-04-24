import { useHotkeys } from 'react-hotkeys-hook'
import { useDashboardURL, TABS } from '@/state/useDashboardURL'
import { useRunData } from '@/state/useRunData'
import { isEditableTarget } from '@/state/shortcuts'

// Mounts all the global hotkey bindings (arrow navigation, tab jumps,
// time scrubber). The shortcut-help dialog and ⌘K palette own their own
// hotkeys because they need local open-state.
export function GlobalHotkeys() {
  const [url, setUrl] = useDashboardURL()
  const { runs, data } = useRunData()
  const nPoints = data?.points.length ?? 0

  const guard =
    <T,>(fn: () => T) =>
    (e: KeyboardEvent) => {
      if (isEditableTarget(document.activeElement)) return
      e.preventDefault()
      fn()
    }

  useHotkeys(
    'left',
    guard(() => setUrl({ point: Math.max(0, url.point - 1), snap: null })),
    { enableOnFormTags: false },
    [url.point, setUrl],
  )
  useHotkeys(
    'right',
    guard(() =>
      setUrl({ point: Math.min(Math.max(0, nPoints - 1), url.point + 1), snap: null }),
    ),
    { enableOnFormTags: false },
    [url.point, nPoints, setUrl],
  )
  useHotkeys(
    'shift+left',
    guard(() => {
      if (!url.run) return
      const i = runs.indexOf(url.run)
      if (i > 0) setUrl({ run: runs[i - 1], point: 0, snap: null })
    }),
    { enableOnFormTags: false },
    [runs, url.run, setUrl],
  )
  useHotkeys(
    'shift+right',
    guard(() => {
      if (!url.run) return
      const i = runs.indexOf(url.run)
      if (i >= 0 && i < runs.length - 1) setUrl({ run: runs[i + 1], point: 0, snap: null })
    }),
    { enableOnFormTags: false },
    [runs, url.run, setUrl],
  )

  // Snap scrubbing.
  useHotkeys(
    'openbracket',
    guard(() => setUrl({ snap: Math.max(1, (url.snap ?? 1) - 1) })),
    { enableOnFormTags: false },
    [url.snap, setUrl],
  )
  useHotkeys(
    'closebracket',
    guard(() => setUrl({ snap: (url.snap ?? 1) + 1 })),
    { enableOnFormTags: false },
    [url.snap, setUrl],
  )

  // Tab jumps.
  TABS.forEach((t, i) => {
    // eslint-disable-next-line react-hooks/rules-of-hooks
    useHotkeys(
      String(i + 1),
      guard(() => setUrl({ tab: t })),
      { enableOnFormTags: false },
      [setUrl],
    )
  })

  return null
}

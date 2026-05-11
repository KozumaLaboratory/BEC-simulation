// Single source of truth for keyboard shortcuts: drives both the
// react-hotkeys-hook bindings and the cmdk command palette / cheat-sheet
// dialog. Keep the `keys` string compatible with react-hotkeys-hook
// syntax (`mod+k`, `ctrl+shift+p`, space-separated alternatives).

export interface Shortcut {
  id: string
  keys: string // react-hotkeys-hook combo (or 'mod+k')
  label: string
  section: 'Navigation' | 'Time' | 'View' | 'Global'
}

export const SHORTCUTS: Shortcut[] = [
  { id: 'prev-point', keys: 'left', label: 'Previous point', section: 'Navigation' },
  { id: 'next-point', keys: 'right', label: 'Next point', section: 'Navigation' },
  { id: 'prev-run', keys: 'shift+left', label: 'Previous run', section: 'Navigation' },
  { id: 'next-run', keys: 'shift+right', label: 'Next run', section: 'Navigation' },

  { id: 'prev-snap', keys: 'openbracket', label: 'Previous snapshot', section: 'Time' },
  { id: 'next-snap', keys: 'closebracket', label: 'Next snapshot', section: 'Time' },
  { id: 'play-pause', keys: 'space', label: 'Play / pause time scrubber', section: 'Time' },

  { id: 'tab-overview', keys: '1', label: 'Overview tab', section: 'View' },
  { id: 'tab-slice', keys: '2', label: '2D View tab', section: 'View' },
  { id: 'tab-view3d', keys: '3', label: '3D View tab', section: 'View' },
  { id: 'tab-data', keys: '4', label: 'Data tab', section: 'View' },
  { id: 'tab-config', keys: '5', label: 'Config tab', section: 'View' },

  { id: 'palette', keys: 'mod+k', label: 'Command palette', section: 'Global' },
  { id: 'help', keys: 'shift+slash', label: 'Shortcut cheat-sheet', section: 'Global' },
]

// True if the active element is editable (input, textarea, contenteditable,
// or inside a leva slider marked data-hotkeys-ignore). Used by every
// global hotkey to avoid stealing keys from the run dir selector etc.
export function isEditableTarget(el: EventTarget | null): boolean {
  if (!(el instanceof HTMLElement)) return false
  if (el.closest('[data-hotkeys-ignore]')) return true
  if (el.isContentEditable) return true
  const tag = el.tagName
  return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT'
}

// Pretty-printed keys for the UI. react-hotkeys-hook uses `openbracket`
// and `closebracket` internally; we display `[` `]`.
export function prettyKey(keys: string): string[] {
  return keys.split('+').map((k) => {
    switch (k) {
      case 'mod': return '⌘'
      case 'left': return '←'
      case 'right': return '→'
      case 'up': return '↑'
      case 'down': return '↓'
      case 'space': return 'Space'
      case 'openbracket': return '['
      case 'closebracket': return ']'
      case 'slash': return '/'
      case 'shift': return '⇧'
      case 'ctrl': return '⌃'
      case 'alt': return '⌥'
      default: return k.toUpperCase()
    }
  })
}

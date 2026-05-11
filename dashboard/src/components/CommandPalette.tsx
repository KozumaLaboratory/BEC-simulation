import { useEffect, useState } from 'react'
import { Command } from 'cmdk'
import { useHotkeys } from 'react-hotkeys-hook'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { useDashboardURL, TABS } from '@/state/useDashboardURL'
import { SHORTCUTS, isEditableTarget } from '@/state/shortcuts'

interface Props {
  runs: string[]
}

// ⌘K / Ctrl-K command palette. Exposes runs, tab jumps, and the current
// shortcut registry as searchable, keyboard-navigable items. Uses cmdk
// (the Linear / Vercel one) inside a shadcn Dialog for consistent
// styling and focus trapping.
export function CommandPalette({ runs }: Props) {
  const [open, setOpen] = useState(false)
  const [search, setSearch] = useState('')
  const [, setUrl] = useDashboardURL()

  useHotkeys(
    'mod+k',
    (e) => {
      if (isEditableTarget(document.activeElement) && !open) return
      e.preventDefault()
      setOpen((o) => !o)
    },
    { enableOnFormTags: true },
    [open],
  )

  useEffect(() => {
    if (!open) setSearch('')
  }, [open])

  const go = (patch: Parameters<typeof setUrl>[0]) => {
    setUrl(patch)
    setOpen(false)
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent
        className="p-0 max-w-xl overflow-hidden"
        aria-describedby={undefined}
      >
        <Command className="bg-popover text-popover-foreground">
          <Command.Input
            value={search}
            onValueChange={setSearch}
            placeholder="Search runs, tabs, shortcuts…"
            className="w-full px-4 py-3 text-sm outline-none border-b bg-transparent"
          />
          <Command.List className="max-h-[400px] overflow-auto py-1">
            <Command.Empty className="px-4 py-6 text-sm text-muted-foreground">
              No matches.
            </Command.Empty>

            <Command.Group heading="Tabs" className="px-1 [&_[cmdk-group-heading]]:px-3 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[10px] [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:text-muted-foreground">
              {TABS.map((t) => (
                <Command.Item
                  key={t}
                  value={`tab ${t}`}
                  onSelect={() => go({ tab: t })}
                  className="px-3 py-2 text-sm rounded cursor-pointer aria-selected:bg-accent"
                >
                  Open {t}
                </Command.Item>
              ))}
            </Command.Group>

            <Command.Group heading="Runs" className="px-1 [&_[cmdk-group-heading]]:px-3 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[10px] [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:text-muted-foreground">
              {runs.map((r) => (
                <Command.Item
                  key={r}
                  value={`run ${r}`}
                  onSelect={() => go({ run: r, point: 0, snap: null })}
                  className="px-3 py-2 text-sm rounded cursor-pointer aria-selected:bg-accent font-mono"
                >
                  {r}
                </Command.Item>
              ))}
            </Command.Group>

            <Command.Group heading="Shortcuts" className="px-1 [&_[cmdk-group-heading]]:px-3 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[10px] [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:text-muted-foreground">
              {SHORTCUTS.map((s) => (
                <Command.Item
                  key={s.id}
                  value={`shortcut ${s.label}`}
                  onSelect={() => setOpen(false)}
                  className="px-3 py-2 text-sm rounded cursor-pointer aria-selected:bg-accent text-muted-foreground"
                >
                  {s.label}
                  <span className="ml-auto text-[10px] font-mono">{s.keys}</span>
                </Command.Item>
              ))}
            </Command.Group>
          </Command.List>
        </Command>
      </DialogContent>
    </Dialog>
  )
}

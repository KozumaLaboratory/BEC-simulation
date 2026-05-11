import { useHotkeys } from 'react-hotkeys-hook'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { SHORTCUTS, isEditableTarget, prettyKey, type Shortcut } from '@/state/shortcuts'

interface Props {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function ShortcutHelp({ open, onOpenChange }: Props) {
  useHotkeys(
    'shift+slash',
    (e) => {
      if (isEditableTarget(document.activeElement)) return
      e.preventDefault()
      onOpenChange(!open)
    },
    { enableOnFormTags: false },
    [open, onOpenChange],
  )

  const sections = Array.from(
    new Set(SHORTCUTS.map((s) => s.section)),
  ) as Shortcut['section'][]

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Keyboard shortcuts</DialogTitle>
        </DialogHeader>
        <div className="space-y-4 text-xs">
          {sections.map((sec) => (
            <div key={sec}>
              <div className="text-muted-foreground font-medium mb-1">{sec}</div>
              <dl className="grid grid-cols-[1fr_auto] gap-x-4 gap-y-1">
                {SHORTCUTS.filter((s) => s.section === sec).map((s) => (
                  <div key={s.id} className="contents">
                    <dt>{s.label}</dt>
                    <dd className="flex gap-1 justify-end">
                      {prettyKey(s.keys).map((k, i) => (
                        <kbd
                          key={i}
                          className="px-1.5 py-0.5 bg-muted rounded border text-[10px] font-mono tabular-nums"
                        >
                          {k}
                        </kbd>
                      ))}
                    </dd>
                  </div>
                ))}
              </dl>
            </div>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  )
}

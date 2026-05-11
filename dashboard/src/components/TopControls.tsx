import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Button } from '@/components/ui/button'
import type { RunDataState } from '@/state/useRunData'
import { RefreshCw } from 'lucide-react'

interface Props {
  state: RunDataState
}

export function TopControls({ state }: Props) {
  const { runs, selectedRun, data, xKey, runFilter, setSelectedRun, setXKey, setRunFilter, refresh } = state
  const scanKeys = data?.scan_keys ?? []
  const runNames = data?.run_names ?? []

  return (
    <div className="flex flex-wrap items-end gap-3 mb-4">
      <LabelSelect
        label="Run dir"
        value={selectedRun ?? ''}
        onChange={setSelectedRun}
        options={runs.map((r) => ({ value: r, label: r }))}
        width="min-w-[240px]"
      />
      <LabelSelect
        label="X-axis"
        value={xKey}
        onChange={setXKey}
        options={[
          { value: 'index', label: 'Point index' },
          ...scanKeys.map((k) => ({ value: k, label: k.replace(/^pipeline\.\d+\./, '') })),
        ]}
      />
      {runNames.length > 0 && (
        <LabelSelect
          label="Run"
          value={runFilter || '__all__'}
          onChange={(v) => setRunFilter(v === '__all__' ? '' : v)}
          options={[
            { value: '__all__', label: 'All' },
            ...runNames.map((r) => ({ value: r, label: r })),
          ]}
        />
      )}
      <Button variant="outline" size="sm" onClick={refresh} className="ml-auto">
        <RefreshCw className="size-3" /> Refresh
      </Button>
    </div>
  )
}

interface LabelSelectProps {
  label: string
  value: string
  onChange: (v: string) => void
  options: Array<{ value: string; label: string }>
  width?: string
}

function LabelSelect({ label, value, onChange, options, width }: LabelSelectProps) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs text-muted-foreground">{label}</span>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger className={width ?? 'min-w-[160px]'}>
          <SelectValue placeholder="—" />
        </SelectTrigger>
        <SelectContent>
          {options.map((o) => (
            <SelectItem key={o.value} value={o.value}>
              {o.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}

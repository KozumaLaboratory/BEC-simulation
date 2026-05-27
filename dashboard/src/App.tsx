import { lazy, Suspense, useEffect, useState } from 'react'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Card, CardContent } from '@/components/ui/card'
import { useRunData } from '@/state/useRunData'
import { useDashboardURL } from '@/state/useDashboardURL'
import { SideNav } from '@/components/SideNav'
import { Stats } from '@/components/Stats'
import { MetricLineChart } from '@/components/charts/MetricLineChart'
import {
  PopulationsChart,
  PopulationsHeatmap,
} from '@/components/charts/PopulationsChart'
import { DataTable } from '@/components/DataTable'
import { LoadingBar } from '@/components/LoadingBar'
import { TabBoundary } from '@/components/TabBoundary'
import { GlobalHotkeys } from '@/components/GlobalHotkeys'
import { ShortcutHelp } from '@/components/ShortcutHelp'
import { CommandPalette } from '@/components/CommandPalette'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'

const View3D = lazy(() =>
  import('@/components/View3D').then((m) => ({ default: m.View3D })),
)
const SlicePanel = lazy(() =>
  import('@/components/SlicePanel').then((m) => ({ default: m.SlicePanel })),
)
const ConfigViewer = lazy(() =>
  import('@/components/ConfigViewer').then((m) => ({ default: m.ConfigViewer })),
)
const ScanGroupView = lazy(() => import('@/components/ScanGroupView'))

const TAB_ITEMS = [
  { id: 'overview', label: 'Overview', sheet: '01' },
  { id: 'slice', label: '2D · slice', sheet: '02' },
  { id: 'view3d', label: '3D · volume', sheet: '03' },
  { id: 'data', label: 'Data', sheet: '04' },
  { id: 'config', label: 'Config', sheet: '05' },
] as const

const SIDEBAR_DEFAULT_W = 280
const SIDEBAR_MIN_W = 220
const SIDEBAR_MAX_W = 480

export default function App() {
  const state = useRunData()
  const [url, setUrl] = useDashboardURL()
  const { data, selectedRun, loading, error, xKey, runFilter, runs } = state
  const [helpOpen, setHelpOpen] = useState(false)
  const isDark = useThemeMode()
  const [sidebarW, setSidebarW] = useSidebarWidth()

  if (url.scan) {
    return (
      <Suspense
        fallback={
          <div className="min-h-screen flex items-center justify-center text-sm text-muted-foreground">
            <span className="status-dot is-cyan mr-2" />
            <span className="caret">loading scan group</span>
          </div>
        }
      >
        <ScanGroupView scanName={url.scan} />
      </Suspense>
    )
  }

  return (
    <div className="min-h-screen">
      <LoadingBar active={loading} />
      <GlobalHotkeys />
      <ShortcutHelp open={helpOpen} onOpenChange={setHelpOpen} />
      <CommandPalette runs={runs} />

      <SideNav
        state={state}
        isDark={isDark}
        width={sidebarW}
        onResize={setSidebarW}
        onShortcuts={() => setHelpOpen(true)}
        onToggleTheme={toggleTheme}
      />

      <main
        className="min-h-screen"
        style={{ marginLeft: sidebarW }}
      >
        <div className="max-w-[1320px] mx-auto px-8 md:px-14 py-10 md:py-12">
          <WorkbenchHeader
            runName={data?.run}
            f={data?.F}
            nPoints={data?.n_points}
            runNames={data?.run_names ?? []}
            scanKeys={data?.scan_keys ?? []}
            loading={loading}
            sheetCode={
              TAB_ITEMS.find((t) => t.id === url.tab)?.sheet ?? '01'
            }
          />

          {error && (
            <div
              className="mt-6 px-5 py-3 text-sm flex items-center gap-3 border"
              style={{
                borderRadius: 'var(--radius-pill)',
                borderColor:
                  'color-mix(in oklch, var(--t-red) 50%, transparent)',
                background:
                  'color-mix(in oklch, var(--t-red) 7%, transparent)',
              }}
            >
              <span className="status-dot is-red" />
              <span className="text-foreground/90">{error}</span>
            </div>
          )}

          {loading && !data && (
            <div className="mt-6 flex items-center gap-2.5 text-sm text-muted-foreground">
              <span className="status-dot is-cyan" />
              <span className="caret">acquiring</span>
            </div>
          )}

          <div className="mt-7 flex flex-wrap items-center gap-x-7 gap-y-3 pb-3 border-b border-[var(--ink-faint)]">
            <span className="font-mono text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
              Plot params
            </span>
            <DraftingSelect
              label="x-axis"
              value={xKey}
              onChange={state.setXKey}
              options={[
                { value: 'index', label: 'Point index' },
                ...(data?.scan_keys ?? []).map((k) => ({
                  value: k,
                  label: k.replace(/^pipeline\.\d+\./, ''),
                })),
              ]}
            />
            {(data?.run_names?.length ?? 0) > 1 && (
              <DraftingSelect
                label="series"
                value={runFilter || '__all__'}
                onChange={(v) =>
                  state.setRunFilter(v === '__all__' ? '' : v)
                }
                options={[
                  { value: '__all__', label: 'All runs' },
                  ...(data?.run_names ?? []).map((r) => ({
                    value: r,
                    label: r,
                  })),
                ]}
              />
            )}
          </div>

          <div className="mt-6">
            <Stats data={data} runFilter={runFilter} />
          </div>

          <Tabs
            value={url.tab}
            onValueChange={(v) => setUrl({ tab: v as typeof url.tab })}
            className="w-full mt-10"
          >
            <div className="mb-5">
              <TabsList>
                {TAB_ITEMS.map((t) => (
                  <TabsTrigger key={t.id} value={t.id}>
                    {t.label}
                  </TabsTrigger>
                ))}
              </TabsList>
            </div>

            <TabsContent value="overview" className="space-y-5">
              <TabBoundary>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <Card>
                    <CardContent className="p-6">
                      <ChartLabel index={1} name="Energy" expr="ℏω_ref" />
                      <MetricLineChart
                        data={data}
                        xKey={xKey}
                        runFilter={runFilter}
                        yLabel="Energy"
                        yAccessor={(p) => p.energy}
                        title=""
                      />
                    </CardContent>
                  </Card>
                  <Card>
                    <CardContent className="p-6">
                      <ChartLabel index={2} name="Magnetization" expr="⟨Fz⟩" />
                      <MetricLineChart
                        data={data}
                        xKey={xKey}
                        runFilter={runFilter}
                        yLabel="Mz"
                        yAccessor={(p) => p.mz_actual}
                        title=""
                      />
                    </CardContent>
                  </Card>
                </div>

                <Card>
                  <CardContent className="p-6">
                    <ChartLabel index={3} name="Populations" expr="|c_m|²" />
                    <PopulationsChart
                      data={data}
                      xKey={xKey}
                      runFilter={runFilter}
                    />
                  </CardContent>
                </Card>

                <Card>
                  <CardContent className="p-6">
                    <ChartLabel index={4} name="Populations · heatmap" />
                    <PopulationsHeatmap
                      data={data}
                      xKey={xKey}
                      runFilter={runFilter}
                    />
                  </CardContent>
                </Card>

                <Card>
                  <CardContent className="p-6">
                    <ChartLabel index={5} name="Wall time / point" expr="seconds" />
                    <MetricLineChart
                      data={data}
                      xKey={xKey}
                      runFilter={runFilter}
                      yLabel="duration (s)"
                      yAccessor={(p) => p.duration_seconds}
                      title=""
                      height={260}
                    />
                  </CardContent>
                </Card>
              </TabBoundary>
            </TabsContent>

            <TabsContent value="slice">
              <TabBoundary>
                <Suspense fallback={<TabFallback />}>
                  <SlicePanel run={selectedRun} data={data} />
                </Suspense>
              </TabBoundary>
            </TabsContent>

            <TabsContent value="view3d">
              <TabBoundary>
                <Suspense fallback={<TabFallback />}>
                  <View3D run={selectedRun} data={data} />
                </Suspense>
              </TabBoundary>
            </TabsContent>

            <TabsContent value="data">
              <TabBoundary>
                <DataTable data={data} runFilter={runFilter} />
              </TabBoundary>
            </TabsContent>

            <TabsContent value="config">
              <TabBoundary>
                <Suspense fallback={<TabFallback />}>
                  <ConfigViewer yaml={data?.config_yaml || ''} />
                </Suspense>
              </TabBoundary>
            </TabsContent>
          </Tabs>
        </div>
      </main>
    </div>
  )
}

interface WBHeaderProps {
  runName?: string
  f?: number | null
  nPoints?: number | null
  runNames: string[]
  scanKeys: string[]
  loading: boolean
  sheetCode: string
}

function WorkbenchHeader({
  runName,
  f,
  nPoints,
  runNames,
  scanKeys,
  loading,
  sheetCode,
}: WBHeaderProps) {
  const now = new Date()
  const stamp = `${now.getFullYear()}.${String(now.getMonth() + 1).padStart(
    2,
    '0',
  )}.${String(now.getDate()).padStart(2, '0')}`

  return (
    <header className="sheet">
      <span className="reg-tl" />
      <span className="reg-tr" />
      <span className="reg-bl" />
      <span className="reg-br" />

      {/* Sheet strip — drafting title-block */}
      <div className="sheet-strip -mx-1.5 mb-5">
        <div>
          <span className="text-[var(--ink-faint)]">Sheet</span>{' '}
          <span className="text-[var(--ink)]">{sheetCode} / 05</span>
        </div>
        <div>
          <span className="text-[var(--ink-faint)]">Drawn</span>{' '}
          <span className="text-[var(--ink)] numeric">{stamp}</span>
        </div>
        <div>
          <span className="text-[var(--ink-faint)]">Scale</span>{' '}
          <span className="text-[var(--ink)]">1 : 1</span>
        </div>
        <div>
          <span className="status-dot mr-2 align-middle " style={
            loading ? { background: 'var(--vermillion)' } : undefined
          } />
          <span className="text-[var(--ink-soft)]">
            {loading ? 'Acquiring' : 'Settled'}
          </span>
        </div>
      </div>

      <h1 className="font-condensed font-semibold uppercase tracking-[-0.012em] text-[40px] md:text-[54px] leading-[0.95] text-[var(--ink)] break-words">
        {runName ?? (
          <span className="text-[var(--ink-faint)] caret">awaiting run</span>
        )}
      </h1>

      <div className="mt-4 flex flex-wrap items-baseline gap-x-2.5 gap-y-1 font-mono text-[12.5px] text-[var(--ink-soft)]">
        <MetaInline label="F" value={f != null ? String(f) : '—'} />
        <MetaSep />
        <MetaInline
          label="Points"
          value={nPoints != null ? String(nPoints) : '—'}
        />
        {runNames.length > 1 && (
          <>
            <MetaSep />
            <MetaInline label="Runs" value={`${runNames.length}`} />
          </>
        )}
        {scanKeys.length > 0 && (
          <>
            <MetaSep />
            <MetaInline
              label="Scan"
              value={scanKeys
                .map((k) => k.replace(/^pipeline\.\d+\./, ''))
                .join(' · ')}
            />
          </>
        )}
      </div>
    </header>
  )
}

function MetaInline({ label, value }: { label: string; value: string }) {
  return (
    <span className="inline-flex items-baseline gap-1.5">
      <span className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
        {label}
      </span>
      <span className="numeric text-[13px] text-[var(--ink)]">{value}</span>
    </span>
  )
}

function MetaSep() {
  return (
    <span
      className="inline-block w-px h-3 align-middle"
      style={{ background: 'var(--ink-faint)' }}
      aria-hidden
    />
  )
}

function DraftingSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  options: Array<{ value: string; label: string }>
}) {
  return (
    <div className="inline-flex items-baseline gap-2">
      <span className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
        {label}
      </span>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger
          className="h-7 min-w-[160px] px-2.5 text-[12px] font-mono border-[var(--ink-faint)] hover:border-[var(--ink)]"
          style={{ borderRadius: 0 }}
        >
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

function ChartLabel({
  name,
  expr,
  index,
}: {
  name: string
  expr?: string
  index?: number
}) {
  return (
    <div className="section-head">
      {index != null && (
        <span className="num">§{String(index).padStart(2, '0')}</span>
      )}
      <span>{name}</span>
      <span className="rule" aria-hidden />
      {expr && <span className="unit">{expr}</span>}
    </div>
  )
}

function toggleTheme() {
  const root = document.documentElement
  const next = !root.classList.contains('dark')
  root.classList.toggle('dark', next)
  try {
    localStorage.setItem('spinorbec.theme', next ? 'dark' : 'light')
  } catch {
    /* ignore */
  }
}

function useSidebarWidth(): [number, (w: number) => void] {
  const [width, setWidth] = useState<number>(() => {
    try {
      const stored = localStorage.getItem('spinorbec.sidebarW')
      if (stored) {
        const n = parseInt(stored, 10)
        if (Number.isFinite(n) && n >= SIDEBAR_MIN_W && n <= SIDEBAR_MAX_W) {
          return n
        }
      }
    } catch {
      /* ignore */
    }
    return SIDEBAR_DEFAULT_W
  })

  const set = (w: number) => {
    const clamped = Math.max(SIDEBAR_MIN_W, Math.min(SIDEBAR_MAX_W, w))
    setWidth(clamped)
    try {
      localStorage.setItem('spinorbec.sidebarW', String(clamped))
    } catch {
      /* ignore */
    }
  }

  return [width, set]
}

function useThemeMode() {
  const [isDark, setIsDark] = useState(() =>
    typeof document !== 'undefined' &&
    document.documentElement.classList.contains('dark'),
  )

  useEffect(() => {
    try {
      const stored = localStorage.getItem('spinorbec.theme')
      if (stored === 'light') {
        document.documentElement.classList.remove('dark')
      } else if (stored === 'dark') {
        document.documentElement.classList.add('dark')
      }
    } catch {
      /* ignore */
    }
    setIsDark(document.documentElement.classList.contains('dark'))

    const obs = new MutationObserver(() => {
      setIsDark(document.documentElement.classList.contains('dark'))
    })
    obs.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class'],
    })
    return () => obs.disconnect()
  }, [])

  return isDark
}

function TabFallback() {
  return (
    <Card>
      <CardContent className="h-[400px] flex items-center justify-center text-muted-foreground text-sm">
        <span className="status-dot is-cyan mr-2" />
        <span className="caret">loading view</span>
      </CardContent>
    </Card>
  )
}

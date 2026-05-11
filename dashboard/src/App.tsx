import { lazy, Suspense } from 'react'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Card, CardContent } from '@/components/ui/card'
import { useRunData } from '@/state/useRunData'
import { useDashboardURL } from '@/state/useDashboardURL'
import { TopControls } from '@/components/TopControls'
import { LiveStatusPanel } from '@/components/LiveStatusPanel'
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
import { useState } from 'react'
import { ShortcutHelp } from '@/components/ShortcutHelp'
import { CommandPalette } from '@/components/CommandPalette'
import { Button } from '@/components/ui/button'
import { Keyboard } from 'lucide-react'

// Lazy chunks — three/webgpu + R3F + drei is ~1.7MB; splitting keeps the
// initial payload light. SlicePanel stays eager since it shares Plotly with
// Overview anyway.
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

export default function App() {
  const state = useRunData()
  const [url, setUrl] = useDashboardURL()
  const { data, selectedRun, loading, error, xKey, runFilter, runs } = state
  const [helpOpen, setHelpOpen] = useState(false)

  if (url.scan) {
    return (
      <Suspense fallback={<div className="p-10 text-sm text-muted-foreground">Loading scan group…</div>}>
        <ScanGroupView scanName={url.scan} />
      </Suspense>
    )
  }

  return (
    <div className="min-h-screen p-6 max-w-[1400px] mx-auto">
      <LoadingBar active={loading} />
      <GlobalHotkeys />
      <ShortcutHelp open={helpOpen} onOpenChange={setHelpOpen} />
      <CommandPalette runs={runs} />
      <header className="mb-4 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-primary">
            {data?.run ?? 'SpinorBEC dashboard'}
          </h1>
          {data && (
            <p className="text-xs text-muted-foreground mt-1">
              F={data.F} · {data.n_points} points
              {(data.run_names?.length ?? 0) > 0 &&
                ` · runs: ${data.run_names.join(', ')}`}
              {(data.scan_keys?.length ?? 0) > 0 &&
                ` · scan: ${data.scan_keys.join(', ')}`}
            </p>
          )}
        </div>
        <div className="flex gap-2 text-xs text-muted-foreground">
          <Button variant="outline" size="sm" onClick={() => setHelpOpen(true)} title="Keyboard shortcuts (?)">
            <Keyboard className="size-3" /> <span className="hidden md:inline">Shortcuts</span>
          </Button>
        </div>
      </header>

      <TopControls state={state} />

      <div className="mb-3">
        <LiveStatusPanel run={selectedRun} onSelect={state.setSelectedRun} />
      </div>

      {error && (
        <div className="mb-4 rounded-md border border-destructive/50 bg-destructive/10 px-4 py-2 text-sm text-destructive">
          {error}
        </div>
      )}

      {loading && !data && (
        <div className="text-sm text-muted-foreground mb-4">Loading…</div>
      )}

      <Stats data={data} runFilter={runFilter} />

      <Tabs
        value={url.tab}
        onValueChange={(v) => setUrl({ tab: v as typeof url.tab })}
        className="w-full"
      >
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="slice">2D View</TabsTrigger>
          <TabsTrigger value="view3d">3D View</TabsTrigger>
          <TabsTrigger value="data">Data</TabsTrigger>
          <TabsTrigger value="config">Config</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
          <TabBoundary>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardContent className="p-3">
                  <MetricLineChart
                    data={data}
                    xKey={xKey}
                    runFilter={runFilter}
                    yLabel="Energy"
                    yAccessor={(p) => p.energy}
                    title="Energy"
                  />
                </CardContent>
              </Card>
              <Card>
                <CardContent className="p-3">
                  <MetricLineChart
                    data={data}
                    xKey={xKey}
                    runFilter={runFilter}
                    yLabel="Mz"
                    yAccessor={(p) => p.mz_actual}
                    title="Magnetization Mz"
                  />
                </CardContent>
              </Card>
            </div>

            <Card>
              <CardContent className="p-3">
                <PopulationsChart data={data} xKey={xKey} runFilter={runFilter} />
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-3">
                <PopulationsHeatmap data={data} xKey={xKey} runFilter={runFilter} />
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-3">
                <MetricLineChart
                  data={data}
                  xKey={xKey}
                  runFilter={runFilter}
                  yLabel="duration (s)"
                  yAccessor={(p) => p.duration_seconds}
                  title="Per-point compute time"
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
  )
}

function TabFallback() {
  return (
    <Card>
      <CardContent className="h-[400px] flex items-center justify-center text-muted-foreground text-sm">
        Loading…
      </CardContent>
    </Card>
  )
}

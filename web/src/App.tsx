import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { useRunData } from '@/state/useRunData'
import { TopControls } from '@/components/TopControls'
import { Stats } from '@/components/Stats'
import { MetricLineChart } from '@/components/charts/MetricLineChart'
import {
  PopulationsChart,
  PopulationsHeatmap,
} from '@/components/charts/PopulationsChart'
import { View3D } from '@/components/View3D'

export default function App() {
  const state = useRunData()
  const { data, selectedRun, loading, error, xKey, runFilter } = state

  return (
    <div className="min-h-screen p-6 max-w-[1400px] mx-auto">
      <header className="mb-4">
        <h1 className="text-2xl font-semibold text-primary">
          {data?.run ?? 'SpinorBEC dashboard'}
        </h1>
        {data && (
          <p className="text-xs text-muted-foreground mt-1">
            F={data.F} · {data.n_points} points
            {data.run_names.length > 0 && ` · runs: ${data.run_names.join(', ')}`}
            {data.scan_keys.length > 0 && ` · scan: ${data.scan_keys.join(', ')}`}
          </p>
        )}
      </header>

      <TopControls state={state} />

      {error && (
        <div className="mb-4 rounded-md border border-destructive/50 bg-destructive/10 px-4 py-2 text-sm text-destructive">
          {error}
        </div>
      )}

      {loading && !data && (
        <div className="text-sm text-muted-foreground mb-4">Loading…</div>
      )}

      <Stats data={data} runFilter={runFilter} />

      <Tabs defaultValue="overview" className="w-full">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="view3d">3D View</TabsTrigger>
          <TabsTrigger value="config">Config</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
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
        </TabsContent>

        <TabsContent value="view3d">
          <View3D run={selectedRun} data={data} />
        </TabsContent>

        <TabsContent value="config">
          <Card>
            <CardHeader>
              <CardTitle>config.yaml</CardTitle>
            </CardHeader>
            <CardContent>
              <pre className="text-xs overflow-auto max-h-[600px] p-3 bg-muted/30 rounded-md whitespace-pre-wrap">
                {data?.config_yaml || '(no config)'}
              </pre>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

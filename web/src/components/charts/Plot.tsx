import type * as React from 'react'
import Plotly from 'plotly.js-dist-min'
import * as plotlyFactoryModule from 'react-plotly.js/factory'
import type { Layout, Config } from 'plotly.js-dist-min'

// react-plotly.js/factory is a CJS module whose default export is the
// factory function. Vite's ESM interop sometimes delivers it as
// `{ default: fn }` instead of the function itself, so unwrap both shapes.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const factoryAny = plotlyFactoryModule as any
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const createPlotlyComponent: (plotly: any) => React.ComponentType<any> =
  typeof factoryAny === 'function'
    ? factoryAny
    : typeof factoryAny.default === 'function'
      ? factoryAny.default
      : factoryAny.default?.default
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const Plot = createPlotlyComponent(Plotly as any)

export const CHART_COLORS = [
  '#00d9ff',
  '#a277ff',
  '#ffd580',
  '#ff6b9d',
  '#50fa7b',
  '#ff8fab',
  '#80e0ff',
  '#c0ff60',
  '#ff60c0',
  '#60ffc0',
  '#ffc060',
  '#c060ff',
  '#60c0ff',
]

export const BASE_LAYOUT: Partial<Layout> = {
  paper_bgcolor: 'rgba(0,0,0,0)',
  plot_bgcolor: 'rgba(0,0,0,0)',
  font: { family: 'ui-sans-serif, system-ui, sans-serif', color: '#e6edf3', size: 12 },
  margin: { t: 30, r: 20, b: 45, l: 60 },
  xaxis: { gridcolor: '#21262d', zerolinecolor: '#3d4550' },
  yaxis: { gridcolor: '#21262d', zerolinecolor: '#3d4550' },
  legend: { bgcolor: 'rgba(0,0,0,0)' },
}

export const BASE_CONFIG: Partial<Config> = {
  responsive: true,
  displayModeBar: false,
}

export { Plot }

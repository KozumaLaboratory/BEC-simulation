import Plotly from 'plotly.js-dist-min'
import createPlotlyComponent from 'react-plotly.js/factory'
import type { Layout, Config } from 'plotly.js-dist-min'

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

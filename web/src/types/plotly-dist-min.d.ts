declare module 'plotly.js-dist-min' {
  import * as PlotlyJS from 'plotly.js'
  export * from 'plotly.js'
  const Plotly: typeof PlotlyJS
  export default Plotly
}

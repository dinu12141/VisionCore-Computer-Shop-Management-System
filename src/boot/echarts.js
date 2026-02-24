import { boot } from 'quasar/wrappers'
import ECharts from 'vue-echarts'
import { use } from 'echarts/core'

import { CanvasRenderer, SVGRenderer } from 'echarts/renderers'
import { BarChart, LineChart, PieChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  LegendComponent,
  TitleComponent,
  DatasetComponent,
  TransformComponent,
  VisualMapComponent,
  ToolboxComponent,
  DataZoomComponent,
  MarkPointComponent,
  MarkLineComponent,
  MarkAreaComponent,
} from 'echarts/components'

export default boot(({ app }) => {
  console.log('[ECharts Boot] Registering v-chart and VChart components')

  use([
    CanvasRenderer,
    SVGRenderer,
    BarChart,
    LineChart,
    PieChart,
    GridComponent,
    TooltipComponent,
    LegendComponent,
    TitleComponent,
    DatasetComponent,
    TransformComponent,
    VisualMapComponent,
    ToolboxComponent,
    DataZoomComponent,
    MarkPointComponent,
    MarkLineComponent,
    MarkAreaComponent,
  ])

  app.component('v-chart', ECharts)
  app.component('VChart', ECharts)
})

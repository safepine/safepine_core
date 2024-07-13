class Charts extends React.Component 
{
  constructor(props) 
  {
    super(props);

    // Class Variables
    this.prices_ALL = [];
    this.dates_ALL = [];
    this.contents = [];
    this.symbols_ALL = [];
    this.windowSize = 0;
    this.chartType = 0;

    // Plotly + React
    this.Plot = createPlotlyComponent(Plotly);

    // Renders
    this.RenderPage = RenderPage.bind(this);

    // Data Interface
    this.CB_DataTransmission = CB_DataTransmission.bind(this);
    this.GET_DataTransmission = GET_DataTransmission.bind(this);

    // User Interface
    this.CB_ChartOptions = CB_ChartOptions.bind(this);
    this.UpdateCharts = UpdateCharts.bind(this);

    // State
    this.state = {content: this.RenderPage()};
    this.revision += 1

    // Initiate connection to the backend
    this.GET_DataTransmission();
  }

  render(type) { return this.state.content; }
}
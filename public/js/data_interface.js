function GET_DataTransmission() 
{
  fetch("/transmission", {
    method: 'GET'
  })
    .then(response => response.text())
    .then(text => {
      this.CB_DataTransmission(text)
    })
}

function GET_PortfolioTransmission()
{
  fetch("/portfolio", {
    method: 'GET'
  })
    .then(response => response.text())
    .then(text => {
      this.CB_PortfolioTransmission(text)
    })
}

function CB_DataTransmission(data_IN) 
{
  data_IN_json = JSON.parse(data_IN);
  for(symbol in data_IN_json)
  {
    prices_close = [];
    prices_high = [];
    prices_low = [];
    prices_open = [];
    dates = [];
    for(row in data_IN_json[symbol]["prices"])
    {
      prices_close.push(data_IN_json[symbol]["prices"][row]["close"]);
      prices_high.push(data_IN_json[symbol]["prices"][row]["high"]);
      prices_low.push(data_IN_json[symbol]["prices"][row]["low"]);
      prices_open.push(data_IN_json[symbol]["prices"][row]["open"]);
      dates.push(data_IN_json[symbol]["prices"][row]["date"]);
    }
    this.prices_ALL.push([prices_close, prices_high, prices_low, prices_open]);
    this.dates_ALL.push(dates);
    this.symbols_ALL.push(symbol);
  }
  this.windowSize = 0;
  this.UpdateCharts(this.windowSize);
}


function CB_PortfolioTransmission(data_IN) 
{
  this.revision += 1
  var charts = [];
  var data_IN_json = JSON.parse(data_IN);

  // Equity
  var time_series_prices = [data_IN_json["close"]["values"],
    data_IN_json["high"]["values"],
    data_IN_json["low"]["values"],
    data_IN_json["open"]["values"]];
  var time_series_dates = data_IN_json["close"]["dates"];   
  mainChart = React.createElement(
    this.Plot, 
    {
      data: chartTrace(
        time_series_dates, 
        time_series_prices, "OHLC" ),
      layout: chartLayout(
        time_series_dates, 
        this.revision,
        this.shapeColor),
      config: {displaylogo: false},
      onUpdate: this.CB_CaptureInput
    }
  );
  final_price = time_series_prices[0][time_series_prices[0].length-1];
  price_change = final_price - time_series_prices[0][0];
  final_price = "$"+Math.round(final_price*100)/100;
  charts.push(this.RenderPortfolioCharts(mainChart, "Total Equity", final_price, price_change))

  // Percentage
  var time_series_portfolio_equity_percentage = data_IN_json["percentage_portfolio"]["values"];
  var time_series_benchmark_equity_percentage = data_IN_json["percentage_benchmark"]["values"];
  mainChart =  React.createElement(
    this.Plot, 
    {
      data: percentageReturnTrace(
        time_series_dates, 
        time_series_portfolio_equity_percentage,
        time_series_benchmark_equity_percentage),
      layout: percentageReturnLayout(
        time_series_dates,
        this.revision),
      config: {displaylogo: false}
    }
  );
  charts.push(this.RenderPortfolioCharts(mainChart, "Percentage", 0.0, 0.0, false))

  // Dividends
  var time_series_cash = data_IN_json["cash"]["values"];
  var time_series_dividends = data_IN_json["dividend"]["values"];
  var time_series_equity_non_cash = ["non_cash"]["values"];
  mainChart = React.createElement(
    this.Plot, 
    {
      data: dividendTrace(
        time_series_dates, 
        time_series_cash, 
        time_series_equity_non_cash, 
        time_series_dividends),
      layout: dividendLayout(
        time_series_dates, 
        this.revision),
      config: {displaylogo: false}
    }
  );
  charts.push(this.RenderPortfolioCharts(mainChart, "Dividends", 0.0, 0.0, false))

  // Pie chart: start
  var pie_begin_names = data_IN_json["pie_begin"]["name"];
  var pie_begin_values = data_IN_json["pie_begin"]["values"];
  mainChart = React.createElement(
    this.Plot, 
    {
      data: pieTrace(
        pie_begin_names, 
        pie_begin_values),
      layout: pieLayout(
        this.revision),
      config: {displaylogo: false}
    }
  );
  charts.push(this.RenderPortfolioCharts(mainChart, "Initial Allocation", 0.0, 0.0, false))

  // Pie chart: end
  var pie_end_names = data_IN_json["pie_end"]["name"];
  var pie_end_values = data_IN_json["pie_end"]["values"];
  mainChart = React.createElement(
    this.Plot, 
    {
      data: pieTrace(
        pie_end_names, 
        pie_end_values),
      layout: pieLayout(
        this.revision),
      config: {displaylogo: false}
    }
  );
  charts.push(this.RenderPortfolioCharts(mainChart, "Final Allocation", 0.0, 0.0, false))

  // Histogram: Portfolio
  var histogram_portfolio_daily_percentage_change = data_IN_json["daily_returns_portfolio"]["daily_returns"];
  mainChart = React.createElement(
    this.Plot, 
    {
      data: distributionTrace(
        histogram_portfolio_daily_percentage_change, 
        'rgba(0,255,0,0.5)'),
      layout: distributionLayout(
        this.revision, 
        "Portfolio"),
      config: {displaylogo: false}
    }
  );
  charts.push(this.RenderPortfolioCharts(mainChart, "Histogram: Portfolio", 0.0, 0.0, false))

  // Histogram: Benchmark
  var histogram_benchmark_daily_percentage_change = data_IN_json["daily_returns_benchmark"]["daily_returns"];  
  mainChart = React.createElement(
    this.Plot, 
    {
      data: distributionTrace(
        histogram_benchmark_daily_percentage_change, 
        '#007BFF'),
      layout: distributionLayout( 
        this.revision, 
        "Benchmark"),
      config: {displaylogo: false}
    }
  );
  charts.push(this.RenderPortfolioCharts(mainChart, "Histogram: Benchmark", 0.0, 0.0, false))


  var rightHandSide = React.createElement(
      "div",
      {        
        key: "div_6",
        className:"col overflow-auto",
      },
      charts);
  this.setState({content: this.RenderPage(rightHandSide)});

}

function UpdateCharts(cutLength_IN, type_IN = "OHLC", chartShapes_IN = [])
{
  this.windowSize = cutLength_IN;
  this.chartType = type_IN;
  this.revision += 1

  var charts = [];
  for (let i = 0; i < this.prices_ALL.length; i++) 
  {
    var time_series_prices = [];
    var time_series_dates = [];

    if(this.windowSize == 0 || this.windowSize > this.prices_ALL[i][0].length)
    {
      time_series_prices = this.prices_ALL[i];
      time_series_dates = this.dates_ALL[i];      
    }
    else
    {
      time_series_prices.push(this.prices_ALL[i][0].slice(this.prices_ALL[i][0].length-this.windowSize, this.prices_ALL[i][0].length-1));
      time_series_prices.push(this.prices_ALL[i][1].slice(this.prices_ALL[i][1].length-this.windowSize, this.prices_ALL[i][1].length-1));
      time_series_prices.push(this.prices_ALL[i][2].slice(this.prices_ALL[i][2].length-this.windowSize, this.prices_ALL[i][2].length-1));
      time_series_prices.push(this.prices_ALL[i][3].slice(this.prices_ALL[i][3].length-this.windowSize, this.prices_ALL[i][3].length-1));
      time_series_dates = this.dates_ALL[i].slice(time_series_dates.length-this.windowSize, time_series_dates.length-1);
    }
    final_price = time_series_prices[0][time_series_prices[0].length-1];
    price_change = final_price - time_series_prices[0][0];
    final_price = "$"+Math.round(final_price*100)/100;
    mainChart = React.createElement(
      this.Plot, 
      {
        data: chartTrace(
          time_series_dates, 
          time_series_prices, type_IN),
        layout: chartLayout(
          time_series_dates, 
          this.revision,
          this.shapeColor,
          chartShapes_IN),
        config: {displaylogo: false},
        onUpdate: this.CB_CaptureInput
      }
    );
    charts.push(this.RenderCharts(mainChart, this.symbols_ALL[i], final_price, price_change))
  }
  var rightHandSide = React.createElement(
      "div",
      {        
        key: "div_6",
        className:"col overflow-auto",
      },
      charts);
  this.setState({content: this.RenderPage(rightHandSide)});
}

function CB_ChartOptions() 
{
  console.log(event.target.innerText);
  if(event.target.innerText == 'DrawLine - Red')
  {
    this.shapeColor = 'red'
    this.UpdateCharts(this.windowSize, this.chartType, this.chartShapes)
  }
  else if(event.target.innerText == 'DrawLine - Green')
  {
    this.shapeColor = 'green'
    console.log('green');
    this.UpdateCharts(this.windowSize, this.chartType, this.chartShapes)
  }
  else if(event.target.innerText == 'DrawLine - Blue')
  {
    this.shapeColor = 'blue'
    this.UpdateCharts(this.windowSize, this.chartType, this.chartShapes)
  }
  else if(event.target.innerText == '5d') 
    this.UpdateCharts(5, this.chartType)
  else if(event.target.innerText == '1m')
    this.UpdateCharts(30, this.chartType)
  else if(event.target.innerText == '3m') 
    this.UpdateCharts(90, this.chartType)
  else if(event.target.innerText == '6m')
    this.UpdateCharts(180, this.chartType)
  else if(event.target.innerText == '1y')
    this.UpdateCharts(360, this.chartType)
  else if(event.target.innerText == '5y')
    this.UpdateCharts(360*5, this.chartType)
  else if(event.target.innerText == 'max')
    this.UpdateCharts(0, this.chartType)
  else if(event.target.innerText == 'OHLC')
    this.UpdateCharts(this.windowSize, "OHLC")
  else if(event.target.innerText == 'Close')
    this.UpdateCharts(this.windowSize, "Close")
}

function CB_CaptureInput(figure_IN)
{
  this.chartShapes = figure_IN.layout.shapes;
}

function CB_PortfolioView()
{
  this.GET_PortfolioTransmission();
}

function CB_WatchlistView()
{
  this.GET_DataTransmission();
}

function UpdateCharts(cutLength_IN, type_IN = "OHLC", chartShapes_IN = [])
{
  this.windowSize = cutLength_IN;
  this.chartType = type_IN;
  this.revision += 1

  var charts = [];
  for (let i = 0; i < this.prices_ALL.length; i++) 
  {
    var time_series_prices = [];
    var time_series_dates = [];

    if(this.windowSize == 0 || this.windowSize > this.prices_ALL[i][0].length)
    {
      time_series_prices = this.prices_ALL[i];
      time_series_dates = this.dates_ALL[i];      
    }
    else
    {
      time_series_prices.push(this.prices_ALL[i][0].slice(this.prices_ALL[i][0].length-this.windowSize, this.prices_ALL[i][0].length-1));
      time_series_prices.push(this.prices_ALL[i][1].slice(this.prices_ALL[i][1].length-this.windowSize, this.prices_ALL[i][1].length-1));
      time_series_prices.push(this.prices_ALL[i][2].slice(this.prices_ALL[i][2].length-this.windowSize, this.prices_ALL[i][2].length-1));
      time_series_prices.push(this.prices_ALL[i][3].slice(this.prices_ALL[i][3].length-this.windowSize, this.prices_ALL[i][3].length-1));
      time_series_dates = this.dates_ALL[i].slice(time_series_dates.length-this.windowSize, time_series_dates.length-1);
    }
    final_price = time_series_prices[0][time_series_prices[0].length-1];
    price_change = final_price - time_series_prices[0][0];
    final_price = "$"+Math.round(final_price*100)/100;
    mainChart = React.createElement(
      this.Plot, 
      {
        data: chartTrace(
          time_series_dates, 
          time_series_prices, type_IN),
        layout: chartLayout(
          time_series_dates, 
          this.revision,
          this.shapeColor,
          chartShapes_IN),
        config: {displaylogo: false},
        onUpdate: this.CB_CaptureInput
      }
    );
    charts.push(this.RenderCharts(mainChart, this.symbols_ALL[i], final_price, price_change))
  }
  var rightHandSide = React.createElement(
      "div",
      {        
        key: "div_6",
        className:"col overflow-auto",
      },
      charts);
  this.setState({content: this.RenderPage(rightHandSide)});
}

function CB_ChartOptions() 
{
  console.log(event.target.innerText);
  if(event.target.innerText == 'DrawLine - Red')
  {
    this.shapeColor = 'red'
    this.UpdateCharts(this.windowSize, this.chartType, this.chartShapes)
  }
  else if(event.target.innerText == 'DrawLine - Green')
  {
    this.shapeColor = 'green'
    console.log('green');
    this.UpdateCharts(this.windowSize, this.chartType, this.chartShapes)
  }
  else if(event.target.innerText == 'DrawLine - Blue')
  {
    this.shapeColor = 'blue'
    this.UpdateCharts(this.windowSize, this.chartType, this.chartShapes)
  }
  else if(event.target.innerText == '5d') 
    this.UpdateCharts(5, this.chartType)
  else if(event.target.innerText == '1m')
    this.UpdateCharts(30, this.chartType)
  else if(event.target.innerText == '3m') 
    this.UpdateCharts(90, this.chartType)
  else if(event.target.innerText == '6m')
    this.UpdateCharts(180, this.chartType)
  else if(event.target.innerText == '1y')
    this.UpdateCharts(360, this.chartType)
  else if(event.target.innerText == '5y')
    this.UpdateCharts(360*5, this.chartType)
  else if(event.target.innerText == 'max')
    this.UpdateCharts(0, this.chartType)
  else if(event.target.innerText == 'OHLC')
    this.UpdateCharts(this.windowSize, "OHLC")
  else if(event.target.innerText == 'Close')
    this.UpdateCharts(this.windowSize, "Close")
}

function CB_CaptureInput(figure_IN)
{
  this.chartShapes = figure_IN.layout.shapes;
}

function CB_PortfolioView()
{
  this.GET_PortfolioTransmission();
}

function CB_WatchlistView()
{
  this.GET_DataTransmission();
}

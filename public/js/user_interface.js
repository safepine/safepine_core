function UpdateCharts(cutLength_IN, type_IN = "OHLC")
{
  this.windowSize = cutLength_IN;
  this.chartType = type_IN;
  this.contents = [];
  this.revision += 1

  for (let i = 0; i < this.prices_ALL.length; i++) 
  {
    var time_series_prices = [];
    var time_series_dates = [];

    if(this.windowSize == 0)
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
          this.revision),
        config: {displaylogo: false}
      }
    );
    this.contents.push(this.RenderPage(mainChart, this.symbols_ALL[i], final_price, price_change))
  }
  this.setState({content: [this.contents]});
}

function CB_ChartOptions() 
{
  if(event.target.innerText == '5d') 
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
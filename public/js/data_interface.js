function GET_DataTransmission(render_figure = true) 
{
  fetch("/transmission", {
    method: 'GET'
  })
    .then(response => response.text())
    .then(text => {
      this.CB_DataTransmission(text,render_figure)
    })
}

function CB_DataTransmission(data_IN, render_figure = true) 
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
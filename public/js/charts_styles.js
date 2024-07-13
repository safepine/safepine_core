function chartTrace(dates_IN, price_IN, type_IN) {
  var trace = 0;
  if(type_IN == "Close")
  {
    trace = 
    {
      x: dates_IN,            
      y: price_IN[0],         
      type: 'scatter',
      showlegend: false,
    };
  }
  else if(type_IN == "OHLC")
  {
    trace = 
    {
      x: dates_IN,            
      close: price_IN[0], 
      high: price_IN[1], 
      low: price_IN[2], 
      open: price_IN[3],         
      type: 'candlestick',
      showlegend: false,
    };    
  }
  return [trace];
}

function chartLayout(dates_IN, revision_IN) {
  var layout = 
  {         
    margin: { l: 40, r: 40, b: 0, t: 40, pad: 0 },
    datarevision: revision_IN,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    showlegend: false,
    xaxis: { gridcolor: 'rgba(255,255,255,0.1)', tickfont: {color: 'rgba(255,255,255,1)',},},
    yaxis: { gridcolor: 'rgba(255,255,255,0.1)', tickfont: {color: 'rgba(255,255,255,1)',},}
  };
  return layout;
}
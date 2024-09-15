/// Watchlist
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

function chartLayout(
  dates_IN, 
  revision_IN, 
  color_IN = 'red', 
  shapes_IN = [],
  arrowValues_IN = [],
  arrowDates_IN = [],
  arrowPrices_IN = []) 
{
  var annotation_array = [];
  var annotation_color = "";
  var annotation_direction = 0;

  for(i = 0; i < arrowValues_IN.length; i++) {
    if(arrowValues_IN[i] > 0) {
      annotation_color = "green";
      annotation_direction = 1;
    }
    else {
      annotation_color = "red";
      annotation_direction = -1;
    }
    var annotation = {
      x: arrowDates_IN[i],
      y: arrowPrices_IN[i],
      text: arrowValues_IN[i],
      textangle: 0,
      ax: 0,
      ay: annotation_direction*25,
      font: {
        color: "White",
        size: 12
      },
      arrowcolor: annotation_color,
      arrowsize: 1,
      arrowwidth: 2,
      arrowhead: 2
    }
    annotation_array.push(annotation);
  }

  var layout = 
  {
    annotations: annotation_array,
    margin: { l: 40, r: 40, b: 0, t: 40, pad: 0 },
    dragmode: "drawline",
    newshape: { line: {color: color_IN,}},
    shapes: shapes_IN,
    datarevision: revision_IN,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    showlegend: false,
    xaxis: { gridcolor: 'rgba(255,255,255,0.1)', tickfont: {color: 'rgba(255,255,255,1)',},},
    yaxis: { gridcolor: 'rgba(255,255,255,0.1)', tickfont: {color: 'rgba(255,255,255,1)',},}
  };
  return layout;
}

function chartSwings(dates_IN, price_IN, color_IN) {
  var trace = {

        x: dates_IN,
        y: price_IN,
        mode: 'markers',
        name: 'Swings',
        marker: {
          color: color_IN,
          size: 10
        },
        arrowcolor: "red",
        arrowsize: 3,
        arrowwidth: 1,
        arrowhead: 1
  };
  return trace;
}

function chartFilter(dates_IN, price_IN) {
  var trace = 
  {
    x: dates_IN,            
    y: price_IN,         
    type: 'scatter',
    showlegend: false,
    marker: {
      color: 'rgb(30,144,255)',
    }
  };
  return [trace];
}

/// Portfolio
function ohlcTrace(dates_IN, price_IN) {
  // Green/Black traces
  // Increasing: 'rgba(0,255,0,0.5)'
  // Decreasing: 'rgba(0,0,0,0.5)'

  var trace = 
  {
    x: dates_IN,            
    close: price_IN[0], 
    high: price_IN[1], 
    low: price_IN[2], 
    open: price_IN[3],         
    type: 'candlestick', 
    increasing: 
    {
      line: 
      {
        color: 'rgba(0,255,0,1.0)'
      }
    }, 
    decreasing: 
    {
      line: 
      {
        color: 'rgba(255,0,0,1.0)'
      }
    }, 
    xaxis: 'x2',
    yaxis: 'y5',
    showlegend: false,
  };
  return [trace];
}

function ohlcLayout(dates_IN, revision_IN) { 
  var layout = 
  {         
    margin: 
    {
      l: 30,
      r: 0,
      b: 120,
      t: 50,
      pad: 0
    },
    title: 
    {
      text:'Open/High/Low/Close',
      font: 
      {
        family: 'Arial, sans-serif',
        color: 'rgba(255,255,255,1)',
        size: 24
      },
      xref: 'paper',
      x: 0.05,
    },     
    datarevision: revision_IN,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    showlegend: true,    
    xaxis2: 
    {
      anchor: 'y5', 
      domain: [0.0, 1.0],
      tickmode: "linear",
      tick0: dates_IN,
      dtick: 15, // days
      titlefont: 
      {
        family: 'Rockwell, sans-serif',
        size: 18,
        color: '#007BFF'
      },            
      tickfont: 
      {
        family: 'Rockwell, serif',
        size: 10,
        color: 'rgba(255,255,255,1)', 
      },   
      gridcolor: 'rgba(255,255,255,0.25)',  
      rangeslider: 
      {
        visible: true
      }       
      },
      yaxis5: 
      {
        anchor: 'x2', 
        domain: [0.0, 1.0], 
        position: 0.0,  
        titlefont: 
        {
          anchor: 'free', 
          family: 'Arial, sans-serif',
          size: 18,
          color: '#007BFF'
        },  
        tickfont: 
        {
          family: 'Rockwell, serif',
          size: 14,
          color: 'rgba(255,255,255,1)', 
        },   
        gridcolor: 'rgba(255,255,255,0.25)',      
      }, 
    };
  return layout;
}

function dividendLayout(dates_IN, revision_IN) { 
  var layout = {
    margin: 
    {
      l: 30,
      r: 0,
      b: 120,
      t: 50,
      pad: 0
    },    
    title: {
      font: 
      {
        family: 'Arial, sans-serif',
        color: 'rgba(255,255,255,1)',
        size: 24
      },
      xref: 'paper',
      x: 0.05,
    },
    datarevision: revision_IN,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    showlegend: false,
    xaxis2: {
      anchor: 'y4', 
      domain: [0.0, 1.0],
      tickmode: "linear",
      tick0: dates_IN,
      dtick: 15, // days
      titlefont: 
      {
        family: 'Arial, sans-serif',
        size: 12,
        color: '#007BFF'
      },       
      gridcolor: 'rgba(255,255,255,0.1)',
      tickfont: 
      {
        family: 'Arial, serif',
        size: 10,
        color: 'rgba(255,255,255,1)'
      },     
      rangeslider: 
      {
        visible: false
      }       
    },  
    yaxis4: {
      anchor: 'x2', 
      domain: [0.0, 1.0],
      titlefont: 
      {
        anchor: 'free', 
        family: 'Arial, sans-serif',
        size: 12,
        color: '#007BFF'
      },  
      gridcolor: 'rgba(255,255,255,0.05)',
      tickfont: 
      {
        family: 'Arial, serif',
        size: 14,
        color: 'rgba(255,255,255,1)'
      },           
    },

  };
  return layout;
}

function dividendTrace(dates_IN, cash_IN, nonCashEquity_IN, div_IN) {  
    var divTrace2 = {
        x: dates_IN,            
        y: div_IN,     
        name: "Dividend",
        marker: 
        {
          color: 'rgba(0,255,0,0.5)'
        },
        xaxis: 'x2', 
        yaxis: 'y4',                
    };   

    var priceData = [divTrace2]; 
    return priceData;
}

function pieLayout(revision_IN) {  
  var layout = 
  {
    margin: 
    {
      l: 30,
      r: 0,
      b: 120,
      t: 50,
      pad: 0
    },    
    title: 
    {
      font: 
      {
        family: 'Arial, sans-serif',
        color: 'rgba(255,255,255,1)',
        size: 24
      },
      xref: 'paper',
      x: 0.05,
    },
    datarevision: revision_IN,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    showlegend: true,  
  };
  return layout;
}

function pieTrace(
  beginNames_IN, 
  beginPercentages_IN) {  
  // wonderful color palette generator:
  // https://gka.github.io/palettes/#/9|s|00429d,96ffea,ffffe0|ffffe0,ff005e,93003a|1|1
  var pieChartColors = [
  '#99CC99', '#00429d', 
  '#2e59a8', '#4771b2', 
  '#5d8abd', '#73a2c6', 
  '#8abccf', '#a5d5d8', 
  '#c5eddf', '#ffffe0']

  var pieChartBegin = 
  {
    values: beginPercentages_IN,
    labels: beginNames_IN,      
    marker: 
    {
      colors: pieChartColors
    },    
    type: 'pie',
    domain: {
      x: [0.0, 1.0],
      y: [0.0, 1.0]
    },  
  };
  var priceData = [pieChartBegin]; 
  return priceData;
}   

function percentageReturnTrace(dates_IN, portfolio_percentage_IN, benchmark_percentage_IN) {
    var equityTrace_1 = 
    {
        x: dates_IN,            
        y: portfolio_percentage_IN,        
        type: 'scatter', 
        xaxis: 'x2', 
        yaxis: 'y5',   
        name: "Portfolio",
        line: 
        {
          color: 'rgba(0,255,0,0.5)'
        }                  
    };
    var equityTrace_2 = 
    {
        x: dates_IN,            
        y: benchmark_percentage_IN,        
        type: 'scatter', 
        xaxis: 'x2', 
        yaxis: 'y5',   
        name: "S&P 500 ETF",
        line: 
        {
          color: '#007BFF', 
        }             
    };
    return [equityTrace_1, equityTrace_2];
}

function percentageReturnLayout(dates_IN, revision_IN) 
{
  var equityLayout = 
  { 
    margin: 
    {
      l: 30,
      r: 0,
      b: 120,
      t: 50,
      pad: 0
    },         
    datarevision: revision_IN,
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    title: 
    {
      font: {
        family: 'Arial, sans-serif',
        color: 'rgba(255,255,255,1)',
        size: 24
      },
      xref: 'paper',
      x: 0.05,
    }, 
    showlegend: false,   
    xaxis2: 
    {    
      anchor: 'y5', 
      domain: [0.0, 1.0],
      tickmode: "linear",
      tick0: dates_IN,
      dtick: 15, // days
      titlefont: 
      {
        family: 'Arial, sans-serif',
        size: 18,
        color: '#007BFF'
      },          
      tickfont: 
      {
        family: 'Arial, serif',
        size: 10,
        color: 'rgba(255,255,255,1)', 
      },   
      gridcolor: 'rgba(255,255,255,0.1)',  
      rangeslider: 
      {
        visible: true
      }       
    },
    yaxis5: {
      anchor: 'x2', 
      domain: [0.0, 1.0], 
      position: 0.0,  
      titlefont: 
      {
        anchor: 'free', 
        family: 'Arial, sans-serif',
        size: 18,
        color: '#007BFF'
      },  
      tickfont: 
      {
        family: 'Arial, serif',
        size: 14,
        color: 'rgba(255,255,255,1)'
      },   
      gridcolor: 'rgba(255,255,255,0.05)',      
    }, 
  };
  return equityLayout;
}

function distributionLayout(revision_IN, title_IN) 
{
  var layout = 
  {
    datarevision: revision_IN,
    margin: 
    {
      l: 30,
      r: 0,
      b: 120,
      t: 50,
      pad: 0
    },
    paper_bgcolor: 'rgba(0,0,0,0)',
    plot_bgcolor: 'rgba(0,0,0,0)',
    title: 
    {
      font: 
      {
        family: 'Arial, sans-serif',
        color: 'rgba(255,255,255,1)',
        size: 24
      },
      xref: 'paper',
      x: 0.05,
    },
    showlegend: false,
    xaxis3: {
      anchor: 'y6', 
      domain: [0.0, 1],
      titlefont: 
      {
        family: 'Arial, sans-serif',
        size: 18,
        color: '#007BFF'
      },          
      gridcolor: 'rgba(76,167,232,0.1)',
      tickfont: 
      {
        family: 'Arial, serif',
        size: 12,
        color: 'rgba(255,255,255,1)', 
      },     
      rangeslider: 
      {
           visible: false
       }       
    },  
    yaxis6: 
    {
      anchor: 'x1', 
      domain: [0.0, 1.0], 
      position: 0.0,
      titlefont: 
      {
        anchor: 'free', 
        family: 'Arial, sans-serif',
        size: 14,
        color: '#007BFF'
      },
      gridcolor: 'rgba(76,167,232,0.1)',
      tickfont: 
      {
        family: 'Arial, serif',
        size: 14,
        color: 'rgba(255,255,255,1)', 
      },
    },

  };
  return layout;
}

function distributionTrace(portDailyPerc_IN, color_IN) {  
    var portDailyPercTrace = {
      x: portDailyPerc_IN,
      name: 'control',
      autobinx: false, 
      histnorm: "count", 
      marker: {
        color: color_IN, 
         line: {
          color:  "rgba(0,0,0, 0.75)", 
          width: 1
        }
      },  
      opacity: 0.5, 
      type: "histogram", 
      xbins: {
        end: 20.0, 
        size: 0.25, 
        start: -20.0
      },
        xaxis: 'x3', 
        yaxis: 'y6',      
    };  

    var priceData = [portDailyPercTrace]; 
    return priceData;
}  
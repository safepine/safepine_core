function RenderPage(chart_IN, symbol_IN, final_price_IN, price_change_IN) 
{
  if(price_change_IN < 0) changeColor = "text-danger"
  else changeColor = "text-success"
  price_change_IN = "$"+Math.round(price_change_IN*100)/100;
  return   React.createElement(
    "div",
    {      
      key: "div_1",
      className:"container-fluid row overflow-auto",
    },
    [
    React.createElement(
      "div",
      {        
        key: "div_2",
        className:"row text-center mt-5",
      },
      [
      React.createElement(
        "h2",
        {          
          key: "h2_3",
          className:"text-white",
        },
        [symbol_IN
        ]),
      React.createElement(
        "h2",
        {          
          key: "h2_4",
          className:"text-white",
        },
        [final_price_IN
        ]),
      React.createElement(
        "p",
        {          
          key: "p_5",
          className: changeColor + " fw-bold",
        },
        [price_change_IN
        ]),
      ]),
    React.createElement(
      "div",
      {        
        key: "div_6",
        className:"col text-center",
      },
      [
      React.createElement(
        "button",
        {          
          key: "button_7",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["5d"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_8",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["1m"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_9",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["3m"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_10",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["6m"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_12",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["1y"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_13",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["5y"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_14",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["max"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_15",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["OHLC"
        ]),
      React.createElement(
        "button",
        {          
          key: "button_16",
          type: "button",
          className:"btn btn-outline-light",
          onClick: this.CB_ChartOptions,
        },
        ["Close"
        ]),
      ]),
    React.createElement(
      "div",
      {        
        key: "div_17",
        className:"row mb-5",
      },
      [
      React.createElement(
        "div",
        {          
          key: "div_18",
          className:"row",
          id: "grid-1-1",
          style: 
          { 
          },
        },
        [chart_IN,
        ]),
      ]),
    ]);
}
window.onload = function() 
{
  ReactDOM.render(
    React.createElement(
      Charts, 
      {
        key: "home_page"
      }
    ),
    document.getElementById('root')
  );
  document.body.className = 'bg-safepine-282833'
};
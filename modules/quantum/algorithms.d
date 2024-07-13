module safepine_core.quantum.algorithms;

// D
import std.datetime.date: Date;
import std.stdio;

// Safepine
import safepine_core.quantum.engine;
import safepine_core.math.matrix;
import safepine_core.math.optimization: PortfolioAllocation;

void Discretionary (
  Engine engine_IN,
  double initial_deposit_IN,
  Date start_date_IN,
  Date end_date_IN,
  string[][] asset_names_IN,
  Matrix[] asset_ratios_IN,
  Date[] asset_dates_IN,
  string connectionID_IN = "none") 
{
  import std.conv: to;
  import std.stdio: writeln;
  import std.datetime.stopwatch: StopWatch, AutoStart;  
  if(connectionID_IN == "none") connectionID_IN = engine_IN.MainConnectionID();
  auto myStopWatch = StopWatch(AutoStart.no);
  myStopWatch.start();

  engine_IN.Refresh(
  initial_deposit_IN, 
  start_date_IN);

  ulong asset_dates_length = asset_dates_IN.length;
  for(ulong asset_date_index = 0; asset_date_index < asset_dates_IN.length; ++asset_date_index)
  {
    while(engine_IN.GetCurrentDate() < asset_dates_IN[asset_date_index]) 
      { engine_IN.IncrementDate(); }
    engine_IN.SellEverything!(safepine_core.quantum.engine.logger.off);

    double[] assets_prices_unit = engine_IN.GetPrice(
      asset_names_IN[asset_date_index],
      engine_IN.GetCurrentDate());
    Matrix asset_prices_unit_m = new Matrix(assets_prices_unit);
    Matrix portfolio_allocation = PortfolioAllocation!(safepine_core.math.optimization.logger.off)
    (
      asset_names_IN[asset_date_index], 
      asset_ratios_IN[asset_date_index], 
      asset_prices_unit_m, 
      initial_deposit_IN
    );   
    engine_IN.Buy(
      asset_names_IN[asset_date_index],
      portfolio_allocation.toInt_v);
  }

  // Handles the delta between portfolio end date, and final date in the input list.
  while(engine_IN.GetCurrentDate() < end_date_IN)
    { engine_IN.IncrementDate(); }

  writeln("[ALGORITHMS: Discretionary] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");
  myStopWatch.reset();
  myStopWatch.stop();
}

void Rebalance (
  Engine engine_IN,
  double initial_deposit_IN,
  Date start_date_IN,
  Date end_date_IN,
  string[] asset_names_IN,
  Matrix asset_ratios_IN,
  int rebalance_day_IN,
  string connectionID_IN = "none") 
{
  import std.conv: to;
  import std.stdio: writeln;
  import std.datetime.stopwatch: StopWatch, AutoStart;
  if(connectionID_IN == "none") connectionID_IN = engine_IN.MainConnectionID();

  auto myStopWatch = StopWatch(AutoStart.no);
  myStopWatch.start();

  // 21 trading days in average in a month
  // 63 trading days in a quarter
  int trade_day_counter = 0;

  engine_IN.Refresh(
    initial_deposit_IN, 
    start_date_IN); 

  // Nothing to rebalance, hold cash only
  if(asset_names_IN.length == 0) {
    while(engine_IN.GetCurrentDate() < end_date_IN) {    
      engine_IN.IncrementDate();
      ++trade_day_counter;
    } 
    return; 
  }

  double[] assets_prices_unit = engine_IN.GetPrice(
    asset_names_IN,
    engine_IN.GetCurrentDate(),
    connectionID_IN);

  Matrix asset_prices_unit_m = new Matrix(assets_prices_unit);

  Matrix portfolio_allocation = PortfolioAllocation!(safepine_core.math.optimization.logger.off)
  (
    asset_names_IN, 
    asset_ratios_IN, 
    asset_prices_unit_m, 
    initial_deposit_IN
  );   

  engine_IN.Buy!(logger.off)(
    asset_names_IN, 
    portfolio_allocation.toInt_v, 
    connectionID_IN);

  while(engine_IN.GetCurrentDate() < end_date_IN) {    
    engine_IN.IncrementDate(connectionID_IN);

      if(rebalance_day_IN == trade_day_counter) {
        trade_day_counter = 0;

        // Sell everything
        if(engine_IN.SellEverything!(logger.off)(connectionID_IN) == BuySell_t.Success) {
          // Get rebalanced equity numbers
          assets_prices_unit = engine_IN.GetPrice(
            asset_names_IN,
            engine_IN.GetCurrentDate(),
            connectionID_IN);
          asset_prices_unit_m = assets_prices_unit;
          portfolio_allocation = PortfolioAllocation!(safepine_core.math.optimization.logger.off)
          (
            asset_names_IN, 
            asset_ratios_IN, 
            asset_prices_unit_m, 
            engine_IN.EquityAtCurrentDate(connectionID_IN)
          );                

          // Buy the rebalanced portfolio
          engine_IN.Buy!(logger.off)(
            asset_names_IN, 
            portfolio_allocation.toInt_v, 
            connectionID_IN);
        }
        else {
            // If selling everything was unsusccesful,
            // try to sell again in the next day.
            trade_day_counter = rebalance_day_IN;
        }
    } else ++trade_day_counter;
  }

  writeln("[ALGORITHMS: Rebalance] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");
  myStopWatch.reset();
  myStopWatch.stop();
}

void BuyAndHold(
  Engine engine_IN,
  double initial_deposit_IN,
  Date start_date_IN,
  Date end_date_IN,
  string[] asset_names_IN,
  Matrix asset_ratios_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = engine_IN.MainConnectionID();

  engine_IN.Refresh(
    initial_deposit_IN, 
    start_date_IN); 

  double[] assets_prices_unit = engine_IN.GetPrice(
    asset_names_IN,
    engine_IN.GetCurrentDate());

  Matrix asset_prices_unit_m = new Matrix(assets_prices_unit);

  Matrix portfolio_allocation = PortfolioAllocation!(safepine_core.math.optimization.logger.off)
  (
    asset_names_IN, 
    asset_ratios_IN, 
    asset_prices_unit_m, 
    initial_deposit_IN
  );   

  engine_IN.Buy!(logger.off)(
    asset_names_IN, 
    portfolio_allocation.toInt_v);    

  int trade_day_counter = 0;     
  while(engine_IN.GetCurrentDate() < end_date_IN) {    
      engine_IN.IncrementDate();
      ++trade_day_counter;
  }  
}
module safepine_core.project;

// D
import std.algorithm: find;
import std.conv: to; 
import std.file;
import std.datetime.date: Date;
import std.stdio: writeln, write;

// Safepine
import safepine_core.backend.sdf: sdf;
import safepine_core.math.statistics;
import safepine_core.pipelines.yahoo;
import safepine_core.quantum.engine;

// Third-Party
import plt = matplotlibd.pyplot;

string NASDAQ_API_KEY = "pZAagxxVqxzy5EkKx4vb";

string Logo
(
  string library_IN,
  string module_IN,
  string test_IN
) 
{
  return "\033[32m
 _____        __           _            
/  ___|      / _|         (_)           
\\ `--.  __ _| |_ ___ _ __  _ _ __   ___ 
 `--. \\/ _` |  _/ _ \\ '_ \\| | '_ \\ / _ \\
/\\__/ / (_| | ||  __/ |_) | | | | |  __/
\\____/ \\__,_|_| \\___| .__/|_|_| |_|\\___|
                    | |                 
                    |_|                 
\033[95m
++++++++++++++++++++++++++++++++++++++++++
+ Library:  "~library_IN~"            
+ Module:   "~module_IN~"        
+ Test:     "~test_IN~"          
++++++++++++++++++++++++++++++++++++++++++
\033[0m\n\n";
}

string App
(
  string appName_IN,
  string date_IN
) 
{
  return "\033[32m
 _____        __           _            
/  ___|      / _|         (_)           
\\ `--.  __ _| |_ ___ _ __  _ _ __   ___ 
 `--. \\/ _` |  _/ _ \\ '_ \\| | '_ \\ / _ \\
/\\__/ / (_| | ||  __/ |_) | | | | |  __/
\\____/ \\__,_|_| \\___| .__/|_|_| |_|\\___|
                    | |                 
                    |_|                 
\033[95m
++++++++++++++++++++++++++++++++++++++++++
+ App         :  "~appName_IN~"    
+ Last Update :  "~date_IN~"         
++++++++++++++++++++++++++++++++++++++++++
\033[0m\n\n";
}

string[] UniqueStrings(string[][] inputList) {
    string[] result;
    string[string] uniqueSet;
    foreach (sublist; inputList) {
        foreach (stringItem; sublist) {
            if (!(stringItem in uniqueSet)) {
                uniqueSet[stringItem] = stringItem;
                result ~= stringItem;
            }
        }
    }
    return result;
}

sdf SetupSafepineCoreBackend(string dataPath)
{
  sdf backend = new sdf("safepine_database"); 
  backend.DeleteUserTable("safepine_core", "prices"); // (username, tablename)
  backend.CreateUserTable("safepine_core", "prices");

  ulong dummy;
  dummy = backend.LoadUserData(
    "safepine_core", // username
    "prices", // tablename
    dataPath,
    0);
  writeln("[SetupSafepineCoreBackend]: Total lines of mysql rows written: "~to!string(dummy));

  return backend;
}

void DataAcquisition(string[] assetSymbols_IN, Date begin_IN, Date end_IN)
{
  Yahoo pipeline;
  string raw_data = "";
  for(int i = 0; i<assetSymbols_IN.length; ++i)
  {
    pipeline.Mine!(safepine_core.pipelines.yahoo.logger.off)(begin_IN, end_IN, assetSymbols_IN[i], intervals.daily);
    raw_data ~= pipeline.Write!(output.csv, safepine_core.pipelines.yahoo.logger.off, string);
  }
  std.file.write("cache/all_data_"~end_IN.toISOString()~".csv", raw_data);
}

void PortfolioMonitor(Engine portfolio_IN, Engine benchmark_IN) {
  // Results
  // Text: Portfolio Contents
  int close_index = 5;
  safepine_core.quantum.engine.Frame[] equity_value = portfolio_IN.EquityMatrix();
  safepine_core.quantum.engine.Frame[] equity_quantity = portfolio_IN.EquityMatrix(
    "none", 
    close_index, 
    AssetColumn_t.Quantity);
  writeln(PortfolioContents(equity_value, equity_quantity));

  // Equity curve
  safepine_core.quantum.engine.Frame equity = portfolio_IN.Equity();

  // Fig: Portfolio Equity vs. Benchmark Equity
  safepine_core.quantum.engine.Frame equity_benchmark = benchmark_IN.Equity();
  safepine_core.quantum.engine.Frame equityPerc = portfolio_IN.Percentage(equity);
  safepine_core.quantum.engine.Frame spyPerc = benchmark_IN.Percentage(equity_benchmark);
  plt.plot(equityPerc.valueArray, "b-", ["label": "$Your Equity$"]);
  plt.plot(spyPerc.valueArray, "r-", ["label": "$Benchmark$"]);
  plt.xlabel("Number of days");
  plt.ylabel("Return %");
  plt.legend();
  plt.grid();
  plt.savefig("fig_equity_percentage_curve_"~portfolio_IN.GetCurrentDate().toString~".png");
  plt.clear();

  // Fig: Dividend
  safepine_core.quantum.engine.Frame dividend = portfolio_IN.Dividend();
  plt.plot(dividend.valueArray, "b-");
  plt.xlabel("Number of days");
  plt.ylabel("Dividend [USD]");
  plt.legend();
  plt.grid();
  plt.savefig("fig_dividends_"~portfolio_IN.GetCurrentDate().toString~".png");
  plt.clear();

  // Fig: Pie Chart
  PieChart(equity_value, portfolio_IN.GetCurrentDate().toString);
  plt.clear();

  // Fig: Histogram, daily
  double histogram_resolution = 100.0;
  auto daily_returns = portfolio_IN.DailyReturns(histogram_resolution);
  plt.hist(daily_returns[0], ["bins": daily_returns[1]]);
  plt.xlabel("Daily returns");
  plt.ylabel("Rolls");
  plt.legend();
  plt.grid();
  plt.savefig("fig_daily_return_histogram_"~portfolio_IN.GetCurrentDate().toString~".png");
  plt.clear();

  // Fig: Histogram, weekly
  histogram_resolution = 100.0;
  auto weekly_returns = portfolio_IN.WeeklyReturns(histogram_resolution);
  plt.hist(weekly_returns[0], ["bins": weekly_returns[1]]);
  plt.xlabel("Weekly returns");
  plt.ylabel("Rolls");
  plt.legend();
  plt.grid();
  plt.savefig("fig_weekly_return_histogram_"~portfolio_IN.GetCurrentDate().toString~".png");
  plt.clear();  

  // Fig: Histogram, monthly
  histogram_resolution = 100.0;
  auto monthly_returns = portfolio_IN.MonthlyReturns(histogram_resolution);
  plt.hist(monthly_returns[0], ["bins": monthly_returns[1]]);
  plt.xlabel("Monthly returns");
  plt.ylabel("Rolls");
  plt.legend();
  plt.grid();
  plt.savefig("fig_monthly_return_histogram_"~portfolio_IN.GetCurrentDate().toString~".png");
  plt.clear();  

  // Fig: Prepare Monte Carlos
  ulong daily_sample_period = daily_returns[0].length/5; // use %20 for sampling
  ulong out_of_sample_period = daily_sample_period;
  ulong monte_carlo_start_index = daily_returns[0].length-out_of_sample_period-daily_sample_period;
  ulong monte_carlo_end_index = daily_returns[0].length-out_of_sample_period;
  double[] return_distribution = daily_returns[0][monte_carlo_start_index..monte_carlo_end_index];
  int possible_futures = 100;
  double[][] equity_matrix = monte_carlo(return_distribution, to!int(out_of_sample_period), possible_futures, equity.valueArray.length-out_of_sample_period);
  
  // Fig: Equity 
  plt.xlabel("Number of days");
  plt.ylabel("Total Equity [USD]");
  for (int i = 0 ; i< possible_futures; ++i) {
    // Normalize equity returns to cash value
    for(int j = 0; j<equity_matrix[i].length; ++j) {
      equity_matrix[i][j] = equity.valueArray[equity.valueArray.length-out_of_sample_period]*equity_matrix[i][j];
    }

    plt.plot(equity_matrix[i]);
  } 
  plt.plot(equity.valueArray, "b-");  
  plt.legend();
  plt.grid();
  plt.savefig("fig_equity_curve_"~portfolio_IN.GetCurrentDate().toString~".png");
  plt.clear();
}

void PieChart(safepine_core.quantum.engine.Frame[] equity_matrix_IN, string date_IN) {
  // Fig: Pie chart at last date in portfolio
  string[] asset_names;
  double[] asset_sizes;
  foreach(asset; equity_matrix_IN){
    ulong length = asset.valueArray.length;
    auto filter_close = find(asset.name, "close");
    if(asset.valueArray[length-1] > 0.0) {
      if(asset.name != "Dividend" && filter_close != null) {
        asset_sizes ~= asset.valueArray[length-1];
        asset_names ~= asset.name;
      }   
    }
  }
  plt.pie(asset_sizes, ["labels": asset_names], ["autopct": "%1.0f%%"]);
  plt.savefig("fig_piechart_"~date_IN~".png");
  plt.clear();
}

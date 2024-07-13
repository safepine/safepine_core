module safepine_core.quantum.web;

// D
import std.json: JSONValue, JSONOptions;
import std.typecons: tuple, Tuple; 

// Safepine
import safepine_core.quantum.engine;
import safepine_core.backend.sdf: sdf;

// Third party
import mysql: Connection, exec, ResultRange, query;
import vibe.d; 
import vibe.web.auth;

struct UserSettings {
    string  userName_;
}

@requiresAuth
class SafepineWebInterface {
  this() {
    portfolios["developer"] = null;
    benchmarks["developer"] = null;
    SetupBackend();
  }

  this(Engine[] backtest_results_IN) {
    portfolios["developer"] = backtest_results_IN[0];
    benchmarks["developer"] = backtest_results_IN[1];
    SetupBackend();
  }

  ~this() {
    backend_sdf_.Close();
    portfolios["developer"].Close();
    benchmarks["developer"].Close();
  }

  // all_data
  @anyAuth
  void getAllData(
    scope HTTPServerRequest req,
    scope HTTPServerResponse res)
  {
    import std.stdio: writeln;
    import std.datetime.stopwatch: StopWatch, AutoStart;

    auto myStopWatch = StopWatch(AutoStart.no);
    myStopWatch.start();

    UserSettings s = req.session.get!UserSettings("auth");

    string connectionID_Portfolio = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID_Portfolio);

    string connectionID_Benchmark = benchmarks[s.userName_].GenerateConnectionID();
    benchmarks[s.userName_].InitializeMysql(
      benchmarks[s.userName_].ConnectionInformation(),
      connectionID_Benchmark);

    JSONValue all_data;
    all_data["open"] = portfolios[s.userName_].Equity_json(connectionID_Portfolio, 2);
    all_data["high"] = portfolios[s.userName_].Equity_json(connectionID_Portfolio, 3);
    all_data["low"] = portfolios[s.userName_].Equity_json(connectionID_Portfolio, 4);
    all_data["close"] = portfolios[s.userName_].Equity_json(connectionID_Portfolio, 5);
    all_data["percentage_portfolio"] = portfolios[s.userName_].Percentage_json(connectionID_Portfolio);
    all_data["percentage_benchmark"] = benchmarks[s.userName_].Percentage_json(connectionID_Benchmark);
    all_data["pie_end"] = portfolios[s.userName_].PieChart_json(connectionID_Portfolio, "end");
    all_data["pie_begin"] = portfolios[s.userName_].PieChart_json(connectionID_Portfolio, "begin");
    all_data["cash"] = portfolios[s.userName_].Cash_json(connectionID_Portfolio);
    all_data["daily_returns_portfolio"] = portfolios[s.userName_].DailyReturns_json(connectionID_Portfolio);
    all_data["daily_returns_benchmark"] = benchmarks[s.userName_].DailyReturns_json(connectionID_Benchmark);
    all_data["non_cash"] = portfolios[s.userName_].NonCashEquity_json(connectionID_Portfolio);
    all_data["dividend"] = portfolios[s.userName_].Dividend_json(connectionID_Portfolio);

    res.writeBody(all_data.toString(JSONOptions.specialFloatLiterals));
    portfolios[s.userName_].Close(connectionID_Portfolio);
    benchmarks[s.userName_].Close(connectionID_Benchmark);

    writeln("[GET: all_data] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");
    myStopWatch.reset();
    myStopWatch.stop();
  }

  // historical_price
  @anyAuth
  void postHistoricalPrice(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    import std.stdio: writeln;
    import std.datetime.stopwatch: StopWatch, AutoStart;

    auto myStopWatch = StopWatch(AutoStart.no);
    myStopWatch.start();    

    JSONValue time_series_json;
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID); 
    
    if(("name_to_search" in req.form) != null)
    {
      string name = to!string(req.form["name_to_search"]);
      string symbol;
      if(name in tickers_)
      {
        symbol = tickers_[name];
      }
      else symbol = name;
      ResultRange range = portfolios[s.userName_].MySQLQuery(
        "select * from "~"root_price_data"~
        " where symbol=\""~symbol~"\";", connectionID);
      if(range.empty) res.writeBody("null");
      else
      {
        string[] open, high, low, close;
        string[] dates;
        foreach(row; range)
        {
          string[] row_string = to!string(row).split(",");
          dates ~= row_string[1];
          open ~= row_string[2];
          high ~= row_string[3];
          low ~= row_string[4];
          close ~= row_string[5];
        }
        time_series_json["name"] = name;
        time_series_json["dates"] = dates;
        time_series_json["open"] = open;
        time_series_json["high"] = high;
        time_series_json["low"] = low;
        time_series_json["close"] = close;
        res.writeBody(time_series_json.toString(JSONOptions.specialFloatLiterals));
      }
    }
    portfolios[s.userName_].Close(connectionID);

    writeln("[POST: historical_price] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");
    myStopWatch.reset();
    myStopWatch.stop();
  }

  // portfolio_equity
  @anyAuth
  void getPortfolioEquity(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);

    JSONValue equity_ohlc;
    equity_ohlc["open"] = portfolios[s.userName_].Equity_json(connectionID, 2);
    equity_ohlc["high"] = portfolios[s.userName_].Equity_json(connectionID, 3);
    equity_ohlc["low"] = portfolios[s.userName_].Equity_json(connectionID, 4);
    equity_ohlc["close"] = portfolios[s.userName_].Equity_json(connectionID, 5);
    
    res.writeBody(equity_ohlc.toString);
    portfolios[s.userName_].Close(connectionID);
  }

  // /portfolio_percentage
  @anyAuth
  void getPortfolioPercentage(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(portfolios[s.userName_].Percentage_json(connectionID).toString);
    portfolios[s.userName_].Close(connectionID);
  }

  // /benchmark_percentage
  @anyAuth
  void getBenchmarkPercentage(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = benchmarks[s.userName_].GenerateConnectionID();
    benchmarks[s.userName_].InitializeMysql(
      benchmarks[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(benchmarks[s.userName_].Percentage_json(connectionID).toString);
    benchmarks[s.userName_].Close(connectionID);
  }

  // /portfolio_pie_begin
  @anyAuth
  void getPortfolioPieBegin (
    scope HTTPServerRequest req,
    scope HTTPServerResponse res) 
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);        
    res.writeBody(portfolios[s.userName_].PieChart_json(connectionID, "end").toString);
    portfolios[s.userName_].Close(connectionID);        
  }

  // /portfolio_pie_end
  @anyAuth
  void getPortfolioPieEnd (
    scope HTTPServerRequest req,
    scope HTTPServerResponse res) 
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);        
    res.writeBody(portfolios[s.userName_].PieChart_json(connectionID, "begin").toString);
    portfolios[s.userName_].Close(connectionID);        
  }

  // /portfolio_cash
  @anyAuth
  void getPortfolioCash(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(portfolios[s.userName_].Cash_json(connectionID).toString);
    portfolios[s.userName_].Close(connectionID);
  } 

  // /daily_returns
  @anyAuth
  void getDailyReturns(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(portfolios[s.userName_].DailyReturns_json(connectionID).toString);
    portfolios[s.userName_].Close(connectionID);
  }    

  // /daily_returns_benchmark
  @anyAuth
  void getDailyReturnsBenchmark(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = benchmarks[s.userName_].GenerateConnectionID();
    benchmarks[s.userName_].InitializeMysql(
      benchmarks[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(benchmarks[s.userName_].DailyReturns_json(connectionID).toString);
    benchmarks[s.userName_].Close(connectionID);
  }         

  // /portfolio_noncashequity
  @anyAuth
  void getPortfolioNoncashequity(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(portfolios[s.userName_].NonCashEquity_json(connectionID).toString);
    portfolios[s.userName_].Close(connectionID);
  }       

  // /portfolio_dividend
  @anyAuth
  void getPortfolioDividend(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)     
  {
    UserSettings s = req.session.get!UserSettings("auth");
    string connectionID = portfolios[s.userName_].GenerateConnectionID();
    portfolios[s.userName_].InitializeMysql(
      portfolios[s.userName_].ConnectionInformation(),
      connectionID);
    res.writeBody(portfolios[s.userName_].Dividend_json(connectionID).toString);
    portfolios[s.userName_].Close(connectionID); 
  }

  // developer_login
  @noAuth
  void postDeveloperLogin( 
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res) 
  {
    if(!developer_logged_in){
      UserSettings new_setting = 
      { 
        userName_: "developer", 
      };

      req.session = res.startSession;
      req.session.set("auth", new_setting);
      res.redirect("/Dashboard");
      developer_logged_in = true;   
    }
  }

  // Authenticate gets called for any method that requires authentication
  @noRoute @safe
  UserSettings authenticate(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res) 
  {
    if (!req.session || !req.session.isKeySet("auth"))
      throw new HTTPStatusException(
        HTTPStatus.forbidden, 
        "Not authorized to perform this action!");
    return req.session.get!UserSettings("auth");
  }

protected:
  bool developer_logged_in = false;
  Engine[string] portfolios = null;
  Engine[string] benchmarks = null;

private:
  void SetupBackend()
  {
    backend_sdf_ = new sdf("firebird_price_database");
    Tuple!(string, string)[] result = backend_sdf_.Tickers("root", "price_data_ticker");
    for(int i = 0; i<result.length; ++i) {
      auto element = result[i];
      tickers_[element[0]] = element[1];
      ticker_names_ ~= element[0];
    } 
  }
  sdf backend_sdf_ = null; // price database
  string[string] tickers_ = null; // maps ticker name to ticker symbol
  string[] ticker_names_;
}
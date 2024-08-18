module safepine_core.quantum.web;

// D
import std.json: JSONValue, JSONOptions, parseJSON;
import std.typecons: tuple, Tuple; 

// Safepine
import safepine_core.backend.sdf: sdf;
import safepine_core.math.matrix;
import safepine_core.project;
import safepine_core.quantum.algorithms;
import safepine_core.quantum.engine;

// Third party
import mysql: Connection, exec, ResultRange, query;
import vibe.d; 
import vibe.web.auth;

struct UserSettings {
    string  userName_;
}

@requiresAuth
class DataInterface
{
  this(string cachePath_IN)
  {
    dataPath = cachePath_IN;
  }

  // tranmission
  @noAuth
  void getTransmission(
    scope HTTPServerRequest req,
    scope HTTPServerResponse res)
  {
    import std.stdio: writeln;
    import std.datetime.stopwatch: StopWatch, AutoStart;
    auto myStopWatch = StopWatch(AutoStart.no);

    myStopWatch.start();
    JSONValue all_data = ImportData(dataPath);
    res.writeBody(all_data.toString(JSONOptions.specialFloatLiterals));
    writeln("[DataInterface: GET/tranmission] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");

    myStopWatch.reset();
    myStopWatch.stop();
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

private:
  JSONValue ImportData(string path_IN)
  {
    import std.algorithm.iteration : map, filter;
    import std.algorithm.searching;
    import std.array : array;
    import std.file;
    import std.path : baseName;
    JSONValue result;
    string[] files = dirEntries(path_IN, "*.json", SpanMode.shallow)
        .filter!(a => a.isFile)
        .map!((return a) => baseName(a.name))
        .array; // List of all json files
    foreach (string file; files)
    {
      auto index = file.indexOf("_");
      string prices_raw = to!string(read(path_IN~"/"~file));
      string symbol = file[0 .. index];
      result[symbol] = parseJSON(prices_raw);
    }
    return result;
  }

  string dataPath;
}

@requiresAuth
class PortfolioInterface
{
  this(
    string                 cachePath_IN, 
    AssetAllocationProfile profile_IN) 
  {
    m_cachePath = cachePath_IN;
    m_profile = profile_IN;
  }

  ~this() {
    m_backend.Close();
    m_portfolio.Close();
    m_benchmark.Close();
  }

  @noAuth
  void getPortfolio(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res)
  {
    import std.stdio: writeln;
    import std.datetime.stopwatch: StopWatch, AutoStart;

    auto myStopWatch = StopWatch(AutoStart.no);
    myStopWatch.start();

    string connectionID_Portfolio = m_portfolio.GenerateConnectionID();
    m_portfolio.InitializeMysql(
      m_portfolio.ConnectionInformation(),
      connectionID_Portfolio);

    string connectionID_Benchmark = m_benchmark.GenerateConnectionID();
    m_benchmark.InitializeMysql(
      m_benchmark.ConnectionInformation(),
      connectionID_Benchmark);

    JSONValue all_data;
    all_data["open"] = m_portfolio.Equity_json(connectionID_Portfolio, 2);
    all_data["high"] = m_portfolio.Equity_json(connectionID_Portfolio, 3);
    all_data["low"] = m_portfolio.Equity_json(connectionID_Portfolio, 4);
    all_data["close"] = m_portfolio.Equity_json(connectionID_Portfolio, 5);
    all_data["percentage_portfolio"] = m_portfolio.Percentage_json(connectionID_Portfolio);
    all_data["percentage_benchmark"] = m_benchmark.Percentage_json(connectionID_Benchmark);
    all_data["pie_end"] = m_portfolio.PieChart_json(connectionID_Portfolio, "end");
    all_data["pie_begin"] = m_portfolio.PieChart_json(connectionID_Portfolio, "begin");
    all_data["cash"] = m_portfolio.Cash_json(connectionID_Portfolio);
    all_data["daily_returns_portfolio"] = m_portfolio.DailyReturns_json(connectionID_Portfolio);
    all_data["daily_returns_benchmark"] = m_benchmark.DailyReturns_json(connectionID_Benchmark);
    all_data["non_cash"] = m_portfolio.NonCashEquity_json(connectionID_Portfolio);
    all_data["dividend"] = m_portfolio.Dividend_json(connectionID_Portfolio);

    res.writeBody(all_data.toString(JSONOptions.specialFloatLiterals));
    m_portfolio.Close(connectionID_Portfolio);
    m_benchmark.Close(connectionID_Benchmark);

    writeln("[GET: all_data] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");
    myStopWatch.reset();
    myStopWatch.stop();
  }

  // Hacky way to load private variables
  // into the web interface class. Solution based on:
  // https://github.com/vibe-d/vibe.d/issues/2438
  @anyAuth
  void LoadBackend() {
    m_backend = SetupSafepineCoreBackend(m_cachePath);
    m_portfolio = new Engine();
    m_benchmark = new Engine();

    // Algorithms
    Discretionary(
      m_portfolio,
      m_profile.initialDeposit,
      m_profile.dataBegin,
      m_profile.dataEnd,
      m_profile.assetNames,
      m_profile.assetRatios,
      m_profile.assetDates,
      m_profile.scheduleType);
    BuyAndHold(
      m_benchmark,
      m_profile.initialDeposit,
      m_profile.dataBegin,
      m_profile.dataEnd,
      ["SPY"],
      new Matrix([1.0]));
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

private:
  sdf                    m_backend = null;
  string                 m_cachePath = "";
  Engine                 m_portfolio = null;
  Engine                 m_benchmark = null;
  AssetAllocationProfile m_profile;
}
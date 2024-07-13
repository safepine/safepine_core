// D
import std.conv: to; 
import std.datetime.date: Date;
import std.stdio: writeln, write;

// Safepine
import safepine_core.project;

import safepine_core.backend.mysqlhook;
import safepine_core.backend.sdf: sdf;

import safepine_core.math.matrix;
import safepine_core.math.statistics;

import safepine_core.quantum.algorithms;
import safepine_core.quantum.engine;
import safepine_core.quantum.prices;
import safepine_core.quantum.stash;

void main()
{
  write(App("Auto-rebalanced Portfolio", "March 13, 2024"));

  // Initialize backend & engines
  sdf backend = SetupSafepineCoreBackend("tests/data/quandl_nasdaq100_2014.csv");
  Engine Portfolio = new Engine();
  Engine Benchmark = new Engine();

  // Algorithms
  Rebalance(
    Portfolio,
    10000.0, // initial deposit [USD]
    Date(2014, 11, 11), // start date
    Date(2015, 5, 11), // end date
    ["AAPL", "AMZN", "GOOG", "TSLA"], // symbols
    new Matrix([0.25, 0.25, 0.25, 0.25]), // percentages
    21); // rebalance period [days]
  BuyAndHold(
    Benchmark,
    10000.00,
    Date(2014, 11, 11),
    Date(2015, 5, 11),
    ["MSFT"],
    new Matrix([1.0]));

  // Visualize/Chart
  PortfolioMonitor(Portfolio, Benchmark);

  // Clean-up
  Portfolio.Close(Portfolio.MainConnectionID());
  Benchmark.Close(Benchmark.MainConnectionID());
  backend.DeleteUserTable("engine_user", "price_data");
  backend.Close(backend.MainConnectionID());
}
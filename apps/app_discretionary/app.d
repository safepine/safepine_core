// D
import std.conv: to; 
import std.datetime.date: Date;
import std.stdio: writeln, write;

// Safepine
import safepine_core.project;

import safepine_core.backend.mysqlhook;
import safepine_core.backend.sdf: sdf;

import safepine_core.math.optimization;
import safepine_core.math.matrix;
import safepine_core.math.statistics;

import safepine_core.quantum.algorithms;
import safepine_core.quantum.engine;
import safepine_core.quantum.prices;
import safepine_core.quantum.stash;

void main()
{
  write(App("Discretionary Portfolio", "May 18, 2024"));

  // Initialize backend & engines
  AssetAllocationProfile input_profile;
  // Replace the following input with "input_percentage.json" to run the algorithm
  // over a percentage based schedule file.
  input_profile = ImportAssetSchedule("config.json");
  string[] symbols = UniqueStrings(input_profile.assetNames);
  symbols ~= "SPY"; // For benchmarks.
  DataAcquisition(
    symbols, 
    input_profile.dataBegin, 
    input_profile.dataEnd,
    input_profile.dataProvider); // saves data under cache/all_data...  
  sdf backend = SetupSafepineCoreBackend("cache/all_data.csv");
  Engine Portfolio = new Engine();
  Engine Benchmark = new Engine();

  // Algorithms
  Discretionary(
    Portfolio,
    input_profile.initialDeposit,
    input_profile.dataBegin,
    input_profile.dataEnd,
    input_profile.assetNames,
    input_profile.assetRatios,
    input_profile.assetDates,
    input_profile.scheduleType);
  BuyAndHold(
    Benchmark,
    input_profile.initialDeposit,
    input_profile.dataBegin,
    input_profile.dataEnd,
    ["SPY"],
    new Matrix([1.0]));

  // Visualize/Chart
  PortfolioMonitor(Portfolio, Benchmark);

  // Clean-up
  Portfolio.Close(Portfolio.MainConnectionID());
  Benchmark.Close(Benchmark.MainConnectionID());
  backend.DeleteUserTable("engine_user", "price_data");
  backend.Close(backend.MainConnectionID());
}
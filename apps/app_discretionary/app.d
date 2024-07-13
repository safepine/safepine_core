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
  Engine Portfolio = new Engine();
  Engine Benchmark = new Engine();
  AssetAllocationProfile input_profile;
  input_profile = Portfolio.ImportAssetAllocationProfile("apps/app_discretionary/input.json");
  string[] symbols = UniqueStrings(input_profile.assetNames);
  symbols ~= "SPY"; // For benchmarks.
  DataAcquisition(symbols, input_profile.dataBegin, input_profile.dataEnd); // saves data under cache/all_data...
  sdf backend = SetupSafepineCoreBackend("cache/all_data_"~input_profile.dataEnd.toISOString()~".csv");

  // Algorithms
  Discretionary(
    Portfolio,
    input_profile.initialDeposit,
    input_profile.dataBegin,
    input_profile.dataEnd,
    input_profile.assetNames,
    input_profile.assetRatios,
    input_profile.assetDates);
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
module safepine_core.quantum.engine;

// D
import core.time: days; 
import std.algorithm: max, min, reduce, find;
import std.array: array, replace; 
import std.conv: to; 
import std.datetime.date: Date, DayOfWeek, Month;
import std.json: JSONValue, parseJSON;
import std.file; // write 
import std.math: abs;
import std.range: iota;
import std.stdio: writeln;
import std.string: indexOf;
import std.typecons: tuple;

// Safepine
import safepine_core.backend.sqlinterface;
import safepine_core.math.matrix;
import safepine_core.quantum.stash;

// Third party
import mysql; 

/// Table definitions used in prices & pricesMeta tables
const string priceTableName = "safepine_core_prices";
const string metaTablename = "safepine_core_prices_meta";
const int openIndex = 2;
const int highIndex = 3;
const int lowIndex = 4;
const int closeIndex = 5;
const int dividendIndex = 7;
const int splitIndex = 8;
const int metaSymbolIndex = 0;
const int metaBeginIndex = 1;
const int metaEndIndex = 2;

/***********************************
 * Safepine's portfolio simulation class.
 * It provides a fast backtester 
 * implementation along with various
 * functions to access portfolio
 * analytics
 */
class Engine(driver T) : sqlinterface!(T) {
public:
/***********************************
 * Constructor: Instantiate the 
 * engine of Safepine Core. See
 * below for further instructions.
  Example:
  -------------------
  double initialDeposit_1 = 3000.0;
  Date startDate_1 = Date(2016, 11, 11);
  auto myEngine_1 = new Engine("tests/data/quandl_small_test_data.csv");
  myEngine_1.Refresh(initialDeposit_1, startDate_1);
  myEngine_1.IncrementDate();
  -------------------
 */
this(string dataPath) 
{
  InitializeSafepineCoreBackend(dataPath);
  InitializeMetaData();
  _myStash = Stash(_maxAssets, _maxTicks); 
}

/***********************************
 * Summary: Refreshes the engine. Must be called after 
 * engine construction. If startDate_IN is a weekend
 * engine starts in the next Monday.
 * Params:
 *    initialDeposit_IN = Value on start date  
 *    startDate_IN = Format -> yyyy-mm-dd
 * Returns:
 *    Success: Bought the asset
 *    Warning_Weekend: Indicates that portfolio was refreshed on a weekend
 *    
 */
Refresh_t Refresh(
  double initialDeposit_IN, 
  Date startDate_IN) 
{
  Refresh_t result = Refresh_t.Success;

  // Check: Weekend
  if(startDate_IN.dayOfWeek == DayOfWeek.sat || startDate_IN.dayOfWeek == DayOfWeek.sun) {
    if(startDate_IN.dayOfWeek == DayOfWeek.sat) {
      startDate_IN += 2.days;
    }
    else {
      startDate_IN += 1.days;
    }
    result = Refresh_t.Warning_Weekend;
  }

  _myStash.Refresh(); // must refresh stash before initializing it again.
  InitializeStash(initialDeposit_IN, startDate_IN);
  _initialDeposit = initialDeposit_IN;
  _tradeNumber = 0; // sets back trade list index to 0
  _dataEndDetected = false;
  _dataEndCounter = 0;
  return result;
}

/***********************************
 * Summary: Returns total number of symbols
 * from the backend and available symbols 
 * at current date from backend & engine
 * Returns:
 *    ulong[3]: Total number of symbols, 
 *              symbols available today, 
 *              symbols available today 
 *              in the portfolio
 * 
 */
pure ulong[3] 
NumberofSymbols() {
  return [_totalTicks, SymbolsToday().length, SymbolsTodayPortfolio().length];
}

/***********************************
 * Summary: Returns all available symbols 
 * for buy/sell between begin/end dates. 
 * This is a SLOW function because of 
 * hashtable access on runtime. 
 * Do not call it inside/with increment days.
 * Params:
 *    beginDate_IN = Begin date. Format -> yyyy-mm-dd
 *    endDate_IN = End date
 * Returns:
 *    tickArray: Available tick names between dates
 */
pure string[string] 
Symbols(
  string beginDate_IN, 
  string endDate_IN) 
{
  // To be returned ...
  string[string]    tickDictionary;   

  // Convert input to date format
  int year = to!int(beginDate_IN[0 .. 4]);
  int month = to!int(beginDate_IN[5 .. 7]);
  int day = to!int(beginDate_IN[8 .. 10]);
  auto beginDate_dt = Date(year, month, day);

  year = to!int(endDate_IN[0 .. 4]);
  month = to!int(endDate_IN[5 .. 7]);
  day = to!int(endDate_IN[8 .. 10]);
  auto endDate_dt = Date(year, month, day);

  // Go through all lines
  foreach(key; _metaData.byKey()) {
    // Check if date has length. Some of them don't. Not sure why. Also skip first row.
    if(_metaData[key].beginDate.length > 0) {
      // Convert meta to date format
      year = to!int(_metaData[key].beginDate[0 .. 4]);
      month = to!int(_metaData[key].beginDate[5 .. 7]);
      day = to!int(_metaData[key].beginDate[8 .. 10]);
      auto beginDateMeta_dt = Date(year, month, day);

      year = to!int(_metaData[key].endDate[0 .. 4]);
      month = to!int(_metaData[key].endDate[5 .. 7]);
      day = to!int(_metaData[key].endDate[8 .. 10]);
      auto endDateMeta_dt = Date(year, month, day);

      // Check if begin date is same or recent than meta's begin.
      // Check if end date is same or older than meta's end.
      if(beginDate_dt >= beginDateMeta_dt && endDate_dt <= endDateMeta_dt) {
        tickDictionary[_metaData[key].tickName] = _metaData[key].tickName;
      }
    }
  }

  return tickDictionary;
}

/***********************************
 * Summary: Returns names in stash as a string array
 */ 
pure string[] 
SymbolsPortfolio() {
  string[] result;
  for(int i = 0; i<_stashTickNamesIndex ; i++) {
    // Tick names in the engine are saved in a list with constant access time.
    result ~= _stashTickNames[i];
  }

  return result;
}

/***********************************
 * Summary: Get all tick names based 
 * on _currentDate value. Uses meta 
 * saved from database. This is a SLOW 
 * function because of hashtable access 
 * on runtime. Do not call it inside/with 
 * increment days.
 * Returns:
 *    tickArray: Available tick names 
 *               at today's value. Today 
 *               is engine's current date.
 */
pure string[] 
SymbolsToday() {
  // To be returned ...
  string[] tickArray;

  // Go through all lines
  foreach(key; _metaData.byKey()) {
    // Check if date has length. Some of them don't. Not sure why. Also skip first row.
    if(_metaData[key].beginDate.length > 0) {
      if(IsSymbolWithinDateRanges(_metaData[key].beginDate, _metaData[key].endDate)) {
        tickArray ~= _metaData[key].tickName;
      }
    }
  }

  // Return result
  return tickArray;
} 

/***********************************
 * Summary: Get tick names available 
 * from portfolio/engine based on 
 * current date value.
 * Returns:
 *    tickArray: Available tick names 
 *               at today's value. 
 *               Today is engine's current date.
 */
pure string[] 
SymbolsTodayPortfolio() {
  // To be returned ...
  string[] tickArray;

  // Go through all lines
  for(int i = 0; i<_stashTickNamesIndex ; i++) {
    // Tick names in the engine are saved in a list with constant access time.
    string key = _stashTickNames[i];

    // Check if date has length. Some of them don't. Not sure why. Also skip first row.
    if(_metaData[key].beginDate.length > 0) {
      if(IsSymbolWithinDateRanges(_metaData[key].beginDate, _metaData[key].endDate)) {
        tickArray ~= _metaData[key].tickName;
      }
    }
  }

  // Return result
  return tickArray;
}

/***********************************
 * Summary: Check whether tick is 
 * available at current date from 
 * prices table. Not meta table. 
 * This is fast for a single tick check.
 * Params:
 *    assetName_IN = String
 *    connectionID_IN = String
 * Returns:
 *    tickAvailable
 */
SymbolAvailableAtDate_t SymbolAvailableAtDate(
  string assetName_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  if(assetName_IN !in _metaData)
    return SymbolAvailableAtDate_t.Error_TickNotFound;
  if(GetPrice(assetName_IN, CurrentDate(), closeIndex, connectionID_IN) < 0.0)
    return SymbolAvailableAtDate_t.Error_TickNotAvailableAtDate;
  return SymbolAvailableAtDate_t.Success;
}

/***********************************
 * Summary: Adds cash to the portfolio at the current date
 * Params:
 *    cashValue_IN = Cash value to be deposited
 */
void Deposit(double cashValue_IN) {
  _myStash.ModifyStash!double(cashValue_IN, "Cash");
  _myStash.ModifyStash!double(cashValue_IN, "Deposit");   
}

/***********************************
 * Summary: List based implementation of buy function.
 * Params:
 *    assetName_IN = Asset name list
 *    assetquantity_IN = Quantityt list. Mus be same size
 *    connectionID_IN = String
 * as asset name list.
  Example:
  -------------------
  myEngine_1.Buy(["MSFT", "SPY"], [1,1]);
  -------------------
 * Template: 
 *    log: Calls logger if templated with logger.on
 * Returns:
 *    Check out buy/sell type enum definition
 */
BuySell_t Buy(logger log = logger.on)(
  string[] assetName_IN, 
  int[] assetquantity_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  BuySell_t result;
  if(assetName_IN.length != assetquantity_IN.length) return BuySell_t.Error_List; 
  for(int i = 0; i<assetName_IN.length; ++i) {
    result = BuyImpl(assetName_IN[i], assetquantity_IN[i], connectionID_IN);
    if(log == logger.on) BuyLogger(result, assetName_IN[i]);
  }
  return result;
}

BuySell_t Buy(logger log = logger.on)(
  string[] assetName_IN, 
  double[] assetquantity_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  BuySell_t result;
  if(assetName_IN.length != assetquantity_IN.length) return BuySell_t.Error_List; 
  for(int i = 0; i<assetName_IN.length; ++i) {
    result = BuyImpl(assetName_IN[i], assetquantity_IN[i], connectionID_IN);
    if(log == logger.on) BuyLogger(result, assetName_IN[i]);
  }
  return result;
} 

/***********************************
 * Summary: Logs to console the outcome of buy
 * Params:
 *    result_IN = Result of the buy action
 *    assetName_IN = Name of the asset
 */
void BuyLogger(
  BuySell_t result_IN, 
  string assetName_IN) 
{
  string msg_fail = 
  "Buy "~assetName_IN~
  " failed at "~to!string(CurrentDate())~
  " due to "~to!string(result_IN);

  string msg_success = 
  "Buy "~assetName_IN~
  " successful at "~to!string(CurrentDate());  

  if(result_IN != BuySell_t.Success) {writeln(msg_fail);}
  else if (result_IN == BuySell_t.Success) {writeln(msg_success);}
}

/***********************************
 * Summary: List based implementation of sell function.
 * Params:
 *    assetName_IN = Asset name list
 *    assetquantity_IN = Quantityt list. Mus be same size
 *    connectionID_IN = String
 * as asset name list.
  Example:
  -------------------
  myEngine_1.Sell(["MSFT", "SPY"], [1,1]);
  -------------------
 * Template: 
 *    log: Calls logger if templated with logger.on
 * Returns:
 *    Check out buy/sell type enum definition
 */
BuySell_t Sell(logger log = logger.on)(
  string[] assetName_IN, 
  int[] assetquantity_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  BuySell_t result;
  if(assetName_IN.length != assetquantity_IN.length) 
    return BuySell_t.Error_List; 
  for(int i = 0; i<assetName_IN.length; ++i) {
    result = SellImpl(
      assetName_IN[i],
      assetquantity_IN[i],
      connectionID_IN);
    if(log == logger.on) 
      SellLogger(result, assetName_IN[i]);
  }
  return result;
}

BuySell_t Sell(logger log = logger.on)(
  string[] assetName_IN, 
  double[] assetquantity_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  BuySell_t result;
  if(assetName_IN.length != assetquantity_IN.length) 
    return BuySell_t.Error_List; 
  for(int i = 0; i<assetName_IN.length; ++i) {
    result = SellImpl(
      assetName_IN[i],
      assetquantity_IN[i],
      connectionID_IN);
    if(log == logger.on) 
      SellLogger(result, assetName_IN[i]);
  }
  return result;
}

/***********************************
 * Summary: Logs to console the outcome of sell
 * Params:
 *    result_IN = Result of the sell action
 *    assetName_IN = Name of the asset
 */
void SellLogger(BuySell_t result_IN, string assetName_IN) {
  string msg_fail = 
  "Sell "~assetName_IN~
  " failed at "~to!string(CurrentDate())~
  " due to "~to!string(result_IN);

  string msg_success = 
  "Sell "~assetName_IN~
  " successful at "~to!string(CurrentDate());  

  if(result_IN != BuySell_t.Success) {writeln(msg_fail);}
  else if (result_IN == BuySell_t.Success) {writeln(msg_success);}
}

/***********************************
 * Summary: Sells everything inside the portfolio
 * Template: 
 *    log: Calls logger if templated with logger.on
 * Params:
 *    connectionID_IN = String
 * Returns:
 *    Check out buy/sell type enum definition
 */
BuySell_t SellEverything(logger log = logger.on)(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  
  BuySell_t result = BuySell_t.Success;
  BuySell_t single_sell_result = BuySell_t.Success;

  string[] names = SymbolsPortfolio();
  for(int i = 0; i<names.length; ++i) {
    single_sell_result = Sell!(log)([names[i]], [Get(names[i])]);
    if(single_sell_result != BuySell_t.Success) result = BuySell_t.Error_SellEverything;
  }
  return result;
} 

/***********************************
 * Summary: Updates tick for stash and date for engine. It skips weekends.
 * Params:
 *      connectionID_IN = String
 * Returns:
 *    Success: Engine date incremented.
 *    Error_Overflow: Stash overflowed.
 *    Error_Stash: Stash threw an error.
 *    Error_MysqlOverflow: If no available ticks are left in mysql. 
 */
IncrementDate_t IncrementDate(string connectionID_IN = "none")
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  _dirty = true;

  // Check: Stash overflow
  if(_myStash.IncrementTick() == -1) {
    return IncrementDate_t.Error_Overflow;
  } 

  // Check: If there are zero available ticks today, throw an error.
  /* CURRENTLY NOT IMPLEMENTED BECAUSE THIS STOPS ENGINE FROM WORKING 
  // IF NOTHING IS IN THE ENGINE. 
  if(TodaysTickNamesFromEngine().length == 0)
  {
    return IncrementDate_t.Error_MysqlOverflow;
  }
  */

  // Skip weekends skip by 2/3 ticks otherwise increment day by one tick.
  if(_currentDate.dayOfWeek == DayOfWeek.sat || _currentDate.dayOfWeek == DayOfWeek.fri) {
    if(_currentDate.dayOfWeek == DayOfWeek.sat) {
      _currentDate += 2.days;
    }
    else {
      _currentDate += 3.days;
    }
  }
  else {
    _currentDate += 1.days;
  }

  // Dividend & Split Handler 
  string[] assetNames_Local = _myStash.GetAssetNames();
  foreach (string key; assetNames_Local) {
    if (key != "Cash") {
      // Check if tick exists at the current date. 
      // Holidays like 2016-Nov-24 thanksgiving don't exist.
      if(GetPrice(key, CurrentDate(), closeIndex, connectionID_IN) > 0) {
        double assetDividend; 
        if(dividendIndex == -1) {
          assetDividend = 0; 
        }
        else {
          assetDividend = GetPrice(key, CurrentDate(), dividendIndex, connectionID_IN);
        }
        double assetSplit;
        if(splitIndex != -1) {
          assetSplit = GetPrice(key, CurrentDate(), splitIndex, connectionID_IN);
        }
        else assetSplit = 1;    
        double[2] assetAmount = _myStash.GetItemAtCurrentIndex(key);

        // Error coming from stash error.
        if(assetAmount[1] != 1) {
          return IncrementDate_t.Error_Stash;
        }   

        // Split Handler
        if(abs(assetSplit - 1) > float.epsilon) {
          // Modify stash will add current assets times 
          // asset split minus current number of assets. Rounded down.
          _myStash.ModifyStash!int(to!int(assetSplit*assetAmount[0] - assetAmount[0]), key);            
        }

        // Dividend Handler: dividend is also kept seperately 
        _myStash.ModifyStash!double(assetDividend*assetAmount[0], "Dividend");
        _myStash.ModifyStash!double(assetDividend*assetAmount[0], "Cash");

        // Last day Handler
        int year = to!int(_metaData[key].endDate[0 .. 4]);
        int month = to!int(_metaData[key].endDate[5 .. 7]);
        int day = to!int(_metaData[key].endDate[8 .. 10]);
        auto endDate_dt = Date(year, month, day);

        if(endDate_dt == _currentDate) {
          double[2] assetQuantity = _myStash.GetItemAtCurrentIndex(key);
          // Verify stash didn't throw an error
          if(assetQuantity[1] != 1) {
            return IncrementDate_t.Error_Stash;
          }       
          // Verify we have more than zero of that asset
          if(assetQuantity[0] > 0) {  
            writeln("End of data feed detected! Symbol: "~key);
            _dataEndDetected = true;
            // Automatically sell it at the last day.
            // Potential bug if table and meta table last days do not match.
            assert(Sell([key], [to!int(assetQuantity[0])], connectionID_IN)== BuySell_t.Success);
          }
        } 
      }
      else {
        // On holidays we still put in a zero as dividend payment.
        _myStash.ModifyStash!double(0 , "Dividend");  
      }
    }
  }

  // Pie charts gets the last update on data end
  // Time series charts start printing without
  // the missing data.
  if(_dataEndDetected) {
    ++_dataEndCounter;
  }

  // Add new date to the array. As long as stash tick starts from zero
  // indeces of the array should match actual dates one-to-one. 
  _dateArray[_myStash.GetStashTick()] = _currentDate; 

  return IncrementDate_t.Success;
}

/***********************************
 * Summary: Updates tick for stash and date for 
 * engine until the target date. It skips weekends. 
 * You can buy/sell at target date and then increment
 * day again.
 * Params:
 *    targetDate_IN = In date format
 *    connectionID_IN = String
 * Returns:
 *    Success: Engine date incremented to target date.
 *    Error_TargetOld: Target date is older then engine's current date. 
 */ 
Increment2Date_t Increment2Date(
  Date targetDate_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  // Check: If target date is older than current date this function returns -1.
  if(targetDate_IN < _currentDate) {
    return Increment2Date_t.Error_TargetOld;
  }

  // Incrementer loop
  while(_currentDate < targetDate_IN) {
    IncrementDate(connectionID_IN);
  }

  return Increment2Date_t.Success;
}

/***********************************
 * Summary: Updates tick for stash and date for 
 * engine until the target date. It skips weekends. 
 * You can buy/sell at target date and then increment
 * day again.
 * Params:
 *    year_IN = integer. For example, 2016
 *    month_IN = integer [0-12]
 *    day_IN = integer [0-31]
 *    connectionID_IN = String
 * Returns:
 *    Success: Engine date incremented to target date.
 *    Error_TargetOld: Target date is older then engine's current date. 
 */ 
Increment2Date_t Increment2Date(
  int year_IN, 
  int month_IN, 
  int day_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  return Increment2Date(Date(year_IN, month_IN, day_IN), connectionID_IN);
}

/***********************************
 * Summary: Exports stash matrix as a 
 * csv file to executable's folder.
 * Params:
 *    name_IN = Name of the output csv file
 *    mode_IN = 0 (asset quantity) or 1 (asset price).
 *    connectionID_IN = String
 * Returns:
 *    Error: CSV error represented as "-1"
 *    Text: CSV file containing portfolio data.
 */ 
string ExportEngineCSV(
  string name_IN,  
  AssetColumn_t mode_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  Frame[] equity_matrix = EquityMatrix(
    connectionID_IN, 
    closeIndex, 
    mode_IN);   
  string result;
  string header_text = "Date,";
  ulong length = equity_matrix[0].dateArray.length;

  for(int i = 0; i<equity_matrix.length; ++i) {
    if(equity_matrix[i].name == "") continue;
    header_text ~= equity_matrix[i].name;
    if(i != equity_matrix.length-1) header_text ~= ",";
  }
  result = header_text ~= "\n";
  
  for (int t = 0; t<length; ++t){
    result ~= to!string(equity_matrix[0].dateArray[t]);
    result ~= ",";        
    for(int i = 0; i<equity_matrix.length; ++i) {
      if(equity_matrix[i].name == "") continue;
      result ~= to!string(equity_matrix[i].valueArray[t]);
      if(i != equity_matrix.length-1) result ~= ",";
    }
    result ~= "\n";
  }

  if(name_IN != "") {
    if (!exists("out/"))
      mkdir("out/");
    std.file.write("out/"~name_IN~".csv", result);
  }

  return result;
} 

/***********************************
 * Summary: If mode is asset quantity (mode: 0), 
 * then returns asset numbers. If mode is asset value (mode: 1),
 * then returns asset_number*asset_price. 
 * Keep in mind returnStructure.valueArray.length should be non-zero upon return.
 * If it is zero, it indicates a holiday or market close day.
 * Params:
 *    name_IN = Name of the output csv file
 *    startTick_IN = Start tick index
 *    numberOfRows_IN = Number of rows to grab
 *    mode_IN = 0 (asset quantity) or 1 (asset price).
 *    assetIndex_IN = Open/High/Low/Close
 *    connectionID_IN = String
 *    ohlc_IN = string
 * Returns:
 *    assetArray: Asset array either as quantity or value.
 */ 
Frame AssetColumn(
  string name_IN, 
  int startTick_IN, 
  int numberOfRows_IN, 
  AssetColumn_t mode_IN,
  int assetIndex_IN,
  string connectionID_IN = "none",
  string ohlc_IN = "")
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame returnStructure;    

  // Only fills data if key exists.
  if(_myStash.CheckKey(name_IN) == _myStash.CheckKey_t.Success) {
    // Copy-Pasted index filter code.
    int localStashTick = _myStash.GetStashTick();

    // Set number of rows to MAXTICKS if input is -1. Therefore pick all columns
    if(numberOfRows_IN == -1) {
      numberOfRows_IN = _maxTicks;
    }

    // Start tick is out of index
    if(startTick_IN < 0 || startTick_IN > localStashTick) {
      // Return empty structure
      return returnStructure;
    }

    // If end tick overflows it becomes stash tick which points 
    // to the last line in the stash
    int endTick;
    if(startTick_IN + numberOfRows_IN > localStashTick) {
      endTick = localStashTick;
    }
    else {
      endTick = startTick_IN + numberOfRows_IN;
    }

    // Get the asset column from the stash
    double[] assetQuantityVector = _myStash.GetColumn(
      name_IN, 
      startTick_IN, 
      numberOfRows_IN);

    // Check if asset exists in the stash
    if(assetQuantityVector != null) {
      // Used for iterating over all dates. These dates 
      // are matched with ticks inside the stash
      Date[] dateSeries = DateColumn(
        startTick_IN, 
        numberOfRows_IN);

      // Used for obtaining date and value series 
      // filtered out with holiday dates etc ...
      Date  [] dateSeriesOutput;
      double  [] valueSeriesOutput;

      for (int i = startTick_IN+1; i < endTick+1; i++) {
        dateSeriesOutput  ~= dateSeries[i-1];

        // Handle cash and dividends seperately since they don't need mysql connection.
        if(
          name_IN == "Cash" || 
          name_IN == "Dividend" || 
          name_IN == "Deposit" || 
          mode_IN == AssetColumn_t.Quantity) {
          valueSeriesOutput   ~= assetQuantityVector[i-startTick_IN];
        }

        // Handle every other tick with total value.
        // Hard-Coded "Cash" and "Dividend" exceptions. 
        // Turns out cash is a tick name in EOD dataset.
        if (
          name_IN != "Cash" && 
          name_IN != "Dividend" && 
          name_IN != "Deposit" && 
          mode_IN == AssetColumn_t.Value ) {
          // Check: Whether tick exists at given date. 
          // Enter here when index is dividend too.
          if(GetPrice(name_IN, dateSeries[i-1], closeIndex, connectionID_IN) > 0) {
            double asset_value = GetPrice(name_IN, dateSeries[i-1], assetIndex_IN, connectionID_IN);
            double number_of_assets = to!double(assetQuantityVector[i-startTick_IN]);
            valueSeriesOutput ~= asset_value*number_of_assets;
          }
          else {
            // This *should* happen if it's a holiday. 
            // Just append the last value on holidays.
            // The zero check is there for single day checks. 
            if(valueSeriesOutput.length > 0) {
              valueSeriesOutput ~= valueSeriesOutput[valueSeriesOutput.length-1];
            }
            else if(valueSeriesOutput.length == 0) { 
            // this happens if a company IPOs during lifetime of the engine 
              valueSeriesOutput ~= 0.0;
            }
          }
        }     
      }

      // Populate filtered return structure
      returnStructure.valueArray = valueSeriesOutput;
      returnStructure.dateArray = dateSeriesOutput;
      returnStructure.name = name_IN~ohlc_IN;
    }
  }
  return returnStructure;
}

/***********************************
 * Summary: Grabs date array. n-runtime.
 * Params:
 *    startTick_IN = Start tick index
 *    numberOfRows_IN = Number of rows to grab
 * Returns:
 *    dateArray: Date array with length "number of rows"
 */ 
pure Date[] 
DateColumn(
  int startTick_IN, 
  int numberOfRows_IN)  
{
  int localStashTick = _myStash.GetStashTick();

  // Set number of rows to MAXTICKS if input is -1. 
  // Therefore pick all columns
  if(numberOfRows_IN == -1) {
    numberOfRows_IN = _maxTicks;
  }

  // Start tick is out of index
  if(startTick_IN < 0 || startTick_IN > localStashTick) {
    return null;
  }

  // If end tick overflows it becomes stash tick which points to the 
  // last line in the stash
  int endTick;
  if(startTick_IN + numberOfRows_IN > localStashTick) {
    endTick = localStashTick;
  }
  else {
    endTick = startTick_IN + numberOfRows_IN;
  }

  Date[] dateArray = new Date[endTick];

  for (int i = startTick_IN; i<endTick; i++) {
    dateArray[i] = _dateArray[i+1];
  }   

  return dateArray;
}

/***********************************
 * Summary: Computes the total equity from tick 
 * names inside stash and the cash value.
 * Params:
 *    connectionID_IN = String
 * Returns:
 *    equity: Double precision, total capital.
 */ 
double EquityAtCurrentDate(string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame currentAssetValue;
  double equity = 0.0;
  foreach (string name; SymbolsPortfolio()) {
    currentAssetValue = AssetColumn(
      name, 
      CurrentTick(), 
      1, 
      AssetColumn_t.Value,
      closeIndex,
      connectionID_IN);

    equity += currentAssetValue.valueArray[0];
  }
  currentAssetValue = AssetColumn(
    "Cash", 
    CurrentTick(), 
    1, 
    AssetColumn_t.Value,
    closeIndex,
    connectionID_IN);

  equity += currentAssetValue.valueArray[0];  
  return equity;
}

/***********************************
 * Summary: Computes frames of each asset inside the stash
 * Template: 
 *    connectionID_IN = String
 *    asset_column_t = Value or quantity
 *    assetIndex_IN = Close price is chosen as default, 5
 * Returns:
 *    asset_matrix: Returns an array of frames. 
 *    Each frame contains all time seris of the asset value in portfolio
 */ 
Frame[] EquityMatrix (
  string connectionID_IN = "none", 
  int assetIndex_IN = 5, // Index of the close, needs to be a enum value!
  AssetColumn_t asset_column_t = AssetColumn_t.Value)
{
    import std.stdio: writeln;
    import std.datetime.stopwatch: StopWatch, AutoStart;  
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

    auto myStopWatch = StopWatch(AutoStart.no);
    myStopWatch.start();

  string[] names = SymbolsPortfolio();
  Frame[] asset_matrix;

  // Add cash
  asset_matrix ~= AssetColumn(
    "Cash", 
    0, 
    _myStash.GetStashTick(), 
    AssetColumn_t.Quantity,
    assetIndex_IN,
    connectionID_IN);

  // Add dividends
  asset_matrix ~= AssetColumn(
    "Dividend", 
    0, 
    _myStash.GetStashTick(), 
    AssetColumn_t.Quantity,
    assetIndex_IN,
    connectionID_IN);

  // Add all assets
  // With OHLC
  for(int i = 0; i<names.length; ++i) {
    asset_matrix ~= AssetColumn(
    names[i],
    0, 
    _myStash.GetStashTick(), 
    asset_column_t,
    closeIndex,
    connectionID_IN,
    "_close");

    asset_matrix ~= AssetColumn(
    names[i], 
    0, 
    _myStash.GetStashTick(), 
    asset_column_t,
    openIndex,
    connectionID_IN,
    "_open"); 

    asset_matrix ~= AssetColumn(
    names[i], 
    0, 
    _myStash.GetStashTick(), 
    asset_column_t,
    highIndex,
    connectionID_IN,
    "_high");   

    asset_matrix ~= AssetColumn(
    names[i], 
    0, 
    _myStash.GetStashTick(), 
    asset_column_t,
    lowIndex,
    connectionID_IN,
    "_low");
  }

  writeln("[ENGINE: EquityMatrix] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");
    myStopWatch.reset();
    myStopWatch.stop();

  return asset_matrix;
}

/***********************************
 * Summary: Helper function. Calling equity matrix after
 * updates to portfolio are finished. Instead of calling it
 * when a user asks for it.
 * Template: 
 *    connectionID_IN = String
 */ 
void UpdateEquityMatrix(string connectionID_IN = "none")
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  if(_dirty)
  {
    _all_assets = EquityMatrix(
      connectionID_IN);
    _dirty = false;
  } 
}

/***********************************
 * Summary: Computes dividends of the portfolio at each date
 * Params:
 *    connectionID_IN = String
 * Returns:
 *    dividend: Returns a frame which contains all dividends
 */ 
Frame Dividend(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame dividend;
  UpdateEquityMatrix(connectionID_IN);

  ulong length = _all_assets[0].dateArray.length;
  for (int t = 0; t<length; ++t){
    double daily_dividend = 0.0;
    for(int i = 0; i<_all_assets.length; ++i) {
      if(_all_assets[i].name == "Dividend") {
        dividend.valueArray ~= _all_assets[i].valueArray[t];
      }
    }
  }
  dividend.dateArray = _all_assets[0].dateArray;
  dividend.name = "Dividend";
  return dividend;
}

/***********************************
 * Summary: Calls dividend and converts to json. Refactor this into a single
 * function with dividend called with template.
 * Params: 
 *    connectionID_IN = String
 * Returns:
 *    dividend_json: dividend frame represented in json format
 */ 
JSONValue Dividend_json(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame dividend = Dividend(connectionID_IN);
  string[] dates;
  foreach (i, date; dividend.dateArray) {
    dates ~= to!string(date).replace("-", "\\");
  }

  JSONValue dividend_json = ["name": dividend.name];
  dividend_json.object["values"] = dividend.valueArray;
  //dividend_json.object["dates"] = dates;
  return dividend_json;
}

/***********************************
 * Summary: Computes total non-cash equity position.
 * Params: 
 *    connectionID_IN = String
 * Returns:
 *    cash: Returns a frame
 */ 
Frame NonCashEquity(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame cash = Cash(connectionID_IN);
  Frame equity = Equity(connectionID_IN);
  Frame nonCashEquity;

  ulong length = equity.dateArray.length;
  for (int t = 0; t<length; ++t){
    nonCashEquity.valueArray ~= equity.valueArray[t] - cash.valueArray[t];
  }

  nonCashEquity.dateArray = equity.dateArray;
  nonCashEquity.name = "NonCashEquity"; 

  return nonCashEquity;
}

/***********************************
 * Summary: Calls non-cash equity and converts to json
 * Params:
 *    connectionID_IN = String
 * Returns:
 *    nonCashEquity_json: equity frame represented in json format
 */ 
JSONValue NonCashEquity_json(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame nonCashEquity = NonCashEquity(connectionID_IN);
  string[] dates;
  foreach (i, date; nonCashEquity.dateArray) {
    dates ~= to!string(date).replace("-", "\\");
  }

  JSONValue nonCashEquity_json = ["name": nonCashEquity.name];
  nonCashEquity_json.object["values"] = nonCashEquity.valueArray;
  //nonCashEquity_json.object["dates"] = dates;
  return nonCashEquity_json;
}

/***********************************
 * Summary: Computes total cash position of portfolio at each date.
 * Params: 
 *    connectionID_IN = String
 * Returns:
 *    cash: Returns a frame which contains all cash
 */ 
Frame Cash(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  return AssetColumn(
    "Cash", 
    0, 
    _myStash.GetStashTick(), 
    AssetColumn_t.Quantity,
    closeIndex,
    connectionID_IN);
}

/***********************************
 * Summary: Calls cash and converts to json. Refactor this into a single
 * function with Cash called with template.
 * Params: 
 *    connectionID_IN = String
 * Returns:
 *    cash_json: cash frame represented in json format
 */ 
JSONValue Cash_json(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame cash = Cash(connectionID_IN);
  string[] dates;
  foreach (i, date; cash.dateArray) {
    dates ~= to!string(date).replace("-", "\\");
  }

  JSONValue cash_json = ["name": cash.name];
  cash_json.object["values"] = cash.valueArray;
  //cash_json.object["dates"] = dates;
  return cash_json;
}

/***********************************
 * Summary: Computes total equity of the portfolio at each date
 * Params:
 *    connectionID_IN = String
 *    assetIndex_IN = Close index is picked as default, 5
 * Returns:
 *    equity: Returns a frame which contains all equity
 */ 
Frame Equity(
  string connectionID_IN = "none", 
  int assetIndex_IN = 5) 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity;
  UpdateEquityMatrix(connectionID_IN);

  ulong length = _all_assets[0].dateArray.length;
  for (int t = 0; t<length; ++t){
    double daily_equity = 0.0;
    for(int i = 0; i<_all_assets.length; ++i) {
      if(_all_assets[i].name != "Dividend" || _all_assets[i].name != "Deposit") {
        if(_all_assets[i].name == "") continue;
        
        if(assetIndex_IN == openIndex) 
          if(indexOf(_all_assets[i].name, "open") != -1)
            daily_equity += _all_assets[i].valueArray[t];

        if(assetIndex_IN == highIndex) 
          if(indexOf(_all_assets[i].name, "high") != -1)
            daily_equity += _all_assets[i].valueArray[t];

        if(assetIndex_IN == lowIndex) 
          if(indexOf(_all_assets[i].name, "low") != -1)
            daily_equity += _all_assets[i].valueArray[t];

        if(assetIndex_IN == closeIndex) 
          if(indexOf(_all_assets[i].name, "close") != -1)
            daily_equity += _all_assets[i].valueArray[t];
  
        if(_all_assets[i].name == "Cash")
          daily_equity += _all_assets[i].valueArray[t];
      }
    }

    equity.valueArray ~= daily_equity;
  }
  equity.dateArray = _all_assets[0].dateArray;
  equity.name = "Equity";
  return equity;
}

/***********************************
 * Summary: Calls equity and converts to json. Refactor this into a single
 * function with Equity called with template.
 * Params:
 *    connectionID_IN = String
 *    assetIndex_IN = Close index for default SDF is 5
 * Returns:
 *    equity_json: equity frame represented in json format
 */ 
JSONValue Equity_json(
  string connectionID_IN = "none",
  int assetIndex_IN = 5) 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity = Equity(connectionID_IN, assetIndex_IN);
  string[] dates;
  foreach (i, date; equity.dateArray) {
    dates ~= to!string(date).replace("-", "\\");
  }

  JSONValue equity_json = ["name": equity.name];
  equity_json.object["values"] = equity.valueArray;
  if(assetIndex_IN == closeIndex)
  {
    equity_json.object["dates"] = dates;
  }
  return equity_json;
}

/***********************************
 * Summary: Returns a json file containing list of assets and their
 * percents in the portolio. Fix the timing issue later on, right no
 * its passed as string with a bad if-else condition.
 * Params:
 *    connectionID_IN = String
 *    time_IN = String
 * Returns:
 *    pie_chart_json: equity frame represented in json format
 */ 
JSONValue PieChart_json(
  string connectionID_IN = "none", 
  string time_IN = "end") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  UpdateEquityMatrix(connectionID_IN);
    string[] asset_names;
    double[] asset_sizes;
    foreach(asset; _all_assets){
        int length = to!int(asset.valueArray.length);
        length = length - _dataEndCounter;
        if(time_IN == "begin")
          length = 1;
        if(asset.valueArray[length-1] > 0.0) {
            if(asset.name != "Dividend") {
              if(indexOf(asset.name, "close") != -1 || asset.name == "Cash")
              {
                  asset_sizes ~= asset.valueArray[length-1];
                  asset_names ~= asset.name;                
              }
            }
        }
    }

  JSONValue pie_chart_json = ["name": asset_names];
  pie_chart_json.object["values"] = asset_sizes;
  return pie_chart_json;
}

/***********************************
 * Summary: Computes daily returns of the simulated portfolio
 * Not unit tested.
 * Params:
 *    resolution = y-axis resolution
 *    connectionID_IN = String
 * Returns:
 *    tuple: Daily returns and bin vector as double[]
 */ 
auto DailyReturns(
  double resolution, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity = Equity(connectionID_IN);
  double[] daily_returns;

  for (int t = 1; t<equity.valueArray.length; ++t) {
    double difference = equity.valueArray[t] - equity.valueArray[t-1];
    if(difference > float.epsilon || difference < -float.epsilon) {
      daily_returns ~= 100.0*difference/equity.valueArray[t-1];
    }
    else daily_returns ~= 0.0;
  }

  return tuple(
    daily_returns, 
    iota(
      daily_returns.reduce!min, 
      daily_returns.reduce!max, 
      (daily_returns.reduce!max-daily_returns.reduce!min) / resolution));
} 

/***********************************
 * Summary: Computes daily returns of the simulated portfolio
 * Not unit tested.
 * Params:
 *    connectionID_IN = String
 * Returns:
 *    daily_returns_json: Daily returns as json
 */ 
JSONValue DailyReturns_json(string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity = Equity(connectionID_IN);
  double[] daily_returns;

  for (int t = 1; t<equity.valueArray.length; ++t) {
    double difference = equity.valueArray[t] - equity.valueArray[t-1];
    if(difference > float.epsilon || difference < -float.epsilon) {
      daily_returns ~= 100.0*difference/equity.valueArray[t-1];
    }
    else daily_returns ~= 0.0;
  }
  JSONValue daily_returns_json = ["daily_returns": daily_returns];

  return daily_returns_json;
}

/***********************************
 * Summary: Computes weekly returns of the simulated portfolio
 * Not unit tested.
 * Params:
 *    resolution = y-axis resolution
 *    connectionID_IN = String
 * Returns:
 *    tuple: Weekly returns and bin vector as double[]
 */ 
 auto WeeklyReturns(
  double resolution, 
  string connectionID_IN = "none") 
 {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity = Equity(connectionID_IN);
  double[] weekly_returns;
  
  //equity.dateArray
  double priceAtWeekBeginning = equity.valueArray[0];
  for (int t = 1; t<equity.valueArray.length; ++t) {
    if(equity.dateArray[t].dayOfWeek == DayOfWeek.mon) {
      double difference = equity.valueArray[t] - priceAtWeekBeginning;
      weekly_returns ~= 100.0*difference/equity.valueArray[t-1];
      priceAtWeekBeginning = equity.valueArray[t];
    }
  }

  return tuple(
    weekly_returns, 
    iota(
      weekly_returns.reduce!min, 
      weekly_returns.reduce!max, 
      (weekly_returns.reduce!max-weekly_returns.reduce!min) / resolution));
} 

/***********************************
 * Summary: Computes monthly returns of the simulated portfolio
 * Not unit tested.
 * Params:
 *    resolution = y-axis resolution
 *    connectionID_IN = String
 * Returns:
 *    tuple: Monthly returns and bin vector as double[]
 */ 
 auto MonthlyReturns(
  double resolution, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity = Equity(connectionID_IN);
  double[] monthly_returns;
  
  //equity.dateArray
  double priceAtMonthBeginning = equity.valueArray[0];
  Month previous_month = equity.dateArray[0].month; 

  for (int t = 1; t<equity.valueArray.length; ++t) {
    Month current_month = equity.dateArray[t].month;
    if(equity.dateArray[t].dayOfWeek == DayOfWeek.mon && current_month != previous_month) {
      double difference = equity.valueArray[t] - priceAtMonthBeginning;
      monthly_returns ~= 100.0*difference/equity.valueArray[t-1];
      priceAtMonthBeginning = equity.valueArray[t];
      previous_month = current_month;
    }
  }
  
  return tuple(
    monthly_returns, 
    iota(
      monthly_returns.reduce!min, 
      monthly_returns.reduce!max, 
      (monthly_returns.reduce!max-monthly_returns.reduce!min) / resolution));
} 

/***********************************
 * Summary: Computes percentage at each date of a frame
 * Returns:
 *    percentageArray: Returns a frame which contains all percentage
 */ 
Frame Percentage(
  Frame valueArray_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame percentageArray;
  ulong length = valueArray_IN.dateArray.length;
  double startPrice = valueArray_IN.valueArray[0];
  double[] percArray;

  if(valueArray_IN.name == "Equity") {
    percArray = NormalizeDeposits(valueArray_IN, connectionID_IN);
  }
  else {    
    for (int t = 0; t<length; ++t){
      percArray ~= 100.0*(valueArray_IN.valueArray[t]-startPrice)/startPrice;
    }
  }
  percentageArray.valueArray = percArray;
  percentageArray.dateArray = valueArray_IN.dateArray;
  percentageArray.name = valueArray_IN.name~"Percentage";
  return percentageArray;
}

/***********************************
 * Summary: Calls percentage and converts to json.
 * Params:
 *    connectionID_IN = String
 *    assetIndex_IN = Close index for default SDF is 5
 * Returns:
 *    percentage_json: equity percentage frame represented in json format
 */ 
JSONValue Percentage_json(
  string connectionID_IN = "none",
  int assetIndex_IN = 5) 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame equity = Equity(connectionID_IN, assetIndex_IN);
  Frame equityPerc = Percentage(equity, connectionID_IN);
  string[] dates;
  foreach (i, date; equityPerc.dateArray) {
    dates ~= to!string(date).replace("-", "\\");
  }

  JSONValue percentage_json = ["name": equityPerc.name];
  percentage_json.object["values"] = equityPerc.valueArray;
  //percentage_json.object["dates"] = dates;
  return percentage_json;
}

/***********************************
 * Summary: Returns close prices of 
 * an asset between engine begin 
 * and current dates. It will fill
 * zeros if price is not found
 * for whatever reason. 
 * Params:
 *    symbol_IN = Asset in the database.
 *    connectionID_IN = String
 * Returns:
 *    assetArray: Returns a frame which contains all prices of the given asset
 * 
 */ 
Frame GetPrice(
  string symbol_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  Frame cash_frame = AssetColumn(
    "Cash", 
    0, 
    _myStash.GetStashTick(), 
    AssetColumn_t.Quantity,
    closeIndex,
    connectionID_IN);

  Frame result;
  result.name = symbol_IN;
  // Make sure to match each date at get price with engine's dates. 
  // Otherwise it won't work with equity output
  foreach(date; cash_frame.dateArray) {
    result.dateArray ~= date;
    result.valueArray ~= GetPrice(symbol_IN, date, closeIndex, connectionID_IN);
  }
  return result;
}

/***********************************
 * Summary: Returns close price of 
 * an asset at input date. Returns
 * -1.0 if price is not found
 * for any reason
 * Params:
 *    symbol_IN = Asset in the database.
 *    date_IN = If nothing is found 
 *              function returns empty.
 *    connectionID_IN = String
 * Returns:
 *    asset_price: Returns price as 
 *                 double precision, 
 *                 -1.0 if operation 
 *                 fails.
 */ 
double GetPrice(
  string symbol_IN, 
  Date date_IN,
  int index_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  ResultRange range = Query(
    "select * from "~priceTableName~
    " where symbol=\""~symbol_IN~
    "\" and date=\""~date_IN.toISOExtString()~"\";", connectionID_IN);

  if(range.empty) {
    return -1.0;
  }
  else {
    return range.front[index_IN].get!double;
  }
}

/***********************************
 * Summary: Returns close price of a 
 * group of assets. Not unit tested.
 * Params:
 *    symbols_IN = Group of assets 
 *                 in the database
 *    date_IN = No weekends etc ... 
 *              Function does not check 
 *              and will return -1.
 *    connectionID_IN = String
 * Returns:
 *    asset_prices: Returns price of 
 *                  each asset in the 
 *                  group as a double[]
 */ 
double[] GetPrice(
  string[] symbols_IN, 
  Date date_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  double[] result;
  for(int i = 0; i<symbols_IN.length; ++i) {
    result ~= GetPrice(
      symbols_IN[i], 
      CurrentDate(), 
      closeIndex, 
      connectionID_IN);
  }
  return result;
}

/***********************************
 * Summary: Return the current stach tick. 
 */ 
pure int 
CurrentTick() {
  return _myStash.GetStashTick()-1;
}

/***********************************
 * Summary: Returns current date of the engine.
 *    Date: Final date
 */ 
pure Date 
CurrentDate() {
  return _currentDate;
}

/***********************************
 * Summary: Returns start date of the engine.
 * Returns:
 *    Date: Begin date
 */ 
pure Date 
StartDate() 
{
  return _startDate;
} 

/***********************************
 * Summary: Returns quantity of the symbol 
 * in portfolio at the current date
 * Returns:
 *    int: Warning, won't work with currencies
 */ 
int Get(
  string symbol_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  Frame f = AssetColumn(
    symbol_IN, 
    CurrentTick(), 
    1, 
    AssetColumn_t.Quantity,
    closeIndex,
    connectionID_IN);
  return to!int(f.valueArray[0]);
}

/***********************************
 * Summary: Return initial deposit
 * Returns:
 *    double: First deposit
 */ 
pure double 
InitialDeposit() 
{
  return _initialDeposit;
}

private:
/***********************************
 * Summary: Refresh calls this. It configures the stash
 * class with dividend, cash.
 * Params:
 *    initialDeposit_IN = Money added to portfolio at start date
 *    startDate_IN = Start date
 */
void InitializeStash(
  double initialDeposit_IN, 
  Date startDate_IN) {
  // Init start date
  _startDate = startDate_IN;
  _currentDate = _startDate;

  // Init date array
  _dateArray[1] = _currentDate;

  // Initialize dividend column
  _myStash.AddAsset("Dividend", Quantity_t.double_Q);

  // Initialize deposits column
  _myStash.AddAsset("Deposit", Quantity_t.double_Q);

  // Initialize cash deposit
  _myStash.IncrementTick();
  Deposit(initialDeposit_IN);

  // Index starts at zero and incremented with each new asset addition.
  _stashTickNamesIndex = 0;
}

/***********************************
 * Summary: Initialize meta data begin/end and tick names.
 * This is called by the constructor.
 * Params:
 *    connectionID_IN = String
 */
void InitializeMetaData(string connectionID_IN = "none") {
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  int rowIndex = 0;   // Index checks first line. Does not process it.
  foreach(row; Query("select * from "~metaTablename~";", connectionID_IN).array) {
    MetaData metaRow;
    // Begin/End dates are listed as 4th and 5th columns on mysql meta table 
    metaRow.beginDate = to!string(row[metaBeginIndex]);
    metaRow.endDate = to!string(row[metaEndIndex]);

    // 0th column is tick names.
    metaRow.tickName = to!string(row[metaSymbolIndex]);
    _metaData[metaRow.tickName] = metaRow;
    rowIndex += 1;
  }

  // Initialize total number of ticks
  _totalTicks = _metaData.length;
}

/***********************************
 * Summary: Used to compensate jumps in percentage 
 * returns happening due to user deposits
 * Called by Percentage.
 */
double[] NormalizeDeposits(
  Frame equity_IN, 
  string connectionID_IN = "none")
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  double[] normalized_equity;
  ulong length = equity_IN.dateArray.length;
  double startPrice = equity_IN.valueArray[0];
  Frame deposits = AssetColumn(
    "Deposit", 
    0, 
    _myStash.GetStashTick(), 
    AssetColumn_t.Quantity,
    closeIndex,
    connectionID_IN);

  double old_deposit = deposits.valueArray[0];
  for (int t = 0; t<length; ++t){
    if(deposits.valueArray[t] != old_deposit) {
      startPrice += deposits.valueArray[t]-old_deposit;
    }
    normalized_equity ~= 100.0*(equity_IN.valueArray[t]-startPrice)/startPrice;
    old_deposit = deposits.valueArray[t];
  }
  return normalized_equity;
}

/***********************************
 * Summary: Utility function to check if the current date is between 
 * begin and end dates.
 * Params:
 *      beginDate_IN = Begin date. Format -> yyyy-mm-dd
 *    endDate_IN = End date
 * Returns:
 *    True within range and false if not
 */
pure bool 
IsSymbolWithinDateRanges(
  string beginDate_IN, 
  string endDate_IN) 
{
  // Add to array if engine's current date is between begin and end dates.
  int year = to!int(beginDate_IN[0 .. 4]);
  int month = to!int(beginDate_IN[5 .. 7]);
  int day = to!int(beginDate_IN[8 .. 10]);
  auto beginDate_dt = Date(year, month, day);

  year = to!int(endDate_IN[0 .. 4]);
  month = to!int(endDate_IN[5 .. 7]);
  day = to!int(endDate_IN[8 .. 10]);
  auto endDate_dt = Date(year, month, day);
  if(_currentDate >= beginDate_dt && _currentDate < endDate_dt) {
    return true;
  }
  else {
    return false;
  }
}

BuySell_t BuyImpl(
  string assetName_IN, 
  double assetquantity_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  //Pre-Buy Checks
  // Check: Negative input
  if(assetquantity_IN < 0) {
    return BuySell_t.Error_Negative;
  }

  // Check: Weekend
  if(_currentDate.dayOfWeek == DayOfWeek.sat || _currentDate.dayOfWeek == DayOfWeek.sun) {
    return BuySell_t.Error_Weekend;
  }

  // Check: Tick Name in Database
  if(SymbolAvailableAtDate(assetName_IN, connectionID_IN) == SymbolAvailableAtDate_t.Error_TickNotFound) {
    return BuySell_t.Error_TickNotFound;
  } 

  // Check: Whether tick exists at given date.
  if(SymbolAvailableAtDate(assetName_IN, connectionID_IN) == SymbolAvailableAtDate_t.Error_TickNotAvailableAtDate) {
    return BuySell_t.Error_TickNotAvailableAtDate;
  }

  // Check: Cash and make sure asset quantity is positive
  double asset_value = GetPrice(assetName_IN, CurrentDate(), closeIndex, connectionID_IN);
  double number_of_assets = assetquantity_IN;
  double assetPrice = asset_value*number_of_assets;
  double[2] cashAmount = _myStash.GetItemAtCurrentIndex("Cash");
  if(cashAmount[1] != 1) {
    return BuySell_t.Error_Stash;
  }
  if(cashAmount[0] < assetPrice || assetquantity_IN < 0) {
    return BuySell_t.Error_TooPoor;
  }

  // Buy checks passed ...

  // Decide whether tick name is in Portfolio
  if(_myStash.CheckKey(assetName_IN) == _myStash.CheckKey_t.Fail) {
    // Add asset if not in portfolio
    _myStash.AddAsset(assetName_IN, Quantity_t.double_Q);

    // Add asset name to internal string array too
    _stashTickNames[_stashTickNamesIndex] = assetName_IN;
    _stashTickNamesIndex += 1;
  }

  // Increase asset quantity.
  _myStash.ModifyStash!double(assetquantity_IN, assetName_IN); 

  // Decerease cash 
  _myStash.ModifyStash!double(-assetPrice , "Cash");  

  // Error on max allowed trades
  if(_tradeNumber >= _maxTrades) return BuySell_t.Error_MaxTrades;

  // Update trade list now that buy action is successful
  Trade currentTrade;
  currentTrade.tradeType = Trade_T.Buy;
  currentTrade.assetName = assetName_IN;
  currentTrade.assetQuantity = assetquantity_IN;
  currentTrade.tradeDate = _currentDate.toISOExtString();
  _engineTradeList[_tradeNumber] = currentTrade;
  _tradeNumber++;

  return BuySell_t.Success;
}

BuySell_t SellImpl(
  string assetName_IN, 
  double assetquantity_IN,
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

  // Check: Negative input
  if(assetquantity_IN < 0) {
    return BuySell_t.Error_Negative;
  }

  // Check: Weekend
  if(_currentDate.dayOfWeek == DayOfWeek.sat || _currentDate.dayOfWeek == DayOfWeek.sun) {
    return BuySell_t.Error_Weekend;
  }

  // Check: Decide whether tick name is in the stash
  if(_myStash.CheckKey(assetName_IN) == _myStash.CheckKey_t.Fail) { 
    return BuySell_t.Error_TickNotFound;
  } 

  // Check: If asset quantity in the stash is larger than zero.
  double[2] assetQuantity = _myStash.GetItemAtCurrentIndex(assetName_IN);
  if(assetQuantity[1] != 1) {
    return BuySell_t.Error_Stash;
  }

  if( ( assetQuantity[0] -  assetquantity_IN ) < 0) {
    return BuySell_t.Error_TooPoor;
  }
  
  // Check: Whether tick exists at given date.
  if(SymbolAvailableAtDate(assetName_IN, connectionID_IN) == SymbolAvailableAtDate_t.Error_TickNotAvailableAtDate) {
    return BuySell_t.Error_TickNotAvailableAtDate;
  }

  double asset_value = GetPrice(assetName_IN, CurrentDate(), closeIndex, connectionID_IN);
  double number_of_assets = to!double(assetquantity_IN);
  double assetPrice = asset_value*number_of_assets;

  // Increase asset quantity.
  _myStash.ModifyStash!double(-assetquantity_IN, assetName_IN);  

  // Decerease cash 
  _myStash.ModifyStash!double(assetPrice , "Cash"); 

  // Error on max allowed trades
  if(_tradeNumber >= _maxTrades) return BuySell_t.Error_MaxTrades;

  // Update trade list now that sell action is successful
  Trade currentTrade;
  currentTrade.tradeType = Trade_T.Sell;
  currentTrade.assetName = assetName_IN;
  currentTrade.assetQuantity = assetquantity_IN;
  currentTrade.tradeDate = _currentDate.toISOExtString();
  _engineTradeList[_tradeNumber] = currentTrade;
  _tradeNumber++;

  return BuySell_t.Success;   
}

/***********************************
 * PortfolioContents: Writes a message to a string indicating each asset's 
 * Params:
 *      valuesIN = Value frame array
 *    quantities_IN =
 * Returns: portfolioContent_msg
 */
string PortfolioContents(Frame[] valuesIN, Frame[] quantities_IN) {
  string portfolioContent_msg = "";
  uint length = 0;
  portfolioContent_msg ~= "\n[ENGINE: PortfolioContents] \n  Values:\n"; 
  foreach(frame; valuesIN) {
    length = cast(uint)frame.dateArray.length;
    if(frame.valueArray[length-1] > 0) {
      string date = to!string(frame.dateArray[length-1]);
      string value = to!string(frame.valueArray[length-1]);
      string line = "    "~frame.name~" at "~date~" is "~value~"\n";
      portfolioContent_msg ~= line;
    }
  }
  portfolioContent_msg ~= "\n  Quantities:\n"; 
  foreach(frame; quantities_IN) {
    length = cast(uint)frame.dateArray.length;
    auto filter_close = find(frame.name, "close");
    bool non_zero_assets = frame.valueArray[length-1] > 0;
    bool dont_add = (
      frame.name != "Cash" && 
      frame.name != "Dividend" && 
      frame.name != "Deposit" &&
      filter_close != null);
    if(non_zero_assets && dont_add) {
      string date = to!string(frame.dateArray[length-1]);
      string value = to!string(frame.valueArray[length-1]);
      string line = "    "~frame.name~" at "~date~" is "~value~"\n";
      portfolioContent_msg ~= line;
    }
  }
  return portfolioContent_msg;
}

/// Obtained from meta data's length
ulong _totalTicks = 0; 

/// Tick names and begin/end dates contained in MetaData dictionary
MetaData[string] _metaData;   

/// assets/ticks mean same thing. fix naming.
const int _maxAssets = 100; 

/// Max day increments
const int _maxTicks = 10000; 

/// Max number of trades
const int _maxTrades = 10000;

/// Contains the stash as a private variable
Stash _myStash;

/// For fast access. Store tick names in stash as an associative array.
string[_maxTicks-1] _stashTickNames; 

/// Trade list
Trade[_maxTrades] _engineTradeList;

/// Number of succesful trades in this engine instance
int _tradeNumber = 0;

// Number of days passed after the first End of data feed detection
int _dataEndCounter = 0;

/// Triggered to True when data feed end is detected.
bool _dataEndDetected = false;

/// Index value to keep track of _stashTickNames
int _stashTickNamesIndex; 

/// Dates
Date _startDate;    
Date _currentDate; 
double _initialDeposit;

/// Date array updated at each increment. Starts at index (1). Index (0) is uninitialized.          
Date[_maxTicks] _dateArray; 

/// Contains time series data for front end
Frame[] _all_assets;

/// Makes sure data collection form engine is only done once
bool _dirty = true;
} 

/// Frame contains time stamped price information and asset name
struct Frame {
  double  []  valueArray = null;  // Holds price or number of assets
  Date  []  dateArray = null;   // Must match the value array precisely
  string name; // asset name
}

/// A struct that contains name, start and end dates
struct MetaData {
  string  tickName;
  string  beginDate;    
  string  endDate;    
}

/// Determines whether a trade is a buy or sell action
enum Trade_T {
  Buy,
  Sell
}

/// Contains name of the traded asset, its quantity, buy/sell and trade date
struct Trade {
  Trade_T tradeType;
  string assetName;
  double assetQuantity;
  string tradeDate;
}

/// Turn on/off console logging
enum logger {
  on, 
  off} 

/// Asset column's quantity or value indicator. Used in AssetColumn.
enum AssetColumn_t {
  Quantity, 
  Value}; 

/// Return type for refresh
enum Refresh_t {
  Success,
  Warning_Weekend
}

/// Return type for tick available at date 
enum SymbolAvailableAtDate_t {
  Success, 
  Error_TickNotFound, 
  Error_TickNotAvailableAtDate} 

/// Return type for Buy/Sell 
enum BuySell_t {
  Success, 
  Error_Weekend, 
  Error_TickNotFound, 
  Error_TickNotAvailableAtDate, 
  Error_Stash, 
  Error_TooPoor, 
  Error_Negative, 
  Error_List,
  Error_SellEverything,
  Error_MaxTrades} 

/// Return type for increment date
enum IncrementDate_t {
  Success, 
  Error_Overflow, 
  Error_Stash, 
  Error_MysqlOverflow} 

/// Return type for increment-2-date
enum Increment2Date_t {
  Success, 
  Error_TargetOld}
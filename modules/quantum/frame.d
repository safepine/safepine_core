module safepine_core.quantum.frame;

// D
import std.conv: to; 
import std.datetime.date: Date;
import std.json: JSONValue, JSONOptions, parseJSON;

/***********************************
 * Safepine's frame struct for 
 * manipulating & accessing
 * high, low, close, open, div,
 * split data along with date
 * timestamps.
 */
struct Frame
{
  string name;
  Price price;
  Dividend div;
  Split split;
  Date date;
}

struct Price
{
  double adjclose;
  double close;
  double high;
  double low;
  double open;
  long volume;
}

struct Dividend
{
  double amount;
} 

struct Split
{
  long denominator;
  long numerator;
}

/***********************************
 * Summary: Normalizes dates of the list 
 * with respect to dates of the benchmark frame
 * Params:
 *    benchmark = Frame for benchmark
 *    lists = List to be benchmarked
 * Returns:
 *    Frame[][]: Normalized list
 *    
 */
Frame[][] NormalizeFrameDates(Frame[] benchmark, Frame[][] lists)
{
  Frame[][] result;
  Frame[] element = lists[0];
  bool[] doesDateExistsForAll;
  bool addDate;
  Date[] normalized_dates;

  // Get all dates in benchmark
  // Find all common dates in lists
  for(int i = 0; i < benchmark.length; ++i)
  {
    addDate = true;
    for(int n = 0; n < lists.length; ++n) doesDateExistsForAll ~= false;
    for(int j = 0; j < lists.length; ++j)
    {
      for(int k = 0; k < lists[j].length; ++k)
      {
        if(benchmark[i].date == lists[j][k].date)
          doesDateExistsForAll[j] = true;
      }
    }
    for(int n = 0; n < lists.length; ++n)
    {
      if(doesDateExistsForAll[n] == false) addDate = false;
    }
    if(addDate)
    {
      normalized_dates ~= benchmark[i].date;
    }
  }

  // Add benchmark's normalized frames to result
  Frame[] normalized_benchmark;
  int i_n = 0;
  for(int i = 0; i < benchmark.length; ++i)
  {
    if(normalized_dates[i_n] == benchmark[i].date)
    {
      normalized_benchmark ~= benchmark[i];
      i_n += 1;
    }
  }
  result ~= normalized_benchmark;

  // Add normalized frames of lists to result
  for(int k = 0; k < lists.length; ++k)
  {
    Frame[] normalized_list_item;
    i_n = 0;

    for(int i = 0; i < lists[k].length; ++i)
    {
      if(i_n < normalized_dates.length)
      {
        if(normalized_dates[i_n] <= lists[k][i].date)
        {
          normalized_list_item ~= lists[k][i];
          i_n += 1;
        } 
      }
    }
    result ~= normalized_list_item;
  }

  return result;
}

/***********************************
 * Summary: Prints frame to terminal
 * Params:
 *    frame_IN = Frame to print
 *    
 */
void PrintFrame(Frame[] frame_IN)
{
  import std.stdio: writeln;

  // Weird break
  writeln();
  writeln("-----::-----::-----::-----::");
  writeln("-----::-----::-----::-----::");
  writeln("Length of " ~ frame_IN[0].name ~ " is " ~  to!string(frame_IN.length));
  writeln("Open, high, low, close, volume");
  for(int j = 0; j < frame_IN.length; ++j)
  {
    writeln(to!string(frame_IN[j].date) ~ ": "~ to!string(frame_IN[j].price.open) ~ ", ", to!string(frame_IN[j].price.high) ~ ", " ~to!string(frame_IN[j].price.low) ~ ", " ~ to!string(frame_IN[j].price.close) ~ ", " ~ to!string(frame_IN[j].price.volume));
  }
}
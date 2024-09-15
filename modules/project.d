module safepine_core.project;

// D
import std.algorithm: find;
import std.array: array, replace; 
import std.conv: to;
import std.csv: csvReader;
import std.datetime.date: Date;
import std.datetime.systime: Clock, SysTime;
import std.datetime.stopwatch: StopWatch, AutoStart;
import std.file;
import std.json: JSONValue, parseJSON;
import std.mmfile;
import std.net.curl: CurlException, download, get;
import std.range;
import std.stdio: writeln, write;
import std.zip: ZipArchive, ZipException;

// Safepine
import safepine_core.backend.sqlinterface;
import safepine_core.math.matrix;
import safepine_core.math.statistics;
import safepine_core.pipelines.publicaccess;
import safepine_core.quantum.engine;

// Enter your key here for NASDAQ Data Link integration
// Currently supports EoD price data provided by them.
string NASDAQ_API_KEY = "";

/// Contains configuration elements from the config.json
struct ConfigurationProfile {
  Date[] scheduleItemDates;
  Matrix[] scheduleItemRatios;
  string[][] scheduleItemNames;
  string scheduleType;
  double initialDeposit;
  string[] assetNames;
  Date beginDate;
  Date endDate;
  string[5] dataProvider;
}

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

ConfigurationProfile ImportConfigurationProfile(string name_IN) 
{
  string raw = to!string(read(name_IN));
  ConfigurationProfile profile;
  JSONValue profile_json = parseJSON(raw);

  // Begin/End dates & watchlist items
  string[] watchlistSymbols;
  profile.beginDate = Date(to!int(to!string(profile_json["begin"]["year"])), to!int(to!string(profile_json["begin"]["month"])), to!int(to!string(profile_json["begin"]["day"])));
  profile.endDate = Date(to!int(to!string(profile_json["end"]["year"])), to!int(to!string(profile_json["end"]["month"])), to!int(to!string(profile_json["end"]["day"])));
  for(ulong k = 0; k < profile_json["watchlist"].array.length; ++k)
  {
    string unfiltered_symbol = to!string(profile_json["watchlist"][k]);
    watchlistSymbols ~= unfiltered_symbol.replace("\"", "");
  }

  // Portfolio
  ulong profile_length = profile_json["portfolio_schedule"]["asset_schedule"].array.length;
  profile.initialDeposit = to!double(to!string(profile_json["portfolio_schedule"]["initial_deposit"]));
  profile.scheduleType = to!string(profile_json["portfolio_schedule"]["type"]);
  profile.scheduleType = profile.scheduleType.replace("\"", "");

  // Add schedule for loop here.
  for(int i = 0; i < profile_length; ++i) {
    string currentDate_string = to!string(profile_json["portfolio_schedule"]["asset_schedule"].array[i]["date"]);
    profile.scheduleItemDates ~= Date(to!int(currentDate_string[1 .. 5]), to!int(currentDate_string[6 .. 8]), to!int(currentDate_string[9 .. 11]));
    ulong assets_length = profile_json["portfolio_schedule"]["asset_schedule"].array[i]["assets"].array.length;
    double[] assetRatio;
    string[] assetNames;
    for(int k = 0; k < assets_length; ++k) {
      string unfiltered_symbol = to!string(profile_json["portfolio_schedule"]["asset_schedule"].array[i]["assets"][k]["name"]);
      assetNames ~= unfiltered_symbol.replace("\"", "");
      assetRatio ~= to!double(to!string(profile_json["portfolio_schedule"]["asset_schedule"].array[i]["assets"][k][profile.scheduleType]));
    }
    profile.scheduleItemRatios ~= new Matrix(assetRatio);
    profile.scheduleItemNames ~= assetNames;
  }

  // Hacky way to merge input_profile (asset schedule)
  // & profile (watchlist) configurations
  for(int i = 0; i < profile.scheduleItemNames.length; ++i) {
    for(int j = 0; j < profile.scheduleItemNames[i].length; ++j) {
      if(find(watchlistSymbols, profile.scheduleItemNames[i][j]).empty) {
        watchlistSymbols ~= profile.scheduleItemNames[i][j];
      }
    }
  }
  profile.assetNames = watchlistSymbols;

  // Data provider
  profile.dataProvider[0] = to!string(profile_json["data_provider"]["content_1"]);
  profile.dataProvider[0] = profile.dataProvider[0].replace("\"", "");
  profile.dataProvider[0] = profile.dataProvider[0].replace("\\", "");
  profile.dataProvider[1] = to!string(profile_json["data_provider"]["content_2"]);
  profile.dataProvider[1] = profile.dataProvider[1].replace("\"", "");
  profile.dataProvider[1] = profile.dataProvider[1].replace("\\", "");
  profile.dataProvider[2] = to!string(profile_json["data_provider"]["content_3"]);
  profile.dataProvider[2] = profile.dataProvider[2].replace("\"", "");
  profile.dataProvider[2] = profile.dataProvider[2].replace("\\", "");
  profile.dataProvider[3] = to!string(profile_json["data_provider"]["content_4"]);
  profile.dataProvider[3] = profile.dataProvider[3].replace("\"", "");
  profile.dataProvider[3] = profile.dataProvider[3].replace("\\", "");
  profile.dataProvider[4] = to!string(profile_json["data_provider"]["content_5"]);
  profile.dataProvider[4] = profile.dataProvider[4].replace("\"", "");
  profile.dataProvider[4] = profile.dataProvider[4].replace("\\", "");
  return profile;
}

void DataAcquisition(
  string[] assetSymbols_IN, 
  Date begin_IN, 
  Date end_IN,
  string[5] dataProvider_IN,
  string cachePath_IN = "cache/")
{
  Public pipeline;
  string raw_data = "";
  for(int i = 0; i<assetSymbols_IN.length; ++i)
  {
    pipeline.Mine!(safepine_core.pipelines.publicaccess.logger.off)(begin_IN, end_IN, assetSymbols_IN[i], intervals.daily, dataProvider_IN, cachePath_IN);
    raw_data ~= pipeline.Write!(output.csv, safepine_core.pipelines.publicaccess.logger.off, string);
  }
  std.file.write(cachePath_IN~"all_data"~".csv", raw_data);
}

// Unzips a Quandl daily zip file. Saves to mysql uploads folder. NOT UNIT TESTED.
void SaveZip(string zipPath) {
  import std.file: write;
  writeln("[SaveZip] Unpacking data.");
  auto mmfile = new MmFile(zipPath);
  auto zipData = new ZipArchive(mmfile[]);
  string csvPath_to = "";
  foreach (name, am; zipData.directory) {
    writeln("[SaveZip] Name: ", name);
    writeln("[SaveZip] Size: ", am.expandedSize, " in bytes."); 
    version(Windows) {
      csvPath_to = "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/"~name;
    } else {
      csvPath_to = "/var/lib/mysql-files/"~name;
    }
    write(csvPath_to, zipData.expand(am));
    writeln("[SaveZip] Wrote daily data to: "~ csvPath_to ~"\n");
    remove(zipPath);
  }
} 

// Bulk data from Quandl and saves to mysql.
// Note that this EoD data is 4-5 gb uncompressed 
// and 1.2 gb compressed. 
// Execution can take couple of minutes.
void DownloadData() {
  auto clock = Clock.currTime();
  string downloaded_filename = "EOD.complete.zip";  
  char[] result = get("https://data.nasdaq.com/api/v3/datatables/QUOTEMEDIA/prices.csv?api_key="~NASDAQ_API_KEY~"&qopts.export=true&api_key="~NASDAQ_API_KEY);
  auto result_csv = result.csvReader(null);
  string quandl_request = result_csv.front.array[0];

  auto stop_watch = StopWatch(AutoStart.no);

  stop_watch.start();
  download(quandl_request, downloaded_filename);
  stop_watch.stop();
  writeln("[DownloadData] Time spent:", stop_watch.peek.total!"seconds", " [seconds].");  
}

module safepine_core.backend.sdf;

// D
import core.thread;
import std.algorithm: filter, endsWith, sort;
import std.array: array;
import std.conv: to;
import std.csv: csvReader;
import std.datetime: Date, DateTime;
import std.datetime.systime: Clock, SysTime;
import std.datetime.stopwatch: StopWatch, AutoStart;
import std.file; // FileException, read, remove, write
import std.mmfile;
import std.net.curl: CurlException, download, get;
import std.process: executeShell;
import std.stdio: writeln;
import std.typecons: tuple, Tuple; 
import std.zip: ZipArchive, ZipException;

// Third party
import mysql: ResultRange, Row;

// Safepine
import safepine_core.project;
import safepine_core.backend.mysqlhook: mysqlhook, mysql_connection;

// Safepine's Standard Data Format (sdf) class
// Price data for seperate users is contained
// and accessed via this class.
class sdf : mysqlhook {
  public:
    this(string databaseName_IN) {
      mysql_connection connection_information;
      
      connection_information.host = "host=127.0.0.1;";
      connection_information.port = "port=3306;";
      connection_information.user = "user=root;";
      connection_information.databaseName = databaseName_IN;
      _mainConnectionID = GenerateConnectionID();
      InitializeMysql(
        connection_information,
        _mainConnectionID); // from mysqlhook
    }

    // destroys table if it exists! returns number of lines. not sure what it returns :/
    ulong CreateUserTable(
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = 
      "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      DeleteUserTable(userName_IN, tableName_IN, connectionID_IN);
      return CreateTable(userName_IN~"_"~tableName_IN, standard_table_structure, connectionID_IN);
    }

    // destroys table if it exists! returns number of lines. not sure what it returns :/
    ulong CreateTickerTable(
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = 
      "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      DeleteTable(userName_IN~"_"~tableName_IN~"_ticker", connectionID_IN);
      return CreateTable(userName_IN~"_"~tableName_IN~"_ticker", standard_ticker_table_structure, connectionID_IN);
    }   

    // Deletes both price data and price meta data tables.
    ulong DeleteUserTable(
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      ulong result = DeleteTable(userName_IN~"_"~tableName_IN, connectionID_IN);
      DeleteTable(userName_IN~"_"~tableName_IN~"_meta", connectionID_IN);
      return result;
    } 

    // Creates and populates user price meta table.
    ulong LoadUserData(
      string userName_IN, 
      string tableName_IN, 
      string tableAddress_IN, 
      int mode,
      string connectionID_IN = "none")
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      ulong result = -1;
      auto stop_watch = StopWatch(AutoStart.no);
      stop_watch.start();
      if(mode == 0){
        result = LoadData_Small(
          userName_IN~"_"~tableName_IN, 
          tableAddress_IN, 
          standard_table_index_structure,
          connectionID_IN);
      }
      else if(mode == 1){
        result = LoadData_Big(
          userName_IN~"_"~tableName_IN, 
          tableAddress_IN, 
          standard_table_index_structure,
          connectionID_IN);
      }     
      GenerateMetatable(userName_IN, tableName_IN, connectionID_IN);
      stop_watch.stop();
      writeln("[LoadUserData] Time spent: ", stop_watch.peek.total!"seconds", " [seconds].");
      return result;
    }

    // Returns all ticker names from root_price_data_ticker
    Tuple!(string, string)[] Tickers(
      string userName_IN, 
      string tableName_IN,
      string connectionID_IN = "none") 
    {
      Tuple!(string, string)[] result = null; 
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      if(!DoesUserTableExist(userName_IN, tableName_IN)) return result;
      string command = "SELECT * from "~userName_IN~"_"~tableName_IN~";";
      ResultRange range = MySQLQuery(command, connectionID_IN);
      int index_in = 0;
      if(range.empty) return result;
      foreach (row; range) {
        Tuple!(string, string) element = 
          tuple(to!string(row[2]), to!string(row[0]));
        result~=element;
      }
      return result.sort().array;
    }

    // Returns true if user table exists
    bool DoesUserTableExist(
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      string command = "SHOW TABLES LIKE \"" ~ userName_IN ~"_"~ tableName_IN ~ "\";";
      ResultRange range = MySQLQuery(command, connectionID_IN);
      if(range.empty) return false;
      else return true;
    }

    // to a csv file
    bool ExportData(
      string userName_IN, 
      string tableName_IN, 
      string symbol_IN, 
      string connectionID_IN = "none")
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      bool check_table = DoesUserTableExist(userName_IN, tableName_IN, connectionID_IN);
      string rawText = "";
      string table_name = userName_IN ~"_"~ tableName_IN;
      string command = "select * from "~table_name~" where symbol=\""~symbol_IN~"\";";
      ResultRange range;
      if(check_table == false){
        return check_table;
      }
      range = MySQLQuery(command, connectionID_IN);
      if(range.empty) return false;

      foreach (row; range) {
        for (int i = 0; i<row.length; ++i){
          // ugly date conversion
          if(i == 1) {
            string s = DateTime.fromSimpleString(to!string(row[i])~" 00:00:00").toISOExtString();
            rawText ~= s[0 .. 10]; // terrible
          }   
          else {
            rawText ~= to!string(row[i]);
          }     
          
          rawText ~= ",";
        }
        rawText ~= "\n";
      }
      std.file.write(symbol_IN~"_from_"~table_name~".csv", rawText);
      return true;    
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

    // Same function as above, bad coding practice. Refactor later.
    void DownloadTickerData() {
      auto clock = Clock.currTime();
      string downloaded_filename = "EOD.ticker.zip";  
      string quandl_request = "";
      char[] result = get("https://data.nasdaq.com/api/v3/datatables/QUOTEMEDIA/tickers.csv?api_key="~NASDAQ_API_KEY~"&qopts.export=true&api_key="~NASDAQ_API_KEY);
      auto result_csv = result.csvReader(null);
      quandl_request = result_csv.front.array[0];
      auto stop_watch = StopWatch(AutoStart.no);
      stop_watch.start();
      download(quandl_request, downloaded_filename);
      stop_watch.stop();
      writeln("[DownloadMetaData] Time spent:", stop_watch.peek.total!"seconds", " [seconds].");  
    }

    // Unzips bulk data, which is 4-5 gigs, using 7zip.
    // Returns save path of the 7zip data
    string Unzip_7zip(string fileName_IN) {
      string save_path = "";
      string path_7z = "";
      string command_7z = " e ";
      string zip_file_destination = "\""~fileName_IN~"\"";

      // 7z path is platform dependent
      version(Windows) {
        path_7z = "\"C:\\Program Files\\7-Zip\\\"7z";
      }
      else {
        path_7z = "7z";
      }

      writeln("[Unzip_7zip] Execute: "~path_7z~command_7z~zip_file_destination);

      auto stop_watch = StopWatch(AutoStart.no);
      stop_watch.start();
      auto result = executeShell(path_7z~command_7z~zip_file_destination);
      auto csvFiles = dirEntries("", SpanMode.depth).filter!(f => f.name.endsWith(".csv"));
      writeln(result.output); 
      // Warning, this WONT work on folder with more than 1 csv files.    
      foreach (csv; csvFiles) {
          writeln("[Unzip_7zip] Save path: "~csv.name);   
          save_path = csv.name;   
      } 
      remove(fileName_IN); // delete downloaded file.
      stop_watch.stop();
      writeln("[Unzip_7zip] Time spent: ", stop_watch.peek.total!"seconds", " [seconds].");         
      return save_path;
    }

    // SDF 24/7 - mysql backend updates. Quandl only. NOT UNIT TESTED.
    void Run(
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      string downloaded_filename = "EOD.partial.zip";   

      auto last_day_clock = Clock.currTime() - 24.hours;
      auto clock = Clock.currTime();

      writeln("[Runner] Entering daily update loop, current time: ", clock);  
      while(true) {
          clock = Clock.currTime();

        // Update at 9pm local time.
        if( clock.hour >= 13) {
          if(!(clock.day == last_day_clock.day &&
             clock.month == last_day_clock.month && 
             clock.year == last_day_clock.year)) { // Make sure it's not the same date.
            writeln("[Runner] Daily update entered.\n");

            try{
              char[] result = get("https://data.nasdaq.com/api/v3/datatables/QUOTEMEDIA/dailyprices.csv?api_key="~NASDAQ_API_KEY~"&qopts.export=true&api_key="~NASDAQ_API_KEY);
              auto result_csv = result.csvReader(null);
              string quandl_request = result_csv.front.array[0];
              download(quandl_request, downloaded_filename);
              writeln("[Runner] Download ended.\n");
              UpdateTables(downloaded_filename, userName_IN, tableName_IN, connectionID_IN);
              SaveZip(downloaded_filename);
            }     
            catch (CurlException e){
              writeln("[Runner] Quandl partial download failed.");
              writeln(e.msg);
              remove(downloaded_filename);
            }

            last_day_clock = clock;
          }
        }
          Thread.sleep( 5.seconds ); // Reduces CPU usage significantly.
      }       
    }

  private:
    // Generates the meta table from the SDF table. Very slow. Takes 30 seconds to run on my dev laptop.
    void GenerateMetatable(
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      CreateTable(userName_IN~"_"~tableName_IN~"_meta ", standard_meta_table_structure, connectionID_IN);
      ResultRange range = MySQLQuery("select distinct symbol from "~userName_IN~"_"~tableName_IN~";", connectionID_IN);
      Row[] result_array = range.array;
      foreach(row; result_array) {
        // "ticker" returns 0000-00-00 and mysql throws and error complaining 0 is not a valid month
        if(row[0] != "ticker"){
          range = MySQLQuery("select min(date) from "~userName_IN~"_"~tableName_IN~" where symbol=\"" ~ to!string(row[0]) ~ "\"", connectionID_IN); 
          Row[] min_array = range.array;
          range = MySQLQuery("select max(date) from "~userName_IN~"_"~tableName_IN~" where symbol=\"" ~ to!string(row[0]) ~ "\"", connectionID_IN);
          Row[] max_array = range.array;    
          string dmin = DateTime.fromSimpleString(to!string(min_array[0][0])~" 00:00:00").toISOExtString();
          string dmax = DateTime.fromSimpleString(to!string(max_array[0][0])~" 00:00:00").toISOExtString();
          string row_s = "(\""~to!string(row[0])~"\",\""~dmin[0 .. 10]~"\",\""~dmax[0 .. 10]~"\")";     
          MySQLExec("INSERT INTO "~userName_IN~"_"~tableName_IN~"_meta (symbol,beginDate,endDate) VALUES "~row_s, connectionID_IN);         
        }
      }
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

    // Update price and price meta tables. NOT UNIT TESTED.
    void UpdateTables(
      string zipPath, 
      string userName_IN, 
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      auto stop_watch = StopWatch(AutoStart.no);
      auto zipData = new ZipArchive(read(zipPath));
      string metatable_name = userName_IN~"_"~tableName_IN~"_meta";

      foreach (name, am; zipData.directory) {
        string rawtext = cast(string)zipData.expand(am);

        auto records = rawtext.csvReader!quandl_row_layout(',');
        ulong number_of_rows_written = 0;
        ulong number_of_meta_rows_written = 0;
        ulong row_no = 0;

        bool[string] is_updated; // hash map to remember if symbol was updated.

        foreach (record; records) {
          string frame_string = "(\""~
            record.symbol~"\","~
            record.date~","~
            record.open~","~
            record.high~","~
            record.low~","~
            record.close~","~
            record.volume~","~
            record.dividend~","~
            record.split~","~
            record.adj_open~","~
            record.adj_high~","~
            record.adj_low~","~
            record.adj_close~","~
            record.adj_volume~")";

          // Update price date

          // Rules for Nasdaq Data Link Partial updates
          if(row_no == 0) {
            row_no++; //Skip first line
            continue; 
          }
          // Skip if record symbol was seen before
          if(record.symbol in is_updated) continue;
          else is_updated[record.symbol] = true;
          
          number_of_rows_written += MySQLExec("INSERT INTO "~userName_IN~"_"~tableName_IN~" "~standard_table_insert_structure~" VALUES "~frame_string, connectionID_IN);
          // Update meta data
          // Should be called after a daily update routine
          //string dmax = record.date.toISOExtString(); // 2021-Oct-08, from Arche
          string dmax = record.date; // 2021-10-08
          number_of_meta_rows_written += MySQLExec(
            "UPDATE "~metatable_name~
            " SET endDate=\""~dmax~
            "\" WHERE symbol=\""~record.symbol~"\";", connectionID_IN);

          row_no++;
        }
        stop_watch.stop();
        writeln("[UpdateTables] Updating daily price took ", stop_watch.peek.total!"seconds", " [seconds].");
        writeln("[UpdateTables] "~to!string(number_of_rows_written)~" no of price rows were written.");
        writeln("[UpdateTables] "~to!string(number_of_meta_rows_written)~" no of price rows were written.");
        stop_watch.reset();

        number_of_rows_written = 0;
        number_of_meta_rows_written = 0;
      }
    }   

    // Compatible with Quandl EoD and csv output from YahooFinanceD
    const string standard_meta_table_structure = 
      "(
      symbol VARCHAR(255) NOT NULL, 
      beginDate VARCHAR(255), 
      endDate VARCHAR(255)
      )";

    const string standard_ticker_table_structure = 
      "(
      ticker VARCHAR(255) NOT NULL, 
      exchange VARCHAR(255) NOT NULL, 
      name VARCHAR(255)
      )";

    const string standard_table_structure = 
      "(
      symbol VARCHAR(255) NOT NULL,
      date DATE,
      open DOUBLE,
      high DOUBLE,
      low DOUBLE,
      close DOUBLE,
      volume DOUBLE,
      dividend DOUBLE,
      split DOUBLE,
      adjopen DOUBLE,
      adjhigh DOUBLE,
      adjlow DOUBLE,
      adjclose DOUBLE,
      adjvolume DOUBLE    
      )";

    const string standard_table_insert_structure = 
      "(
      symbol, 
      date, 
      open, 
      high, 
      low, 
      close,
      volume,
      dividend,
      split,
      adjopen,
      adjhigh,
      adjlow,
      adjclose,
      adjvolume
      )";

    // Index structure for faster queries in larger databases
    const string standard_table_index_structure = " (symbol, date)";

    struct quandl_row_layout {
      string symbol;
      string date;
      string open;
      string high;
      string low;
      string close;
      string volume;
      string dividend;
      string split;
      string adj_open;
      string adj_high;
      string adj_low;
      string adj_close;
      string adj_volume;
    }
}
module safepine_core.backend.mysqlhook;

// D
import std.array : array;
import std.base64: Base64;
import std.conv: to;
import std.file: exists, readText, copy, remove;
import std.string: lineSplitter;
import std.stdio: write, writeln;
import std.random: unpredictableSeed, Random;
import std.datetime.stopwatch;

// Third party
import mysql: Connection, exec, ResultRange, query;

struct mysql_connection {
  string host; 
  string port; 
  string user;
  string pass;
  string databaseName;
}

enum string NOT_CONNECTED = "-1";

// Wraps around mysql-native with helper functions for Safepine's business
class mysqlhook {
  public:
    // InitializeMysql: binds to server using infosec credentials. Creates the database from input if not exists.
    // Input:
    //    connectionInformation_IN    : Server info struct
    //    connectionID_IN         : String, id of the current connection
    void InitializeMysql(mysql_connection connectionInformation_IN, string connectionID_IN) {
      // Generate connection string
      string connectionStr = connectionInformation_IN.host~connectionInformation_IN.port~connectionInformation_IN.user~connectionInformation_IN.pass;
      if(exists("infosec")) {
        if(lineSplitter(readText("infosec")).array.length == 1) {
          string[1] s = lineSplitter(readText("infosec")).array;
          connectionStr = connectionInformation_IN.host~connectionInformation_IN.port~"user="~s[0];
        }       
        else if(lineSplitter(readText("infosec")).array.length == 2) {
          string[2] s = lineSplitter(readText("infosec")).array;
          connectionStr = connectionInformation_IN.host~connectionInformation_IN.port~"user="~s[0]~";pwd="~s[1];          
        }
        else if(lineSplitter(readText("infosec")).array.length == 3) {
          string[3] s = lineSplitter(readText("infosec")).array;
          connectionStr = connectionInformation_IN.host~connectionInformation_IN.port~"user="~s[0]~";pwd="~s[1];          
          _magic = s[2];
        }       
      }

      // Handle connection
      _conn[connectionID_IN] = new Connection(connectionStr);

      ResultRange oneAtATime = MySQLQuery("SHOW DATABASES LIKE " ~ "'" ~ connectionInformation_IN.databaseName ~ "'", connectionID_IN);
      if(oneAtATime.empty) {
        MySQLExec("CREATE DATABASE IF NOT EXISTS " ~ connectionInformation_IN.databaseName, connectionID_IN); 
      }

      // Use given database
      MySQLExec("USE " ~ connectionInformation_IN.databaseName ~ ";", connectionID_IN);   
    } 

    // Close: wrapper for the mysql native close
    // Input: 
    //    connectionID_IN         : String, id of the current connection
    void Close(string connectionID_IN = "none") {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;

      _conn[connectionID_IN].close();
    }

    // MySQLQuery: makes a query to mysql with timer.
    // Input:
    //    query_IN            : String 
    //    connectionID_IN         : String, id of the current connection
    // Returns:
    //    resultRange           : Result from mysql 
    ResultRange MySQLQuery(
      string query_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      if(_debugger) 
      {
        write("\u001b[33m[MySQLQuery] Command: \033[0m");
        writeln(query_IN);
      }

      _numberOfMysqlCalls += 1; // Increment call number  
      auto myStopWatch = StopWatch(AutoStart.no); // Create and start watch   
      myStopWatch.start();

      ResultRange range  = _conn[connectionID_IN].query(query_IN);

      myStopWatch.stop();
      _totalMysqlCallTime += to!double(myStopWatch.peek.total!"usecs"); // Count total time and reset.
      myStopWatch.reset();

      if(_debugger)
      {
        if(range.empty)
          writeln("\u001b[31m[MySQLQuery] Result: Empty range \033[0m");
        else
          writeln("\u001b[32m[MySQLQuery] Result: Success \033[0m");
      }

      return range;
    }

    // MySQLExec: makes a qcall to mysql with timer.
    // Input:
    //    exec_IN             : String 
    //    connectionID_IN         : String, id of the current connection
    // Returns:
    //    ulong               : Result from mysql 
    ulong MySQLExec(
      string exec_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      if(_debugger) 
      {
        write("\u001b[33m[MySQLExec] Command: \033[0m");
        writeln(exec_IN);
      }

      _numberOfMysqlCalls += 1; // Increment call number      
      auto myStopWatch = StopWatch(AutoStart.no); // Create and start watch 
      myStopWatch.start();

      ulong res = _conn[connectionID_IN].exec(exec_IN);
      if(_debugger)
      {
        if(res < 0)
          writeln("\u001b[31m[MySQLExec] Result: Error \033[0m");
        else
          writeln("\u001b[32m[MySQLExec] Result: Success \033[0m");
      }

      myStopWatch.stop();
      _totalMysqlCallTime += to!double(myStopWatch.peek.total!"usecs"); // Count total time and reset.
      myStopWatch.reset();        
      return res;
    } 

    // Performance: Mysql performance metrics from the engine
    // Returns:
    //    perfVector            : [0] Number of mysql calls, [1] Total mysql call time. All in ms.      
    double[2] Performance() pure {
      return [_numberOfMysqlCalls, _totalMysqlCallTime];
    }

    // CreateTable: creates a table given its name and column structure
    // Input:
    //    tableName_IN          : Table name
    //    tableStructure_IN       : Table structure
    //    connectionID_IN         : String
    ulong CreateTable(
      string tableName_IN, 
      string tableStructure_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      return MySQLExec("CREATE TABLE IF NOT EXISTS " ~ tableName_IN ~ tableStructure_IN ~ ";", connectionID_IN);  
    }

    // DeleteTable: Deletes the table
    // Input:
    //    tableName_IN          : Table to be deleted
    //    connectionID_IN         : String
    ulong DeleteTable(
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      return MySQLExec("DROP TABLE IF EXISTS "~tableName_IN, connectionID_IN);
    }

    // DeleteDatabase: Deletes the database. WARNING: It really deletes the whole database with all tables.
    // Input:
    //    databaseName_IN         : Database to be deleted
    //    connectionID_IN         : String
    ulong DeleteDatabase(
      string databaseName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      return MySQLExec("DROP DATABASE IF EXISTS " ~ databaseName_IN, connectionID_IN);
    }

    // LoadData: A fast, cross-platform (Ubuntu+Windows) function to dump csv data and optimize it for time series access
    // Input:
    //    tableName_IN          : Table to add data
    //    csvPath_from_IN         : Path of the data csv file.
    //    connectionID_IN         : String
    // NOT UNIT TESTED
    ulong LoadData_Big(
      string tableName_IN, 
      string csvPath_from_IN, 
      string index_structure_IN = "none", 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;

      string csvPath_to = "";
      string skip_header = "";

      // Secure file priv storage locations for Ubuntu and Windows
      version(Windows) {
        csvPath_to = "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/"~csvPath_from_IN;
      } else {
        csvPath_to = "/var/lib/mysql-files/"~csvPath_from_IN;
        skip_header = " IGNORE 1 LINES"; // Header needs to be skipped on Ubuntu/mysql
      }

      // Copy current data to uploads
      csvPath_from_IN.copy(csvPath_to);
      remove(csvPath_from_IN);

      // Load data
      string loaderString = 
        "LOAD DATA INFILE \'"~csvPath_to~
        "\' INTO TABLE "~tableName_IN~
        " FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\\n'";
      loaderString ~= skip_header;
      ulong rowsAffected = MySQLExec(loaderString, connectionID_IN);
      // Create an index over time series data so queries are optimized.
      // https://stackoverflow.com/questions/22101954/best-indexing-strategy-for-time-series-in-a-mysql-database-with-timestamps
      if(index_structure_IN != "none")
        MySQLExec("create index indexedprice on "~tableName_IN~index_structure_IN, connectionID_IN);

      return rowsAffected;
    }

    // LoadData: A fast, cross-platform (Ubuntu+Windows) function to dump csv data and optimize it for time series access
    // Input:
    //    tableName_IN          : Table to add data
    //    csvPath_from_IN         : Path of the data csv file.
    //    connectionID_IN         : String
    ulong LoadData_Small(
      string tableName_IN, 
      string csvPath_from_IN, 
      string index_structure_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;

      string csvPath_to = "";

      // Secure file priv storage locations for Ubuntu and Windows
      version(Windows) {
        csvPath_to = "C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/"~tableName_IN~".csv";
      } else {
        csvPath_to = "/var/lib/mysql-files/"~tableName_IN~".csv";
      }

      // Copy current data to uploads
      csvPath_from_IN.copy(csvPath_to);

      // Load data
      string loaderString = "LOAD DATA INFILE \'"~csvPath_to~"\' INTO TABLE "~tableName_IN~" FIELDS TERMINATED BY ',' LINES TERMINATED BY '\\n'";
      ulong rowsAffected = MySQLExec(loaderString, connectionID_IN);

      // Create an index over time series data so queries are optimized.
      // https://stackoverflow.com/questions/22101954/best-indexing-strategy-for-time-series-in-a-mysql-database-with-timestamps
      MySQLExec("create index indexedprice on "~tableName_IN~index_structure_IN, connectionID_IN);

      return rowsAffected;
    }   

    // GetColumnNames: gets all columns names
    // Input:
    //    tableName_IN          : Table to get columns names
    //    connectionID_IN         : String, id of the current connection
    // Returns:
    //    string[]            : String array with column names
    string[] GetColumnNames(
      string tableName_IN, 
      string connectionID_IN = "none") 
    {
      if(connectionID_IN == "none") connectionID_IN = _mainConnectionID;
      
      string query = "SHOW COLUMNS FROM "~tableName_IN~";";
      string[] columns;
      ResultRange oneAtATime = MySQLQuery(query, connectionID_IN);
      foreach (row; oneAtATime) {
        columns ~= to!string(row[0]);
      }
      return columns;
    }

    string GenerateConnectionID() {
      return to!string(Random(unpredictableSeed).front);
    }

    string MainConnectionID() {
      return _mainConnectionID;
    }

    string Magic() {
      return _magic;
    }

  protected:
    string _mainConnectionID;         // Connection ID of the thread that constructs the hook.

  private:
    Connection[string] _conn;       // Holds the thread's mysql connection
    double _numberOfMysqlCalls = 0.0;     // Performance: Total numberof mysql inqueries.
    double _totalMysqlCallTime = 0.0;     // Performance: Total time spent on mysql inqueires in [us]   
    bool _debugger = false;
    string _magic = "";
}
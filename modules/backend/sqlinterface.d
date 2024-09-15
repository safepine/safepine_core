module safepine_core.backend.sqlinterface;

// D
import std.algorithm: sort;
import std.array : array, replace;
import std.base64: Base64;
import std.conv: to;
import std.datetime: Date, DateTime;
import std.datetime.stopwatch;
import std.file;
import std.json: JSONValue, parseJSON;
import std.string: lineSplitter;
import std.stdio: write, writeln;
import std.random: unpredictableSeed, Random;
import std.typecons: tuple, Tuple; 

// Third party
import mysql;
import sqlite3d;

/***********************************
 * Safepine's sql integration class
 * MySQL: For server applications
 * SQLite: For desktop applications
 */
class sqlinterface(driver T) {
public:
/***********************************
 * Constructor: For derived classes
 */
this()
{
  // ////// Temporary place for sqlite injection \\\\\\
  sqlite3 *db;
  int rc;
  rc = sqlite3_open("safepine_database.db", &db);
  if( rc ){
    writeln("Can't open database: " ~ to!string(sqlite3_errmsg(db)));
    sqlite3_close(db);
  }
  // \\\\\\ Temporary place for sqlite injection //////

  m_connectionInformation.host = "host=127.0.0.1;";
  m_connectionInformation.port = "port=3306;";
  m_connectionInformation.user = "user=root;";
  m_connectionInformation.databaseName = "safepine_database";
  m_mainConnectionID = GenerateConnectionID();
  ConnectSQL(
    m_connectionInformation,
    m_mainConnectionID);
}

/***********************************
 * Summary: Connect to SQL & create 
 * the database from input if not exists.
 * Params:
 *    connectionInformation_IN = Server info struct
 *    connectionID_IN = String, id of the current connection
 *    
 */
void ConnectSQL(driver val = T)(
  mysql_connection  connectionInformation_IN,
  string            connectionID_IN)
{
  ConnectSQL_Impl!val(
    connectionInformation_IN, 
    connectionID_IN);
}

/***********************************
 * Summary: Mysql driver
 * Params:
 *    connectionInformation_IN = Server info struct
 *    connectionID_IN = String, id of the current connection
 *    
 */
void ConnectSQL_Impl(driver val)(
  mysql_connection  connectionInformation_IN, 
  string            connectionID_IN)
  if(val == driver.mysql)
{
  // Generate connection string
  string connectionStr = connectionInformation_IN.host~connectionInformation_IN.port~connectionInformation_IN.user~connectionInformation_IN.pass;
  if(exists("config.json")) {
    string raw = to!string(read("config.json"));
    JSONValue profile_json = parseJSON(raw);
    string[2] s;
    s[0] = to!string(profile_json["mysql"]["username"]);
    s[0] = s[0].replace("\"", "");
    s[1] = to!string(profile_json["mysql"]["password"]);
    s[1] = s[1].replace("\"", "");

    connectionStr = connectionInformation_IN.host~connectionInformation_IN.port~"user="~s[0]~";pwd="~s[1]; 
  }

  // Handle connection
  m_conn[connectionID_IN] = new Connection(connectionStr);

  ResultRange oneAtATime = Query("SHOW DATABASES LIKE " ~ "'" ~ connectionInformation_IN.databaseName ~ "'", connectionID_IN);
  if(oneAtATime.empty) {
    Exec("CREATE DATABASE IF NOT EXISTS " ~ connectionInformation_IN.databaseName, connectionID_IN); 
  }

  // Use given database
  Exec("USE " ~ connectionInformation_IN.databaseName ~ ";", connectionID_IN);
}

/***********************************
 * Summary: SQLite driver
 * Params:
 *    connectionInformation_IN = Server info struct
 *    connectionID_IN = String, id of the current connection
 *    
 */
void ConnectSQL_Impl(driver val)(
  mysql_connection  connectionInformation_IN, 
  string            connectionID_IN)
  if(val == driver.sqlite)
{
  int rc;
  rc = sqlite3_open(connectionInformation_IN.databaseName~".db", &m_db);
  if( rc ){
    writeln("Can't open database: " ~ to!string(sqlite3_errmsg(m_db)));
    sqlite3_close(m_db);
  }
}

void InitializeSafepineCoreBackend(string dataPath)
{
  DropTable("safepine_core_prices");
  DropTable("safepine_core_prices_meta");
  CreateTable("safepine_core_prices", PriceStructure);

  ulong dummy;
  dummy = LoadData(
    "safepine_core", // username
    "prices", // tablename
    dataPath,
    0);
  writeln("[InitializeSafepineCoreBackend]: Total lines of mysql rows written: "~to!string(dummy));
}

/***********************************
 * Summary: Close template
 * Params:
 *    connectionID_IN = String, id of the current connection
 *    
 */
void Close(driver val = T)(
  string connectionID_IN = "none")
{
  Close_Impl!val(connectionID_IN);
}

/***********************************
 * Summary: Wrapper for the mysql native close
 * Params:
 *    connectionID_IN = String, id of the current connection
 *    
 */
void Close_Impl(driver val)(
  string connectionID_IN = "none")
  if(val == driver.mysql)
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  m_conn[connectionID_IN].close();
}

/***********************************
 * Summary: SQLite close wrapper
 * Params:
 *    connectionID_IN = String, id of the current connection
 *    
 */
void Close_Impl(driver val)(
  string connectionID_IN = "none")
  if(val == driver.sqlite)
{
  sqlite3_close(m_db);
}

/***********************************
 * Summary: Creates a table given its name and column structure
 * Params:
 *    tableName_IN = Table name
 *    tableStructure_IN = Table structure
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    ulong: Result from mysql 
 *    
 */
ulong CreateTable(
  string tableName_IN, 
  string tableStructure_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  return Exec("CREATE TABLE IF NOT EXISTS " ~ tableName_IN ~ tableStructure_IN ~ ";", connectionID_IN);  
}

/***********************************
 * Summary: Deletes the table
 * Params:
 *    tableName_IN = Table to be deleted
 *    connectionID_IN = String, id of the current connection
 */
ulong DropTable(
  string tableName_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  return Exec("DROP TABLE IF EXISTS "~tableName_IN, connectionID_IN);
}

/***********************************
 * Summary: Checks if table exists
 * Params:
 *    userName_IN = Users name
 *    tableName_IN = Users tables name
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    bool: True if exists
 *    
 */
bool FindTable(
  string userName_IN, 
  string tableName_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  string command = "SHOW TABLES LIKE \"" ~ userName_IN ~"_"~ tableName_IN ~ "\";";
  ResultRange range = Query(command, connectionID_IN);
  if(range.empty) return false;
  else return true;
}

/***********************************
 * Summary: Deletes the database. 
 * WARNING: It really deletes the whole database with all tables.
 * Params:
 *    databaseName_IN = Database to be deleted
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    ulong: Result from mysql
 *    
 */
ulong DropDatabase(
  string databaseName_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  return Exec("DROP DATABASE IF EXISTS " ~ databaseName_IN, connectionID_IN);
}

/***********************************
 * Summary: Wraps around 
 * LoadData_Small/Large data functions
 * and generates meta table from the loaded set.
 * Params:
 *    userName_IN = Users name
 *    tableName_IN = Users tables name
 *    tableAddress_IN = Path
 *    mode  = Selects between small/large functions
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    ulong: Result from mysql 
 *    
 */
ulong LoadData(
  string userName_IN, 
  string tableName_IN, 
  string tableAddress_IN, 
  int mode,
  string connectionID_IN = "none")
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  ulong result = -1;
  auto stop_watch = StopWatch(AutoStart.no);
  stop_watch.start();
  if(mode == 0){
    result = LoadData_Small(
      userName_IN~"_"~tableName_IN, 
      tableAddress_IN, 
      m_indexStructure,
      connectionID_IN);
  }
  else if(mode == 1){
    result = LoadData_Big(
      userName_IN~"_"~tableName_IN, 
      tableAddress_IN, 
      m_indexStructure,
      connectionID_IN);
  }     
  GenerateMetatable(userName_IN, tableName_IN, connectionID_IN);
  stop_watch.stop();
  writeln("[LoadUserData] Time spent: ", stop_watch.peek.total!"seconds", " [seconds].");
  return result;
}

/***********************************
 * Summary: Random number assigned to 
 * a mysql connection to enable 
 * concurrent access to the database
 */
string GenerateConnectionID() 
{
  return to!string(Random(unpredictableSeed).front);
}

/***********************************
 * Summary: Persistent ID, gets 
 * assigned at construction
 */
string MainConnectionID() 
{
  return m_mainConnectionID;
}

/***********************************
 * Summary: Table structure for 
 * holding OHLC price data
 */
string PriceStructure() 
{
  return m_priceStructure;
}

/***********************************
 * Summary: Mysql performance metrics
 * Returns:
 *    perfVector: [0] Number of mysql calls, [1] Total mysql call time. All in ms.
 *    
 */  
double[2] Performance() pure 
{
  return [m_numberOfMysqlCalls, m_totalMysqlCallTime];
}

/***********************************
 * Summary: Mysql connection information
 * as mysql_connection struct. This can
 * be used to initialize mysql connection.
 */ 
pure mysql_connection ConnectionInformation() 
{
  return m_connectionInformation;
}

protected:
/***********************************
 * Summary: Makes a query to sql
 * callbacks speeds are measured
 * with a timer.
 * Params:
 *    query_IN = String 
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    resultRange: Result from sql 
 *    
 */
ResultRange Query(driver val = T)(
  string query_IN,
  string connectionID_IN = "none")
{
  return Query_Impl!val(
    query_IN, 
    connectionID_IN);
}

/***********************************
 * Summary: Mysql implementation
 * of the Query call.
 * Params:
 *    query_IN = String 
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    resultRange: Result from sql 
 *    
 */
ResultRange Query_Impl(driver val)(
  string query_IN,
  string connectionID_IN = "none")
  if(val == driver.mysql)
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  if(m_debugger) 
  {
    write("\u001b[33m[Query] Command: \033[0m");
    writeln(query_IN);
  }

  m_numberOfMysqlCalls += 1; // Increment call number  
  auto myStopWatch = StopWatch(AutoStart.no); // Create and start watch   
  myStopWatch.start();

  ResultRange range  = m_conn[connectionID_IN].query(query_IN);

  myStopWatch.stop();
  m_totalMysqlCallTime += to!double(myStopWatch.peek.total!"usecs"); // Count total time and reset.
  myStopWatch.reset();

  if(m_debugger)
  {
    if(range.empty)
      writeln("\u001b[31m[Query] Result: Empty range \033[0m");
    else
      writeln("\u001b[32m[Query] Result: Success \033[0m");
  }

  return range;
}

/// Connection ID of the thread that constructs the hook.
string m_mainConnectionID;

private:
/***********************************
 * Summary: Generates the meta table 
 * from the table. Can be slow if 
 * worked on 1-5 gigs of data. 
 * Takes 30 seconds to run on my dev laptop.
 * Params:
 *    userName_IN = Users name
 *    tableName_IN = Users tables name
 *    connectionID_IN = String, id of the current connection
 *    
 */
void GenerateMetatable(
  string userName_IN, 
  string tableName_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  CreateTable(userName_IN~"_"~tableName_IN~"_meta ", m_metaStructure, connectionID_IN);
  ResultRange range = Query("select distinct symbol from "~userName_IN~"_"~tableName_IN~";", connectionID_IN);
  Row[] result_array = range.array;
  foreach(row; result_array) {
    // "ticker" returns 0000-00-00 and mysql throws and error complaining 0 is not a valid month
    if(row[0] != "ticker"){
      range = Query("select min(date) from "~userName_IN~"_"~tableName_IN~" where symbol=\"" ~ to!string(row[0]) ~ "\"", connectionID_IN); 
      Row[] min_array = range.array;
      range = Query("select max(date) from "~userName_IN~"_"~tableName_IN~" where symbol=\"" ~ to!string(row[0]) ~ "\"", connectionID_IN);
      Row[] max_array = range.array;    
      string dmin = DateTime.fromSimpleString(to!string(min_array[0][0])~" 00:00:00").toISOExtString();
      string dmax = DateTime.fromSimpleString(to!string(max_array[0][0])~" 00:00:00").toISOExtString();
      string row_s = "(\""~to!string(row[0])~"\",\""~dmin[0 .. 10]~"\",\""~dmax[0 .. 10]~"\")";     
      Exec("INSERT INTO "~userName_IN~"_"~tableName_IN~"_meta (symbol,beginDate,endDate) VALUES "~row_s, connectionID_IN);         
    }
  }
}

/***********************************
 * Summary: Makes exec call to sql
 * callbacks speeds are measured
 * with a timer.
 * Params:
 *    exec_IN = String 
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    uLong: Number of rows written
 *    
 */
ulong Exec(driver val = T)(
  string exec_IN,
  string connectionID_IN = "none")
{
  return Exec_Impl!val(
    exec_IN, 
    connectionID_IN);  
}

/***********************************
 * Summary: Mysql implementation of
 * the exec call.
 * Params:
 *    exec_IN = String 
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    ulong: Number of rows written
 *    
 */
ulong Exec_Impl(driver val)(
  string exec_IN, 
  string connectionID_IN = "none")
  if(val == driver.mysql)
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;
  if(m_debugger) 
  {
    write("\u001b[33m[Exec] Command: \033[0m");
    writeln(exec_IN);
  }

  m_numberOfMysqlCalls += 1; // Increment call number      
  auto myStopWatch = StopWatch(AutoStart.no); // Create and start watch 
  myStopWatch.start();

  ulong res = m_conn[connectionID_IN].exec(exec_IN);
  if(m_debugger)
  {
    if(res < 0)
      writeln("\u001b[31m[Exec] Result: Error \033[0m");
    else
      writeln("\u001b[32m[Exec] Result: Success \033[0m");
  }

  myStopWatch.stop();
  m_totalMysqlCallTime += to!double(myStopWatch.peek.total!"usecs"); // Count total time and reset.
  myStopWatch.reset();        
  return res;
}

/***********************************
 * Summary: A fast, cross-platform (Ubuntu+Windows) function to dump csv data 
 * and optimize it for time series access. LARGE Sized Data 1-5 gigs.
 * Params:
 *    tableName_IN = Table to add data
 *    csvPath_from_IN = Path of the data csv file.
 *    index_structure_IN = Table index
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    ulong: Result from mysql 
 *    
 */
ulong LoadData_Big(
  string tableName_IN, 
  string csvPath_from_IN, 
  string index_structure_IN = "none", 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

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
  ulong rowsAffected = Exec(loaderString, connectionID_IN);
  // Create an index over time series data so queries are optimized.
  // https://stackoverflow.com/questions/22101954/best-indexing-strategy-for-time-series-in-a-mysql-database-with-timestamps
  if(index_structure_IN != "none")
    Exec("create index indexedprice on "~tableName_IN~index_structure_IN, connectionID_IN);

  return rowsAffected;
}

/***********************************
 * Summary: A fast, cross-platform (Ubuntu+Windows) function to dump csv data 
 * and optimize it for time series access. SMALL Sized Data 1-100 mbs.
 * Params:
 *    tableName_IN = Table to add data
 *    csvPath_from_IN = Path of the data csv file.
 *    index_structure_IN = Table index
 *    connectionID_IN = String, id of the current connection
 * Returns:
 *    ulong: Result from mysql 
 *    
 */
ulong LoadData_Small(
  string tableName_IN, 
  string csvPath_from_IN, 
  string index_structure_IN, 
  string connectionID_IN = "none") 
{
  if(connectionID_IN == "none") connectionID_IN = m_mainConnectionID;

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
  ulong rowsAffected = Exec(loaderString, connectionID_IN);

  // Create an index over time series data so queries are optimized.
  // https://stackoverflow.com/questions/22101954/best-indexing-strategy-for-time-series-in-a-mysql-database-with-timestamps
  Exec("create index indexedprice on "~tableName_IN~index_structure_IN, connectionID_IN);

  return rowsAffected;
}

/// Holds the thread's mysql connection
Connection[string] m_conn;

/// SQLite pointer
sqlite3 *m_db;

/// Performance: Total numberof mysql inqueries.
double m_numberOfMysqlCalls = 0.0;

/// Performance: Total time spent on mysql inqueires in [us]   
double m_totalMysqlCallTime = 0.0;

/// Flag to enable debugging
bool m_debugger = false;

/// Mysql connection info
mysql_connection m_connectionInformation;

/// Table structure for prices
const string m_priceStructure = 
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

/// Table structure for meta data of prices
const string m_metaStructure = 
  "(
  symbol VARCHAR(255) NOT NULL, 
  beginDate VARCHAR(255), 
  endDate VARCHAR(255)
  )";

/// Index structure for faster queries in larger databases
const string m_indexStructure = " (symbol, date)";
}

/// Holds mysql connection information
struct mysql_connection {
  string host, port, user, pass, databaseName; 
}

/// SQL interface drivers
enum driver {mysql, sqlite}

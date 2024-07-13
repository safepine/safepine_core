module safepine_core.quantum.prices;

// D
import core.time: days; 
import std.datetime;
import std.algorithm: max, min, reduce;
import std.array: array, replace; 
import std.conv: to; 
import std.datetime.date: Date, DayOfWeek, Month;
import std.json: JSONValue, parseJSON;
import std.file; // write 
import std.math: abs;
import std.range: iota;
import std.stdio: write, writeln;
import std.typecons: tuple;

// Safepine
import safepine_core.quantum.engine;
import safepine_core.quantum.stash;
import safepine_core.backend.mysqlhook: mysqlhook, mysql_connection, NOT_CONNECTED; 

// Third party
import mysql: ResultRange, Row;

/***********************************
 * Safepine's price access class. Allows
 * programmatic access to price time
 * series in the database.
 */
class Prices : mysqlhook {
/***********************************
 * Constructor: Constructs the price class
 * Params:
 *      connectionInformation_IN = mysql configuration
 * 		  engineDataFormat_IN = Price, meta tables and their format
 */
this(
	mysql_connection connectionInformation_IN, 
	engine_data_format engineDataFormat_IN) 
{
	_engineDataFormat.metatablename = engineDataFormat_IN.metatablename;
	_engineDataFormat.pricetablename = engineDataFormat_IN.pricetablename;	
	_engineDataFormat.datecolumn = "date";
	_engineDataFormat.symbolcolumn = "symbol";
	_engineDataFormat.mysqlopenindex = 2;
	_engineDataFormat.mysqlhighindex = 3;
	_engineDataFormat.mysqllowindex = 4;
	_engineDataFormat.mysqlcloseindex = 5;
	_engineDataFormat.mysqldividendindex = 7; 
	_engineDataFormat.mysqlsplitindex = 8;
	_engineDataFormat.metasymbolindex = 0;
	_engineDataFormat.metabeginindex = 1;
	_engineDataFormat.metaendindex = 2;

	_connectionInformation = connectionInformation_IN;

	// Call this AFTER mysql connection
	InitializeMetaData();
}

/***********************************
 * Summary: Returns price as frame from to until dates
 * Params:
 * 		symbol_IN = Asset in the database.
 * 		from_IN = start date
 * 		until_IN = end date
 * Returns:
 * 		asset_price: frame
 */	
Frame get(
	string symbol_IN, 
	Date from_IN,
	Date until_IN) 
{
	Frame result;
	string command;
	command = "
	SELECT * FROM " ~
		_engineDataFormat.pricetablename ~ 
	" WHERE symbol=\"" ~ 
		symbol_IN ~ 
	"\" AND date BETWEEN \"" ~ 
		from_IN.toISOExtString() ~ 
	"\" AND \"" ~
		until_IN.toISOExtString() ~ 
	"\"";
	Connect();
	auto range = MySQLQuery(command);
	result.name = symbol_IN;
	foreach(row; range)
	{
		result.dateArray ~= Date.fromSimpleString(to!string(row[1]));
		result.valueArray ~= to!double(to!string(row[this._engineDataFormat.mysqlcloseindex]));
	}
	Disconnect();
	return result;
}

// UPDATE QUERY TO FOLLOWING
// SELECT * FROM dummy_price_data WHERE symbol="KL"AND date <= "2018-08-25" ORDER BY date DESC LIMIT 10;

/***********************************
 * Summary: Returns price of last n-entries
 * Params:
 * 		symbol_IN = Asset in the database.
 * 		until_IN = final date in the price series
 * 		length = length of the returned frame
 * Returns:
 * 		asset_price: frame
 */
Frame get(
	string symbol_IN, 
	Date until_IN,
	int length) 
{
	Frame result;
	string command;
	command = "
	SELECT * FROM " ~
		_engineDataFormat.pricetablename ~ 
	" WHERE symbol=\"" ~ 
		symbol_IN ~ 
	"\" AND date <=\"" ~
		until_IN.toISOExtString() ~
	"\" ORDER BY date DESC LIMIT " ~ 
		to!string(length) ~ 
	";";
	Connect();
	Row[] rs = MySQLQuery(command).array;
	Disconnect();
	for(int i = 0; i<rs.length; ++i){
		result.name = symbol_IN;
		result.valueArray ~= rs[i][this._engineDataFormat.mysqlcloseindex].get!double;
		result.dateArray ~= Date.fromSimpleString(to!string(rs[i][1]));
	}
	assert(length == result.valueArray.length);
	return result;
}

/***********************************
 * Summary: Initialize meta data begin/end and tick names.
 * This is called by the constructor.
 */
void InitializeMetaData() 
{
	Connect();
	int rowIndex = 0;		// Index checks first line. Does not process it.
	foreach(row; MySQLQuery("select * from "~this._engineDataFormat.metatablename~";", _mainConnectionID).array) {
		MetaData metaRow;
		// Begin/End dates are listed as 4th and 5th columns on mysql meta table 
		metaRow.beginDate = to!string(row[this._engineDataFormat.metabeginindex]);
		metaRow.endDate = to!string(row[this._engineDataFormat.metaendindex]);

		// 0th column is tick names.
		metaRow.tickName = to!string(row[this._engineDataFormat.metasymbolindex]);
		_metaData[metaRow.tickName] = metaRow;
		rowIndex += 1;
	}
	Disconnect();
}

private:
/***********************************
 * Summary: Makes a quick connection
 * to the mysql server. Each function in this
 * class is responsible for making their connections
 * and then closing them.
 */
void Connect()
{
  _mainConnectionID = GenerateConnectionID();
  InitializeMysql(
    _connectionInformation,
    _mainConnectionID); // from mysqlhook
}

/***********************************
 * Summary: Disconnects user class from
 * the mysql server.
 */
void Disconnect()
{
  Close();
  _mainConnectionID = NOT_CONNECTED;
}

/// Tick names and begin/end dates contained in MetaData dictionary
MetaData[string] _metaData; 	

/// Connection information
mysql_connection _connectionInformation;

/// mysql table information
engine_data_format _engineDataFormat;
}
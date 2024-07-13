module safepine_core.backend.users;

// D
import std.conv: to;

// Third party
import mysql: ResultRange;

// Safepine
import safepine_core.backend.mysqlhook: 
mysqlhook, 
mysql_connection, 
NOT_CONNECTED;

/***********************************
 * Safepine's user management class
 */

class users : mysqlhook {
/***********************************
 * Constructor: Creates safepine_users_tables and
 * binds a main connection ID to it.
 * Params:
 *      tableName_IN = string
 *      databaseName_IN = string
 *      resetUsers_IN = false/true, deletes user table!
  Example:
  -------------------
  users_obsolete users = new users(); 
  users.Close(users.MainConnectionID());    
  -------------------
 */
this(
  string tableName_IN = "safepine_users_table",
  string databaseName_IN = "safepine_users",
  bool resetUsers_IN = true)
{
  name = tableName_IN;
  database = databaseName_IN;

  _info.host = "host=127.0.0.1;";
  _info.port = "port=3306;";
  _info.user = "user=root;";
  _info.databaseName = database;

  // Create and delete functions are
  // mysqlhook functions which rely
  // on Connect/Disconnect methods
  // from the user class
  Connect();
  if(resetUsers_IN) {
    DeleteTable(
      name,
      _mainConnectionID);   
  }
  CreateTable(
    name, 
    structure, 
    _mainConnectionID);
  Disconnect();
}

/***********************************
 * Summary: Add user if it doesn't exist
 * Params:
 *      userName_IN = username
 *      email_IN = email
 *      password_IN = user password
 * Returns:
 *      result: ulong, 1 if user is added 0 if user was not added
 */ 
ulong Add(
    string userName_IN,
    string email_IN, 
    string password_IN)
{
  if(Exists(userName_IN)) return 0;
  string command = "
    INSERT INTO "
      ~ name ~" " 
      ~ columns ~ 
    " VALUES (\"" 
      ~ userName_IN ~ "\",\"" 
      ~ email_IN ~ "\",\"" 
      ~ password_IN ~ "\"
    );";
  Connect();
  MySQLExec(command);
  Disconnect();
  return 1;
}

/***********************************
 * Summary: Deletes a user
 * Params:
 *      userName_IN = username
 * Returns:
 *      result: ulong, 1 deleted and 0 if nothing to delete
 */ 
ulong Delete(string userName_IN) 
{
  ulong result = -1;
  string command = "
    DELETE FROM " 
      ~ name ~
    " WHERE user_name = \"" 
      ~ userName_IN ~ 
    "\";";
  Connect();
  result = MySQLExec(command);
  Disconnect();
  return result;
}

/***********************************
 * Summary: Deletes all users and the table
 * Returns:
 *      result: ulong, 1 deleted and 0 if nothing to delete
 */ 
ulong DeleteAllUsers() 
{
  ulong result = -1;
  Connect();
  result = users.DeleteTable("safepine_users_table");
  Disconnect();
  return result;
}

/***********************************
 * Summary: Check whether user exists
 * Params:
 *      userName_IN = username
 * Returns:
 *      result: bool, true if exists and false if not
 */ 
bool Exists(string userName_IN) 
{
  bool result = false;
  string command = "
    SELECT EXISTS (SELECT * FROM " ~ 
      name ~ 
    " WHERE user_name = \"" ~ 
      userName_IN ~ 
    "\");";
  Connect();
  ResultRange range = MySQLQuery(command);
  result = range.empty;  
  if (range.front[0] == 0) result = false;
  else result =  true;
  Disconnect();
  return result;
}   

/***********************************
 * Summary: Return names of all registered users
 * Returns:
 *      result: string[]
 */ 
string[] Names() 
{
  string[] result = null;
  string command = "
    SELECT user_name FROM " ~ 
      name ~ 
    ";";
  Connect();
  ResultRange range = MySQLQuery(command);
  foreach(row; range) result~=to!string(row[0]);
  Disconnect();
  return result;
}

/***********************************
 * Summary: Return emails of all registered users
 * Returns:
 *      result: string[]
 */ 
string[] Emails() 
{
  string[] result = null;
  string command = "
    SELECT email FROM " ~ 
    name ~ 
    ";";
  Connect();
  ResultRange range = MySQLQuery(command);
  foreach(row; range) result~=to!string(row[0]);
  Disconnect();
  return result;
}

/***********************************
 * Summary: Return emails of all registered users
 * parametritized wrt username.
 * Params:
 *      names = string
 * Returns:
 *      result: associative array, string
 */ 
string[string] Emails(string[] names)
{
  string[string] result = null;
  Connect();
  foreach(user_name; names) {
    string command = 
      "SELECT email FROM " ~ 
        name ~ " 
      WHERE user_name = \"" ~ 
        user_name ~ 
      "\";";
    ResultRange range = MySQLQuery(command);
    foreach(row; range) {
      result[user_name] =to!string(row[0]);
    }       
  }
  Disconnect();
  return result;
}

/***********************************
 * Summary: Authentication
 * Params:
 *      user_IN = name
 *      pass_IN = Password
 * Returns:
 *      result: true/false based on password
 */ 
bool Authenticate(
    string user_IN,
    string pass_IN) 
{
  bool result = false;
  string command = "SELECT password FROM "~name~" where user_name = \""~user_IN~"\";";
  Connect();
  ResultRange range = MySQLQuery(command);
  if(!range.empty)
  {
    if(pass_IN == to!string(range.front[0])) 
    {
      result = true;
    }   
    else
    {
      result = false;
    }   
  }
  Disconnect();
  return result;
}

/***********************************
 * Summary: Database column names
 * Returns:
 *      result: Column names as a string array.
 */ 
string[] ColumnNames()
{
  string[] result;
  Connect();
  result = GetColumnNames("safepine_users_table");
  Disconnect();
  return result;
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
    _info,
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

/// Connection information
mysql_connection _info;

/// User table's name
string name = "";

/// User table's database name
string database = "";

/// User table is composed of user name, email and passwords
const string structure = 
"(
    user_name VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    password VARCHAR(255)       
)";
/// Used for insert operations into table
const string columns = 
"(
    user_name, 
    email, 
    password
)";     
}
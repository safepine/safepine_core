import std.conv;
import std.stdio;
import std.string;

import sqlite3d;

extern(C)
{
  static int callback(void *NotUsed, int argc, char **argv, char **azColName)
  {
    int i;
    for(i=0; i<argc; i++){
      printf("%s = %s\n", azColName[i], argv[i] ? argv[i] : "NULL");
    }
    printf("\n");
    return 0;
  }
}

int main(string[] args)
{
  sqlite3 *db;
  char *zErrMsg;
  int rc;

  if( args.length!=3 ){
    writeln("Usage: ./app DATABASE SQL-STATEMENT");
    return 1;
  }

  rc = sqlite3_open(&args[1].dup[0], &db);
  if( rc ){
    writeln("Can't open database: " ~ to!string(sqlite3_errmsg(db)));
    sqlite3_close(db);
    return 1;
  }

  rc = sqlite3_exec(db, &args[2].dup[0], &callback, null, &zErrMsg);
  if( rc!=SQLITE_OK ){
    writeln("SQL error: "~fromStringz(zErrMsg));
    sqlite3_free(zErrMsg);
  }

  sqlite3_close(db);
  return 0;
}

// D 
import std.json: JSONValue, JSONOptions, parseJSON;
import std.stdio: write, writeln;

// Third party
import vibe.core.file;
import vibe.d; 
import vibe.inet.message;
import vibe.web.auth;

struct UserSettings {
    string  userName_;
}

@requiresAuth
class DataInterface
{
  // tranmission
  @noAuth
  void getTransmission(
    scope HTTPServerRequest req,
    scope HTTPServerResponse res)
  {
    import std.stdio: writeln;
    import std.datetime.stopwatch: StopWatch, AutoStart;
    auto myStopWatch = StopWatch(AutoStart.no);

    myStopWatch.start();
    JSONValue all_data = ImportData("./cache");
    res.writeBody(all_data.toString(JSONOptions.specialFloatLiterals));
    writeln("[DataInterface: GET/tranmission] Timing: "~to!string((to!double(myStopWatch.peek.total!"usecs")*0.001))~" ms");

    myStopWatch.reset();
    myStopWatch.stop();
  }

  // Authenticate gets called for any method that requires authentication
  @noRoute @safe
  UserSettings authenticate(
    scope HTTPServerRequest req, 
    scope HTTPServerResponse res) 
  {
    if (!req.session || !req.session.isKeySet("auth"))
      throw new HTTPStatusException(
        HTTPStatus.forbidden, 
        "Not authorized to perform this action!");
    return req.session.get!UserSettings("auth");
  }

private:
  JSONValue ImportData(string path_IN)
  {
    import std.algorithm.iteration : map, filter;
    import std.algorithm.searching;
    import std.array : array;
    import std.file;
    import std.path : baseName;
    JSONValue result;
    string[] files = dirEntries(path_IN, "*.json", SpanMode.shallow)
        .filter!(a => a.isFile)
        .map!((return a) => baseName(a.name))
        .array; // List of all json files
    foreach (string file; files)
    {
      auto index = file.indexOf("_");
      string prices_raw = to!string(read(path_IN~"/"~file));
      string symbol = file[0 .. index];
      result[symbol] = parseJSON(prices_raw);
    }
    return result;
  }
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

void main() {
  write(App("Safepine Visuals", "May 30, 2024"));

  // Register web services
  DataInterface app_interface = new DataInterface();
  auto router = new URLRouter;
  router.registerWebInterface(app_interface);

  // Add static pages & files to router
  router.get("/Dashboard", staticRedirect("/index.html"));
  router.get("*", serveStaticFiles("public"));

  auto settings = new HTTPServerSettings;
  settings.sessionStore = new MemorySessionStore;
  settings.bindAddresses = ["localhost"];
  settings.port = 8080; 

  auto listener = listenHTTP(settings, router);
  scope(exit) listener.stopListening();   
  runApplication();
}

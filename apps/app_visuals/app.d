// D
import std.digest.sha;
import std.stdio: write, writeln;

// Safepine
import safepine_core.project;
import safepine_core.quantum.web;

// Third party
import vibe.core.file;
import vibe.d; 
import vibe.inet.message;
import vibe.web.auth;

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

  // Data path;
  ubyte[20] hash_ulong;
  string cachePathSeed, hashedCachePath;

  // URL Router
  auto router = new URLRouter;

  // Interface: Watchlist
  DataAcquisitionProfile profile = ImportDataAcquisitionProfile(
    "config.json");
  cachePathSeed = "";
  for(int i = 0; i < profile.assetNames.length; ++i)
  {
    cachePathSeed ~= profile.assetNames[i];
  }
  cachePathSeed ~= profile.dataBegin.toISOString();
  cachePathSeed ~= profile.dataEnd.toISOString();
  hash_ulong = sha1Of(cachePathSeed);
  hashedCachePath = toHexString(hash_ulong);
  DataAcquisition(
    profile.assetNames, 
    profile.dataBegin, 
    profile.dataEnd,
    profile.dataProvider,
    "cache/"~hashedCachePath~"/");
  DataInterface dataInterface = new DataInterface(
    "cache/"~hashedCachePath~"/");
  router.registerWebInterface(dataInterface);

  // Interface: Portfolio
  AssetAllocationProfile input_profile = ImportAssetSchedule(
    "config.json");
  string[] symbols = UniqueStrings(input_profile.assetNames);
  symbols ~= "SPY"; // For benchmarks.
  cachePathSeed = "";
  for(int i = 0; i < symbols.length; ++i)
  {
    cachePathSeed ~= symbols[i];
  }
  cachePathSeed ~= input_profile.dataBegin.toISOString();
  cachePathSeed ~= input_profile.dataEnd.toISOString();
  hash_ulong = sha1Of(cachePathSeed);
  hashedCachePath = toHexString(hash_ulong);  
  DataAcquisition(
    symbols, 
    input_profile.dataBegin, 
    input_profile.dataEnd,
    profile.dataProvider,
    "cache/"~hashedCachePath~"/");  
  PortfolioInterface portfolioInterface = new PortfolioInterface(
    "cache/"~hashedCachePath~"/all_data.csv",
    input_profile);
  portfolioInterface.LoadBackend(); 
  router.registerWebInterface(portfolioInterface);

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

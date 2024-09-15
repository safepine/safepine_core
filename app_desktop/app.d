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

void main() {
  write(App("Safepine Core Desktop", "Aug 27, 2024"));

  // Configuration parser & data acquisition
  ubyte[20] hash_ulong;
  string cachePathSeed, hashedCachePath;
  ConfigurationProfile profile = ImportConfigurationProfile(
    "config.json");
  cachePathSeed = "";
  for(int i = 0; i < profile.assetNames.length; ++i)
  {
    cachePathSeed ~= profile.assetNames[i];
  }
  cachePathSeed ~= profile.beginDate.toISOString();
  cachePathSeed ~= profile.endDate.toISOString();
  hash_ulong = sha1Of(cachePathSeed);
  hashedCachePath = toHexString(hash_ulong);  
  DataAcquisition(
    profile.assetNames, 
    profile.beginDate, 
    profile.endDate,
    profile.dataProvider,
    "cache/"~hashedCachePath~"/");  

  // Server setup
  auto settings = new HTTPServerSettings;
  settings.sessionStore = new MemorySessionStore;
  settings.bindAddresses = ["localhost"];
  settings.port = 8080;   
  auto router = new URLRouter;

  // Interface: Portfolio
  PortfolioInterface portfolioInterface = new PortfolioInterface(
    "cache/"~hashedCachePath~"/all_data.csv",
    profile);
  portfolioInterface.LoadBackend(); 
  router.registerWebInterface(portfolioInterface);

  // Interface: Watchlist
  DataInterface dataInterface = new DataInterface(
    "cache/"~hashedCachePath~"/");
  router.registerWebInterface(dataInterface);

  // Add static pages & files to router
  router.get("/Dashboard", staticRedirect("/index.html"));
  router.get("*", serveStaticFiles("public"));

  auto listener = listenHTTP(settings, router);
  scope(exit) listener.stopListening();   
  runApplication();
}

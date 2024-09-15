module safepine_core.quantum.stash;

// D
import std.conv: to;
import std.file; // write

// QuantityHolder
union QuantityHolder {
    int   numberInt;    // Discrete stock/bond holdings.
    double  numberDouble; // Cash.
}

// QuantityHolder Vector 
enum Quantity_t {integer_Q, double_Q}
struct Quantity {
  QuantityHolder[]  internalQuantity; 
  Quantity_t      internalType;
}

struct Stash {
  // Constructor
  this(int maxAssets_IN, int maxTick_IN) {
    // stash limits
    this.MAXASSETS  = maxAssets_IN;
    this.MAXTICKS   = maxTick_IN;

    Initialize();
  }

  // Refresh: restarts stash.
  void Refresh() {
    _stashMatrix.clear();
    Initialize();
  }

  // AddAsset: stocks, bonds, cash, dividends ...
  // Input:
  //    key_IN        : Asset name as string
  //    qhMode_IN     : Quantity holder mode: true, double. false, int. 
  // Returns:
  //    Success     : Success
  //    Error_Full    : Fail, can't hold more assets.
  //    Error_Duplicate : Fail, asset already exists.
  enum AddAsset_t {Success, Error_Full, Error_Duplicate}
  AddAsset_t AddAsset(string key_IN, Quantity_t qhMode_IN) pure {
    if(_stashMatrix.length == MAXASSETS) {
      return AddAsset_t.Error_Full;
    }

    Quantity asset;
    asset.internalQuantity = new QuantityHolder[MAXTICKS];

    bool constructed = false;
    _stashMatrix.require(key_IN,  { constructed=true; return asset;}());
    if(constructed) {
      _stashMatrix[key_IN].internalType = qhMode_IN;
      string fail_msg = "Failure: Array length not set to max tick input.";
      assert(_stashMatrix[key_IN].internalQuantity.length == MAXTICKS, fail_msg);
      _assetLength += 1;
      return AddAsset_t.Success;
    }
    else {
      return AddAsset_t.Error_Duplicate;
    }
  } 

  // Deposit/Credit or Buy/Sell or goLong/goShort
  // Input:
  //    number_IN     : Positive is buy negative is sell. int or double.
  //    key_IN      : Asset name as string  
  // Returns:
  //    Success     : Success
  //    Error_Key   : Fail, key (asset) does not exist. 
  enum ModifyStash_t {Success, Error_Key}
  ModifyStash_t ModifyStash(T)(T number_IN, string key_IN) pure {
    if(key_IN in _stashMatrix) {
      if(_stashMatrix[key_IN].internalType == Quantity_t.double_Q) {
        _stashMatrix[key_IN].internalQuantity[_stashTick].numberDouble += number_IN;
      }
      else {
        // Not sure why cast is needed here. 
        // Without cast I was getting a fruncating conversion warning.
        _stashMatrix[key_IN].internalQuantity[_stashTick].numberInt += to!int(number_IN);
      }
      return ModifyStash_t.Success;
    }
    else {
      return ModifyStash_t.Error_Key;
    }   
  } 

  // This is going to be the increment function. 
  // Returns:
  //    Success     : Obvious success is obvious
  //    Error_LastTick  : Fail, reached last tick 
  enum IncrementTick_t {Success, Error_LastTick}
  IncrementTick_t IncrementTick() pure {
    // Max tick check
    if(_stashTick < MAXTICKS-1) {
      _stashTick += 1;
      foreach (string key; _stashMatrix.byKey()) {
        // Hard to understand what's being selected here. integer or double?
        _stashMatrix[key].internalQuantity[_stashTick] = _stashMatrix[key].internalQuantity[_stashTick-1];
      }

      return IncrementTick_t.Success;
    }
    else {
      return IncrementTick_t.Error_LastTick;
    }
  }

  // Returns column depending on internal data type
  // Input:
  //    key_IN      : Asset name as string  
  //    startTick_IN  : Start tick index
  //    numberOfRows_IN : Number of rows to grab, picks everything if -1  
  // Returns:
  //    null      : If asset not found or start tick out of index.
  //    double[]    : Array holding n-double values
  double[]  GetColumn(string key_IN, int startTick_IN, int numberOfRows_IN) pure {
    // Set number of rows to MAXTICKS if input is -1. Therefore pick all columns
    if(numberOfRows_IN == -1) {
      numberOfRows_IN = MAXTICKS;
    }

    // Start tick is out of index
    if(startTick_IN < 0 || startTick_IN > _stashTick) {
      return null;
    }

    // If end tick overflows it becomes stash tick which points to the last line in the stash
    int endTick;
    if(startTick_IN + numberOfRows_IN > _stashTick) {
      endTick = _stashTick;
    }
    else {
      endTick = startTick_IN + numberOfRows_IN;
    }

    if(key_IN in _stashMatrix) {
      // Type: Double
      if(_stashMatrix[key_IN].internalType == Quantity_t.double_Q) {
        double[] returnArray = new double[endTick-startTick_IN+1];
        for (int i = startTick_IN ; i <= endTick ; i++) {
          double val = _stashMatrix[key_IN].internalQuantity[i].numberDouble;
          returnArray[i-startTick_IN] = val;
        }
        return returnArray;
      }
      // Type: Integer
      else {
        double[] returnArray = new double[endTick-startTick_IN+1];
        for (int i = startTick_IN ; i <= endTick ; i++) {
          double val = to!double(_stashMatrix[key_IN].internalQuantity[i].numberInt);
          returnArray[i-startTick_IN] = val;
        }
        return returnArray;
      }
    } 
    else {
      return null;
    }
  }

  // Returns the item for key at index.
  // Input:
  //    key_IN      : Asset name as string  
  //    itemIndex_IN  : Index of the row. Must be positive.
  // Returns:
  //    double[2]     : 0: requested value in double format. 1: is error number.
  //    errorNumbers  : -1 is index array. -2 is key not found.
  double[2]   GetItem(string key_IN, int itemIndex_IN) pure {
    double[2] returnArray;

    if(key_IN in _stashMatrix) {
      // Type: Double
      if(_stashMatrix[key_IN].internalType == Quantity_t.double_Q) {
        if(itemIndex_IN <= _stashTick && itemIndex_IN >= 0) {
          double val = _stashMatrix[key_IN].internalQuantity[itemIndex_IN].numberDouble;
          returnArray[0] = val;
          returnArray[1] = 1;
          return returnArray;
        }
        else {
          returnArray[1] = -1;
          return returnArray;
        }
      }
      // Type: Integer
      else {
        if(itemIndex_IN <= _stashTick && itemIndex_IN >= 0) {
          double val = to!double(_stashMatrix[key_IN].internalQuantity[itemIndex_IN].numberInt);
          returnArray[0] = val;
          returnArray[1] = 1;
          return returnArray;
        }
        else {
          returnArray[1] = -1;
          return returnArray;
        }
      }
    } 
    else
    {
      returnArray[1] = -2;
      return returnArray;
    }
  } 

  // Gets the current stash tick.
  // Returns:
  //    stashTick     : As integer.
  int     GetStashTick() pure {
    return _stashTick;
  }

  // Returns an item at current index/tick.
  // Input:
  //    key_IN      : Asset name as string  
  // Returns:
  //    double[2]     : 0: is requested value in double format. 1: error number.
  //    errorNumbers  : -1 is index array. -2 is key not found.
  double[2]   GetItemAtCurrentIndex(string key_IN) pure {
    return GetItem(key_IN, _stashTick);
  }   

  // Can be used to get an array of current asset names
  string[]  GetAssetNames() pure {
    string[] returnArray = new string[_assetLength];
    int counter = 0;
    foreach (string key; _stashMatrix.byKey()) {
      returnArray[counter] = key;
      counter++;
    } 
    return returnArray;
  }

  // Exports stash matrix as a csv file to executable's folder.
  // Input:
  //    name_IN     : Name of the output csv file
  //    startTick_IN  : Start tick index
  //    numberOfRows_IN : Number of rows to grab, picks everything if -1
  // Returns:
  //    null      : If there is an indexing error
  //    rawText     : Raw text file containing csv
  string    ExportCSV(string name_IN, int startTick_IN, int numberOfRows_IN) {
    // Set number of rows to MAXTICKS if input is -1. Therefore pick all columns
    if(numberOfRows_IN == -1) {
      numberOfRows_IN = MAXTICKS;
    }

    // Start tick is out of index
    if(startTick_IN < 0 || startTick_IN > _stashTick) {
      return "Null";
    }

    // If end tick overflows it becomes stash tick which points to the last line in the stash
    int endTick;
    if(startTick_IN + numberOfRows_IN > _stashTick) {
      endTick = _stashTick;
    }
    else {
      endTick = startTick_IN + numberOfRows_IN;
    }

    string rawText;
    // key (a.k.a asset name) is index for columns
    // j is index for rows
    for (int j = startTick_IN ; j <= endTick; j++) {
      int assetIndex = 0;
      // true, double. false, integer.
      foreach (string key; _stashMatrix.byKey()) {
        assetIndex += 1;

        // Title row
        if(j==0) {
          rawText ~= key;
        }
        // Non-Title rows
        else {
          auto dataType = _stashMatrix[key].internalType;
          
          // Data type selection for write operation
          if(dataType == Quantity_t.double_Q) {
            string line = to!string(_stashMatrix[key].internalQuantity[j].numberDouble);
            rawText ~= line;
          }
          else {
            string line = to!string(_stashMatrix[key].internalQuantity[j].numberInt);
            rawText ~= line;
          }         
        }
        
        if(assetIndex != _assetLength) {
          rawText ~= ",";
        }
      }
      rawText ~= "\n";
    } 

    // Write to output file if input name is non-empty string.
    if(name_IN != "") {
      if (!exists("out/"))
        mkdir("out/");     
      std.file.write("out/"~name_IN~".csv", rawText);
    }

    // Return raw text.
    return rawText;
  } 

  // Checks if a key is in the internal stash.
  // Input:
  //    key_IN      : Asset name as string  
  // Returns:
  //    Success     : Key found
  //    Fail      : Key not found 
  enum CheckKey_t {Success, Fail}
  int CheckKey(string key_IN) pure {
    if(key_IN in _stashMatrix) {
      return CheckKey_t.Success;
    }
    else {
      return CheckKey_t.Fail;
    }
  }

private:

  // Init stash
  void Initialize() {
    // Initialize stash tick to zero.
    _stashTick = 0;

    // Set assetlength to 0 explicitly
    _assetLength = 0;

    // Add cash as default asset
    // Set bool flag as true since cash is stored as double.
    AddAsset("Cash", Quantity_t.double_Q);    
  }

  // Determines maximum size of the trade matrix
  const int       MAXASSETS;
  const int       MAXTICKS;

  // Holds current length of asset matrix
  int         _assetLength;

  // Stash tick points to the current tick in the matrix
  int         _stashTick;

  // NxMxP matrix, where N is number of assets
  // M is number of ticks and P is unit of asset hold or currency.
  Quantity[string]  _stashMatrix;
}
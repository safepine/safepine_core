module safepine_core.math.optimization;

// D
import std.conv: to;
import std.stdio: writeln;

// Safepine
import safepine_core.math.matrix: 
Diag,
Matrix;

enum logger {
	on, 
	off} // Enable/disable logging

Matrix 
PortfolioAllocation(logger log = logger.on)(
	const string[] assets_IN, 
	const ref Matrix asset_ratios_IN,
	const ref Matrix asset_prices_unit_IN,
	double equity_IN) 
{
	Matrix asset_prices = new Matrix(1, asset_ratios_IN.Rows, 0.0);
	asset_prices = asset_ratios_IN*equity_IN;
	Matrix A_portfolio = Diag(asset_prices_unit_IN);
	Matrix x_portfolio = A_portfolio.Inv*asset_prices.T;
	double computed_equity = 0.0;

	for(int i = 0; i<x_portfolio.Rows; ++i) {
		if(log == logger.on) writeln("Asset "~assets_IN[i]~" has "~to!string(to!int(x_portfolio[i,0]))~" units with sub-total value: "~to!string(to!int(x_portfolio[i,0])*asset_prices_unit_IN[0,i]));
		computed_equity += to!int(x_portfolio[i,0])*asset_prices_unit_IN[0,i];
	}
	if(log == logger.on) {
		writeln("Desired equity: "~to!string(equity_IN));
		writeln("Computed equity: "~to!string(computed_equity));				
	}
	return x_portfolio;
}
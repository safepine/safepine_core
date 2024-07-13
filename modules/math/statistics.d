module safepine_core.math.statistics;

// D
import std.algorithm: max, min, reduce;
import std.array: replicate;
import std.conv: to;
import std.exception: enforce;
import std.math: exp, sqrt, log, pow;
import std.numeric: normalize;
import std.random: dice, Random, uniform, unpredictableSeed;
import std.stdio: writefln, writeln;
import std.typecons: tuple;

double compute_autocorrelation(double[] array_IN, int tao) pure {
	double result = 0.0;
	int n = to!int(array_IN.length);
	double mean = compute_mean(array_IN);
	double numerator = 0.0;
	double denominator = 0.0; 
	for(int i = tao; i < n; ++i ) {
		numerator += (array_IN[i] - mean)*(array_IN[i-tao] - mean) / n;
		denominator += pow(array_IN[i] - mean, 2) / n;
	}
	return numerator/denominator;
}

double[] compute_correlogram(double[] array_IN) pure {
	int n = to!int(array_IN.length);
	double[] result;
	for(int tao = 0; tao < n/5; ++tao) {
		result ~= compute_autocorrelation(array_IN, tao);
	}
	return result;
}

double compute_mean(double[] array_IN) pure {
	double sum = 0;
	int n = to!int(array_IN.length);
	for(int i = 0; i<n; i++) { sum += array_IN[i]; }
	return sum/n;
}

double compute_geometric_average(double[] array_IN) {
	double product_log = 0.0;
	int n = to!int(array_IN.length);
	for(int i = 0; i<n; i++) { 
		if(1+array_IN[i] >= 0.0) product_log += to!double(log(1+array_IN[i])); 
		else product_log -= to!double(log(-(1+array_IN[i]))); 
	}
	return exp(product_log/n);
}

double compute_std(double[] array_IN) pure {
	double sum = 0;
	double mean = compute_mean(array_IN);
	int n = to!int(array_IN.length);
	for(int i = 0; i<n; i++) { sum += pow((array_IN[i]-mean),2); }
	return sqrt(sum/n);	
}

auto compute_mean_std(R)(R numbers) /*nothrow*/ @safe /*@nogc*/ {
    if (numbers.empty)
        return tuple(0.0L, 0.0L);
 
    real sx = 0.0, sxx = 0.0;
    ulong n;
    foreach (x; numbers) {
        sx += x;
        sxx += x ^^ 2;
        n++;
    }
    return tuple(sx / n, (n * sxx - sx ^^ 2) ^^ 0.5L / n);
}

double compute_variance(double[] array_IN) pure {
	double std = compute_std(array_IN);
	return pow(std,2);
}

double compute_correlation(double[] array_x_IN, double[] array_y_IN) pure {
	enforce(array_x_IN.length == array_y_IN.length, "compute_correlation: not same length"); 
	int n = to!int(array_x_IN.length);
	double x_mean = compute_mean(array_x_IN);
	double y_mean = compute_mean(array_y_IN);
	double numerator = 0.0;
	double denominator = 0.0;
	for (int i = 0; i<n; i++) {
		numerator += (array_x_IN[i]-x_mean)*(array_y_IN[i]-y_mean);
		denominator += sqrt(pow(array_x_IN[i]-x_mean, 2)*pow(array_y_IN[i]-y_mean, 2));
	}
	return numerator/denominator;
}

double[2] compute_ordinary_least_squares(double[] array_x_IN, double[] array_y_IN) pure {
	enforce(array_x_IN.length == array_y_IN.length, "compute_ordinary_least_squares: not same length"); 
	int n = to!int(array_x_IN.length);
	double x_mean = compute_mean(array_x_IN);
	double y_mean = compute_mean(array_y_IN);
	double numerator = 0.0;
	double denominator = 0.0;
	double b1, b2;
	for(int i = 0; i<n; i++) {
		numerator += (array_x_IN[i]-x_mean)*(array_y_IN[i]-y_mean);
		denominator += pow(array_x_IN[i]-x_mean, 2);
	}
	b2 = numerator/denominator;
	b1 = y_mean - b2*x_mean;
	return [b1, b2];
}

double[] compute_z_score(double[] array_IN) {
	int n = to!int(array_IN.length);
	double[] result;
	double mean = compute_mean(array_IN);
	double std = compute_std(array_IN);
	for(int i = 0; i < n; ++i) {
		result ~= (array_IN[i] - mean) / std;
	}
	return result;
}

double[] compute_spread(double[] array_a, double[] array_b, double k) {
	double[] result;
	assert(array_a.length == array_b.length);
	int n = to!int(array_a.length);
	for(int i = 0; i < n; ++i) {
		result ~= log(array_a[i]) - k*log(array_b[i]);
	}
	return result;
}

double[] generate_white_noise(int n) {
	// Generate a float in [0, 1]
	double[] result;
	auto rnd = Random(unpredictableSeed);
	int count = 0;
	while(count < n) {
		auto b = uniform!"[]"(-1.0f, 1.0f, rnd);
		result ~= to!double(b);
		count++;
	}
	return result;
}

double[] generate_moving_average_process(double beta, int n) {
	// Generate a float in [0, 1]
	double[] result;
	auto rnd = Random(unpredictableSeed);
	double previous_random = to!double(uniform!"[]"(-1.0f, 1.0f, rnd));
	result ~= previous_random;
	int count = 1;
	while(count < n) {
		auto b = uniform!"[]"(-1.0f, 1.0f, rnd);
		result ~= to!double(b) + beta*previous_random;
		count++;
		previous_random = result[count-1];
	}
	return result;	
}

double[] generate_arma_process(double alpha, double beta, int n) {
	double[] result;
	auto rnd = Random(unpredictableSeed);
	double x_prev = to!double(uniform!"[]"(-1.0f, 1.0f, rnd));
	result ~= x_prev;
	for(int i = 1; i < n; ++i) {
		double x_t = to!double(uniform!"[]"(-1.0f, 1.0f, rnd));
		result ~= alpha*result[i-1] + beta*x_prev + x_t;
		x_prev = x_t;
	}

	return result;
}

double[] generate_autoregressive_process_dice(double alpha, double rho, double e_t, int n) {
    double y = 0;
    double[] time_series;
    for (int i = 0; i<n; i++) {
        if (dice(0.5, 0.5) == 1) y = alpha + rho*y + e_t;
        else y = alpha + rho*y - e_t;
        time_series ~= y;   	
    }
    return time_series;
}

double[] generate_autoregressive_process(double alpha, double rho, int n) {
    double y = 0;
    auto rnd = Random(unpredictableSeed);
    double[] time_series;
    for (int i = 0; i<n; i++) {
		auto b = uniform!"[]"(-1.0f, 1.0f, rnd);
        y = alpha + rho*y + to!double(b);
        time_series ~= y;   	
    }
    return time_series;
}

double[][] monte_carlo(
	double[] return_distribution, 
	int dice_rolls, 
	int possible_futures,
	ulong offset = 0) {
	auto rnd = Random(unpredictableSeed);
	ulong random_return_index;
	double[][] equity_matrix;
	double equity = 1.0;
	double[] equity_vector;
	equity_vector ~= equity;
	for (int i = 0 ; i< possible_futures; ++i) {
		equity_vector = [];
		equity = 1.0;
		for(int j = 0; j<offset+dice_rolls; ++j) {
			if(j < offset) equity_vector ~= 0.0;
			else {
				random_return_index = uniform(0, return_distribution.length, rnd);
				equity += equity*(return_distribution[cast(uint)random_return_index]/100.0);
				equity_vector ~= equity;				
			}
		}		
		equity_matrix ~= equity_vector;
	}
	return equity_matrix;
}

auto compute_histogram(R)(R numbers, ulong bins_length) {
    ulong[] bins_normalized;
    double[] bins;
	double minimum_value = numbers.reduce!min;
	double maximum_value = numbers.reduce!max;    
    for(int i = 0; i<bins_length; ++i) {bins_normalized ~= 0;}
    for(int i = 0; i<bins_length; ++i) {
    	bins ~= minimum_value + i*(maximum_value-minimum_value)/bins_length;
    }
	normalize(numbers);

    foreach (immutable x; numbers) {
        immutable index = cast(size_t)(x * bins_length);
        enforce(index >= 0 && index < bins_length);
        bins_normalized[index]++;
    }

    return tuple(bins_normalized, bins);
}

void print_histogram(T)(T hist) {
	enum maxWidth = 50; // N. characters.
	immutable real maxFreq = hist[0].reduce!max;
	foreach (immutable n_value, immutable i; hist[0])
	    writefln(" %.2f: %s", hist[1][n_value],
	             replicate("*", cast(int)(i / maxFreq * maxWidth)));
	writeln;		
}
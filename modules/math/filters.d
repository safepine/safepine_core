module safepine_core.math.filters;

// D
import std.algorithm: max, reverse, maxElement;
import std.conv: to;
import std.math: PI;
import std.stdio;

// Safepine
import safepine_core.math.matrix: Matrix, toDouble_v;

void add_index_range(ref int[] indices, int beg, int end, int inc = 1) {
    for (int i = beg; i <= end; i += inc) {
       indices ~= (i);
    }
}

void add_index_const(ref int[] indices, int value, int numel) {
    while (numel--) {
        indices ~= value;
    }
}

void append_vector(ref double[] vec, ref double[] tail) {
    vec ~= tail;
}

double[] subvector_reverse(const ref Matrix vec, int idx_end, int idx_start) {
	double[] result;
	for(int i = idx_start; i<idx_end+1; ++i) {
		result ~= vec[0, i];
	}
    return result.reverse;
}

Matrix filter(Matrix B, Matrix A, const Matrix X, const Matrix Zi) pure {
	Matrix Y; // output

	// input sanity
	if(A.empty) {
		throw new Exception("The feedback filter coefficients are empty.");
	}
	if(A.Size[0] > 1) {
		throw new Exception("The feedback filter coefficients is not a row vector.");
	}
	bool all_zeros = true;
	for(int c = 0; c<A.Size()[1]; ++c) {
		if(A[0,c] != 0.0) {
			all_zeros = false;
			continue;
		}
	}
	if(all_zeros) {
		string msg = "At least one of the feedback filter coefficients has to be non-zero.";
		throw new Exception(msg);
	}
	if(A[0,0] == 0.0) {
		throw new Exception("First feedback coefficient has to be non-zero.");
	}

	double a0 = A[0,0];
	if(a0 != 1.0) {
		for(int i = 0; i< A.Size()[0]; ++i) {
			A[0,i] = A[0,i] / a0;
		}
		for(int i = 0; i< B.Size()[0]; ++i) {
			B[0,i] = B[0,i] / a0;
		}		
	}

	int input_size = X.Size()[1];
	int filter_order = max(A.Size()[1], B.Size[1]);
	Matrix b = new Matrix(1, filter_order, 0.0);
	Matrix a = new Matrix(1, filter_order, 0.0);
	Matrix z = new Matrix(1, filter_order, 0.0);
	for(int i = 0; i<filter_order; ++i) {
		if(i < B.Size()[1]) {
			b[0,i] = B[0,i];
		}
		else b[0,i] = 0.0;		
		if(i < A.Size()[1]) {
			a[0,i] = A[0,i];
		}
		else a[0,i] = 0.0;	
		if(i < Zi.Size()[1]) {
			z[0,i] = Zi[0,i];
		}
		else z[0,i] = 0.0;				
	}	
	Y = new Matrix(1, input_size, 0);

	for(int i = 0; i<input_size; ++i) {
		int order = filter_order - 1;
        while (order) {
            if (i >= order) {
                z[0, order - 1] = b[0, order] * X[0, i - order] - a[0, order] * Y[0, i - order] + z[0, order];
            }
            --order;
        }
        Y[0, i] = b[0, 0] * X[0, i] + z[0, 0];
	}

	return Y;
}

Matrix filtfilt(Matrix B, Matrix A, const Matrix X) {
	Matrix Y; // output

    int len = X.Size()[1]; // length of input
    int na = A.Size()[1];
    int nb = B.Size()[1];
    int nfilt = (nb > na) ? nb : na;
    int nfact = 3 * (nfilt - 1); // length of edge transients

    if (len <= nfact) {
    	string msg = "Input data too short! Data must have length more than 3 times filter order.";
        throw new Exception(msg);
    }

	Matrix b = new Matrix(1, nfilt, 0.0);
	Matrix a = new Matrix(1, nfilt, 0.0);    
	for(int i = 0; i<nfilt; ++i) {
		if(i < B.Size()[1]) {
			b[0,i] = B[0,i];
		}
		if(i < A.Size()[1]) {
			a[0,i] = A[0,i];
		}
	}   

    int[] rows, cols;
    add_index_range(rows, 0, nfilt - 2);
    if (nfilt > 2) {
        add_index_range(rows, 1, nfilt - 2);
        add_index_range(rows, 0, nfilt - 3);
    }
    add_index_const(cols, 0, nfilt - 1);
    if (nfilt > 2) {       
        add_index_range(cols, 1, nfilt - 2);
        add_index_range(cols, 1, nfilt - 2);
    } 

    int klen = to!int(rows.length);
    double[] data;
    for(int i = 0; i<klen; ++i) {
    	data ~= 0.0;
    }

    data[0] = 1.0 + a[0,1];  int j = 1;
    if (nfilt > 2) {
        for (int i = 2; i < nfilt; i++)
            data[j++] = a[0, i];
        for (int i = 0; i < nfilt - 2; i++)
            data[j++] = 1.0;
        for (int i = 0; i < nfilt - 2; i++)
            data[j++] = -1.0;
    }

    double[] leftpad = subvector_reverse(X, nfact, 1);
    double _2x0 = 2 * X[0, 0];
	for(int i = 0; i< leftpad.length; ++i) {
		leftpad[i] = _2x0 - leftpad[i];
	}

	double[] rightpad = subvector_reverse(X, len - 2, len - nfact - 1);
    double _2xl = 2 * X[0, len-1];
	for(int i = 0; i< rightpad.length; ++i) {
		rightpad[i] = _2xl - rightpad[i];
	}

    double y0;
    double[] signal1, signal2, zi;

    double[] Xd = toDouble_v(X);
    append_vector(signal1, leftpad);
    append_vector(signal1, Xd);
    append_vector(signal1, rightpad);    

    // Calculate initial conditions
    Matrix sp = new Matrix(rows.maxElement+1, cols.maxElement+1, 0.0);
    for (int k = 0; k < klen; ++k) {
        sp[rows[k], cols[k]] = data[k];
    }    
	Matrix bb = new Matrix(1, nfilt, 0.0);
	for(int i = 0; i<nfilt; ++i) {
		bb[0,i] = b[0,i]; 
	}
	Matrix aa = new Matrix(1, nfilt, 0.0);  
	for(int i = 0; i<nfilt; ++i) {
		aa[0,i] = a[0,i]; 
	}	
	Matrix bb_segment = new Matrix(1, nfilt-1, 0.0);
	for(int i = 0; i<nfilt-1; ++i) {
		bb_segment[0,i] = bb[0,i+1]; 
	}	
	Matrix aa_segment = new Matrix(1, nfilt-1, 0.0);
	for(int i = 0; i<nfilt-1; ++i) {
		aa_segment[0,i] = aa[0,i+1]; 
	}		
	Matrix zzi = sp.Inv()*(bb_segment - (aa_segment * bb[0,0])).T();

    for(int i = 0; i<zzi.Size()[1]; ++i) {
    	zi ~= 0.0;
    }

    // Do the forward and backward filtering
    y0 = signal1[0];
	for(int i = 0; i< zzi.Size()[1]; ++i) {
		zi[i] = zzi[0, i] * y0;
	}    
	Matrix signal1_m = new Matrix(signal1);
	Matrix zi_m = new Matrix(zi);
    signal2 = toDouble_v(filter(B, A, signal1_m, zi_m));
    signal2 = signal2.reverse;
    y0 = signal2[0];
	for(int i = 0; i< zzi.Size()[1]; ++i) {
		zi[i] = zzi[0, i] * y0;
	} 
	Matrix signal2_m = new Matrix(signal2); 
	signal1_m = filter(B, A, signal2_m, zi_m);
	Y = new Matrix(subvector_reverse(signal1_m, signal1_m.Size()[1] - nfact - 1, nfact));
	return Y;
}

Matrix SMA(Matrix X_IN, int window_size_IN) pure {
	Matrix b_coeff = new Matrix(1, window_size_IN, 1.0)/window_size_IN;
	Matrix a_coeff = new Matrix([1.]); 
	Matrix zi = new Matrix([ 0. ]);	

	return filter(b_coeff, a_coeff, X_IN, zi);
}

Matrix EMA(Matrix X_IN, double alpha) pure {
	Matrix b_coeff = new Matrix([alpha]);
	Matrix a_coeff = new Matrix([1.0, -(1.0-alpha)]); 
	Matrix zi = new Matrix([ 0. ]);	

	return filter(b_coeff, a_coeff, X_IN, zi);
}

Matrix Butterworth(Matrix X_IN, double A, double w_n, double epsilon) pure {
	// This function does not WORK NOT TESTED
	Matrix b_coeff = new Matrix([A]);
	Matrix a_coeff = new Matrix([w_n*w_n, 2*epsilon*w_n, 1.0]); 
	Matrix zi = new Matrix([ 0. ]);	

	return filter(b_coeff, a_coeff, X_IN, zi);
}
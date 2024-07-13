module safepine_core.math.matrix_struct;

// D
import std.conv: to;
import std.math: abs, pow;

// Safepine
import matrix_size;
import safepine_core.project;

enum ScalarOperations_t {
	Success, 
	Error_Type, 
	Error_Shape};

enum VectorOperations_t {
	Success, 
	Error_Type, 
	Error_Multiplication_Size, 
	Error_Sum_Size, 
	Error_Subtract_Size};

@nogc @safe struct MatrixStruct {
public:
enum Reshape_t {
	Success,
	Error_Row_Length,
	Error_Column_Length
}

enum Set_t {
	Success, 
	Error_Out_Of_Index, 
	Error_Not_Initialized, 
	Error_Input_Matrix_Not_Valid_Row_Length, 
	Error_Input_Matrix_Not_Valid_Column_Length,
	Error_Input_Vector_Not_Valid};

enum LUPDecomposition_t {
	Success, 
	Error_Not_Square, 
	Error_Determinant_Zero}	

enum Inv_t {
	Success,
	Error_Not_Square,
	Error_Determinant_Zero
}

@nogc @safe pure Reshape_t 
Reshape(int nr_IN, int nc_IN) {
	if(nr_IN >= MAXROWS) return Reshape_t.Error_Row_Length;
	if(nc_IN >= MAXCOLUMNS) return Reshape_t.Error_Column_Length;
	_nr = nr_IN;
	_nc = nc_IN;
	return Reshape_t.Success;
}

@nogc @safe pure const int 
Rows() {return _nr;};

@nogc @safe pure const int 
Columns() {return _nc;};

@nogc @safe pure const double 
Get(int r_IN, int c_IN) {return _m[r_IN][c_IN];}; 

@nogc @safe pure const double[MAXCOLUMNS][MAXROWS]
Get() {return _m;}; 

@nogc @safe pure const MatrixStruct
Get(int c_IN) {
	MatrixStruct column;
	column.Reshape(_nr, 1);
	for (int r = 0; r<_nr; ++r) {
		column.Set(r, 0, Get(r, c_IN));
	}
	return column;
}

@nogc @safe pure Set_t
Set(int r_IN, int c_IN, double val_IN) {
	if(_nr <= 0 || _nc <= 0) return Set_t.Error_Not_Initialized;
	if(r_IN < _nr && c_IN < _nc) {
		_m[r_IN][c_IN] = val_IN;
		return Set_t.Success;
	}
	else return Set_t.Error_Out_Of_Index;
}

@nogc @safe pure Set_t
Set(double val_IN) {
	Set_t result;
	for(int r = 0; r<_nr; ++r) {
		for(int c = 0; c<_nc; ++c) {
			result = Set(r, c, val_IN);
			if(result != Set_t.Success) return result;
		}
	}
	return result;
}

@nogc @safe pure Set_t
Set(
	const double[][] matrix_IN,
	int rowLength_IN, 
	int columnLength_IN) 
{
	Set_t result;
	if(matrix_IN.length <= 0) return Set_t.Error_Input_Matrix_Not_Valid_Row_Length;
	if(matrix_IN[0].length <= 0) return Set_t.Error_Input_Matrix_Not_Valid_Column_Length;
	Reshape(rowLength_IN, columnLength_IN);
	for(int r = 0; r<_nr; ++r) {
		for(int c = 0; c<_nc; ++c) {
			result = Set(r, c, matrix_IN[r][c]);
			if(result != Set_t.Success) return result;
		}
	}
	return result;
}

@nogc pure Set_t
Set(
	const double[] vector_IN, 
	int columnLength_IN) 
{
	Set_t result;
	if(vector_IN.length == 0) return Set_t.Error_Input_Vector_Not_Valid;
	Reshape(1, toInt(vector_IN.length));	
	for(int c = 0; c<_nc; ++c) {
		result = Set(0, c, vector_IN[c]);
		if(result != Set_t.Success) return result;
	}
	return result;
}

@nogc @safe pure const LUPDecomposition_t 
LUPDecomposition(
	ref MatrixStruct lower,
	ref MatrixStruct upper,
	ref MatrixStruct pivot) 
{
	int nr = Rows;
	int nc = Columns;

	if(nr == nc) {	
		lower.Reshape(nr, nc);
		lower.Set(0.0);
		upper.Reshape(nr, nc);
		upper.Set(0.0);
		pivot.Reshape(nr, nc);	
		pivot.Set(0.0);	

    	MatrixStruct perm; // perm[0:nc]
    	perm.Reshape(1, nc);
    	for(int c = 0; c<=nc; ++c) perm.Set(0, c, c);
    	double[MAXCOLUMNS][MAXROWS] input1 = Get();
    	
	    for (int j = 0; j < nr; ++j) {
	        int max_index = j;
	        double max_value = 0;
	        for (int i = j; i < nr; ++i) {
	            double value = abs(input1[toInt(perm.Get(0,i))][j]);
	            if (value > max_value) {
	                max_index = i;
	                max_value = value;
	            }
	        }
	        if (max_value <= float.epsilon)
	            return LUPDecomposition_t.Error_Determinant_Zero;
	        if (j != max_index) {
	        	double dummy = perm.Get(0,j);
	        	perm.Set(0, j, perm.Get(0,max_index));
	        	perm.Set(0, max_index, dummy);
	        }
	        int jj = toInt(perm.Get(0,j));
	        for (int i = j + 1; i < nr; ++i) {
	            int ii = toInt(perm.Get(0,i));
	            input1[ii][j] /= input1[jj][j];
	            for (int k = j + 1; k < nr; ++k)
	                input1[ii][k] -= input1[ii][j] * input1[jj][k];
	        }
	    }
	    
	    for (int j = 0; j < nr; ++j) {
	    	lower.Set(j,j, 1);
	        for (int i = j + 1; i < nr; ++i)
	        	lower.Set(i, j, input1[toInt(perm.Get(0,i))][j]);
	        for (int i = 0; i <= j; ++i)
	        	upper.Set(i, j, input1[toInt(perm.Get(0,i))][j]);
	    }
	    
    	for (int i = 0; i < nr; ++i)
    		pivot.Set(i, toInt(perm.Get(0,i)), 1.0);
	}
	else {
		return LUPDecomposition_t.Error_Not_Square;
	}  	  
	return LUPDecomposition_t.Success;
}

@nogc @safe pure const double 
Det()  {
	MatrixStruct[3] LUP;
	LUPDecomposition(LUP[0], LUP[1], LUP[2]);
	return Det(LUP);
}

@nogc @safe pure const MatrixStruct 
T() {
	MatrixStruct transpose;
	transpose.Reshape(Columns, Rows);
	transpose.Set(0.0);
	for (int r=0; r<transpose.Rows; r++) {
		for (int c=0; c<transpose.Columns; c++) {
			transpose.Set(r,c, Get(c,r));
		}
	}
	return transpose;
}

@nogc @safe pure const Inv_t 
Inv(ref MatrixStruct inverted_IN) {
	int nr = Rows;
	int nc = Columns;

	if(nr == nc) {	
		MatrixStruct[3] LUP;	
		LUPDecomposition(LUP[0], LUP[1], LUP[2]);  

		double determinant = Det(LUP);
	    if (abs(determinant) <= float.epsilon) { 
	        return Inv_t.Error_Determinant_Zero; 
	    } 		

		MatrixStruct e = Identity(nr); 

	    inverted_IN.Reshape(nr, nc);   
	    MatrixStruct x;
	    for (int i = 0; i<_nr; ++i) {
		    x = LUPSolve(LUP[0], LUP[1], LUP[2], e.Get(i));
		    for(int j = 0; j<_nr; ++j) {
		    	inverted_IN.Set(j,i,x.Get(j,0));
		    }
	    }
	    return Inv_t.Success;
    }	
	else {
		return Inv_t.Error_Not_Square;
	}    
} 

private:
@nogc @safe pure const double 
Det(const ref MatrixStruct[3] LUP_IN) {
	MatrixStruct P = LUP_IN[2];

	int nr = Rows;
	double det = 1.0;
	double diagonal_sum = 0.0;
	for (int i = 0; i<nr; ++i) {
		diagonal_sum += P.Get(i,i);
	}

	int nswaps = nr - toInt(diagonal_sum);
	for(int i = 0; i< nr; ++i) {
		det *= LUP_IN[1].Get(i,i);
	}
	if(nswaps == 0) return det;
	else return det*pow(-1,nswaps - 1);
}

int _nr = -1;
int _nc = -1;
double[MAXCOLUMNS][MAXROWS] _m;
}

@nogc @safe pure ScalarOperations_t 
ScalarOperations(
	const ref MatrixStruct A_IN, 
	const double val_IN, 
	ref MatrixStruct result_OUT,
	const string operation_IN)  
{
	result_OUT.Reshape(A_IN.Rows, A_IN.Columns); // reshape to mXn
	for(int r = 0; r < A_IN.Rows; r++) {
		for(int c = 0; c < A_IN.Columns; c++) {
			if(operation_IN == "+") result_OUT._m[r][c] = A_IN._m[r][c] + val_IN;
			else if (operation_IN == "-") result_OUT._m[r][c] = A_IN._m[r][c] - val_IN;
			else if (operation_IN == "*") result_OUT._m[r][c] = A_IN._m[r][c] * val_IN;
			else if (operation_IN == "/") result_OUT._m[r][c] = A_IN._m[r][c] / val_IN;
			else return ScalarOperations_t.Error_Type;
		}
	}
	return ScalarOperations_t.Success;
}

@nogc @safe pure VectorOperations_t 
VectorOperations(
	const ref MatrixStruct A_IN, 
	const ref MatrixStruct B_IN, 
	ref MatrixStruct result_OUT,
	const string operation_IN) 
{
	if(operation_IN == "*") {
		if(A_IN.Columns == B_IN.Rows) { // Verify mXn * nXp condition
			result_OUT.Reshape(A_IN.Rows, B_IN.Columns); // reshape to mXp
			for (int r = 0; r<A_IN.Rows; r++) {
				for (int c = 0; c<B_IN.Columns; c++) {
					for (int k = 0; k<A_IN.Columns; k++) {
						if(k == 0) result_OUT._m[r][c] = A_IN._m[r][k] * B_IN._m[k][c];
						else result_OUT._m[r][c] += A_IN._m[r][k] * B_IN._m[k][c];
					}
				}
			}	
		}	
		else return VectorOperations_t.Error_Multiplication_Size;
		return VectorOperations_t.Success;		
	}
	else if (operation_IN == "+" || operation_IN == "-") {
		if(B_IN.Rows == A_IN.Rows && B_IN.Columns == A_IN.Columns) {
			result_OUT.Reshape(A_IN.Rows, A_IN.Columns); // reshape to mXn
			for(int r = 0; r < A_IN.Rows; ++r) {
				for(int c = 0; c < A_IN.Columns; ++c) {
					if(operation_IN == "+") result_OUT._m[r][c] = A_IN._m[r][c] + B_IN._m[r][c];
					else if (operation_IN == "-") result_OUT._m[r][c] = A_IN._m[r][c] - B_IN._m[r][c];
				}
			}		
		}
		else return VectorOperations_t.Error_Sum_Size;
		return VectorOperations_t.Success;	
	}
	return VectorOperations_t.Error_Type;
}

@nogc @safe pure MatrixStruct
LUPSolve(
	const ref MatrixStruct L, 
	const ref MatrixStruct U, 
	const ref MatrixStruct P, 
	const MatrixStruct b)
{
    MatrixStruct z;
    VectorOperations(P, b, z, "*");
    MatrixStruct x = LUSolve(L, U, z);
    return x;
}

@nogc @safe pure MatrixStruct 
LUSolve(
	const ref MatrixStruct L, 
	const ref MatrixStruct U, 
	const ref MatrixStruct b)
{	
    MatrixStruct y = ForwardSubstitution(L, b);
    MatrixStruct x = BackwardSubstitution(U, y);
    return x;
}

@nogc @safe pure MatrixStruct 
ForwardSubstitution(
	const ref MatrixStruct L, 
	const ref MatrixStruct b)
{
    int nr = L.Rows;
    MatrixStruct x;
    x.Reshape(nr, 1);
    x.Set(0.0);    
    for (int i = 0; i<nr; ++i) {
        double tmp = b.Get(i,0);
        for (int j = 0; j<i; ++j){
            tmp -= L.Get(i,j) * x.Get(j,0);
        }
        x.Set(i,0,tmp / L.Get(i,i));
    }
    return x;
}

@nogc @safe pure MatrixStruct
BackwardSubstitution(
	const ref MatrixStruct U, 
	const ref MatrixStruct b)
{
    int nr = U.Rows;
    MatrixStruct x;
    x.Reshape(nr, 1);
    x.Set(0.0);
    for (int i = nr-1; i>-1; --i) {
        double tmp = b.Get(i,0);
        for (int j = i+1; j<nr; ++j){
            tmp -= U.Get(i,j) * x.Get(j,0);
    	}
        x.Set(i,0,tmp / U.Get(i,i));
    }
    return x;    
}

@nogc @safe pure MatrixStruct
Identity(int n) {
	MatrixStruct result;
	result.Reshape(n, n);
	result.Set(0.0);
	for(int i = 0; i<n; ++i) {
		result.Set(i,i,1.0);
	}	
	return result;
}

@nogc @safe pure int 
toInt(ulong u) {
	assert(u<=int.max);
	return cast(int)u;
}

@nogc @safe pure int 
toInt(double d) {
	assert(d<=int.max);
	return cast(int)d;
}

string 
toCSV(const ref MatrixStruct matrix_IN) {
	string result;
	for(int r = 0; r < matrix_IN.Rows; ++r) {
		for(int c = 0; c < matrix_IN.Columns; ++c) {
			result ~= to!string(matrix_IN.Get(r,c));
			if(c == matrix_IN.Columns - 1) result ~= "\n";
			else result ~= ",";
		}
	}
	return result;
}
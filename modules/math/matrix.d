module safepine_core.math.matrix;

// D
import std.conv: to; 
import std.math: abs, pow, sin;
import std.random: dice;

// Safepine
import safepine_core.project;
import safepine_core.math.matrix_struct: 
ScalarOperations,
ScalarOperations_t,
VectorOperations,
VectorOperations_t,
MatrixStruct,
LUPSolve;

string 
toCSV(const Matrix matrix_IN) {
	string result;
	for(int r = 0; r < matrix_IN.Rows; ++r) {
		for(int c = 0; c < matrix_IN.Columns; ++c) {
			result ~= to!string(matrix_IN[r,c]);
			if(c == matrix_IN.Columns - 1) result ~= "\n";
			else result ~= ",";
		}
	}
	return result;
}

double[] 
toDouble_v(const Matrix matrix_IN) {
	double[] vector_double;
	if(matrix_IN._m.Columns == 1) {
		for(int r = 0; r<matrix_IN._m.Rows; ++r) {
			vector_double ~= matrix_IN._m.Get(r,0);
		}			
	}
	else if(matrix_IN._m.Rows == 1) {
		for(int c = 0; c<matrix_IN._m.Columns; ++c) {
			vector_double ~= matrix_IN._m.Get(0,c);
		}	
	}
	else throw new Exception("Not a vector. Row or columns length must be zero. 
		Rows: "~to!string(matrix_IN._m.Rows) ~ ", Columns: " ~ to!string(matrix_IN._m.Columns));
	return vector_double;
}

int[] 
toInt_v(const Matrix matrix_IN) {
	int[] vector_int;
	if(matrix_IN._m.Columns == 1) {
		for(int r = 0; r<matrix_IN._m.Rows; ++r) {
			vector_int ~= to!int(matrix_IN._m.Get(r,0));
		}			
	}
	else if(matrix_IN._m.Rows == 1) {
		for(int c = 0; c<matrix_IN._m.Columns; ++c) {
			vector_int ~= to!int(matrix_IN._m.Get(0,c));
		}	
	}
	else throw new Exception("Not a vector. Row or columns length must be zero.");
	return vector_int;
}

double[][] 
toDouble_m(const Matrix matrix_IN) {
	double[][] matrix_double;
	for(int r = 0; r < matrix_IN._m.Rows; ++r) {
		matrix_double ~= [[matrix_IN._m.Get(r,0)]];
		for(int c = 1; c < matrix_IN._m.Columns; ++c) {
			matrix_double[r] ~= matrix_IN._m.Get(r,c);
		}
	}	
	return matrix_double;
}

pure Matrix 
sin(const Matrix matrix_IN) {
	Matrix sin_matrix = new Matrix(matrix_IN.Size()[0], matrix_IN.Size()[1], 0.0);
	for(int r = 0; r < matrix_IN._m.Rows; ++r) {
		for(int c = 0; c < matrix_IN._m.Columns; ++c) {
			sin_matrix[r,c] = sin(matrix_IN._m.Get(r,c));
		}
	}
	return sin_matrix;
}

Matrix noise(const Matrix matrix_IN, double mean, double var) {
	Matrix noise_matrix = new Matrix(matrix_IN.Size()[0], matrix_IN.Size()[1], 0.0);
	for(int r = 0; r < matrix_IN._m.Rows; ++r) {
		for(int c = 0; c < matrix_IN._m.Columns; ++c) {
			noise_matrix[r,c] = mean + var*2.0*(dice(0.5, 0.5)-0.5);
		}
	}
	return noise_matrix;
}

pure Matrix 
Diag(const ref Matrix rowVector_IN) {
	if(rowVector_IN.Rows != 1 || rowVector_IN.Rows < 1) {
		string diag_row_err = "Diag: input not a row vector";
		throw new Exception(diag_row_err);		
	}
	Matrix result = new Matrix(rowVector_IN.Columns, rowVector_IN.Columns, 0.0);
	for(int i = 0; i<rowVector_IN.Columns; ++i){
		result[i, i] = rowVector_IN[0,i];
	}
	return result;
}

class Matrix {
public:
this() {
}

pure 
this(
	const int rowLength_IN, 
	const int columnLength_IN, 
	const double n) 
{
	_m.Reshape(rowLength_IN, columnLength_IN);
	_m.Set(n);
}

pure 
this(const double[][] matrixRHS_IN) {
	MatrixStruct.Set_t result;
	result = _m.Set(matrixRHS_IN, to!int(matrixRHS_IN.length), to!int(matrixRHS_IN[0].length));
}

pure 
this(const double[] rowvectorRHS_IN) {
	_m.Set(rowvectorRHS_IN, to!int(rowvectorRHS_IN.length));   	
}

pure 
this(const int[int] x) {
	if(x.length == 1) {
		foreach(val; x.keys) {
			_m.Reshape(1, x[val]-val+1);
			_m.Set(0.0);			
			for(int r = 0; r < _m.Rows; ++r) {
				for(int c = 0; c < _m.Columns; ++c) {
					_m.Set(r, c, c+val);
				}
			}   			
		}
	}
	else {
		throw new Exception("Associative array length must be 1.");
	}
}

pure void 
opAssign(const double[][] matrixRHS_IN) {
	MatrixStruct.Set_t result;
	result = _m.Set(matrixRHS_IN, to!int(matrixRHS_IN.length), to!int(matrixRHS_IN[0].length)); 
}	

pure void 
opAssign(const double[] matrixRHS_IN) {
	MatrixStruct.Set_t result;
	result = _m.Set(matrixRHS_IN, to!int(matrixRHS_IN.length)); 
}		

pure void 
opOpAssign(string operation_IN)(const Matrix rhs_IN) {
	Matrix result = new Matrix(_m.Rows, _m.Columns, 0.0);
	if(operation_IN == "+"){	
		result = this + rhs_IN;	
		_m = result._m;		
	}
	else if(operation_IN == "-"){	
		result = this - rhs_IN;	
		_m = result._m;		
	}    	
	else if(operation_IN == "*"){	
		result = this * rhs_IN;	
		_m.Reshape(result.Size()[0], result.Size()[1]);
		_m = result._m;
	}    	
}    

pure void 
opOpAssign(string operation_IN)(const double rhs_IN) {
	Matrix result = new Matrix(_m.Rows, _m.Columns, 0.0);
	if(operation_IN == "+"){	
		result = this + rhs_IN;		
		_m = result._m;	
	}
	else if(operation_IN == "-"){	
		result = this - rhs_IN;		
		_m = result._m;	
	}
	else if(operation_IN == "*"){	
		result = this * rhs_IN;		
		_m = result._m;	
	}
	else if(operation_IN == "/"){	
		result = this / rhs_IN;		
		_m = result._m;	
	}  
	else if(operation_IN == "~"){
		if(_m.Rows > 1) 
			throw new Exception("Append error: Only works with column vectors.");
		if(!empty())
			_m.Reshape(_m.Rows, _m.Columns+1);
		else
			_m.Reshape(1, 1);
		_m.Set(0, _m.Columns-1, rhs_IN);		
	}		 	
}      

pure Matrix 
opBinary(string operation_IN)(const Matrix rhs_IN) {
	Matrix result;
	bool sum = operation_IN == "+";
	bool subtract = operation_IN == "-";
	bool multiply = operation_IN == "*";
	int rhs_nr = rhs_IN._m.Rows;
	int rhs_nc = rhs_IN._m.Columns;
	if(sum) {
		result = new Matrix(_m.Rows, _m.Columns, 0.0);
		if(VectorOperations(_m, rhs_IN._m, result._m, "+") != VectorOperations_t.Success) {
			string matrix_addition_err = "matrix add: wrong dimensions.";
			throw new Exception(matrix_addition_err);			
		}
	}
	if(subtract) {
		result = new Matrix(_m.Rows, _m.Columns, 0.0);
		if(VectorOperations(_m, rhs_IN._m, result._m, "-") != VectorOperations_t.Success) {
			string matrix_addition_err = "matrix subtract: wrong dimensions.";
			throw new Exception(matrix_addition_err);			
		}
	}	
	else if(multiply) {	
		result = new Matrix(_m.Rows, rhs_IN._m.Columns, 0.0);
		if (VectorOperations(_m, rhs_IN._m, result._m, "*") != VectorOperations_t.Success) {
			string matrix_multip_err = "matrix multiplication: wrong dimensions.";
			throw new Exception(matrix_multip_err);
		}			
	}
	return result;
}    

pure const Matrix 
opBinary(string operation_IN)(const double rhs_IN) {
	Matrix result = new Matrix(_m.Rows, _m.Columns, 0.0);
	ScalarOperations(_m, rhs_IN, result._m, operation_IN);		 	
	return result;
}    

pure const override bool 
opEquals(Object o) {
	auto rhs = cast(const Matrix)o;
	if(rhs.Size()[0] == Size()[0] && rhs.Size[1] == Size[1]){
		for(int r = 0; r<rhs._m.Rows; ++r) {
			for(int c = 0; c<rhs._m.Columns; ++c) {
				if(rhs._m.Get(r,c) != _m.Get(r,c)) return false;
			}
		}
	}
	else return false;
	return true;
}

pure void 
opIndexAssign(double val, int r, int c) {
	_m.Set(r, c, val);
}

pure const double 
opIndex(int r, int c) {
	if(r >= _m.Rows) {
		string row_err = "opIndex[][]: row length error";
		throw new Exception(row_err);
	}
	if(c >= _m.Columns) {
		string row_err = "opIndex[][]: column length error";
		throw new Exception(row_err);
	}	
	return _m.Get(r,c);
}

pure const Matrix 
opIndex(int r) {
	if(r >= _m.Rows) {
		string row_err = "opIndex[]: row length error";
		throw new Exception(row_err);
	}	
	Matrix row_vector;
	if(r < _m.Rows) {
		row_vector = new Matrix(1, _m.Columns, 0.0);
		for (int c = 0; c<_m.Columns; ++c) {
			row_vector[0, c] = _m.Get(r,c);
		}
	}
	else throw new Exception("Can't access row.");
	return row_vector;
}

pure const Matrix 
T() {
	Matrix transpose = new Matrix(_m.Columns, _m.Rows, 0.0);
	for (int r=0; r<transpose.Size()[0]; r++) {
		for (int c=0; c<transpose.Size()[1]; c++) {
			transpose._m.Set(r,c, _m.Get(c,r));
		}
	}
	return transpose;
}

pure const Matrix 
Inv() {
	Matrix inverse_matrix;
	MatrixStruct inverse_struct;
	inverse_struct.Inv_t result = _m.Inv(inverse_struct);
	if(result == inverse_struct.Inv_t.Error_Not_Square)
		throw new Exception("Inverse error: not square\n");
	if(result == inverse_struct.Inv_t.Error_Determinant_Zero)
		throw new Exception("Inverse error: determinant must be non-zero\n"); 
	inverse_matrix = new Matrix(Size()[0], Size()[1], 0.0);
	inverse_matrix._m = inverse_struct;
	return inverse_matrix;
}

pure const double 
Det() {
	return _m.Det();
}

pure const double 
Sum() {
	double all_sum = 0.0;
	for(int r = 0; r < _m.Rows; r++) {
		for(int c = 0; c < _m.Columns; c++) {
			all_sum += _m.Get(r,c);
		}
	}
	return all_sum;		
}    

pure const double 
Sum(const int r) {
	if(r < _m.Rows) {
		double row_sum = 0.0;
		for(int c = 0; c < _m.Columns; c++) {
			row_sum += _m.Get(r,c);
		}
		return row_sum;	
	}
	else {
		string sum_row_err = "Sum row: index out of bounds";
		throw new Exception(sum_row_err);
	}
}	

pure void 
zeros() {
	for(int r = 0; r < _m.Rows; ++r) {
		for(int c = 0; c < _m.Columns; ++c) {
			_m.Set(r, c, 0.0);
		}
	}
}

pure void 
ones() {
	for(int r = 0; r < _m.Rows; ++r) {
		for(int c = 0; c < _m.Columns; ++c) {
			_m.Set(r, c, 1.0);
		}
	}
}

pure const Matrix 
Diag() {
	if(_m.Rows != _m.Columns) {
		string diag_square_err = "Diag: not a square";
		throw new Exception(diag_square_err);		
	}
	Matrix result = new Matrix(1, _m.Rows, 0.0);
	for(int i = 0; i<_m.Rows; ++i){
		result[0, i] = _m.Get(i,i);
	}
	return result;
}

pure const Matrix 
Identity(int n) {
	Matrix result = new Matrix(n, n, 0.0);
	for(int i = 0; i<n; ++i) {
		result[i,i] = 1.0;
	}
	return result;
}

pure const int[2] 
Size() {
	return [_m.Rows, _m.Columns];
}    

pure const int 
Rows() {
	return _m.Rows;
}    

pure const int 
Columns()  {
	return _m.Columns;
}    

pure const bool 
empty() {
	if(_m.Rows <= 0 && _m.Columns <= 0) return true;
	else return false;
}    

pure const Matrix
Solve(Matrix b_IN) {
	MatrixStruct[3] LUP;
	MatrixStruct result;
	Matrix result_M;
	_m.LUPDecomposition(LUP[0], LUP[1], LUP[2]);
	result = LUPSolve(LUP[0], LUP[1], LUP[2], b_IN._m);
	result_M = new Matrix(result.Rows, result.Columns, 0.0);
	result_M._m = result;
	return result_M; 
}

private:
MatrixStruct _m;
}
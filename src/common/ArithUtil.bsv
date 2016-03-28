import Types::*;


//functions for ones complement arithmetic.

//addition.
//overflow could be an issue.
//As in the original AGC, (-1) + (+1) = (-0)
function Bit#(n) addOnes (Bit#(n) a, Bit#(n) b);
    //
    Bit#(n+1) sum_u = {0, a[n-1:0]} + b[n-1:0];
    Bit#(n) sum;
    if (sum_u[n] == 1) begin //if the carry bit overflows to the left
        //wrap it back around to the right.
	sum_u = sum_u[n-1:0] + 1;
	sum = sum_u[n-1:0];
    end
    
    //return truncated sum.
    sum = sum_u[n-1:0];
    return sum;

endfunction

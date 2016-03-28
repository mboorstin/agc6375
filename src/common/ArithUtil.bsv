import Types::*;

//TODO: test all.

//single and double precision integers
typedef Bit#(15) SP;
typedef Bit#(30) DP;


//functions for ones complement arithmetic

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

//subtraction.
//a - b is returned.
function Bit#(n) subOnes (Bit#(n) a, Bit#(n) b);
    //invert b, add.
    return addOnes(a, ~b);
endfunction


//functions for converting SP/DP values and performing arithmetic with them
function SP addSP (SP a, SP b);
    return addOnes(a, b);
endfunction

function DP addDP(DP a, DP b);
    //TODO
endfunction

//sometimes DP values can have inconsistent signs.  The output of this function will have consistent signs.
function DP makeConsistentSign(DP a);
    DP out;

    if (a[29] != a[14]) begin //if not currently consistent
        SP high = a[29:15];
	SP low = a[14:0];
	
	SP new_high;
	SP new_low;

	if (a[29] == 1) begin //if larger portion is negative
            new_high = addOnes(high, fromInteger(1)); //move amount from smaller SP to larger SP
	    new_low = subOnes(low, 15'b0_100_000_000_000_000);
	end
	else begin //otherwise
            new_high = subOnes(high, fromInteger(1)); //move amount from larger SP to smaller SP
	    new_low = addOnes(low, 15'b0_100_000_000_000_000);
	end
	out = {new_high, new_low}; //new value (should be equivalent to old value)
    end
    else begin
        out = a;
    end
    return out;
endfunction


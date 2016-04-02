import Types::*;

//TODO: write and test 1) divide and 2) faster adder.

//single and double precision integers
typedef Bit#(15) SP;
typedef Bit#(30) DP;


//functions for ones complement arithmetic

//addition.
//overflow could be an issue.
//As in the original AGC, (-1) + (+1) = (-0)
function Bit#(n) addOnes (Bit#(n) a, Bit#(n) b);
    //
    Bit#(TAdd#(n,1)) sum_u = addOnesCarry(a, b);

    Bit#(n) sum;
    Bit#(1) msb = truncateLSB(sum_u);
    
    if (msb == 1) begin //if the carry bit overflows to the left
        //wrap it back around to the right.
        sum_u = truncate(addOnesCarry(sum_u, fromInteger(1)));
    end

    //return truncated sum.
    sum = truncate(sum_u);

    return sum;

endfunction

//returns the sum of a and b with a carry bit as the MSB
function Bit#(TAdd#(n,1)) addOnesCarry (Bit#(n) a, Bit#(n) b);
    //
    Bit#(TAdd#(n,1)) sum_u = {1'b0, a} + {1'b0, b};
    
    return sum_u;

endfunction

//subtraction.
//a - b is returned.
function Bit#(n) subOnes (Bit#(n) a, Bit#(n) b);
    //invert b, add.
    return addOnes(a, ~b);
endfunction

//multiplication
//a * b is returned.
//functions by converting to 2's complement and multiplying.
//takes in two SP values, outputs one DP value
//
function DP multOnes (SP a, SP b);
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    Bit#(15) u_a = (sign_a == 1) ? (~a[14:0]) : a[14:0];
    Bit#(15) u_b = (sign_b == 1) ? (~b[14:0]) : b[14:0];

    //convert magnitudes to 2's complement
    Bit#(15) twos_a = toTwos(u_a);
    Bit#(15) twos_b = toTwos(u_b);
    Bit#(28) prod2s = zeroExtend(twos_a) * zeroExtend(twos_b);
    DP prod1s;

    if (sign_a != sign_b) begin
        prod1s = {1'b1, ~prod2s[27:14], 1'b1, ~prod2s[13:0]};
    end
    else begin
        prod1s = {1'b0, prod2s[27:14], 1'b0, prod2s[13:0]};
    end

    return prod1s;
endfunction

//returns 2's complement version of the input 1's complement value
function Bit#(n) toTwos(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(n) twos = (sign_a == 1) ? (a+1) : a;
    return twos;
endfunction

//returns 1's complement version of the input 2's complement value
//does not work for a = 1000000000...0
function Bit#(n) toOnes(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(n) ones = (sign_a == 1) ? (a-1) : a;
    return ones;
endfunction

//functions for converting SP/DP values and performing arithmetic with them
function SP addSP (SP a, SP b);
    return addOnes(a, b);
endfunction

/*
//faster, but has overflow issues
function DP addDP(DP a, DP b);
    //holders
    SP a1 = a[29:15];
    SP a2 = a[14:0];
    SP b1 = b[29:15];
    SP b2 = b[14:0];
    SP out1;
    SP out2;

    //preliminary addition
    Bit#(16) result2 = addOnesCarry(a2,b2);
    Bit#(15) result1 = addOnes(a1,b1);
    Bit#(16) carry1;

    //deal with carries
    if (result2[14] == 1'b0) begin
        carry1 = addOnesCarry(result1, 15'b1); //add 1
    end
    else begin
        carry1 = addOnesCarry(result1, 15'o77776); //add -1
    end


    out2 = truncate(result2);

    return {out1,out2};
endfunction*/


function DP addDP(DP a, DP b);
    //holders
    DP a_con = makeConsistentSign(a);
    DP b_con = makeConsistentSign(b);

    //preliminary addition
    Bit#(29) result = addOnes({a_con[29:15],a_con[13:0]},{b_con[29:15],b_con[13:0]});

    DP out = {result[28:14], result[28], result[13:0]};

    return out;
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
            new_low = subOnes(low, 15'b100_000_000_000_000);
        end
        else begin //otherwise
            
            if (high == 15'b1) begin //be careful of special case; can end up with -0 instead of 0
                new_high = 15'b0; //move amount from larger SP to smaller SP
            end
            else begin
                new_high = subOnes(high, 15'b1);
            end

            new_low = addOnes(low, 15'b100_000_000_000_000);
        end
        out = {new_high, new_low}; //new value (should be equivalent to old value)
    end
    else begin
        out = a;
    end
    return out;
endfunction

function Fmt displayDecimal(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(TSub#(n,1)) mag = truncate(a);
    Bit#(1) sign = truncateLSB(a);
    Fmt out;

    if (sign == 1'b1) begin
        out = $format("-%d", ~mag);
    end
    else begin
        out = $format("+%d", mag);
    end

    return out;
endfunction

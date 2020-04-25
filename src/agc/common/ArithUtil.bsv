import Types::*;


//single and double precision integers
typedef Bit#(15) SP;
typedef Bit#(30) DP;

//Divider module interface
//req begins the division a / b
//a call to resp will only be successful when the division is done.
//a call to req, if division is ongoing, will overwrite current division.
//DP returned by resp is of the form {q,r} with q and r of type SP
//q = floor(a/b) = quotient
//r = a - (q * b) = remainder
interface Divider;
    method Action req(DP a, SP b);
    method ActionValue#(DP) resp();
endinterface


//functions for ones complement arithmetic

//addition.
//automatically overflow-corrected.
//assumes a leading sign bit.
//As in the original AGC, (-1) + (+1) = (-0)
function Bit#(TAdd#(n,1)) addOnesOverflow (Bit#(n) a, Bit#(n) b)
        provisos(Add#(a__, b__, TAdd#(n,1)),
                 Add#(1, a__, n),
                 Add#(c__, a__, TAdd#(n,2)));
    //

    //unsigned a and b magnitudes
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);
    //Bit#(n) u_a = (sign_a == 0) ? a : ~a;
    //Bit#(n) u_b = (sign_b == 0) ? b : ~b;
    Bit#(TAdd#(n,1)) a_long = {sign_a, a};
    Bit#(TAdd#(n,1)) b_long = {sign_b, b};


    Bit#(TAdd#(n,2)) sum_u = addOnesCarry(a_long, b_long);

    Bit#(2) msb = truncateLSB(sum_u);

    if (msb[1] == 1) begin //if the carry bit overflows to the left
        //wrap it back around to the right.
        sum_u = addOnesCarry(truncate(sum_u), fromInteger(1));
    end

    return truncate(sum_u);

endfunction

//automatically overflow corrected
//ones complement addition
function Bit#(n) addOnesCorrected (Bit#(n) a, Bit#(n) b)
        provisos(Add#(a__, b__, TAdd#(n,1)),
                 Add#(1, a__, n),
                 Add#(c__, a__, TAdd#(n,2)));
    //
    //get full sum
    Bit#(TAdd#(n,1)) sum_u = addOnesOverflow(a,b);

    Bit#(1) msb = truncateLSB(sum_u);
    Bit#(n) corrected_sum = {msb, truncate(sum_u)};

    return corrected_sum;
endfunction

//non-overflow corrected
//ones complement addition
function Bit#(n) addOnesUncorrected (Bit#(n) a, Bit#(n) b)
        provisos(Add#(a__, b__, TAdd#(n,1)),
                 Add#(1, a__, n),
                 Add#(c__, a__, TAdd#(n,2)));
    //
    //get full sum
    Bit#(TAdd#(n,1)) sum_u = addOnesOverflow(a,b);

    return truncate(sum_u);

endfunction

//overflow correction of a value like that in the accumulator
//bit n-1 is only used for overflow correction / checking
//usual use case is transferring an accumulator value outside
//running it on a value which has not overflowed should return the same value.
function Bit#(TSub#(n, 1)) overflowCorrect(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) msb = truncateLSB(a);
    Bit#(TSub#(n,2)) mag = truncate(a);
    Bit#(TSub#(n,1)) result = {msb, mag}; //extract magnitude bits and corrected sign bit from a
    return result;
endfunction

//returns the sum of a and b with a carry bit as the MSB
function Bit#(TAdd#(n,1)) addOnesCarry (Bit#(n) a, Bit#(n) b);
    //
    Bit#(TAdd#(n,1)) sum_u = {1'b0, a} + {1'b0, b};

    return sum_u;
endfunction

//subtraction.
//a - b is returned.
//version that is automatically corrected for overflow
function Bit#(n) subOnesCorrected (Bit#(n) a, Bit#(n) b)
        provisos(Add#(a__, b__, TAdd#(n,1)),
                 Add#(1, a__, n),
                 Add#(c__, a__, TAdd#(n,2)));
    //invert b, add.
    return addOnesCorrected(a, ~b);
endfunction

//version that is not automatically corrected for overflow
function Bit#(n) subOnesUncorrected (Bit#(n) a, Bit#(n) b)
        provisos(Add#(a__, b__, TAdd#(n,1)),
                 Add#(1, a__, n),
                 Add#(c__, a__, TAdd#(n,2)));
    //invert b, add.
    return addOnesUncorrected(a, ~b);
endfunction

//for MSU
//takes in a and b, both in 2's complement, and subtracts them.
function Bit#(n) modularSubtract(Bit#(n) a, Bit#(n) b)
        provisos(Add#(a__, 1, n));
    Bool pos = (a >= b);
    Bit#(n) u_result = pos ? (a - b) : (b - a); //unsigned answer
    if (u_result == signExtend(1'b1)) begin //handle special edge case to give +0
        u_result = zeroExtend(1'b0);
    end

    //add sign
    Bit#(TSub#(n, 1)) result_trunc = truncate(u_result);
    Bit#(n) result = pos ? {1'b0, result_trunc} : {1'b1, ~result_trunc};

    return result;
endfunction

// This function appears in a few places (namely DINC and DIM).  If val == +/-0, leave
// it as is; if it's > 0 then subtract 1; if its < = then add 1.
function Bit#(n) subOrAddNonZero(Bit#(n) val)
        provisos(Add#(1, a__, n),
            Add#(a__, b__, TAdd#(n, 1)),
            Add#(c__, a__, TAdd#(n,2))
            );
    if ((val == 0) || (val == ~0)) begin
        return val;
    end else if (val[valueOf(TSub#(n, 1))] == 0) begin
        return subOnesUncorrected(val, 1);
    end else begin
        return addOnesUncorrected(val, 1);
    end
endfunction

//multiplication
//a * b is returned.
//functions by converting to 2's complement and multiplying.
//takes in two SP values, outputs one DP value
//
function DP multOnesSlow (SP a, SP b);
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    //unsigned a and b
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

//multiplication
//probably faster than above
//(if not, the reason is probably that Bluespec's compiler didn't correctly
//  ignore multiplying and adding of zeroes that will always be zeroes)
function DP multOnes (SP a, SP b);
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    //unsigned a and b
    //these have an assumed leading zero (positive)
    Bit#(14) u_a = (sign_a == 1) ? (~a[13:0]) : a[13:0];
    Bit#(14) u_b = (sign_b == 1) ? (~b[13:0]) : b[13:0];

    //
    Bit#(5) top_a = {1'b0, u_a[13:10]}; // << 10
    Bit#(5) mid_a = u_a[9:5]; // << 5
    Bit#(5) low_a = u_a[4:0];

    Bit#(5) top_b = {1'b0, u_b[13:10]}; // << 10
    Bit#(5) mid_b = u_b[9:5]; // << 5
    Bit#(5) low_b = u_b[4:0];

    //multiply cases
    Bit#(8) t_t0 = zeroExtend(top_a) * zeroExtend(top_b);
    Bit#(9) t_m0 = zeroExtend(top_a) * zeroExtend(mid_b);
    Bit#(9) t_l0 = zeroExtend(top_a) * zeroExtend(low_b);
    Bit#(9) m_t0 = zeroExtend(mid_a) * zeroExtend(top_b);
    Bit#(10) m_m0 = zeroExtend(mid_a) * zeroExtend(mid_b);
    Bit#(10) m_l0 = zeroExtend(mid_a) * zeroExtend(low_b);
    Bit#(9) l_t0 = zeroExtend(low_a) * zeroExtend(top_b);
    Bit#(10) l_m0 = zeroExtend(low_a) * zeroExtend(mid_b);
    Bit#(10) l_l0 = zeroExtend(low_a) * zeroExtend(low_b);

    //shift cases to final positions
    Bit#(28) t_t = zeroExtend(t_t0) << 20;
    Bit#(28) t_m = zeroExtend(t_m0) << 15;
    Bit#(28) t_l = zeroExtend(t_l0) << 10;
    Bit#(28) m_t = zeroExtend(m_t0) << 15;
    Bit#(28) m_m = zeroExtend(m_m0) << 10;
    Bit#(28) m_l = zeroExtend(m_l0) << 5;
    Bit#(28) l_t = zeroExtend(l_t0) << 10;
    Bit#(28) l_m = zeroExtend(l_m0) << 5;
    Bit#(28) l_l = zeroExtend(l_l0);

    //sum all cases
    Bit#(28) result = t_t + t_m + t_l + m_t + m_m + m_l + l_t + l_m + l_l;

    //turn into double precision
    DP dp = (sign_a == sign_b) ? ({1'b0, result[27:14], 1'b0, result[13:0]}) : ({1'b1, ~result[27:14], 1'b1, ~result[13:0]});
    return dp;
endfunction

//this conversion function uses SIGNED two's complement
//returns 2's complement version of the input 1's complement value
function Bit#(n) toTwos(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(n) twos = (sign_a == 1) ? (a+1) : a;
    return twos;
endfunction

//this conversion function uses SIGNED two's complement
//returns 1's complement version of the input 2's complement value
//does not work for a = 1000000000...0
function Bit#(n) toOnes(Bit#(n) a)
        provisos(Add#(1, a__, n));
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(n) ones = (sign_a == 1) ? (a-1) : a;
    return ones;
endfunction

//adding DP values

//a and b need not be consistent sign.
//used for DAS instruction.
//returns {overflow, sign, 31'b result.  16 bits of precision for accumulator overflow.}
//overflow = 1 if overflow occurred
//sign is the sign bit of the overflow
function Bit#(33) addDP(DP a, DP b);
    //extract individual pairs.
    SP a_upper = a[29:15];
    SP a_lower = a[14:0];
    SP b_upper = b[29:15];
    SP b_lower = b[14:0];

    //perform actual additions
    Bit#(16) upper_prelim = addOnesCorrected(signExtend(a_upper), signExtend(b_upper));
    Bit#(16) lower_long = addOnesCorrected(signExtend(a_lower), signExtend(b_lower));

    //Add on overflow from lower, if necessary
    Bool overflow = (lower_long[15] != lower_long[14]); //overflow present?
    Bool lower_pos = (lower_long[15] == 0); //is the lower portion positive?
    Bit#(16) upper_corrected = lower_pos ? (addOnesCorrected(upper_prelim, 16'o00001)) : (addOnesCorrected(upper_prelim, 16'o177776));
    Bit#(16) upper = overflow ? upper_corrected : upper_prelim;
    Bit#(15) lower = {lower_long[15], lower_long[13:0]};

    Bit#(1) overflow_bit = (upper[15] != upper[14]) ? 1 : 0;
    Bit#(1) sign = (upper_corrected[15]);
    return {overflow_bit, sign, upper, lower};
endfunction
/*function DP addDPCorrected(DP a, DP b);
    //holders
    DP a_con = makeConsistentSign(a);
    DP b_con = makeConsistentSign(b);

    //preliminary addition
    Bit#(29) result = addOnesCorrected({a_con[29:15],a_con[13:0]},{b_con[29:15],b_con[13:0]});

    DP out = {result[28:14], result[28], result[13:0]};

    return out;
endfunction

function DP addDPUncorrected(DP a, DP b);
    //holders
    DP a_con = makeConsistentSign(a);
    DP b_con = makeConsistentSign(b);

    //preliminary addition
    Bit#(29) result = addOnesUncorrected({a_con[29:15],a_con[13:0]},{b_con[29:15],b_con[13:0]});

    DP out = {result[28:14], result[28], result[13:0]};

    return out;
endfunction*/


//sometimes DP values can have inconsistent signs.
//The output of this function will have consistent signs.
function DP makeConsistentSign(DP a);
    DP out;

    if (a[29] != a[14]) begin //if not currently consistent
        SP high = a[29:15];
        SP low = a[14:0];

        SP new_high;
        SP new_low;

        if (high == 15'b0) begin //special cases where larger SP is +/-0
            new_high = 15'o77777;
            new_low = low;
        end
        else if (~high == 15'b0) begin
            new_high = 15'b0;
            new_low = low;
        end
        else begin //ordinary use
            if (a[29] == 1) begin //if larger portion is negative
                new_high = addOnesUncorrected(high, fromInteger(1)); //move amount from smaller SP to larger SP
                new_low = subOnesUncorrected(low, 15'b100_000_000_000_000);
            end
            else begin //otherwise

                if (high == 15'b1) begin //be careful of special case; can end up with -0 instead of 0
                    new_high = 15'b0; //move amount from larger SP to smaller SP
                end
                else begin
                    new_high = subOnesUncorrected(high, 15'b1);
                end

                new_low = addOnesUncorrected(low, 15'b100_000_000_000_000);
            end

        end

        out = {new_high, new_low}; //new value (should be equivalent to old value)
    end
    else begin
        out = a;
    end
    return out;
endfunction



//slow divider.  Uses Bluespec's default divider.
function DP divideSlow (DP a, SP b);
    DP consistent = makeConsistentSign(a);
    DP dp;

    //sign bits
    Bit#(1) sign_a = truncateLSB(a);
    Bit#(1) sign_b = truncateLSB(b);

    //unsigned a and b magnitudes
    //these have a leading zero (positive)
    Bit#(28) u_a = (sign_a == 1) ? ({~a[28:15], ~a[13:0]}) : ({a[28:15], a[13:0]});
    Bit#(14) u_b = (sign_b == 1) ? (~b[13:0]) : b[13:0];

    if (u_a == 0 && u_b == 0) begin //output 0 if dividing by 0
        dp = {sign_a, 14'b0, sign_a, 14'b0};
    end
    else if (u_b == 0) begin
        dp = {sign_a, 14'b0, sign_a, 14'b0};
    end
    else if (u_a == {u_b, 14'b0}) begin //if inputs are equal
        Bit#(15) accum = 15'o37777; //store 37777 in A
        dp = {accum, b}; //and divisor in L
    end
    else if (u_a > {u_b, 14'b0}) begin //this value means divisor is larger
        dp = {sign_a, 14'd0, sign_a, 14'd12};
    end
    else begin
        //
        Bit#(14) quotient = truncate(u_a / zeroExtend(u_b));
        Bit#(14) remainder = truncate(u_a - zeroExtend(quotient * u_b));
        Bit#(14) remainder_signed = (sign_a == 1) ? (~remainder) : (remainder);
        Bit#(28) result;

        result = {quotient, remainder_signed};

        //synthesize output
        dp = (sign_a == sign_b) ? ({1'b0, result[27:14], sign_a, result[13:0]}) : ({1'b1, ~result[27:14], sign_a, result[13:0]});
    end
    //



    return dp;
endfunction

//multicycle divider
//uses GetPut-type interface
(* synthesize *)
module mkDivider(Divider);
    //
    Reg#(Bit#(14)) quo <- mkRegU();              //in-progress quotient
    Reg#(Bit#(14)) rem <- mkRegU();              //in-progress remainder
    Reg#(Bit#(28)) dividend <- mkRegU();         //magnitude of a, modified by computation process
    Reg#(Bit#(14)) divisor <- mkRegU();          //magnitude of b
    Reg#(Bit#(1)) sign_q <- mkRegU();            //sign of output value, 1 negative
    Reg#(Bit#(1)) sign_r <- mkRegU();            //sign of remainder
    Reg#(Bit#(5)) stage <- mkReg(15);            //stage.
    //15: default start value, should never appear otherwise
    //0-14: number of shifts applied to divisor before comparing to remaining dividend
    //31: calculating remainder
    //30: ready to be output
    //29: waiting for input

    //step calculation of the quotient
    //fires many times, then sets stage so remainder will fire.
    rule step (stage < 5'd15);
        //scaled divisor.
        Bit#(28) shift_div = {14'b0, divisor} << stage;

        //if the scaled divisor can't be subtracted out of the dividend
        if (shift_div > dividend) begin
            //the answer for this bit is 0
            quo <= (quo << 1);
        end
        else begin //otherwise
            dividend <= dividend - shift_div;
            quo <= (quo << 1) + 1; //the answer for this bit is 1
        end

        //increment stage; the next time this rule is executed,
        //shift_div will be one to the right.
        //will eventually wrap around to 31, which signals that the division is done.
        stage <= stage - 1;
    endrule

    //calculate remainder
    //fires once, right before data becomes ready.
    rule remainder (stage == 5'd31);
        //determine the remainder depending on the sign
        /* sign_q, sign_r
        * 00: a and b positive,       remainder = dividend remaining
        * 01: a and b negative,       remainder = dividend remaining
        * 10: a negative, b positive, remainder = inverted
        * 11: a positive, b negative, remainder = inverted
        */
        rem <= truncate(dividend);

        //now ready to be output!
        stage <= 5'd30;
    endrule

    //used to put data into this module
    //if module is currently dividing, this method will override the current division
    //this method conflicts with division rules, though, and so results may be unpredictable.
    method Action req(DP a, SP b);
        //extract information
        DP a_cons = makeConsistentSign(a);
        Fmt a_cons_fmt = $format("(") + displayDecimal(a_cons[29:15]) + $format(",    ") + displayDecimal(a_cons[14:0]) + $format(")");

        Bit#(1) sign_a = truncateLSB(a_cons); //input signs
        Bit#(1) sign_b = truncateLSB(b);
        sign_q <= (sign_a == sign_b) ? (0) : (1); //output signs


        //unsigned a and b magnitudes
        //these have a leading zero (positive)
        Bit#(28) u_a = (sign_a == 1) ? ({~a_cons[28:15], ~a_cons[13:0]}) : ({a_cons[28:15], a_cons[13:0]});
        Bit#(14) u_b = (sign_b == 1) ? (~b[13:0]) : b[13:0];

        //check for special cases
        //special cases are ready for output immediately.
        if ({u_b, 14'b0} < u_a) begin
            //return dummy value
            stage <= 5'd30;
            quo <= 14'd12;
            rem <= 14'd12;
            sign_r <= sign_a;
        end
        else if ({u_b, 14'b0} == u_a) begin //if divisor == divident
            //outputs
            stage <= 5'd30;
            quo <= 14'o37777;
            rem <= u_b;
            sign_r <= sign_b;
        end
        else begin //no special cases; do the division
            //set registers
            quo <= 0;
            rem <= 0;
            dividend <= u_a;
            divisor <= u_b;
            sign_r <= sign_a;
            stage <= 5'd14;
        end

        //
    endmethod

    //used to request a response from this module
    //will fire only if ready
    method ActionValue#(DP) resp() if (stage == 5'd30);
        //synthesize output DP value
        SP quotient =  (sign_q == 0) ? {1'b0, quo} : {1'b1, ~quo};
        SP remainder = (sign_r == 0) ? {1'b0, rem} : {1'b1, ~rem};

        //set stage to wait for input
        stage <= 5'd29;

        return {quotient, remainder};
    endmethod
endmodule

//nice display function for ones complement values.
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

//  DABS(x)=|x|-1 if |x|>1, or +0 otherwise.
function Bit#(n) dABS(Bit#(n) x)
        provisos(Add#(1, a__, n));

    //extract sign bit and magnitude
    Bit#(1) sign_x = truncateLSB(x);
    Bit#(n) x_mag = (sign_x == 0) ? x : ~x;

    //do operation if necessary
    Bit#(n) out_mag = (x_mag >= 1) ? (x_mag - 1) : x_mag;

    return out_mag;
endfunction

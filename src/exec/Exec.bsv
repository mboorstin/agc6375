import InterStage::*;
import Types::*;
import ArithUtil::*;

/*
TAGLSB: places dependent on the choice of LSB 0 for 15-bit memory in 16-bit words
TAGEXCEPTION: places with overflows/other exceptions to be implemented



*/

//(* noinline *)
function Exec2Writeback exec(ExecFuncArgs args);
    case (args.instNum)
        AD: return ad(args);
        ADS: return ads(args);
        AUG: return aug(args);
        BZF: return bzf(args);
        BZMF: return bzmf(args);
        CA: return ca(args);
        CCS: return ccs(args);
        CS: return cs(args);
        DIM: return dim(args);
        // Bunch of double's here
        INCR: return incr(args);
        INDEX: return index(args);
        // Bunch of other stuff here
        INHINT: return inhint(args);
        LXCH: return regXCH(args, rL);
        MASK: return mask(args);
        // Bunch of stuff here
        QXCH: return regXCH(args, rQ);
        // Bunch of stuff here
        READ: return read(args);
        RETURN: return returnFunc(args);
        // Bunch of stuff here
        SU: return su(args);
        TC: return tc(args);
        TCF: return tcf(args);
        TS: return ts(args);
        // Bunch of stuff here
        WRITE: return write(args);
        XCH: return regXCH(args, rA);
        // Bunch of stuff here
        // Once we're done with everything, should turn into a
        // raise unimplemented error
        default: return unimplemented(args);
    endcase
endfunction


//All of the functions to execute opcodes.
//these functions have the same information as Exec does.
//They should be inlined.

//add
//adds the contents of a memory location into the accumulator (rA)
function Exec2Writeback ad(ExecFuncArgs args);
    //address is 12 bits; not an extracode, so ignore LSB.
    //Addr k = args.inst[12:1];

    Word mem_resp = args.memOrIOResp[15:0];
    Word reg_resp = args.regResp[15:0];
    Addr memAddr = args.inst[12:1]; //TAGLSB


    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    //Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};
    Word mem_val = is16BitRegM(memAddr) ? mem_resp : {mem_resp[15], mem_resp[15:1]};

    Word sum = addOnesUncorrected(mem_val, reg_resp); //assume values are extended left

    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Exec2Writeback e2w = Exec2Writeback{
        eRes1: {?, mem_resp},
        eRes2: {?, sum}, //write sum back to accumulator only
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA, //accumulator
        newZ: args.z + 1
    };
    return e2w;
endfunction

//add to storage
//adds the contents of a erasable memory location to the accumulator
//and stores the result back in both the accumulator and memory location.
function Exec2Writeback ads(ExecFuncArgs args);

    Word mem_resp = args.memOrIOResp[15:0];
    Word reg_resp = args.regResp[15:0];
    Addr memAddr = zeroExtend(args.inst[10:1]); // TAGLSB

    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    //Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};
    Word mem_val = is16BitRegM(memAddr) ? mem_resp : {mem_resp[15], mem_resp[15:1]};

    Word sum = addOnesUncorrected(mem_val, reg_resp); //assume values are extended left
    SP sum_c = overflowCorrect(sum);

    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Addr mem_addr_wb = {2'b0, args.inst[10:1]}; //10 bit k, from instruction
    Exec2Writeback e2w = Exec2Writeback{
        eRes1: {?, sum_c, 1'b0}, //TAGLSB
        eRes2: {?, sum}, //write sum back to both
        memAddrOrIOChannel: tagged Addr mem_addr_wb,
        regNum: tagged Valid rA, //accumulator
        newZ: args.z + 1
    };
    return e2w;
endfunction

// augment
// Increments a positive value in an erasable-memory location in-place by +1
// or a negative value by -1
// Parameterized helper function
function Bit#(n) addOrSub(Bit#(n) val)
        provisos(Add#(1, a__, n),
                Add#(a__, b__, TAdd#(n, 1)),
                 Add#(c__, a__, TAdd#(n,2))
                );
    if (val[valueOf(TSub#(n, 1))] == 0) begin
        return addOnesUncorrected(val, 1);
    end else begin
        return subOnesUncorrected(val, 1);
    end
endfunction

function Exec2Writeback aug(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];

    Word auged;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        auged = addOrSub(memResp);
    end else begin
        // TAGLSB
        auged = {addOrSub(memResp[15:1]), 1'b0};
    end

    return Exec2Writeback {
        eRes1: {?, auged},
        // Should be ? but setting to 0 to keep tests happy
        eRes2: ?,
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// Branch Zero to Fixed
// The "Branch Zero to Fixed" instruction jumps to a memory location
// in fixed (as opposed to erasable) memory if the accumulator is zero
function Exec2Writeback bzf(ExecFuncArgs args);
    // TAGEXCEPTION
    // I *think* this is the correct handling of overflow, but should check
    Word acc = args.regResp[15:0];

    Bool doBranch = (acc[15] == acc[14]) && ((acc[14:0] == 0) || (acc[14:0] == ~0));

    Addr newZ = (doBranch ? args.inst[12:1] : args.z) + 1;

    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: newZ
    };
endfunction

// Branch Zero or Minus to Fixed
// The "Branch Zero or Minus to Fixed" instruction jumps to a memory
// location in fixed (as opposed to erasable) memory if the accumulator is zero or negative.
function Exec2Writeback bzmf(ExecFuncArgs args);
    // TAGEXCEPTION
    // I *think* this is the correct handling of overflow, but should check
    Word acc = args.regResp[15:0];

    Bool doBranch = (acc[15] == acc[14]) ? ((acc[14:0] == 0) || acc[14] == 1) : (acc[15:14] == 2'b10);

    Addr newZ = (doBranch ? args.inst[12:1] : args.z) + 1;

    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: newZ
    };
endfunction

// Clear and Add
// The "Clear and Add" (or "Clear and Add Erasable" or "Clear and Add Fixed")
// instruction moves the contents of a memory location into the accumulator.
function Exec2Writeback ca(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Addr memAddr = args.inst[12:1]; // TAGLSB

    // TAGLSB
    Word newAcc = is16BitRegM(memAddr) ? memResp : {memResp[15], memResp[15:1]};

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, newAcc},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// Counct, Compare, and Skip
// The "Count, Compare, and Skip" instruction stores a variable from erasable memory into the
// accumulator (which is decremented), and then performs one of several jumps based on the original
// value of the variable.  This is the only "compare" instruction in the AGC instruction set.
function Exec2Writeback ccs(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Addr memAddr = args.inst[12:1]; // TAGLSB

    Bool is16Bits = is16BitRegM(memAddr);

    Word memRespCleaned = is16Bits ? memResp : {memResp[15], memResp[15:1]};

    Word dabs = dABS(memRespCleaned);

    // This could probably be made more efficient - we're choosing to do dynamic addition, but
    // might be worth the extra space and do static addition?  Unclear.  On the other hand, the
    // compiler can hopefully figure out that there are only 4 options for addend.
    Addr addend;

    // Note that positive numbers in 1's and 2's complement are the same
    if (memRespCleaned == 0) begin
        addend = 2;
    // == -0
    end else if (memRespCleaned == ~0) begin
        addend = 4;
    // > +0
    end else if (memRespCleaned[15] == 0) begin
        addend = 1;
    // < -0
    end else begin
        addend = 3;
    end

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, dabs},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + addend
    };
endfunction

// Clear and Subtract
// The "Clear and Subtract" instruction moves the 1's-complement (i.e., the negative) of a memory location into
// the accumulator.
function Exec2Writeback cs(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Addr memAddr = args.inst[12:1]; // TAGLSB

    Bit#(15) upper = ~memResp[15:1];

    Bool is16Bits = is16BitRegM(memAddr);

    Word acc = is16BitRegM(memAddr) ? {upper, ~memResp[0]} : signExtend(upper);

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, acc},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// Diminish
// The "Diminish" instruction decrements a positive non-zero value in an
// erasable-memory location in-place, or increments a negative non-zero value.
// It's difficult to get this to share hardware with AUG because of the differing
// handling of +/- 0.  Code-wise, Bluespec doesn't allow function pointers, so it's
// not really worth the overhead of combining aug and dim.
// Parameterized helper function
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

function Exec2Writeback dim(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];

    Word dimmed;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        dimmed = subOrAddNonZero(memResp);
    end else begin
        // TAGLSB
        dimmed = {subOrAddNonZero(memResp[15:1]), 1'b0};
    end

    return Exec2Writeback {
        eRes1: {?, dimmed},
        // Should be ? but setting to 0 to keep tests happy
        eRes2: ?,
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// INCR
// The "Increment" instruction increments an erasable-memory location in-place by +1.
function Exec2Writeback incr(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];

    Word auged;

    Addr memAddr = {2'b0, args.inst[10:1]};

    if (is16BitRegM(memAddr)) begin
        auged = addOnesCorrected(memResp, 1);
    end else begin
        // TAGLSB
        auged = {addOnesCorrected(memResp[15:1], 1), 1'b0};
    end

    return Exec2Writeback {
        eRes1: {?, auged},
        // Should be ? but setting to 0 to keep tests happy
        eRes2: ?,
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// INDEX
// Note that eRes2 is added to the next instruction.
function Exec2Writeback index(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    // This is not stricly correct, because is 12 bits when INDEX is used as an extracode,
    // but we only use it for is16BItRegM and isCSCE.
    Addr memAddr = zeroExtend(args.inst[10:1]);

    Word toAdd = is16BitRegM(memAddr) ? {overflowCorrect(memResp), 0} : memResp;

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, toAdd},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// INHINT
// Disable interrupts.  For now, doing nothing.
function Exec2Writeback inhint(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

// XCH, LXCH and QXCH
// The "Exchange A/L/Q and K" instruction exchanges the value in the A/L/Q register with a
// value stored in erasable memory.
function Exec2Writeback regXCH(ExecFuncArgs args, RegIdx regNum);
    Word memResp = args.memOrIOResp[15:0];
    Word rResp = args.regResp[15:0];

    Addr memAddr = {2'b0, args.inst[10:1]};

    Bool is16Bits = is16BitRegM(memAddr);

    // TAGLSB
    Word newL = is16Bits ? memResp : signExtend(memResp[15:1]);
    // TAGEXCEPTION
    Word newMem = is16Bits ? rResp : {rResp[14:0], 0};

    return Exec2Writeback {
        eRes1: {?, newMem},
        eRes2: {?, newL},
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: tagged Valid regNum,
        newZ: args.z + 1
    };
endfunction

// MASK
// The "Mask A by K" instruction logically ANDs the contents of a memory
// location bitwise into the accumulator.
function Exec2Writeback mask(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Word aResp = args.regResp[15:0];

    Addr memAddr = {2'b0, args.inst[10:1]};

    Word newA;
    // Hopefully the compiler figures out it can use most of these
    // & gates for both cases...right?
    if (is16BitRegM(memAddr)) begin
        newA = memResp & aResp;
    end else begin
        // TAGEXCEPTION
        newA = signExtend(memResp[15:1] & aResp[14:0]);
    end

    return Exec2Writeback {
        eRes1: ?,
        eRes2: {?, newA},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// RETURN
// This is really a special case of TC
function Exec2Writeback returnFunc(ExecFuncArgs args);
    Addr newAddr = truncate(args.regResp[15:0]);

    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: newAddr + 1
    };
endfunction

// SU
// The "Subtract" instruction subtracts a memory value from the accumulator.
function Exec2Writeback su(ExecFuncArgs args);
    Word memResp = args.memOrIOResp[15:0];
    Word aResp = args.regResp[15:0];
    Addr memAddr = zeroExtend(args.inst[10:1]);

    Word aSubbed = subOnesUncorrected(aResp, is16BitRegM(memAddr) ? memResp : signExtend(memResp[15:1]));

    return Exec2Writeback {
        eRes1: {?, memResp},
        eRes2: {?, aSubbed},
        memAddrOrIOChannel: isCSCE(memAddr) ? (tagged Addr memAddr) : tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// TC
// The "Transfer Control" (or "Transfer Control setting up a Return") instruction calls a subroutine,
// first preparing for a later return to the instruction following the TC instruction.
function Exec2Writeback tc(ExecFuncArgs args);
    Word zData = args.regResp[15:0];

    return Exec2Writeback {
        eRes1: ?,
        // Note that "The Q register is set up with the address following the instruction.",
        // and Z already has the address following the instruction.
        eRes2: {?, {zData[15], zData[15:1]}},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rQ,
        newZ: args.inst[12:1] + 1
    };
endfunction

// TCF
// The "Transfer Control to Fixed" instruction jumps to a memory location in fixed
// (as opposed to erasable) memory.
function Exec2Writeback tcf(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.inst[12:1] + 1
    };
endfunction

// TS
//The "Transfer to Storage" instruction copies the accumulator into memory ... and so much more.
function Exec2Writeback ts(ExecFuncArgs args);
    Word aResp = args.regResp[15:0];
    Bool hasOverflow = (aResp[15] != aResp[14]);
    Addr memAddr = {2'b0, args.inst[10:1]};

    Bit#(15) top = signExtend(aResp[15]);

    return Exec2Writeback {
        eRes1: {?, is16BitRegM(memAddr) ? aResp : {overflowCorrect(aResp), 1'b0}},
        // Bluespec doesn't seem to like {15'b(aResp[15]), 1'b(!aResp[15])}.
        eRes2: {?, {top, ~aResp[15]}},
        memAddrOrIOChannel: tagged Addr memAddr,
        regNum: (hasOverflow && (args.inst[10:1] != zeroExtend(rA))) ? tagged Valid rA : tagged Invalid,
        newZ: hasOverflow ? (args.z + 2) : (args.z + 1)
    };
endfunction

// READ
// The "Read Channel KC" instruction moves the contents of an i/o channel
// into the accumulator.
function Exec2Writeback read(ExecFuncArgs args);
    Word ioResp = args.memOrIOResp[15:0];

    return Exec2Writeback {
        eRes1: ?,
        eRes2: {?, is16BitChannel(args.inst[7:1]) ? ioResp : signExtend(ioResp[15:1])},
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        newZ: args.z + 1
    };
endfunction

// WRITE
// The "Write Channel KC" instruction moves the contents of the accumulator into an i/o channel.
function Exec2Writeback write(ExecFuncArgs args);
    Word acc = args.regResp[15:0];
    IOChannel channel = args.inst[7:1];

     //TAGEXCEPTION
     return Exec2Writeback {
        eRes1: {?, is16BitChannel(channel) ? acc : {acc[14:0], 0}},
        eRes2: ?,
        memAddrOrIOChannel: tagged IOChannel channel,
        regNum: tagged Invalid,
        newZ: args.z + 1
     };
endfunction


function Exec2Writeback unimplemented(ExecFuncArgs args);
    return Exec2Writeback {
        eRes1: ?,
        eRes2: ?,
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        newZ: args.z + 1
    };
endfunction

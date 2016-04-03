import GetPut::*;

import Types::*;

typedef union tagged {
    RegIdx RegNum;
    MemAddr MemAddr;
} RealMemAddr deriving(Eq, Bits, FShow);

// A wrapper that knows how to read and write RealMemAddr's
interface MemAndRegWrapper;
    // We're aiming for the following: unfortunately, Bluespec doesn't let
    // you mark methods (only rules) as conflict_free
    // (* conflict_free = "readMem, readReg, readRegImm, writeMem, writeReg",
    //   conflict_free = "readRegImm, memResp, regResp, writeMem, writeReg" *)

    method Action readMem(RealMemAddr addr);
    method Action readReg(RegIdx idx);
    method Word readRegImm(RegIdx idx);

    method ActionValue#(Word) memResp();
    method ActionValue#(Word) regResp();

    method Action writeMem(RealMemAddr addr, Word data);
    method Action writeReg(RegIdx idx, Word data);
    method Action writeZImm(Word data);
endinterface

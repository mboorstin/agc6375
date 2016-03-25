import GetPut::*;

import Types::*;

// Internally we use a 16-bit BRAM to store data, since the 12 bit
// address space can actually address 16 bits with switched banks.
typedef 16 MemAddrSz;
typedef Bit#(MemAddrSz) MemAddr;

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
endinterface

typedef struct {
    MemAddr addr;
    Word data;
} MemInitLoad deriving(Eq, Bits, FShow);

typedef union tagged {
    MemInitLoad InitLoad;
    void InitDone;
} MemInit deriving(Eq, Bits, FShow);

interface MemInitIfc;
    interface Put#(MemInit) request;
    method Bool done();
endinterface

// A memory suitable for storing and fetching AGC instructions
interface IMemory;
    method Action req(Addr addr);
    method ActionValue#(Instruction) resp();
endinterface

// A memory suitable for fetching AGC data.  Note that the
// addr in memReq may point to anything, but the addr in regReq
// may only point to a register
interface DMemoryFetcher;
    method Action memReq(Addr addr);
    method Action regReq(RegIdx idx);

    method ActionValue#(Word) memResp();
    method ActionValue#(Word) regResp();
endinterface

// A memory suitable for storing AGC data.  Similarly to above,
// addr in memReq may point to anything, but the addr in regReq
// may only point to a register
interface DMemoryStorer;
    method Action memStore(Addr addr, Word data);
    method Action regStore(RegIdx idx, Word data);
endinterface

interface AGCMemory;
    interface IMemory imem;
    interface DMemoryFetcher fetcher;
    interface DMemoryStorer storer;
    interface MemInitIfc init;
endinterface

import GetPut::*;

import Types::*;

// Internally we use a 15-bit BRAM to store data, since the 12 bit
// address space can actually address 16 bits with switched banks, and
// we use 32 bit words on the BRAM.
typedef 16 MemAddrSz;
typedef Bit#(MemAddrSz) MemAddr;

typedef TDiv#(MemAddrSz, 2) DMemAddrSz;
typedef Bit#(DMemAddrSz) DMemAddr;

typedef struct {
    DMemAddr addr;
    DoubleWord data;
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
    interface MemInitIfc init;
endinterface

// A memory suitable for fetching AGC data.  Note that the
// addr in memReq may point to anything, but the addr in regReq
// may only point to a register
interface DMemoryFetcher;
    method Action memReq(Addr addr);
    method Action regReq(Addr addr);

    method ActionValue#(DoubleWord) memResp();
    method ActionValue#(DoubleWord) regResp();

    interface MemInitIfc init;
endinterface

// A memory suitable for storing AGC data.  Similarly to above,
// addr in memReq may point to anything, but the addr in regReq
// may only point to a register
// TODO: Split into memReq and memReqD?
interface DMemoryStorer;
    method Action memStore(Addr addr, DoubleWord data, Bool isDouble);
    method Action regStore(Addr addr, DoubleWord data, Bool isDouble);

    interface MemInitIfc init;
endinterface

interface AGCMemory;
    interface IMemory imem;
    interface DMemoryFetcher fetcher;
    interface DMemoryStorer storer;
endinterface

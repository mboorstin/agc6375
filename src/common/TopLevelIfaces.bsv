import Types::*;

// Memory-related

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

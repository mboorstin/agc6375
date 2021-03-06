import Vector::*;

import Types::*;

// Memory-related

// A memory suitable for storing and fetching AGC instructions
interface IMemory;
    method Action req(Addr addr);
    method ActionValue#(Instruction) resp();
    method Word getZ();
    method Action setZ(Word data);
endinterface

// A memory suitable for fetching AGC data.  Note that the
// addr in memReq may point to anything, but the addr in regReq
// may only point to a register
interface DMemoryFetcher;
    method Action memReq(Addr addr);
    method Action regReq(RegIdx idx);

    method ActionValue#(Word) memResp();
    method ActionValue#(Word) regResp();

    method Word readRegImm(RegIdx idx);
    method Bool hasOverflows();
    method Addr getZRUPT();
endinterface

// A memory suitable for storing AGC data.  Similarly to above,
// addr in memReq may point to anything, but the addr in regReq
// may only point to a register
interface DMemoryStorer;
    method Action memStore(Addr addr, Word data);
    method Action regStore(RegIdx idx, Word data);
endinterface

// An interface for handling the superbank
interface SuperbankProvider;
    method Action set(Word data);
    method Word get();
endinterface

// An interface for handling timers
interface AGCTimers;
    method Bool interruptNeeded(InterruptIdx interrupt);
    method Action clearInterrupt(InterruptIdx interrupt);
endinterface

// It would be nice to expose this as an interface with get() and set() methods.  It's
// difficult to do that because we want to be able to call the set() method multiple times
// per cycle on different registers, and Bluespec doesn't allow calling a method multiple times.
// I also can't find an (elegant) way to parameterize method definition for interfaces.  So,
// we just expose the Vector#(Reg) directly.
// Note that we may eventually want to change this to a Vector#(Vector#()) to expose multiple ports.
typedef Vector#(NRegs, Reg#(Word)) RegisterPort;

interface AGCMemory;
    interface IMemory imem;
    interface DMemoryFetcher fetcher;
    interface DMemoryStorer storer;
    interface RegisterPort regPort;
    interface SuperbankProvider superbank;
    interface MemInitIfc init;
endinterface

interface InternalIO;
    // Read directly (immediately) from the internal I/O buffer.
    method Word readImm(IOChannel channel);

    // Request a read and fetch its response a cycle later
    method Action readReq(IOChannel channel);
    method ActionValue#(Word) readResp();

    // Write
    method Action write(IOChannel channel, Word data);
endinterface

interface AGCIO;
    interface HostIO hostIO;
    interface InternalIO internalIO;
endinterface

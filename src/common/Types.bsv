import GetPut::*;

typedef 12 AddrSz;
typedef Bit#(AddrSz) Addr;

typedef 16 WordSz;
typedef Bit#(WordSz) Word;
typedef Word Instruction;

typedef 8 IOChannelSize;
typedef Bit#(IOChannelSize) IOChannel;

typedef struct {
    IOChannel channel;
    Word data;
} IOPacket deriving (Eq, Bits, FShow);

// Annoyingly all of the MemInit stuff has to be here so that it can
// be used in interface AGC
// Internally we use a 16-bit BRAM to store data, since the 12 bit
// address space can actually address 16 bits with switched banks.
typedef 16 MemAddrSz;
typedef Bit#(MemAddrSz) MemAddr;

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

interface AGC;
    // I/O send (ie, WRITE)
    method ActionValue#(IOPacket) ioAGCToHost;
    // I/O receive (ie, READ)
    method Action ioHostToAGC(IOPacket packet);
    // Start the simulation
    // Can maybe replace this with an ioHostToAGC call,
    // or hardcode where it's actually support to start and have
    // memInit finished trigger it?
    method Action start(Addr startZ);
    // Memory initialization
    interface MemInitIfc memInit;
endinterface

typedef 49 NRegs;
typedef TLog#(NRegs) LNRegs;
typedef Bit#(LNRegs) RegIdx;

// Registers
RegIdx rA = 0;
RegIdx rL = 1;
RegIdx rQ = 2;
RegIdx rEB = 3;
RegIdx rFB = 4;
RegIdx rZ = 5;
RegIdx rBB = 6;
RegIdx rZERO = 7;
RegIdx rARUPT = 8;
RegIdx rLRUPT = 9;
RegIdx rQRUPT = 10;
RegIdx rSPARE0 = 11;
RegIdx rSPARE1 = 12;
RegIdx rZRUPT = 13;
RegIdx rBBRUPT = 14;
RegIdx rBRUPT = 15;
RegIdx rCYR = 16;
RegIdx rSR = 17;
RegIdx rCYL = 18;
RegIdx rEDOP = 19;
// TIME2 then TIME1 is intentional (or maybe)
// a typo on ibiblio.org/apollo
RegIdx rTIME2 = 20;
RegIdx rTIME1 = 21;
RegIdx rTIME3 = 22;
RegIdx rTIME4 = 23;
RegIdx rTIME5 = 24;
RegIdx rTIME6 = 25;
RegIdx rCDUX = 26;
RegIdx rCDUY = 27;
RegIdx rCDUZ = 28;
RegIdx rOPTY = 29;
RegIdx rOPTX = 30;
RegIdx rPIPAX = 31;
RegIdx rPIPAY = 32;
RegIdx rPIPAZ = 33;
RegIdx rQRHCCTR = 34;
RegIdx rPRHCCTR = 35;
RegIdx rRRHCCTR = 36;
RegIdx rINLINK = 37;
RegIdx rRNRAD = 38;
RegIdx rGYROCTR = 39;
RegIdx rCDUXCMD = 40;
RegIdx rCDUYCMD = 41;
RegIdx rCDUZCMD = 42;
RegIdx rOPTYCMD = 43;
RegIdx rOPTXCMD = 44;
RegIdx rTHURST = 45;
RegIdx rLEMONNM = 46;
RegIdx rOUTLINK = 47;
RegIdx rALTM = 48;

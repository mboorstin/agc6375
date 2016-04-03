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

// Bluespec doesn't have overloaded functions, and for whatever reason
// doesn't like the parameterized version on Bit#(n) :-()
function Bool is16BitReg(RegIdx r);
    return (r == rA) || (r == rL) || (r== rQ);
endfunction

function Bool is16BitRegM(Addr a);
    return (a[11:2] == 0) && is16BitReg(truncate(a));
endfunction

// Opcodes
typedef Bit#(3) Opcode;
// Non-extended
Opcode opTC = 0;
Opcode opCCS = 1;
Opcode opTCF = 1;
Opcode opDAS = 2;
Opcode opLXCH = 2;
Opcode opINCR = 2;
Opcode opADS = 2;
Opcode opCA = 3;
Opcode opCS = 4;
Opcode opINDEX = 5;
Opcode opDXCH = 5;
Opcode opTS = 5;
Opcode opXCH = 5;
Opcode opAD = 6;
Opcode opMASK = 7;
// Extended
// Not an actual opcode name but matches all I/O channel opcodes
Opcode opIO = 0;
Opcode opDV = 1;
Opcode opBZF = 1;
Opcode opMSU = 2;
Opcode opQXCH = 2;
Opcode opAUG = 2;
Opcode opDIM = 2;
Opcode opDCA = 3;
Opcode opDCS = 4;
// opINDEX already exists
Opcode opSU = 6;
Opcode opBZMF = 6;
Opcode opMP = 7;

// Quartercodes!  These are only defined when necessary
// In particular, if an instruction is "anything but 0", it's not
// given a quartercode, as presumably the corresponding 0 code will
// be matched against
typedef Bit#(2) QC;
// Non-extended
// Opcode 0
QC qcCCS = 0;
// TCF is anything but 0
// Opcode 1
QC qcDAS = 0;
QC qcLXCH = 1;
QC qcINCR = 2;
QC qcADS = 3;
// Opcode 5
QC qcINDEX = 0;
QC qcDXCH = 1;
QC qcTS = 2;
QC qcXCH = 3;
// Extended
// Opcode 0 is I/O and is three bits: has its own QCIO codes below
// Opcode 1
QC qcDV = 0;
// BZF is anything but 0
// Opcode 2
QC qcMSU = 0;
QC qcQXCH = 1;
QC qcAUG = 2;
QC qcDIM = 3;
// Opcode 6
QC qcSU = 0;
// BZMF is anything but 0

typedef Bit#(3) QCIO;
QCIO qcioREAD = 0;
QCIO qcioWRITE = 1;
QCIO qcioRAND = 2;
QCIO qcioWAND = 3;
QCIO qcioROR = 4;
QCIO qcioWOR = 5;
QCIO qcioRXOR = 6;
QCIO qcioEDRUPT = 7;

// These are internal instructions numbers that, unlike the AGC instruction
// set, have a one-to-one mapping with logical operations
// Instruction numbers
typedef enum {
    TC,
    CCS,
    TCF,
    DAS,
    LXCH,
    INCR,
    ADS,
    CA,
    CS,
    INDEX,
    DXCH,
    TS,
    XCH,
    AD,
    MASK,
    IO,
    DV,
    BZF,
    MSU,
    QXCH,
    AUG,
    DIM,
    DCA,
    DCS,
    SU,
    BZMF,
    MP,
    READ,
    WRITE,
    RAND,
    WAND,
    ROR,
    WOR,
    RXOR,
    EDRUPT,
    INHINT,
    RELINT,
    EXTEND
} InstNum deriving (Eq, Bits, FShow);

typedef 12 AddrSz;
typedef Bit#(AddrSz) Addr;

typedef 16 WordSz;
typedef Bit#(WordSz) Word;
typedef Word Instruction;

typedef TMul#(WordSz, 2) DoubleWordSz;
typedef Bit#(DoubleWordSz) DoubleWord;
typedef DoubleWord Data;

typedef 49 NRegs;
typedef TLog#(NRegs) LNRegs;

// Registers
Bit#(LNRegs) rA = 0;
Bit#(LNRegs) rL = 1;
Bit#(LNRegs) rQ = 2;
Bit#(LNRegs) rEB = 3;
Bit#(LNRegs) rFB = 4;

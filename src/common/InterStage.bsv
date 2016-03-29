import Types::*;

typedef struct {
    Addr z;
} Fetch2Decode deriving (Eq, Bits);

typedef struct {
    Addr z;
    Instruction inst;
    Bool isExtended;
    Bool deqFromMem;
    Bool deqFromReg;
} Decode2Exec deriving (Eq, Bits);

typedef struct {
    Addr z;
    Instruction inst;
    Bool isExtended;
    Maybe#(Word) memResp; //corresponds to deqFromMem
    Maybe#(Word) regResp; //corresponds to deqFromReg
} ExecFuncArgs deriving (Eq, Bits);

typedef struct {
    Word eRes1; //corresponds to memAddr
    Word eRes2; //corresponds to regNum
    Maybe#(Addr) memAddr;
    Maybe#(RegIdx) regNum;
    // Should only be used for TS instruction
    Maybe#(Addr) newZ;
} Exec2Writeback deriving (Eq, Bits, FShow);

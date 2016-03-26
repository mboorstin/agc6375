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
    Word eRes1;
    Word eRes2;
    Maybe#(Addr) memAddr;
    Maybe#(RegIdx) regNum;
    // Should only be used for TS instruction
    Maybe#(Addr) newZ;
} Exec2Writeback deriving (Eq, Bits);

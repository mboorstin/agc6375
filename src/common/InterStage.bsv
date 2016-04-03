import Types::*;

typedef struct {
    Addr z;
} Fetch2Decode deriving (Eq, Bits, FShow);

typedef struct {
    Maybe#(Addr) memAddr;
    Maybe#(RegIdx) regNum;
    InstNum instNum;
} DecodeRes deriving (Eq, Bits, FShow);

typedef struct {
    Addr z;
    Instruction inst;
    InstNum instNum;
    Bool deqFromMem;
    Bool deqFromReg;
} Decode2Exec deriving (Eq, Bits, FShow);

typedef struct {
    Addr z;
    Instruction inst;
    InstNum instNum;
    Maybe#(Word) memResp; //corresponds to deqFromMem
    Maybe#(Word) regResp; //corresponds to deqFromReg
} ExecFuncArgs deriving (Eq, Bits, FShow);

typedef struct {
    Word eRes1; //corresponds to memAddr
    Word eRes2; //corresponds to regNum
    Maybe#(Addr) memAddr;
    Maybe#(RegIdx) regNum;
    Addr newZ;
} Exec2Writeback deriving (Eq, Bits, FShow);

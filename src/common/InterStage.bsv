import Types::*;

typedef struct {
    Addr z;
} Fetch2Decode deriving (Eq, Bits, FShow);

typedef union tagged {
    Addr Addr;
    IOChannel IOChannel;
    void None;
} AddrOrIOChannel deriving (Eq, Bits, FShow);

typedef struct {
    AddrOrIOChannel memAddrOrIOChannel;
    Maybe#(RegIdx) regNum;
    InstNum instNum;
} DecodeRes deriving (Eq, Bits, FShow);

typedef enum {
    Mem,
    IO,
    None
} MemOrIODeq deriving (Eq, Bits, FShow);

typedef struct {
    Addr z;
    Instruction inst;
    InstNum instNum;
    MemOrIODeq deqFromMemOrIO;
    Bool deqFromReg;
} Decode2Exec deriving (Eq, Bits, FShow);

typedef struct {
    Addr z;
    Instruction inst;
    InstNum instNum;
    Maybe#(Word) memOrIOResp; //corresponds to deqFromMemOrIO
    Maybe#(Word) regResp; //corresponds to deqFromReg
} ExecFuncArgs deriving (Eq, Bits, FShow);

typedef struct {
    Word eRes1; //corresponds to memAddrOrIOChannel
    Word eRes2; //corresponds to regNum
    AddrOrIOChannel memAddrOrIOChannel;
    Maybe#(RegIdx) regNum;
    Addr newZ;
} Exec2Writeback deriving (Eq, Bits, FShow);

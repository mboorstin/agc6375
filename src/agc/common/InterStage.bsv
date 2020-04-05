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
    DecodeRes decoded;
    Word fromMemForDouble;
    Word fromRegForDouble;
} Decode2Exec deriving (Eq, Bits, FShow);

typedef struct {
    Addr z;
    Instruction inst;
    InstNum instNum;
    DoubleWord memOrIOResp; //corresponds to deqFromMemOrIO
    DoubleWord regResp; //corresponds to deqFromReg
} ExecFuncArgs deriving (Eq, Bits, FShow);

typedef struct {
    DoubleWord eRes1; //corresponds to memAddrOrIOChannel
    DoubleWord eRes2; //corresponds to regNum
    AddrOrIOChannel memAddrOrIOChannel;
    Maybe#(RegIdx) regNum;
    Addr newZ;
} Exec2Writeback deriving (Eq, Bits, FShow);

import InterStage::*;
import Types::*;

function DecodeRes decode(Instruction inst, Bool isExtended);
    //pulling data out of inst
    Bit#(3) ccc = inst[15:13]; //primary opcode values
    //Bit#(13) addr = args.inst[12:0]; //all bits that may contain address info
    Bit#(2) qq = inst[12:11]; //secondary opcode values (qc values)
    Bit#(3) ppp = inst[12:10]; //secondary opcode values for IO instructions (pc values)

    //maybe there's a better way to set this up?  Either way, I'm so sorry.
    //extracode
    if (isExtended) begin
        //
        case(ccc)
            opIO: begin //corresponds to I/O instructions
                case(ppp)
                    qcioREAD: begin //READ
                        return dREAD(inst);
                    end
                    qcioWRITE: begin //WRITE
                        return dWRITE();
                    end
                    qcioRAND: begin //RAND
                        return dRAND(inst);
                    end
                    qcioWAND: begin //WAND
                        return dWAND(inst);
                    end
                    qcioROR: begin //ROR
                        return dROR(inst);
                    end
                    qcioWOR: begin //WOR
                        return dWOR(inst);
                    end
                    qcioRXOR: begin //RXOR
                        return dRXOR(inst);
                    end
                    qcioEDRUPT: begin //EDRUPT
                        return dEDRUPT();
                    end
                endcase
            end
            opDV: begin //corresponds to DV and BZF
                if (qq == qcDV) begin //DV
                    return dUNIMPLEMENTED();
                end
                else begin //BZF
                    return dBZF();
                end
            end
            opMSU: begin //corresponds to MSU, QXCH, AUG, and DIM
                case(qq)
                    qcMSU: begin //MSU
                        return dMSU(inst);
                    end
                    qcQXCH: begin //QXCH
                        return dRegXCH(inst, rQ, QXCH);
                    end
                    qcAUG: begin //AUG
                        return dUNIMPLEMENTED();
                    end
                    qcDIM: begin //DIM
                        return dUNIMPLEMENTED();
                    end
                endcase
            end
            opDCA: begin //DCA
                return dDCA(inst);
            end
            opDCS: begin //DCS
                return dDCS(inst);
            end
            opINDEX: begin //INDEX
                return dINDEXExtended(inst);
            end
            opSU: begin //corresponds to SU and BZMF
                if  (qq == qcSU) begin //SU
                    return dSU(inst);
                end
                else begin //BZMF
                    return dBZMF();
                end
            end
            opMP: begin //MP
                return dMP(inst);
            end
        endcase
    end
    else begin //not extracode
        case (ccc)
            opTC: begin //TC
                case (inst[12:1])
                    2: begin // RETURN
                        return dRETURN();
                    end
                    3: begin // RELINT
                        return dUNIMPLEMENTED();
                    end
                    4: begin // INHINT
                        return dINHINT();
                    end
                    6: begin // EXTEND
                        return dEXTEND();
                    end
                    default: begin // Everything else
                        return dTC();
                    end
                endcase
            end
            opCCS: begin //corresponds to CCS and TCF
                if (qq == qcCCS) begin //CCS
                    return dCCS(inst);
                end
                else begin //TCF
                    return dTCF();
                end
            end
            opDAS: begin //corresponds to DAS, LXCH, INCR, and ADS
                case (qq)
                    qcDAS: begin //DAS
                        return dDAS(inst);
                    end
                    qcLXCH: begin //LXCH
                        return dRegXCH(inst, rL, LXCH);
                    end
                    qcINCR: begin //INCR
                        return dINCR(inst);
                    end
                    qcADS: begin //ADS
                        return dADS(inst);
                    end
                endcase
            end
            opCA: begin //CA
                return dCA(inst);
            end
            opCS: begin //CS
                return dCS(inst);
            end
            opINDEX: begin //corresponds to INDEX, DXCH, TS, XCH
                case (qq)
                    qcINDEX: begin //INDEX
                        return dINDEXBasic(inst);
                    end
                    qcDXCH: begin //DXCH
                        return dDXCH(inst);
                    end
                    qcTS: begin //TS
                        return dTS();
                    end
                    qcXCH: begin //XCH
                        return dRegXCH(inst, rA, XCH);
                    end
                endcase
            end
            opAD: begin //AD
                return dAD(inst);
            end
            opMASK: begin //MASK
                return dMASK(inst);
            end
        endcase
    end
endfunction

function DecodeRes dAD(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[12:1]),
        regNum: tagged Valid rA,
        instNum: AD
    };
endfunction

function DecodeRes dADS(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Valid rA,
        instNum: ADS
    };
endfunction

function DecodeRes dBZF();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        instNum: BZF
    };
endfunction

function DecodeRes dBZMF();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        instNum: BZMF
    };
endfunction

function DecodeRes dCA(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr inst[12:1],
        regNum: tagged Invalid,
        instNum: CA
    };
endfunction

function DecodeRes dCCS(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Invalid,
        instNum: CCS
    };
endfunction

function DecodeRes dCS(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr inst[12:1],
        regNum: tagged Invalid,
        instNum: CS
    };
endfunction

function DecodeRes dDAS(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1] - 1),
        regNum: tagged Valid rA,
        instNum: DAS
    };
endfunction

function DecodeRes dDCA(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr (inst[12:1] - 1),
        regNum: tagged Invalid,
        instNum: DCA
    };
endfunction

function DecodeRes dDCS(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr (inst[12:1] - 1),
        regNum: tagged Invalid,
        instNum: DCS
    };
endfunction

function DecodeRes dDXCH(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1] - 1),
        regNum: tagged Valid rA,
        instNum: DXCH
    };
endfunction

function DecodeRes dEDRUPT();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        instNum: EDRUPT
    };
endfunction

function DecodeRes dEXTEND();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        instNum: EXTEND
    };
endfunction

function DecodeRes dINCR(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Invalid,
        instNum: INCR
    };
endfunction

function DecodeRes dINDEXBasic(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Invalid,
        instNum: INDEX
    };
endfunction

function DecodeRes dINDEXExtended(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr inst[12:1],
        regNum: tagged Invalid,
        instNum: INDEX
    };
endfunction

// For now, completely ignoring interrupts
function DecodeRes dINHINT();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        instNum: INHINT
    };
endfunction

function DecodeRes dMASK(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr inst[12:1],
        regNum: tagged Valid rA,
        instNum: MASK
    };
endfunction

function DecodeRes dMP(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[12:1]),
        regNum: tagged Valid rA,
        instNum: MP
    };
endfunction

function DecodeRes dMSU(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Valid rA,
        instNum: MSU
    };
endfunction

function DecodeRes dRegXCH(Instruction inst, RegIdx regNum, InstNum instNum);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Valid regNum,
        instNum: instNum
    };
endfunction

function DecodeRes dRETURN();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rQ,
        instNum: RETURN
    };
endfunction

function DecodeRes dSU(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged Addr zeroExtend(inst[10:1]),
        regNum: tagged Valid rA,
        instNum: SU
    };
endfunction

function DecodeRes dTC();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rZ,
        instNum: TC
    };
endfunction

function DecodeRes dTCF();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        instNum: TCF
    };
endfunction

function DecodeRes dTS();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        instNum: TS
    };
endfunction

function DecodeRes dREAD(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged IOChannel inst[7:1],
        regNum: tagged Invalid,
        instNum: READ
    };
endfunction

function DecodeRes dWRITE();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Valid rA,
        instNum: WRITE
    };
endfunction

function DecodeRes dRAND(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged IOChannel inst[7:1],
        regNum: tagged Valid rA,
        instNum: RAND
    };
endfunction

function DecodeRes dWAND(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged IOChannel inst[7:1],
        regNum: tagged Valid rA,
        instNum: WAND
    };
endfunction

function DecodeRes dROR(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged IOChannel inst[7:1],
        regNum: tagged Valid rA,
        instNum: ROR
    };
endfunction

function DecodeRes dWOR(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged IOChannel inst[7:1],
        regNum: tagged Valid rA,
        instNum: WOR
    };
endfunction

function DecodeRes dRXOR(Instruction inst);
    return DecodeRes {
        memAddrOrIOChannel: tagged IOChannel inst[7:1],
        regNum: tagged Valid rA,
        instNum: RXOR
    };
endfunction

function DecodeRes dUNIMPLEMENTED();
    return DecodeRes {
        memAddrOrIOChannel: tagged None,
        regNum: tagged Invalid,
        instNum: UNIMPLEMENTED
    };
endfunction

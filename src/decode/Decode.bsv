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
                        return ?;
                    end
                    qcioWRITE: begin //WRITE
                        return ?;
                    end
                    qcioRAND: begin //RAND
                        return ?;
                    end
                    qcioWAND: begin //WAND
                        return ?;
                    end
                    qcioROR: begin //ROR
                        return ?;
                    end
                    qcioWOR: begin //WOR
                        return ?;
                    end
                    qcioRXOR: begin //RXOR
                        return ?;
                    end
                    qcioEDRUPT: begin //EDRUPT
                        return dEDRUPT();
                    end
                endcase
            end
            opDV: begin //corresponds to DV and BZF
                if (qq == qcDV) begin //DV
                    return ?;
                end
                else begin //BZF
                    return ?;
                end
            end
            opMSU: begin //corresponds to MSU, QXCH, AUG, and DIM
                case(qq)
                    qcMSU: begin //MSU
                        return ?;
                    end
                    qcQXCH: begin //QXCH
                        return ?;
                    end
                    qcAUG: begin //AUG
                        return ?;
                    end
                    qcDIM: begin //DIM
                        return ?;
                    end
                endcase
            end
            opDCA: begin //DCA
                return ?;
            end
            opDCS: begin //DCS
                return ?;
            end
            opINDEX: begin //INDEX
                return ?;
            end
            opSU: begin //corresponds to SU and BZMF
                if  (qq == qcSU) begin //SU
                    return ?;
                end
                else begin //BZMF
                    return ?;
                end
            end
            opMP: begin //MP
                return ?;
            end
        endcase
    end
    else begin //not extracode
        case (ccc)
            opTC: begin //TC
                case (inst[12:1])
                    3: begin // RELINT
                        return ?;
                    end
                    4: begin // INHINT
                        return ?;
                    end
                    6: begin // EXTEND
                        return dEXTEND();
                    end
                    default: begin // Everything else
                        return ?;
                    end
                endcase
            end
            opCCS: begin //corresponds to CCS and TCF
                if (qq == qcCCS) begin //CCS
                    return ?;
                end
                else begin //TCF
                    return ?;
                end
            end
            opDAS: begin //corresponds to DAS, LXCH, INCR, and ADS
                case (qq)
                    qcDAS: begin //DAS
                        return ?;
                    end
                    qcLXCH: begin //LXCH
                        return ?;
                    end
                    qcINCR: begin //INCR
                        return ?;
                    end
                    qcADS: begin //ADS
                        return dADS(inst);
                    end
                endcase
            end
            opCA: begin //CA
                return?;
            end
            opCS: begin //CS
                return?;
            end
            opINDEX: begin //corresponds to INDEX, DXCH, TS, XCH
                case (qq)
                    qcINDEX: begin //INDEX
                        return ?;
                    end
                    qcDXCH: begin //DXCH
                        return ?;
                    end
                    qcTS: begin //TS
                        return ?;
                    end
                    qcXCH: begin //XCH
                        return ?;
                    end
                endcase
            end
            opAD: begin //AD
                return?;
            end
            opMASK: begin //MASK
                return ?;
            end
        endcase
    end
endfunction

function DecodeRes dADS(Instruction inst);
    return DecodeRes {
        memAddr: tagged Valid zeroExtend(inst[10:1]),
        regNum: tagged Valid rA,
        instNum: ADS
    };
endfunction

function DecodeRes dEDRUPT();
    return DecodeRes {
        memAddr: tagged Invalid,
        regNum: tagged Invalid,
        instNum: EDRUPT
    };
endfunction

function DecodeRes dEXTEND();
    return DecodeRes {
        memAddr: tagged Invalid,
        regNum: tagged Invalid,
        instNum: EXTEND
    };
endfunction

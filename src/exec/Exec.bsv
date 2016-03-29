import InterStage::*;
import Types::*;
import ArithUtil::*;

/*
TAGLSB: places dependent on the choice of LSB 0 for 15-bit memory in 16-bit words
TAGEXCEPTION: places with overflows/other exceptions to be implemented



*/

(* noinline *)
function Exec2Writeback exec(ExecFuncArgs args);
    //exec

    //pulling data out of inst
    Bit#(3) ccc = args.inst[15:13]; //primary opcode values
    //Bit#(13) addr = args.inst[12:0]; //all bits that may contain address info
    Bit#(2) qq = args.inst[12:11]; //secondary opcode values (qc values)
    Bit#(3) ppp = args.inst[12:10]; //secondary opcode values for IO instructions (pc values)


    //maybe there's a better way to set this up?  Either way, I'm so sorry.
    //extracode
    if (args.isExtended) begin
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
                        return ?;
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
                return ?;
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
                        return ads(args);
                    end
                endcase
            end
            opCA: begin //CA
                return ?;
            end
            opCS: begin //CS
                return ?;
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
                return ad(args);
            end
            opMASK: begin //MASK
                return ?;
            end
        endcase
    end

    //encoding output
    /*Exec2Writeback e2w = Exec2Writeback{
    eRes1:eRes1,
    eRes2:eRes2,
    memAddr:memAddr,
    regNum:regNum,
    newZ:newZ,
    };
    return e2w;*/

endfunction


//All of the functions to execute opcodes.
//these functions have the same information as Exec does.
//They should be inlined.

//add
//adds the contents of a memory location into the accumulator (rA)
function Exec2Writeback ad(ExecFuncArgs args);
    //address is 12 bits; not an extracode, so ignore LSB.
    //Addr k = args.inst[12:1];

    Word mem_resp = fromMaybe(?, args.memResp);
    Word reg_resp = fromMaybe(?, args.regResp);
    

    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};
    
    Word sum = addOnes(mem_val, reg_resp); //assume values are extended left
    
    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Exec2Writeback e2w = Exec2Writeback{
        eRes1:16'b0,
        eRes2:sum, //write sum back to accumulator only
        memAddr: tagged Invalid,
        regNum: tagged Valid rA, //accumulator
        newZ: tagged Invalid
    };
    return e2w;
endfunction

//add to storage
//adds the contents of a erasable memory location to the accumulator
//and stores the result back in both the accumulator and memory location.
function Exec2Writeback ads(ExecFuncArgs args);

    Word mem_resp = fromMaybe(?, args.memResp);
    Word reg_resp = fromMaybe(?, args.regResp);

    //mem_resp is the value to be added to the accumulator.
    //TAGLSB
    Word mem_val = {mem_resp[15], truncateLSB(mem_resp)};
    
    Word sum = addOnes(mem_val, reg_resp); //assume values are extended left
    
    if (sum[15] != sum[14]) begin
        //overflow-- TAGEXCEPTION
    end

    //return
    Addr mem_addr_wb = {2'b0, args.inst[10:1]}; //10 bit k, from instruction
    Exec2Writeback e2w = Exec2Writeback{
        eRes1:sum,
        eRes2:sum, //write sum back to both
        memAddr: tagged Valid mem_addr_wb, 
        regNum: tagged Valid rA, //accumulator
        newZ: tagged Invalid
    };
    return e2w;
endfunction
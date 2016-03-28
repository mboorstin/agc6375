import InterStage::*;
import Types::*;
import ArithUtil::*;

(* noinline *)
function Exec2Writeback Exec(Decode2Exec d2e, AGCMemory memory);
    //exec

    //receive from memory if necessary
    Word mem_resp;
    Word reg_resp;
    if (d2e.deqFromMem) mem_resp <- memory.fetcher.memResp();
    if (d2e.deqFromReg) reg_resp <- memory.fetcher.regResp();

    //pulling data out of inst
    Bit#(3) ccc = d2e.inst[15:13]; //primary opcode values
    Bit#(12) addr = d2e.inst[12:0]; //all bits that may contain address info
    Bit#(2) qq = d2e.inst[12:11]; //secondary opcode values (qc values)
    Bit#(3) ppp = d2e.inst[12:10]; //secondary opcode values for IO instructions (pc values)

    //values to pass to writeback
    Word eRes1;
    Word eRes2;
    Maybe#(Addr) memAddr;
    Maybe#(RegIdz) regNum;
    Maybe#(Addr) newZ;

	//maybe there's a better way to set this up?  Either way, I'm so sorry.
	//extracode
	if (d2e.isExtended) begin
	    //
	    case(ccc)
		opIO: begin //corresponds to I/O instructions
                    case(ppp)
                        qcioREAD: begin //READ
                            //
			end
			qcioWRITE: begin //WRITE
                            //
			end
			qcioRAND: begin //RAND
                            //
			end
			qcioWAND: begin //WAND
                            //
			end
			qcioROR: begin //ROR
                            //
			end
			qcioWOR: begin //WOR
                            //
			end
			qcioRXOR: begin //RXOR
                            //
			end
			qcioEDRUPT: begin //EDRUPT
                            //
			end
		    endcase
		end
		opDV: begin //corresponds to DV and BZF
                    if (qq == qcDV) begin //DV
                        //
	            end
	            else begin //BZF
                        //
	            end
	        end
		opMSU: begin //corresponds to MSU, QXCH, AUG, and DIM
                    case(qq)
                        qcMSU: begin //MSU
                            //
			end
			qcQXCH: begin //QXCH
                            //
			end
			qcAUG: begin //AUG
                            //
			end
			qcDIM: begin //DIM
                            //
			end
	            endcase
		end
		opDCA: begin //DCA
                    //
	        end
		opDCS: begin //DCS
                    //
		end
		opINDEX: begin //INDEX
                    //
	        end
		opSU: begin //corresponds to SU and BZMF
                    if  (qq == qcSU) begin //SU
                        //
		    end
		    else begin //BZMF
			//
		    end
	        end
		opMP: begin //MP
                    //
	        end
	    endcase
	end 
	else begin //not extracode
            case (aaa)
                opTC: begin //TC
		    //
		end
		opCCS: begin //corresponds to CCS and TCF
		    if (qq == qqCCS) begin //CCS
	                //
		    end
		    else begin //TCF
			//
		    end
		end
		opDAS: begin //corresponds to DAS, LXCH, INCR, and ADS
		    case (qq)
		        qcDAS: begin //DAS
			    //
			end
			qcLXCH: begin //LXCH
			    //
			end
			qcINCR: begin //INCR
			    //
			end
			qcADS: begin //ADS
			    //
			end
		    endcase
		end
		opCA: begin //CA
		    //
		end
		opCS: begin //CS
		    //
		end
		opINDEX: begin //corresponds to INDEX, DXCH, TS, XCH
		    case (qq)
			qcINDEX: begin //INDEX
			    //
			end
			qcDXCH: begin //DXCH
			    //
			end
			qcTS: begin //TS
			    //
			end
			qcXCH: begin //XCH
			    //
			end
		    endcase
		end
		opAD: begin //AD
		    //adds the contents of a memory location into the accumulator (rA)
		    //will in the future set the overflow flag.
		    if 
		end
		opMASK: begin //MASK
		    //
		end
	    endcase
	end

    //encoding output
    Exec2Writeback e2w = Exec2Writeback{
	eRes1:eRes1,
	eRes2:eRes2,
	memAddr:memAddr,
	regNum:regNum,
	newZ:newZ,
    };
    return e2w;

endfunction


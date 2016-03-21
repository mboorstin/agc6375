import GetPut::*;

import AGCMemory::*;
import MemTypes::*;
import Types::*;

(*synthesize*)

module mkAGCMemoryTester(Empty);
    AGCMemory memory <- mkAGCMemory();

    Reg#(Bit#(32)) step <- mkReg(0);

    rule s0 (step == 0);
        memory.init.request.put(tagged InitDone);
        step <= 1;
    endrule

    rule s1 (step == 1);
        // Everything should start at 0, so 'O1600 should map to the middle of E0
        memory.storer.memStore('O1600, 'hDEAD);
        memory.storer.regStore(rA, 'hBEEF);
        step <= 2;
    endrule

    rule s2 (step == 2);
        // Start the request
        memory.fetcher.memReq('O200);
        // Start the request for A via registers
        memory.fetcher.regReq(rA);
        memory.imem.req('O1600);

        step <= 3;
    endrule

    // Tests timing (fetch and read request)
    rule s3 (step == 3);
        Word mRet <- memory.fetcher.memResp();
        if (mRet != 'hDEAD) begin
            $display("FAILED: s3, mRet = %x", mRet);
            $finish();
        end

        Word rRet <- memory.fetcher.regResp();
        if (rRet != 'hBEEF) begin
            $display("FAILED: s3, rRet = %x", rRet);
            $finish();
        end

        Word iRet <- memory.imem.resp();
        if (iRet != 'hDEAD) begin
            $display("FAILED: s3, iRet = %x", iRet);
            $finish();
        end

        memory.fetcher.memReq(zeroExtend(rA));
        memory.fetcher.regReq(zeroExtend(rQ));
        memory.imem.req(zeroExtend(rA));

        step <= 4;
    endrule

    // Tests timing (fetch and write request), and sets up
    // EB and FB for next test
    rule s4 (step == 4);
        Word mRet <- memory.fetcher.memResp();
        if (mRet != 'hBEEF) begin
            $display("FAILED: s4, mRet = %x", mRet);
            $finish();
        end

        Word rRet <- memory.fetcher.regResp();
        if (rRet != 0) begin
            $display("FAILED: s4, rRet = %x", rRet);
            $finish();
        end

        Word iRet <- memory.imem.resp();
        if (iRet != 'hBEEF) begin
            $display("FAILED: s4, iRet = %x", iRet);
            $finish();
        end

        // Selects E bank 4
        memory.storer.memStore(zeroExtend(rEB), 'h800);
        // Select F bank 4
        memory.storer.regStore(zeroExtend(rFB), 'h2000);

        step <= 5;
    endrule

    // Make sure BB was mirrored correctly.  Should add a test for
    // readRegImm once we've found an elegant way of incorporating it
    rule s5 (step == 5);
        memory.fetcher.memReq('O200);
        memory.fetcher.regReq(rBB);
        memory.imem.req('O1600);

        step <= 6;
    endrule

    // Get back the BB tests, and make sure that 'O200 still points at E0 but that
    // 'O1600 points at E4
    rule s6 (step == 6);
        Word mRet <- memory.fetcher.memResp();
        if (mRet != 'hDEAD) begin
            $display("FAILED: s6, mRet = %x", mRet);
            $finish();
        end

        Word rRet <- memory.fetcher.regResp();
        if (rRet != 'h2008) begin
            $display("FAILED: s6, rRet = %x", rRet);
            $finish();
        end

        Word iRet <- memory.imem.resp();
        if (iRet != 'hAAAA) begin
            $display("FAILED: s6, iRet = %x", iRet);
            $finish();
        end

        step <= 1000;
    endrule

    rule finish (step == 1000);
        $display("PASSED");
        $finish();
    endrule

endmodule

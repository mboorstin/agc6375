#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>

#include "bsv_scemi.h"
#include "SceMiHeaders.h"
#include "ResetXactor.h"

#define AGC_START_IP 04000

int main(int argc, char* argv[]) {
    std::cout << "Starting up" << std::endl;

    int sceMiVersion = SceMi::Version( SCEMI_VERSION_STRING );
    SceMiParameters params("../scemi.params");
    SceMi *sceMi = SceMi::Init(sceMiVersion, &params);

    // Initialize the SceMi ports
    OutportQueueT<IOPacket> ioAGCToHost("", "scemi_ioAGCToHost_outport", sceMi);
    InportProxyT<IOPacket> ioHostToAGC("", "scemi_ioHostToAGC_inport", sceMi);
    InportProxyT<Addr> start("", "scemi_start_inport", sceMi);
    InportProxyT<MemInit> memInit("", "scemi_memInit_inport", sceMi);

    ResetXactor reset("", "scemi", sceMi);
    ShutdownXactor shutdown("", "scemi_shutdown", sceMi);

    // Service SceMi requests
    SceMiServiceThread *scemi_service_thread = new SceMiServiceThread(sceMi);

    // Make sure the AGC is reset
    reset.reset();

    // Initialize the memory

    // Start up the yaDSKY server

    // Finally, start the processor
    start.sendMessage(AGC_START_IP);

    std::cout << "Press Enter to quit" << std::endl;
    getchar();

    std::cout << "Shutting down" << std::endl;

    shutdown.blocking_send_finish();
    scemi_service_thread->stop();
    scemi_service_thread->join();
    SceMi::Shutdown(sceMi);

    return 0;
}


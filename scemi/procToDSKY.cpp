#include <iostream>
#include <unistd.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <sys/socket.h>
#include <netinet/in.h>

#include "bsv_scemi.h"
#include "SceMiHeaders.h"
#include "ResetXactor.h"

#define AGC_START_IP 04000
#define DSKY_PORT 19797

// This testbench initializes the memory from a binary file and handles passing
// I/O requests back and forth between the simulation/FPGA and yaDSKY2
// It's (for now) super sketchy; in particular, besides being a single giant
// ugly hacky messy file, it makes no attempt  to handle race conditions between the
// different monitoring threads.  This *shouldn't* be a problem because they use
// different SceMi channels and the operating systemc should handle sharing the TCP
// socket talking to yaDSKY2, but it still seems sketchy.  The sharing of dskyFD is
// scary and terrible.

// 00utpppp 01pppddd 10dddddd 11dddddd
struct DSKYPacket {
    unsigned int pUpper:   4;
    unsigned int t:        1;
    unsigned int u:        1;
    unsigned int padding0: 2;

    unsigned int dUpper:   3;
    unsigned int pLower:   3;
    unsigned int padding1: 2;

    unsigned int dMiddle:  6;
    unsigned int padding2: 2;

    unsigned int dLower:   6;
    unsigned int padding3: 2;
} __attribute__((packed));

void dskyPacketToIOPacket(DSKYPacket* in, IOPacket* out) {
    out->m_channel = (in->pUpper << 3) + in->pLower;
    out->m_data = (in->dUpper << 12) + (in->dMiddle << 6) + in->dLower;
}

// We're repeatedly setting padding, t, and u unnecessarily.  Should just initialize once.
void ioPacketToDSKYPacket(IOPacket* in, DSKYPacket* out) {
    out->pUpper = (((unsigned int) in->m_channel) & 0x78u) >> 3;
    out->t = 0;
    out->u = 0;
    out->padding0 = 0;

    out->dUpper = (((unsigned int) in->m_data) & 0x7000u) >> 12;
    out->pLower = ((unsigned int) in->m_channel) & 0x07u;
    out->padding1 = 1;

    out->dMiddle = (((unsigned int) in->m_data) & 0xFC0u) >> 6;
    out->padding2 = 2;

    out->dLower = ((unsigned int) in->m_data) & 0x3Fu;
    out->padding3 = 3;
}

struct RunDSKYListenerArgs {
    int serverFD;
    int* dskyFD;
    InportProxyT<IOPacket>* ioHostToAGC;
};

void* runDSKYListener(void* arg) {
    struct sockaddr_in client;
    socklen_t clientLen = sizeof(client);
    DSKYPacket inBuf;
    IOPacket outBuf;

    RunDSKYListenerArgs* args = (RunDSKYListenerArgs*) arg;

    listen(args->serverFD, 1);
    while (true) {
        int dskyFD = accept(args->serverFD, (struct sockaddr*)&client, &clientLen);
        *(args->dskyFD) = dskyFD;

        while (true) {
            if (read(dskyFD, &inBuf, sizeof(DSKYPacket)) < sizeof(DSKYPacket)) {
                fprintf(stderr, "Error reading from socket!\n");
                break;
            }

            fprintf(stderr, "Received data from yaDSKY2!\n");
            dskyPacketToIOPacket(&inBuf, &outBuf);
            args->ioHostToAGC->sendMessage(outBuf);
        }
    }
}

struct RunAGCListenerArgs {
    int* dskyFD;
    OutportQueueT<IOPacket>* ioAGCToHost;
};

void* runAGCListener(void* arg) {
    DSKYPacket outBuf;

    RunAGCListenerArgs* args = (RunAGCListenerArgs*) arg;

    while (true) {
        IOPacket packet = args->ioAGCToHost->getMessage();
        printf("Received data from AGC!\n");
        ioPacketToDSKYPacket(&packet, &outBuf);
        if (!(*(args->dskyFD)) || (write(*(args->dskyFD), &outBuf, sizeof(DSKYPacket)) < 0)) {
            fprintf(stderr, "Error writing to socket!\n");
        }
    }
}

void exitCleanly(ShutdownXactor* shutdown, SceMiServiceThread* scemiServiceThread, SceMi* sceMi, int serverFD, int ret) {
    printf("Shutting down!\n");

    shutdown->blocking_send_finish();
    scemiServiceThread->stop();
    scemiServiceThread->join();
    SceMi::Shutdown(sceMi);

    if (serverFD > 0) {
        close(serverFD);
    }

    exit(ret);
}

int main(int argc, char* argv[]) {
    printf("Starting up!\n");

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
    SceMiServiceThread *scemiServiceThread = new SceMiServiceThread(sceMi);

    // Make sure the AGC is reset
    reset.reset();

    // Initialize the FPGA memory

    // Set up the DSKY socket
    int serverFD = socket(AF_INET, SOCK_STREAM, 0);
    if (serverFD < 0) {
        fprintf(stderr, "Error opening socket!\n");
        exitCleanly(&shutdown, scemiServiceThread, sceMi, serverFD, 1);
    }

    struct sockaddr_in server;
    server.sin_family = AF_INET;
    server.sin_addr.s_addr = INADDR_ANY;
    server.sin_port = htons(DSKY_PORT);
    if (bind(serverFD, (struct sockaddr *) &server, sizeof(server)) < 0) {
        fprintf(stderr, "Error binding socket!\n");
        exitCleanly(&shutdown, scemiServiceThread, sceMi, serverFD, 1);
    }

    // Start the listeners in separate threads
    int dskyFD = 0;
    pthread_t dskyListener, agcListener;
    RunDSKYListenerArgs dskyArgs = {serverFD, &dskyFD, &ioHostToAGC};
    RunAGCListenerArgs agcArgs = {&dskyFD, &ioAGCToHost};

    int failure = pthread_create(&dskyListener, NULL, runDSKYListener, &dskyArgs);
    if (failure) {
        fprintf(stderr, "Error creating DSKY listener thread: %d\n", failure);
        exitCleanly(&shutdown, scemiServiceThread, sceMi, serverFD, 1);
    }

    failure = pthread_create(&agcListener, NULL, runAGCListener, &agcArgs);
    if (failure) {
        fprintf(stderr, "Error creating AGC listener thread: %d\n", failure);
        exitCleanly(&shutdown, scemiServiceThread, sceMi, serverFD, 1);
    }

    // Finally, start the processor
    start.sendMessage(AGC_START_IP);

    printf("Press Enter to quit\n");

    getchar();

    exitCleanly(&shutdown, scemiServiceThread, sceMi, serverFD, 0);
}

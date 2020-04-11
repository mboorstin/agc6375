#!/usr/bin/env python3

import argparse
from dsky import DSKY
from harness import Harness

# Testbench to initialize the AGC and handle communication between peripherals like the DSKY.

def main():
    # Argument parsing
    parser = argparse.ArgumentParser()
    # Can't use -h because of --help
    parser.add_argument('-a', '--harness', help = 'Harness address to connect to')
    args = parser.parse_args()

    # Instantiate the two main listeners
    harness = Harness(args.harness)
    dsky = DSKY()

    # Initialize them.  Both are blocking on their respective connections.  We also take
    # this as the time to initialize the data callbacks between them
    harness.initialize(getListenerCB(dsky))
    dsky.initialize(getListenerCB(harness))

    # Everything is ready, so start the processor
    harness.start()

# Return a callback suitable for passing a packet from one listener to another
def getListenerCB(listener):
    return lambda u, channel, data: listener.sendPacket(u, channel, data)


if __name__ == "__main__":
    main()

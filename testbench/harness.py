import socket
import threading

# Class to handle communication with the harness.  See SimHarness.bsv for the packet structures.

class Harness:

    # The processor actually starts at 4000, but Z always points to the next instruction
    ADDR_START = 0o4001

    # See SimHarness.bsv
    COMMAND_INIT_MEM = 1
    COMMAND_INIT_IO = 2
    COMMAND_INIT_DONE = 3
    COMMAND_START = 4
    COMMAND_HOST_TO_AGC = 5
    COMMAND_AGC_TO_HOST = 6

    READ_PACKET_SIZE = 4

    def __init__(self, address):
        self.address = address

    # Connect to and initialize the processor, for now without transferring a program.
    # Does not start it.
    # agcToHostCB should be a function to call with (u, channel, data) when received from the AGC
    def initialize(self, agcToHostCB):
        self.agcToHostCB = agcToHostCB

        # Do the TCP connection
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        # Need to split into a host and port
        hostAndPort = self.address.split(':')
        # Do the connection
        self.socket.connect((hostAndPort[0], int(hostAndPort[1])))

        print('[Testbench] Connected to the harness')

        # Start a new thread for listening to the connection
        self.listenerThread = threading.Thread(target = self.readHandler)
        self.listenerThread.start()

        # Initialize the I/O channels.  These seem to be initial start up settings.
        self.sendInitIO(0o30, 0o37777);
        self.sendInitIO(0o31, 0o77777);
        self.sendInitIO(0o32, 0o77777);
        self.sendInitIO(0o33, 0o77777);

        # For now, skipping memory initialization

        # Mark the initialization as done
        self.sendInitDone()

    # Start the processor
    def start(self):
        self.sendStart(self.ADDR_START)

    # Low level send functionality to handle bit packing and such
    def send(self, command, encodedData):
        # Build the packet by prefixing the 1 byte command to the encoded data.  Byteorder doesn't matter
        # for a 1-byte array but the function requires it
        packet = command.to_bytes(1, byteorder = 'big') + encodedData
        self.socket.send(packet)

    def sendInitMem(self):
        raise Exception('Not implemented yet!')

    def sendInitIO(self, channel, data):
        # IO initialization always has a u of 0, so we zero out the top bit of the channel
        encodedData = (channel & 0x7F).to_bytes(1, byteorder = 'big') + data.to_bytes(2, byteorder = 'big')
        self.send(self.COMMAND_INIT_IO, encodedData)

    def sendInitDone(self):
        self.send(self.COMMAND_INIT_DONE, b'')

    # Start the processor at the given startZ
    def sendStart(self, startZ):
        self.send(self.COMMAND_START, startZ.to_bytes(2, byteorder = 'big'))

    def sendHostToAGC(self, u, channel, data):
        # Python's struct library doesn't seem to support individual bits, so we have to do it manually
        ubit = 0x80 if (u == 1) else 0x0
        channelBits = ubit | (channel & 0x7F)
        encodedData = channelBits.to_bytes(1, byteorder = 'big') + data.to_bytes(2, byteorder = 'big')

        self.send(self.COMMAND_HOST_TO_AGC, encodedData)

    # Thread to read from the handler
    def readHandler(self):
        # Listen for 4 byte packets from the harness
        while True:
            # Wait for all 4 bytes (the current harness is only able to write 1 byte at a time)
            data = self.socket.recv(self.READ_PACKET_SIZE, socket.MSG_WAITALL)
            if not data:
                raise Exception('Error receiving data from harness; exiting.')

            # Parse the data.  Python's struct library doesn't seem to support individual bits, so since we're already doing
            # bit manipulations might as well do all of them
            if data[0] != self.COMMAND_AGC_TO_HOST:
                raise Exception('Unexpected agcToHost command: 0x%s' % (data.hex()))
            # Top bit
            u = data[1] & 0x80
            # Rest of the bits
            channel = data[1] & 0x7F
            data = int.from_bytes(data[2:4], byteorder = 'big')

            # Send it to the handler
            self.agcToHostCB(u, channel, data)

    # Send a packet to the harness
    def sendPacket(self, u, channel, data):
        self.sendHostToAGC(u, channel, data)

import socket
import threading

# Class to handle communication with the DSKY

class DSKY:

    DSKY_PACKET_SIZE = 4
    DSKY_PORT = 19797

    def __init__(self):
        self.serverSock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.serverSock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.serverSock.bind(('localhost', self.DSKY_PORT))
        self.serverSock.listen()

    # hostToAGCCB should be a function to call with (u, channel, data) when received from the DSKY
    # Wait for a connection from the DSKY and start a new thread on readHandler when it comes.  We only
    # ever need to service a single connection.
    def initialize(self, hostToAGCCB):
        self.hostToAGCCB = hostToAGCCB

        print('[Testbench] Waiting for DSKY to connect...')
        # Wait for the connection
        self.clientSock, address = self.serverSock.accept()
        # Start a new thread for listening to the connection
        self.listenerThread = threading.Thread(target = self.readHandler)
        self.listenerThread.start()

    # Thread to read from the DSKY
    def readHandler(self):
        print('[Testbench] Got DSKY connection')
        # Listen for 4 byte packets from the DSKY
        while True:
            data = self.clientSock.recv(self.DSKY_PACKET_SIZE, socket.MSG_WAITALL)
            if not data:
                raise Exception('Error receiving data from DSKY; exiting.')

            # Have to parse a similar structure as sendPacket().  Again, it would be
            # nice if Python's struct library let you specify bit lengths.
            u = (data[0] & 0x20) >> 5
            channel = ((data[0] & 0x0F) << 3) | ((data[1] & 0x38) >> 3)
            data = ((data[1] & 0x07) << 12) | ((data[2] & 0x3F) << 6) | (data[3] & 0x3F)
            print('[Testbench] Received data (%d, %d, 0x%x) from the DSKY' % (u, channel, data))

            # Send it to the handler
            self.hostToAGCCB(u, channel, data)

    # Send a packet to the DSKY
    def sendPacket(self, u, channel, data):
        # print('[Testbench] Writing data (%d, %d, 0x%x) to the DSKY' % (u, channel, data))
        # DSKY packets are of the form 00utpppp 01pppddd 10dddddd 11dddddd, where p is the channel
        # bits and d is the data bits (I'm using yaDSKY's nomenclature; not sure why he's calling it p).
        # Python's struct library doesn't let you specify exact bit lengths, so we're on our own here.
        # Note that t is always 0.
        packet = bytearray([])

        ubit = 0x20 if (u == 1) else 0x0
        pUpper = (channel & 0x78) >> 3
        packet += (ubit | pUpper).to_bytes(1, byteorder = 'big')

        pLower = (channel & 0x07) << 3
        dUpper = (data & 0x7000) >> 12
        packet += (0x40 | pLower | dUpper).to_bytes(1, byteorder = 'big')

        dMiddle = (data & 0xFC0) >> 6
        packet += (0x80 | dMiddle).to_bytes(1, byteorder = 'big')

        dLower = data & 0x3F
        packet += (0xC0 | dLower).to_bytes(1, byteorder = 'big')

        self.clientSock.send(packet)

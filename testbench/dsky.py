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
            data = self.clientSock.recv(self.DSKY_PACKET_SIZE)
            if not data:
                raise Exception('Error receiving data from DSKY; exiting.')
            print('[Testbench] Received data 0x%s from the DSKY' % (data.hex()))
            raise Exception('Not implemented yet!')

    # Send a packet to the DSKY
    def sendPacket(self, u, channel, data):
        print('[Testbench] Writing data (%d, %d, 0x%x) to the DSKY' % (u, channel, data))
        # DSKY packets are of the form 00utpppp 01pppddd 10dddddd 11dddddd, where p is the channel
        # bits and d is the data bits.  Python's struct library doesn't let you specify exact bit
        # lengths, so we're on our own here.  Oh well.  Note that t is always 0.
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

        print('[Testbench] Encoded data 0x%s' % packet.hex())
        self.clientSock.send(packet)

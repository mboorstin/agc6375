#!/usr/bin/env python

# Translate between yaYUL-generated core rope images and hex VMH
# This is (for now) very specific to our memory map, but could be
# generalized pretty easily
# Using hex instead of binary because the address markings mess up
# the alignmentin hex viewers so binary VMH is unpleasant to use

import sys

if len(sys.argv) != 3:
    print "Usage: ./toVMH [input bin] [output vmh]"
    raise

inFilePath = sys.argv[1]
outFilePath = sys.argv[2]

with open(inFilePath, "rb") as inFile:
    with open(outFilePath, "w") as outFile:
        def transWord():
            # Ugh binary manipulations in Python :-(
            upper = inFile.read(1)
            lower = inFile.read(1)
            word = (ord(upper) << 8) + ord(lower)
            outFile.write(format(word, "x") + "\n")

        # Bank 2: 4096
        outFile.write("@1000\n")
        # Banks 2, 3
        for i in xrange(2048):
            transWord()
        # Bank 0: 2048
        outFile.write("@800\n")
        # Banks 0, 1
        for i in xrange(2048):
            transWord()
        # Bank 4: 6144
        outFile.write("@1800\n")
        # Banks [4, 36)
        for i in xrange(1024 * 32):
            transWord()

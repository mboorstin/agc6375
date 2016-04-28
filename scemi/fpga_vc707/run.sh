#!/bin/bash

# Takes one argument: path to the program to run

# if [ "$#" -ne 1 ]; then
#     echo "Usage: ./run.sh programPath"
#     exit
# fi

source /mit/6.375/setup.sh

bash bluenoc_hotswap
sleep 1
bluenoc reset
sleep 1
bluenoc reset
# ./build/bin/procToDSKY ${1}
# Scemi needs to be run from the build directory because it's expecting
# a parameters file...sigh
sleep 1
cd build/bin
./procToDSKY
cd -
sleep 1
bluenoc reset
sleep 1

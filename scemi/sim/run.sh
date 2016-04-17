#!/bin/bash

# Takes one argument: name of the processor to run

if [ "$#" -ne 1 ]; then
    echo "Usage: ./run.sh procName (ie, ./run.sh fourcycle)"
    exit
fi

source /mit/6.375/setup.sh
# Bluesim needs to be run from the same directory as program.vmh...sigh
cd build/bin
./${1}Sim &> ../../simOut &
sleep .5
./procToDSKY
cd -

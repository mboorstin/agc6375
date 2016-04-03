6.375 Final Project: Apollo Guidance Computer
=============================================

Building
--------

To build for simulation, run `build -v [procname]` in `scemi/sim`.  Currently, only `scemitest` and `fourcycle` are supported for `procname`.  This produces the following binaries in `scemi/sim/build/bin`:
  - `[procname]Sim`: Bluesim executable simulating the target processor
  - `procToDSKY`: Testbench that proxies yaDSKY I/O traffic to the target processor and vice versa.  Also handles memory initialization.

The Bluesim file should be started first, then `procToDSKY`, and finally `yaDSKY2` should be used to connect to `procToDSKY` (on port 19797).


Writing Programs
----------------

This will be makefile'd very soon.  For now, you should use yaYUL (download and install separately) on your source file.  This will produce a `.bin` file that you should run through `programs/toVMH.py`.  That produces a `vmh` file that you should copy to `scemi/sim/build/bin/program.vmh`, which will then be loaded by Bluesim.

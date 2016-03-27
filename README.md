6.375 Final Project: Apollo Guidance Computer
=============================================

Building
--------

To build for simulation, run `build -v [procname]` in `scemi/sim`.  Currently, only `scemitest` and `fourcycle` are supported for `procname`.  This produces the following binaries in `scemi/sim/build/bin`:
  - `[procname]Sim`: Bluesim executable simulating the target processor
  - `procToDSKY`: Testbench that proxies yaDSKY I/O traffic to the target processor and vice versa.  Also handles memory initialization.

The Bluesim file should be started first, then `procToDSKY`, and finally `yaDSKY2` should be used to connect to `procToDSKY` (on port 19797).

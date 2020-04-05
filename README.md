6.375 Final Project: Apollo Guidance Computer
=============================================

New Work
========

During the 2020 coronavirus epidemic we started up work on this again, using the open source https://github.com/B-Lang-org/bsc compiler.  I've started to clean up the work I did for 6.375 a few years ago, but things are still messy.


Prerequisites
-------------

* Bluespec: Follow the installation directions at https://github.com/B-Lang-org/bsc, and make sure the `bsc` binary is in your path.
* SceMi: The basic Bluespec installation doesn't come with a copy of the Bluespec SceMi library.  Get a copy of it and put it in your Bluespec library directory.
* yaYUL: Install `yaYUL` from https://github.com/virtualagc/virtualagc, and make sure it is in your path.


Compiling Programs
------------------

To compile a program into a VMH that can be loaded into the AGC's memory, run `make $PROGRAM_NAME`, like so:

```sh
$ make debugging/ads
```


Building and Running in Simulation
----------------------------------

To build and run for Bluesim simulation, do the following, substituting `ads` for the name of a program you compiled above.

```sh
$ make simbuild
$ make simrun PROGRAM=ads
```


Old Docs
========

Building
--------

To build for simulation, run `build -v [procname]` in `scemi/sim`.  Currently, only `scemitest` and `fourcycle` are supported for `procname`.  This produces the following binaries in `scemi/sim/build/bin`:
  - `[procname]Sim`: Bluesim executable simulating the target processor
  - `procToDSKY`: Testbench that proxies yaDSKY I/O traffic to the target processor and vice versa.  Also handles memory initialization.

The Bluesim file should be started first, then `procToDSKY`, and finally `yaDSKY2` should be used to connect to `procToDSKY` (on port 19797).


Writing Programs
----------------

This will be makefile'd very soon.  For now, you should use yaYUL (download and install separately) on your source file.  This will produce a `.bin` file that you should run through `programs/toVMH.py`.  That produces a `vmh` file that you should copy to `scemi/sim/build/bin/program.vmh`, which will then be loaded by Bluesim.

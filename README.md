6.375 Final Project: Apollo Guidance Computer
=============================================

New Work
========

During the 2020 coronavirus epidemic Val and I started up work on this again, using the open source https://github.com/B-Lang-org/bsc compiler.  We've started to clean up the work we did for 6.375 a few years ago, but things are still messy.


Prerequisites
-------------

* Bluespec: Follow the installation directions at https://github.com/B-Lang-org/bsc, and make sure the `bsc` binary is in your path.
* SceMi: The basic Bluespec installation doesn't come with a copy of the Bluespec SceMi library.  Get a copy of it and put it in your Bluespec library directory.
* VirtualAGC compontents: Install `yaDSKY2`, `yaYUL`, and `LM_Simulator` from https://github.com/virtualagc/virtualagc, and make sure they are in your path.
* Submodules: Get the submodules fetched with `git submodule update --init --recursive`.


Compiling Programs
------------------

To compile a program into a VMH that can be loaded into the AGC's memory, run `make $PROGRAM_NAME`, like so:

```sh
$ make demo/demo.bin
```


Building and Running in Simulation
----------------------------------

To build and run for Bluesim simulation, do the following, substituting `demo` for the name of a program you compiled above.

```sh
$ make simbuild
$ make simrun-demo
```

Now that you have the simulation running, start up the testbench in a second window:

```sh
$ make testbench
```

And finally start up the control UI.  You can either use `yaDSKY2` if you just want the keyapd, or `LM_Simulator` for more control panels.  Note that `LM_Simulator` won't start up unless the testbench is already serving the selected port.

```sh
$ LM_Simulator --port 19797
```


Adding a New Harness
--------------------

In order to add a new harness, such as a new simulation type or a new FPGA transport type, you need to be able to call the following AGC functions:
  - `agc.memInit.request.put(MemInitLoad data)` to initialize the program memory (only needed if you're not initializing the memory out-of-band)
  - `agc.hostIO.init(IOPacket packet)` to initialize the I/O buffers.
  - `agc.memInit.InitDone()` to mark the program memory as initialized.  You must call this even if you're not using `MemInit.InitLoad()`.
  - `agc.start(uint16_t addr)` to actually start the AGC.  You probably want to start it at `04001`.
  - `agc.hostIO.hostToAGC(IOPacket packet)` to send data to the AGC's I/O channels.
  - `agc.hostIO.agcToHost() => IOPacket` to receive data from the AGC's I/O channels.

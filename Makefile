#############
# Constants #
#############

# Basic Flags
BSC=bsc


# Directories
DIR_BIN=bin
DIR_BUILD=build
DIR_PROGRAMS=programs
DIR_SOURCE=src

# BSV-related constants
# List of modules to compile, separated by :
# TODO: Autogenerate these lists
BSV_MODULES_COMMON=agc:agc/common:agc/decode:agc/exec:agc/includes:agc/io:agc/memory
BSV_MODULES_SIM=harness/sim/vendor/BlueBasics:harness/sim/vendor/CharIO
# Symlink for program to load (see discussion in AGCMemory.bsv)
BSV_PROGRAM_PATH=$(DIR_BUILD)/program

# Simulation related constants
# BDPI C files that need compiling.  Note this needs to be relative to the build directory
SIM_BDPI_FILES_ROOT:=$(shell find $(DIR_SOURCE) -name '*.c')
SIM_BDPI_FILES:=$(SIM_BDPI_FILES_ROOT:%=../%)
# Port for the harness to listen on
SIM_HARNESS_PORT=19796


#######################
# Program Compilation #
#######################

# General target for any .bin
%.bin:
	# Compile.  Annoyingly yaYUL doesn't let you specify an output directory, so it
	# compiles in the source directory which is ugly.  We move it to the bin directory ourselves.
	yaYUL $(DIR_PROGRAMS)/$(basename $@).agc
	mv $(DIR_PROGRAMS)/$(basename $@).agc.bin $(DIR_BIN)/$(notdir $@)
	rm $(DIR_PROGRAMS)/$(basename $@).agc.symtab
	# Convert it to a VMH
	./toVMH.py $(DIR_BIN)/$(notdir $@) $(DIR_BIN)/$(notdir $*).vmh

# Programs to compile
debugging/ads: debugging/ads.bin


#######################
# Bluespec Simulation #
#######################

# Build the processor for Bluesim
simbuild:
	# Compile
	# -fdir dir is supposed to set the working directory, but doesn't seem to work.  Oh well.
	# TODO: Pull out the BSC flags
	cd $(DIR_SOURCE) && $(BSC) -cpp -Xcpp -I. -sim -p +:$(BSV_MODULES_COMMON):$(BSV_MODULES_SIM) -bdir ../$(DIR_BUILD) -D SIM -D PROGRAM_PATH='"$(BSV_PROGRAM_PATH)"' -D SIM_HARNESS_PORT=$(SIM_HARNESS_PORT) -u harness/sim/SimHarness.bsv

	# Link
	cd $(DIR_BUILD) && $(BSC) -sim -e mkSimHarness -o mkSimHarness mkSimHarness.ba $(SIM_BDPI_FILES)

# Run the Bluesim simulator
simrun-%:
	# Symlink the program to run (see discussion in AGCMemory.bsv)
	ln -sf $(abspath $(DIR_BIN)/$*.vmh) $(BSV_PROGRAM_PATH)

	# Start the simulator
	./$(DIR_BUILD)/mkSimHarness


#########
# Other #
#########

# Clean all generated files
clean:
	rm -rf $(DIR_BIN)/*
	rm -rf $(DIR_BUILD)/*

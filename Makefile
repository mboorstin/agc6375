#############
# Constants #
#############

# Directories
DIR_BIN=bin
DIR_BUILD=build
DIR_PROGRAMS=programs
DIR_SOURCE=src

# BSV-related constants
# List of modules to compile, separated by :
BSV_MODULES=common:decode:exec:includes:io:memory
# Symlink for program to load (see discussion in AGCMemory.bsv)
BSV_PROGRAM_PATH=$(DIR_BUILD)/program


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
	./toVMH.py $(DIR_BIN)/$(notdir $@) $(DIR_BIN)/$(notdir $@).vmh

# Programs to compile
debugging/ads: debugging/ads.bin


#######################
# Bluespec Simulation #
#######################

# Build the processor for Bluesim
simbuild:
	# Compile
	# -fdir dir is supposed to set the working directory, but doesn't seem to work.  Oh well.
	cd $(DIR_SOURCE) && bsc -sim -p +:$(BSV_MODULES) -bdir ../$(DIR_BUILD) -D SIM -D PROGRAM_PATH='"$(BSV_PROGRAM_PATH)"' -u FourCycle.bsv
	# Link
	cd $(DIR_BUILD) && bsc -sim -e mkAGC -o mkAGC mkAGC.ba

# Run the Bluesim simulator
simrun:
ifndef PROGRAM
	$(error PROGRAM not set)
endif
	# Symlink the program to run (see discussion in AGCMemory.bsv)
	ln -sf $(abspath $(DIR_BIN)/$(PROGRAM).bin.vmh) $(BSV_PROGRAM_PATH)
	# Start the simulator
	./$(DIR_BUILD)/mkAGC


#########
# Other #
#########

# Clean all generated files
clean:
	rm -rf $(DIR_BIN)/*
	rm -rf $(DIR_BUILD)/*

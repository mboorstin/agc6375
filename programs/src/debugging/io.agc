# Really simple test to see if I/O works
# Waits for data from channel 15 (any key press), then sets the
# COMP ACTY indicator (channel 11, bit 2)

		# Program
		SETLOC	4000
		CA	4400
		EXTEND
		WRITE	11

		EXTEND
		EDRUPT 0

		# Data
		SETLOC	4400
		OCT 1

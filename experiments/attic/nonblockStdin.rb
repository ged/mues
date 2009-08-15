#!/usr/bin/ruby -w

require '../utils'
include UtilityFunctions

# An experiment to test for ways of doing non-blocking reads on $stdin for the
# console listener.

header "Experiment: Non-blocking reads on STDIN."

message "Starting read loop..."
loop {
	len = $stdin.read( 4096 )
	message "."

	unless len.nil? || len.empty?
		message "(Read %d bytes)\n" % len.length
	end
}


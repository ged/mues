#!/usr/bin/ruby -w

require '../utils'
include UtilityFunctions

# This is an experiment to see if a begin/ensure block inside of a while will
# act like a Perl while/continue.

header "Experiment: Fake Continue block"

i = 0

while i < 10
	begin
		i += 1
		next if ( i % 2 ).nonzero?
		message "Even loop (#{i}).\n"
	ensure
		message "Ensured (#{i}).\n"
	end
end


#!/usr/bin/ruby -w

require '../utils'
include UtilityFunctions

# This is an experiment to figure out once and for all what the path of
# execution through a Continuation is.

header "Experiment: Demystifying Continuations"


message "Creating a continuation...\n"

cont = callcc {|cc|
	message "Inside the callcc block, about to return: %p.\n" % cc
	cc
}

message "After creating the continuation: %p\n" % cont

if cont.is_a?( Continuation )
	message "Calling %p\n" % cont
	cont.call( :foo )
	message "Done calling the continuation\n"
else
	message "Continuation was false.\n"
end

message "Done considering the continuation\n"


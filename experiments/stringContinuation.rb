#!/usr/bin/ruby -w

require '../utils'
include UtilityFunctions

# This is just a little experiment with Ruby's string continuation to test when
# you can use it and when you can't.

header "Creating string 'a'"
a = "This is " \
	"a string"
message "String a: #{a}\n\n"


header "Creating string 'b'"
b = sprintf( "This is a string "\
			 "with some %s in "\
			 "it", 'esc'\
			 'apes' )
message "String b: #{b}\n\n"


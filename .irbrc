#!/usr/bin/ruby

puts ">>> Adding lib and ext to load path..."
$LOAD_PATH.unshift( "lib", "ext" )

require './utils'
include UtilityFunctions

def colored( prompt, *args )
	return ansiCode( *(args.flatten) ) + prompt + ansiCode( 'reset' )
end


# Modify prompt to do highlighting unless we're running in an inferior shell.
unless ENV['EMACS']
	IRB.conf[:PROMPT][:MUES] = { # name of prompt mode
		:PROMPT_I => colored( "%N(%m):%03n:%i>", %w{bold white on_blue} ) + " ",
		:PROMPT_S => colored( "%N(%m):%03n:%i%l", %w{white on_blue} ) + " ",
		:PROMPT_C => colored( "%N(%m):%03n:%i*", %w{white on_blue} ) + " ",
		:RETURN => "    ==> %s\n\n"      # format to return value
	}
	IRB.conf[:PROMPT_MODE] = :MUES
end

# Try to require the 'mues' library
begin
	puts "Requiring mues..."
	require "mues"
rescue => e
	$stderr.puts "Ack! MUES library failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end

#!/usr/bin/ruby
###########################################################################
=begin

=IOEvents.rb

== Name

IOEvents - A collection of I/O event classes

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Exceptions"

require "mues/events/BaseClass"

module MUES

	###########################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	###########################################################################

	### (ABSTRACT) CLASS: IOEvent < Event
	class IOEvent < Event ; implements AbstractClass
		attr_accessor	:data

		def initialize( *args )
			super()
			@data = args.collect {|m| m.to_s}.join('')
		end

		def to_s
			return "%s: %s" % [ super(), @data ]
		end
	end

	### (ABSTRACT) CLASS: ControlIOModeEvent < IOEvent
	class ControlIOModeEvent < IOEvent ; implements AbstractClass

		### :WORK: Control modes/commands (eg., NO_ECHO_MODE, LINE_MODE,
		### CHAR_MODE, etc.)
		NO_ECHO_MODE	= :NO_ECHO_MODE
		LINE_MODE		= :LINE_MODE
		CHAR_MODE		= :CHAR_MODE
	end


	###########################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	###########################################################################

	### CLASS: OutputEvent < IOEvent
	class OutputEvent < IOEvent; end


	### CLASS: InputEvent < IOEvent
	class InputEvent < IOEvent; end


	### CLASS: DebugOutputEvent < OutputEvent
	class DebugOutputEvent < OutputEvent
		attr_accessor :count
		def initialize( count )
			@count = count
		end
	end


end # module MUES


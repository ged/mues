#!/usr/bin/env ruby
###########################################################################
=begin

= Exceptions.rb

== NAME

MUES::Exceptions - Collection of exception classes

== SYNOPSIS

  require "mues/Exceptions"
  raise MUES::Exception "Something went wrong."

== DESCRIPTION

This file contains various exception classes for use in the FaerieMUD server.

== AUTHOR

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

### MUD-specific errors
module MUES

	class Exception < StandardError
		def initialize( error_message = "Unknown mud error" )
			super( error_message )
		end
	end

	class EngineException < Exception
		def initialize( error_message = "Unknown engine error" )
			super( error_message )
		end
	end

	class EventQueueException < Exception
		def initialize( error_message = "Unknown error in event queue" )
			super( error_message )
		end
	end

	class LogError < Exception
		def initialize( error_message = "Unknown error in log handle" )
			super( error_message )
		end
	end

	class UnhandledEventError < Exception
		def initialize( error_message = "Unhandled event" )
			if ( error_message.is_a? Event ) then
				error_message = "Unhandled event: #{error_message.to_s}"
			end
			super( error_message )
		end
	end

	class EventRecursionError < ScriptError
		@@DefaultError = "Event cannot include itself in its consequences."
		def initialize( error_message = @@DefaultError )
			
			if error_message.is_a?( Event ) then
				error_message = "%s: %s" % [event.to_s, @@DefaultError]
			end

			super( error_message )
		end
	end


	### Exception events

	class Reload < Exception
		def initialize( error_message = "Configuration reloaded" )
			super( error_message )
		end
	end

	class Shutdown < Exception
		def initialize( error_message = "Server shutdown" )
			super( error_message )
		end
	end

end


### Other (non-MUD-specific) kinds of exceptions

class VirtualMethodError < TypeError
	def initialize( error_message = "Unimplemented virtual method" )
		super( error_message )
	end
end

class InstantiationError < TypeError
	def initialize( error_message = "Instantiation attempted of abstract class" )
		super( error_message )
	end
end

class SocketIOError < IOError
	def initialize( error_message = "Error condition on socket." )
		super( error_message )
	end
end

class ParseError < SyntaxError
	def initialize( error_message = "Error while parsing." )
		super( error_message )
	end
end


###########################################################################



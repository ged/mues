#!/usr/bin/env ruby
###########################################################################
=begin 

= Exceptions.rb

== Name

MUES::Exceptions - Collection of exception classes

== Synopsis

  require "mues/Exceptions"
  raise MUES::Exception "Something went wrong."

== Description

This file contains various exception classes for use in the MUES server.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "e2mmap"

### MUD-specific errors
module MUES

	### Base exception class
	class Exception < StandardError
		Message = "MUES error"

		def initialize( message=nil )
			message ||= self.class.const_get( "Message" )
			super( message )
		end
	end

	#extend Exception2MessageMapper
	def MUES.def_exception( name, message, superclass=StandardError )
		name = name.id2name if name.kind_of?( Fixnum )
		eClass = Class.new( superclass )
		eClass.module_eval %Q{
			def initialize( *args )
				if ! args.empty?
					msg = args.collect {|a| a.to_s}.join
					super( "#{message}: \#{msg}" )
				else
					super( "#{message}" )
				end					
			end
		}
		const_set( name, eClass )
	end

	def_exception :EngineException,		"Engine error",						Exception
	def_exception :EventQueueException,	"Event queue error",				Exception
	def_exception :LogError,			"Error in log handle",				Exception
	def_exception :SecurityViolation,	"Security violation",				Exception

	def_exception :Reload,				"Configuration out of date",		Exception
	def_exception :Shutdown,			"Server shutdown",					Exception

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

	def_exception :VirtualMethodError,	"Unimplemented virtual method",					TypeError
	def_exception :InstantiationError,	"Instantiation attempted of abstract class",	TypeError
	def_exception :SocketIOError,		"Error condition on socket.",					IOError
	def_exception :ParseError,			"Error while parsing.",							SyntaxError
end




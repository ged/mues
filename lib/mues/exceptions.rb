#!/usr/bin/env ruby
#######################################################
=begin 

= Exceptions.rb

== Name

MUES::Exceptions - Collection of exception classes

== Synopsis

  require "mues/Exceptions"
  raise MUES::Exception "Something went wrong."

== Description

This file contains various exception classes for use in the MUES server.

== Functions

Requiring this file will add the following method to the MUES namespace:

--- def_exception( name, message, superclass )

    Define an exception class with the specified ((|name|)) (a (({Symbol})))
    with the specified ((|message|)). The new exception class will inherit from
    the specified ((|superclass|)), if specified, or (({StandardError})) if not
    specified.

== Classes

=== MUES::Exception

The base MUES exception class. Inherits from StandardError.

=== MUES::EngineException

An error class used to indicate an error in a ((<MUES::Engine>)) object.

=== MUES::EventQueueException

An error class used to indicate an error in a ((<MUES::EventQueue>)).

=== MUES::LogError

An error class used to indicate an error in a log handle object.

=== MUES::SecurityViolation

An error class used to indicate a failure of an operation due to security restrictions.

=== MUES::EnvironmentError

An error class used to indicate an error in a ((<MUES::Environment>)).

=== MUES::EnvironmentLoadError

An error class used to indicate an error which occurs while loading a
((<MUES::Environmment>)).

=== MUES::EnvironmentUnloadError

An error class used to indicate an error which occurs while unloading a
((<MUES::Environmment>)).

=== MUES::Reload

A pseudo-error class used to indicate to the listener thread that the Engine^s
configuration is being reloaded.

=== MUES::Shutdown

A server shutdown pseudo-error class used to signal server shutdown to the
listener thread.

=== MUES::CommandError

An error class used to indicate an error in a user^s command shell.

=== MUES::MacroError

An error class used to indicate an error in a user^s MacroFilter.

=== MUES::UnhandledEventError

An error class used to indicate that an event was dispatched to an object which
did not provide a handler for it.

=== MUES::EventRecursionError

An error class which is used to indicate that an event included itself in its
own consequences. Inherits from (({ScriptError})) to avoid being caught by the
worker thread^s exception handling.

=== MUES::VirtualMethodError

An error class used to indicate a call to an unimplemented virtual
method. Inherits from (({TypeError})).

=== MUES::InstantiationError

An error class used to indicate an attempted instantiation of an abstract
class. Inherits from (({TypeError})).

=== MUES::SocketIOError

An error class used to indicate an error condition on a socket. Inherits from
(({IOError})).

=== MUES::ParseError

An error class used to indicate an error while parsing. Inherits from
(({SyntaxError})).

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#######################################################

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

	# System exceptions
	def_exception :EngineException,			"Engine error",						Exception
	def_exception :EventQueueException,		"Event queue error",				Exception
	def_exception :LogError,				"Error in log handle",				Exception
	def_exception :SecurityViolation,		"Security violation",				Exception

	# Environment exceptions
	def_exception :EnvironmentError,		"Generic environment error",		Exception
	def_exception :EnvironmentLoadError,	"Could not load environment",		EnvironmentError
	def_exception :EnvironmentUnloadError,	"Could not unload environment",		EnvironmentError

	# Signal exceptions
	def_exception :Reload,					"Configuration out of date",		Exception
	def_exception :Shutdown,				"Server shutdown",					Exception

	# Command shell/macro shell exceptions
	def_exception :CommandError,			"Command error",					Exception
	def_exception :MacroError,				"Macro error",						Exception

	### Event exceptions
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

	# General exceptions
	def_exception :VirtualMethodError,	"Unimplemented virtual method",					TypeError
	def_exception :InstantiationError,	"Instantiation attempted of abstract class",	TypeError
	def_exception :SocketIOError,		"Error condition on socket.",					IOError
	def_exception :ParseError,			"Error while parsing.",							SyntaxError


end




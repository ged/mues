#!/usr/bin/env ruby
#
# This module contains a collection of exception classes that are used throughout
# the MUES server.
# 
# == Synopsis
# 
#   require "mues/Exceptions"
#   raise MUES::Exception, "Something went wrong."
# 
# == Exception Classes
# 
# [<b><tt>MUES::Exception</tt></b>]
# 
#   The base MUES exception class. Inherits from StandardError.
# 
# [<b><tt>MUES::EngineException</tt></b>]
# 
#   An error class used to indicate an error in a ((<MUES::Engine>)) object.
# 
# [<b><tt>MUES::EventQueueException</tt></b>]
# 
#   An error class used to indicate an error in a ((<MUES::EventQueue>)).
# 
# [<b><tt>MUES::LogError</tt></b>]
# 
#   An error class used to indicate an error in a log handle object.
# 
# [<b><tt>MUES::SecurityViolation</tt></b>]
# 
#   An error class used to indicate a failure of an operation due to security restrictions.
# 
# [<b><tt>MUES::EnvironmentError</tt></b>]
# 
#   An error class used to indicate an error in a ((<MUES::Environment>)).
# 
# [<b><tt>MUES::EnvironmentLoadError</tt></b>]
# 
#   An error class used to indicate an error which occurs while loading a
#   ((<MUES::Environmment>)).
# 
# [<b><tt>MUES::EnvironmentUnloadError</tt></b>]
# 
#   An error class used to indicate an error which occurs while unloading a
#   ((<MUES::Environmment>)).
# 
# [<b><tt>MUES::Reload</tt></b>]
# 
#   A pseudo-error class used to indicate to the listener thread that the Engine^s
#   configuration is being reloaded.
# 
# [<b><tt>MUES::Shutdown</tt></b>]
# 
#   A server shutdown pseudo-error class used to signal server shutdown to the
#   listener thread.
# 
# [<b><tt>MUES::CommandError</tt></b>]
# 
#   An error class used to indicate an error in a user^s command shell.
# 
# [<b><tt>MUES::MacroError</tt></b>]
# 
#   An error class used to indicate an error in a user^s MacroFilter.
# 
# [<b><tt>MUES::UnhandledEventError</tt></b>]
# 
#   An error class used to indicate that an event was dispatched to an object which
#   did not provide a handler for it.
# 
# [<b><tt>MUES::EventRecursionError</tt></b>]
# 
#   An error class which is used to indicate that an event included itself in its
#   own consequences. Inherits from (({ScriptError})) to avoid being caught by the
#   worker thread^s exception handling.
# 
# [<b><tt>MUES::VirtualMethodError</tt></b>]
# 
#   An error class used to indicate a call to an unimplemented virtual
#   method. Inherits from (({NoMethodError})).
# 
# [<b><tt>MUES::InstantiationError</tt></b>]
# 
#   An error class used to indicate an attempted instantiation of an abstract
#   class. Inherits from (({TypeError})).
# 
# [<b><tt>MUES::SocketIOError</tt></b>]
# 
#   An error class used to indicate an error condition on a socket. Inherits from
#   (({IOError})).
# 
# [<b><tt>MUES::ParseError</tt></b>]
# 
#   An error class used to indicate an error while parsing. Inherits from
#   (({SyntaxError})).
# 
# == Rcsid
# 
# $Id: exceptions.rb,v 1.12 2002/07/07 18:30:25 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#
 

#require "e2mmap"

module MUES

	### Base exception class
	class Exception < StandardError
		Message = "MUES error"

		def initialize( message=nil )
			message ||= self.class.const_get( "Message" )
			super( message )
		end
	end

	### Define an exception class with the specified <tt>name</tt> (a Symbol)
	### with the specified <tt>message</tt>. The new exception class will
	### inherit from the specified <tt>superclass</tt>, if specified, or
	### <tt>StandardError</tt> if not specified.
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

	# General exceptions
	def_exception :VirtualMethodError,		"Unimplemented virtual method",					NoMethodError
	def_exception :InstantiationError,		"Instantiation attempted of abstract class",	TypeError
	def_exception :SocketIOError,			"Error condition on socket.",					IOError
	def_exception :ParseError,				"Error while parsing.",							SyntaxError

	# System exceptions
	def_exception :EngineException,			"Engine error",									Exception
	def_exception :EventQueueException,		"Event queue error",							Exception
	def_exception :LogError,				"Error in log handle",							Exception
	def_exception :SecurityViolation,		"Security violation",							Exception
	def_exception :ConfigError,				"Configuration error",							Exception

	# Environment exceptions
	# (Moved to Environment.rb - [Ged])

	# Signal exceptions
	def_exception :Reload,					"Configuration out of date",					Exception
	def_exception :Shutdown,				"Server shutdown",								Exception

	# Command shell/macro shell exceptions
	def_exception :CommandError,			"Command error",								Exception
	def_exception :MacroError,				"Macro error",									Exception


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
end





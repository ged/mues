#!/usr/bin/ruby
###########################################################################
=begin

=SystemEvents.rb

== Name

SystemEvents - A collection of system event classes

== Synopsis

  require "mues/events/SystemEvents"

== Description

A collection of system events for the MUES Engine.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "socket"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Debugging"

require "mues/events/BaseClass"

module MUES


	###########################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	###########################################################################

	### (ABSTRACT) CLASS: SystemEvent < Event
	class SystemEvent < Event ; implements AbstractClass
	end


	### (ABSTRACT) CLASS: SocketEvent < SystemEvent
	class SocketEvent < SystemEvent ; implements AbstractClass
		attr_accessor	:socket

		### METHOD: initialize( aSocket )
		def initialize( aSocket )
			checkType( aSocket, TCPSocket )
			raise ArgumentError, "Socket is not connected" if aSocket.closed?

			@socket = aSocket
			super()
		end
	end



	###############################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	###############################################################################

	### CLASS: SocketConnectEvent < SocketEvent
	class SocketConnectEvent < SocketEvent
	end


	### CLASS: LogEvent < SystemEvent
	class LogEvent < SystemEvent

		### Instance variables
		attr_reader :message, :severity

		### METHOD: initialize( severity, message )
		def initialize( severity, *args )
			if ( severity =~ %r{(debug|info|notice|error|crit|fatal)} )
				@severity = $1
			else
				@severity = "info"
				args.push( severity )
			end

			@message = args.size > 0 ? args.to_s : "[Mark]"
			super()
		end

		### METHOD: to_s
		### Returns a stringified version of the event
		def to_s
			return "%s: (%s) %s" % [
				super(),
				@severity,
				@message
			]
		end

	end


	### CLASS: TickEvent < SystemEvent
	class TickEvent < SystemEvent

		attr_accessor :tickNumber

		def initialize( tickNumber )
			checkType( tickNumber, Fixnum )

			@tickNumber = tickNumber
			super()
		end

	end

	### CLASS: EngineShutdownEvent < SystemEvent
	class EngineShutdownEvent < SystemEvent

		attr_accessor :agent

		def initialize( anObject )
			@agent = anObject
			super()
		end
	end


	### CLASS: ReconfigEvent < SystemEvent
	### Event which is issued when the configuration has changed.
	class ReconfigEvent < SystemEvent
	end


	### CLASS: ExceptionEvent < SystemEvent
	class ExceptionEvent < SystemEvent
		attr_accessor :exception

		### METHOD: initialize( exception )
		def initialize( exception )
			checkType( exception, ::Exception, Interrupt )

			@exception = exception
			super()
		end
	end


	### CLASS: UntrappedExceptionEvent < SystemEvent
	class UntrappedExceptionEvent < ExceptionEvent
	end


	### CLASS: CallbackEvent < SystemEvent
	class CallbackEvent < SystemEvent
		attr_accessor :callback, :args

		### METHOD: initialize( callback )
		def initialize( callback, *args )
			checkType( callback, Proc, Method )
			@callback = callback
			@args = args
		end
	end


	### CLASS: ThreadShutdownEvent < SystemEvent
	class ThreadShutdownEvent < SystemEvent
	end


	### CLASS: UntrappedSignalEvent < ExceptionEvent
	class UntrappedSignalEvent < ExceptionEvent
	end


end # module MUES


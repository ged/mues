#!/usr/bin/ruby
# 
# This file contains a collection of system event classes. System events are the
# events which the MUES::Engine uses directly, and generally concerned with
# low-level subsystems and Engine functionality itself.
#
# The event classes defined in this file are:
#
# [MUES::SystemEvent]
# 	An abstract system event class.
#
# [MUES::PrivilegedSystemEvent]
#	An abstract privileged system event class.
#
# [MUES::ListenerEvent]
# 	An abstract MUES::Listener event class. Events which deal with listener
# 	connections, disconnections, etc. are derived from this class.
#
# [MUES::ListenerConnectEvent]
# 	An event class that is created when a connection is accepted on a listener.
#
# [MUES::RebuildCommandRegistryEvent]
#	An event class that is used to request that the Engine's factory look for
#	updated command files, and if found, reload the commands contained in
#	them.
#
# [MUES::LogEvent]
# 	An event class used to add an entry to the log.
#
# [MUES::TickEvent]
# 	An event class used to mark the passage of time, trigger other scheduled or
# 	interval-driven events, and provide the hosted Environments with a
# 	"heartbeat".
#
# [MUES::EngineShutdownEvent]
# 	An event class used to instruct the MUES::Engine to shut down.
#
# [MUES::GarbageCollectionEvent]
# 	An event that instructs the Engine to start a garbage-collection cycle.
#
# [MUES::ReconfigEvent]
# 	An event that notifies the Engine that an item in the server configuration
# 	has changed.
#
# [MUES::ExceptionEvent]
# 	An event that contains an exception object of some sort.
#
# [MUES::UntrappedExceptionEvent]
# 	An event which is generated if a subsystem of the MUES lets an exception
# 	propagated into the EventQueue.
#
# [MUES::CallbackEvent]
# 	An event class which encapsulates a callback of some kind.
#
# [MUES::ThreadShutdownEvent]
# 	An event type which is generated by the supervisor thread of the
# 	MUES::EventQueue when it is scaling back the number of worker threads which
# 	are running.
#
# [MUES::UntrappedSignalEvent]
# 	An event which is generated when an untrapped  signal is caught.
# 
# == Synopsis
# 
#   require "mues/events/SystemEvents"
# 
# == Rcsid
# 
# $Id: systemevents.rb,v 1.15 2003/08/05 17:48:16 deveiant Exp $
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

require "mues/Object"
require "mues/Exceptions"
require "mues/events/Event"


module MUES

	#################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	#################################################################

	### An abstract system event class. It is derived from the MUES::Event
	### class.
	class SystemEvent < Event ; implements MUES::AbstractClass
	end


	### An abstract privileged system event class. It is derived from the
	### MUES::PrivilegedEvent class.
	class PrivilegedSystemEvent < PrivilegedEvent ; implements MUES::AbstractClass
	end


	### An abstract listener event class. Events which deal with MUES::Listener
	### connections, errors, etc. are derived from this class. It derives from
	### the MUES::SystemEvent class.
	class ListenerEvent < PrivilegedSystemEvent ; implements MUES::AbstractClass

		### Initialize a new ListenerEvent with the specified <tt>listener</tt>
		### (a MUES::Listener object).
		def initialize( listener ) # :notnew:
			checkType( listener, MUES::Listener )

			@listener = listener

			super()
		end

		######
		public
		######

		# The listener object (MUES::Listener) associated with the event.
		attr_accessor	:listener

	end



	#####################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#####################################################################

	### An event class that is used to request that the Engine's factory look
	### for updated command files, and if found, reload the commands contained
	### in them. It derives from MUES::PrivilegedSystemEvent.
	class RebuildCommandRegistryEvent < PrivilegedSystemEvent
	end


	### An event class that is created when an error condition is detected on a
	### listener's associated IO object. It is a derivative of
	### MUES::ListenerEvent.
	class ListenerErrorEvent < ListenerEvent

		### Create and return a new ListenerErrorEvent with the specified
		### <tt>listener</tt> (a MUES::Listener object) and <tt>reactor</tt> (an
		### IO::Reactor object).
		def initialize( listener, reactor )
			@reactor = reactor
			super( listener )
		end


		######
		public
		######

		# The reactor (IO::Reactor object) which originated the error event
		attr_reader :reactor
	end


	### An event class that is created when a connection is accepted on a
	### listener's associated IO object. It is a derivative of
	### MUES::ListenerEvent.
	class ListenerConnectEvent < ListenerEvent

		### Initialize a new ListenerConnectEvent with the specified
		### <tt>listener</tt> (a MUES::Listener object) and filter (a
		### MUES::IOEventFilter object).
		def initialize( listener, filter )
			checkType( filter, MUES::OutputFilter )

			super( listener )
			@filter = filter
		end


		######
		public
		######

		# The new IOEventFilter created to abstract the new connection.
		attr_reader :filter
	end

	
	### An event class created when a connection which needs cleanup or resource
	### de-allocation at the listener level is terminated.
	class ListenerCleanupEvent < ListenerEvent

		### Initialize a new ListenerCleanupEvent with the specified
		### <tt>listener</tt> (a MUES::Listener object) and filter (a
		### MUES::OutputFilter object).
		def initialize( listener, filter )
			checkType( filter, MUES::OutputFilter )

			@filter = filter

			super( listener )
		end


		######
		public
		######

		# The halted IOEventFilter that originated the event.
		attr_reader :filter

	end


	### An event class used to add an entry to the log. It derives from the
	### MUES::SystemEvent class.
	class LogEvent < SystemEvent

		# Create and return a new LogEvent with the specified <tt>severity</tt>
		# (which must be one of <tt>"debug", "info", "notice", "error", "crit",
		# or "fatal") and +message+ parts, which will be <tt>join</tt>ed with
		# the empty string.
		def initialize( severity, *message )
			if ( severity =~ %r{(debug|info|notice|error|crit|fatal)} )
				@severity = $1
			else
				@severity = "info"
				message.unshift( severity )
			end

			@message = if message.empty? then "[Mark]" else message.join(" ") end
			super()
		end


		######
		public
		######

		# The log message
		attr_reader :message

		# The log "severity" level
		attr_reader :severity


		### Returns a stringified version of the event
		def to_s
			return "%s: (%s) %s" % [
				super(),
				@severity,
				@message
			]
		end

	end


	### An event class used to mark the passage of time, trigger other scheduled
	### or interval-driven events, and provide the hosted Environments with a
	### "heartbeat". It derives from the MUES::SystemEvent class.
	class TickEvent < SystemEvent

		### Create and return a new TickEvent with the sequence number specified
		### by <tt>tickNumber</tt>, which must be a Fixnum.
		def initialize( tickNumber )
			checkType( tickNumber, Fixnum )

			@tickNumber = tickNumber
			super()
		end


		######
		public
		######

		# The sequence number of the tick
		attr_accessor :tickNumber

	end


	### An event class used to instruct the MUES::Engine to shut down. It
	### derives from the MUES::SystemEvent class.
	class EngineShutdownEvent < SystemEvent

		# Create and return a new EngineShutdownEvent with the specified object
		# registered as the agent.
		def initialize( anObject )
			@agent = anObject
			super()
		end


		######
		public
		######

		# The agent of the shutdown (ie., the User or system requesting the
		# shutdown).
		attr_accessor :agent

	end


	### An event that instructs the Engine to start a garbage-collection
	### cycle. It derives from the MUES::SystemEvent class.
	class GarbageCollectionEvent < SystemEvent
	end


	### An event that notifies the Engine that an item in the server
	### configuration has changed. It derives from the
	### MUES::PrivilegedSystemEvent class.
	class ReconfigEvent < PrivilegedSystemEvent
	end


	### An event that contains an exception object of some sort. It derives from
	### the MUES::SystemEvent class.
	class ExceptionEvent < SystemEvent

		### Create and return a new ExceptionEvent with the specified +exception+.
		def initialize( exception )
			checkType( exception, ::Exception )

			@exception = exception
			super()
		end

		######
		public
		######

		# The exception object
		attr_accessor :exception

	end


	### An event which is generated if a subsystem of the MUES lets an exception
	### propagated into the EventQueue. It derives from the MUES::ExceptionEvent
	### class.
	class UntrappedExceptionEvent < ExceptionEvent

		### Stringify the event
		def to_s
			return "%s: %s\n\t%s" % [
				super(),
				@exception.message,
				@exception.backtrace.join( "\n\t" )
			]
		end
	end


	### An event class which encapsulates a callback of some kind. It is used
	### when a callback should be executed asynchronously, such as a repeating
	### or scheduled call to a timer or heartbeat function that operates at a
	### different interval than the Engine's TickEvent. It derives from the
	### MUES::SystemEvent class.
	class CallbackEvent < SystemEvent

		### Create and return a new CallbackEvent with the specified +callback+
		### (a Proc or a Method object), which will be called with the specified
		### arguments.
		def initialize( callback, *args )
			checkType( callback, Proc, Method )
			@callback = callback
			@args = args
			super()
		end


		######
		public
		######

		# The callback (a Proc or Method object).
		attr_accessor :callback

		# The callback's argument array.
		attr_accessor :args

		### Call the callback with the args given at instantiation.
		def call
			@callback.call( *@args )
		end
	end


	### An event type which is generated by the supervisor thread of the
	### MUES::EventQueue when it is scaling back the number of worker threads
	### which are running. It derives from the MUES::SystemEvent class.
	class ThreadShutdownEvent < SystemEvent
	end


	### An event which is generated when a signal is trapped by the signal
	### handlers. It derives from MUES::SystemEvent.
	class SignalEvent < PrivilegedSystemEvent

		### Create and return a new ExceptionEvent with the specified +exception+.
		def initialize( signalName, message=nil )
			@signal = signalName.to_s
			@message = message || "Caught a '#{@signal}' signal."
			super()
		end


		######
		public
		######

		# The name of the signal that was trapped
		attr_reader :signal

		# The message describing the anticipated reaction to the signal
		attr_reader :message

		# Return a human-readable version of the event
		def to_s
			"SignalEvent: SIG#{@signal.upcase}"
		end
	end


	### An event which is generated when an untrapped signal is caught. It
	### derives from the MUES::SignalEvent class.
	class UntrappedSignalEvent < SignalEvent
	end


end # module MUES


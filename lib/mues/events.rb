#!/usr/bin/ruby
###########################################################################

=begin
= Events.rb
== Name

MUES::Events - a collection of event classes for the MUES Engine

== Synopsis

  require "mues/Events"

  event = MUES::EngineShutdownEvent.new
  eventQueue.priorityEnqueue( event )

== Description

This module is a collection of event classes for system-level events in the
FaerieMUD server. World events are subclasses of MUES::WorldEvent, and are
defined in the game object library.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################
require "mues/Namespace"
require "mues/Exceptions"
require "mues/Debugging"
require "socket"


###############################################################################
###	A B S T R A C T   E V E N T   C L A S S E S
###############################################################################

module MUES

	### (ABSTRACT BASE) CLASS: Event < Object
	class Event < Object

		include Debuggable
		include AbstractClass

		### MODULE: Event::Handler
		#  A useful default event handler module. Mixes in a handleEvent() method
		#  that does dynamic dispatch to methods in the class that mixes it in. It
		#  will look for a method called '_handle<eventClass>()', where eventClass
		#  is the class of the event to handle. If no explicit handler is found,
		#  each of the event's superclasses is tried as well. If no handler is
		#  defined for any of the events, it tries to call _handleUnknownEvent(). If
		#  no handler is found, an UnhandledEventError is raised.
		module Handler

			def handleEvent( event )
				raise TypeError, "argument (#{event.to_s}) is not an event"	unless
					event.is_a?( Event )

				methodName = ''

				### Search the event's class heirarchy for Event subclasses, and
				###	look up handler methods based on the class name
				event.class.ancestors.find_all {|klass| 
					klass <= Event
				}.each do |klass|
					methodName = '_handle%s' % klass.name
					if self.class.method_defined?( methodName ) then
						return self.send( methodName, event )
					end
				end

				### Now call an UnknownEvent handler if it defines one
				return self._handleUnknownEvent( event ) if
					self.class.method_defined?( :_handleUnknownEvent )

				raise UnhandledEventError, "No handler defined for #{event.class.name}s"
			end

		end


		### Class variable: Handler objects for the various event classes, keyed
		###		by class
		@@Handlers = { Event => [] }

		### (STATIC) METHOD: RegisterHandlers( *handlers )
		### Register the specified objects as interested in events of the
		###		receiver class
		def Event.RegisterHandlers( *handlers )
			checkEachResponse( handlers, "handleEvent" )

			### Add the handlers to the handlers for this class
			@@Handlers[ self ] |= handlers
			return @@Handlers[ self ].length
		end

		### (STATIC) METHOD: UnregisterHandlers( *handlers )
		### Unregister the specified objects as interested in events of the
		###		receiver class
		def Event.UnregisterHandlers( *handlers )
			@@Handlers[ self ] -= handlers
			@@Handlers[ self ].length
		end

		### (STATIC) METHOD: GetHandlers
		### Return handlers for the specified class and its parents, most
		###		specific first
		def Event.GetHandlers
			return self.ancestors.find_all { |klass| 
				klass <= Event
			}.collect { |klass|
				@@Handlers[ klass ]
			}.flatten.uniq
		end

		### (SINGLETON) METHOD: inherited( newSubclass )
		### Set up a handler array for each new subclass as it is created
		def Event.inherited( newSubclass )
			@@Handlers[ newSubclass ] = []
		end

		### Instance methods
		attr_reader :creationTime

		### METHOD: initialize
		### Initialize a new event
		def initialize( *args )
			super()
			@creationTime = Time.now
			_debugMsg( 1, "Initializing an #{self.class.name} at #{@creationTime}" )
		end

	end


	### (ABSTRACT) CLASS: SystemEvent < Event
	class SystemEvent < Event
		include AbstractClass
	end


	### (ABSTRACT) CLASS: WorldEvent < Event
	class WorldEvent < Event
		include AbstractClass
	end


	### (ABSTRACT) CLASS: PlayerEvent < Event
	class PlayerEvent < Event

		include		AbstractClass
		autoload	:Player, "lib/Player"
		attr_reader :player

		### METHOD: initialize( aPlayer )
		def initialize( aPlayer )
			checkType( aPlayer, Player )
			@player = aPlayer
			super()
		end
	end


	### (ABSTRACT) CLASS: IOEvent < Event
	class IOEvent < Event

		include			AbstractClass
		attr_accessor	:data

		def initialize( *args )
			super()
			@data = args.collect {|m| m.to_s}.join('')
		end
	end


	### (ABSTRACT) CLASS: SocketEvent < SystemEvent
	class SocketEvent < SystemEvent
		
		include			AbstractClass
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
			end

			@message = args.size > 0 ? args.to_s : "[Mark]"
			super()
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
			checkType( exception, Exception )

			@exception = exception
			super()
		end
	end


	### CLASS: UntrappedSignalEvent < ExceptionEvent
	class UntrappedSignalEvent < ExceptionEvent
	end


	### CLASS: UntrappedExceptionEvent < SystemEvent
	class UntrappedExceptionEvent < ExceptionEvent
	end


	### CLASS: ThreadShutdownEvent < SystemEvent
	class ThreadShutdownEvent < SystemEvent
	end


	### CLASS: OutputEvent < IOEvent
	class OutputEvent < IOEvent
	end


	### CLASS: InputEvent < IOEvent
	class InputEvent < IOEvent
	end


	### CLASS: DebugOutputEvent < OutputEvent
	class DebugOutputEvent < OutputEvent
		attr_accessor :count
		def initialize( count )
			@count = count
		end
	end


	### CLASS: SocketConnectEvent < SocketEvent
	class SocketConnectEvent < SocketEvent
	end


	### CLASS: PlayerLoginEvent < PlayerEvent
	class PlayerLoginEvent < PlayerEvent
	end


	### CLASS: PlayerLoginFailureEvent < PlayerEvent
	class PlayerLoginFailureEvent < PlayerEvent

		attr_reader :reason

		### METHOD: initialize( aPlayer, reason )
		def initialize( player, reason )
			super( player )
			@reason = reason
		end

	end


	### CLASS: PlayerIdleTimeoutEvent < PlayerEvent
	class PlayerIdleTimeoutEvent < PlayerEvent
	end


	### CLASS: PlayerDisconnectEvent < PlayerEvent
	class PlayerDisconnectEvent < PlayerEvent
	end


	### CLASS: PlayerLogoutEvent < PlayerEvent
	class PlayerLogoutEvent < PlayerEvent
	end

	### CLASS: PlayerAuthenticationEvent
	class PlayerAuthenticationEvent < PlayerEvent
		attr_reader :login, :password, :successCallback, :failureCallback

		### METHOD: initialize( aPlayer, username, password, successCallback, failureCallback )
		def initialize( player, username, password, sCallback, fCallback )
			super( player )

			@username	= username
			@password	= password
			@successCallback = sCallback
			@failureCallback = fCallback
		end
	end

end # module MUES



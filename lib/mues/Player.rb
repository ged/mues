#!/usr/bin/ruby
###########################################################################
=begin
= Player.rb
== Name

MUES::Player - a user connection class for the MUES Engine

== Synopsis

  require "mues/Player"

  player = MUES::Player.new( '127.0.0.1' )

== Description

This class encapsulates a remote socket connection to a client. It contains the
raw socket object, an IOEventStream object which is used to manipulate and
direct input and output between the remote user and the player object, an array
of characters which are currently being controlled, and some miscellaneous
information about the client.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "socket"

require "mues/Namespace"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"

module MUES
	class Player < Object

		include Debuggable
		include Event::Handler

		@@DefaultPrompt = 'mues> '

		#############################################################################
		###	P U B L I C   M E T H O D S
		#############################################################################
		public

		attr_accessor	:ioEventStream, :name, :isImmortal, :prompt
		attr_reader		:remoteIp

		### METHOD: initialize( remoteIp )
		### Initialize a new player object with the remote ip address of the initial
		### connection
		def initialize( remoteIp )
			super()

			@ioEventStream = nil
			@name = "<unnamed player #{self.id}>"
			@isImmortal = false
			@characters = []
			@currentCharacter = nil
			@prompt = @@DefaultPrompt
			@remoteIp = remoteIp

			OutputEvent.RegisterHandlers( self )
			TickEvent.RegisterHandlers( self )
		end

		### METHOD: to_s
		def to_s
			if @currentCharacter then
				return "#{@name.capitalize} [#{@currentCharacter.to_s}] (#{@remoteIp})"
			else
				return "#{@name.capitalize} (#{@remoteIp})"
			end
		end

		### METHOD: disconnect( )
		### Disconnect our IOEventStream and prepare to be destroyed
		def disconnect

			### Tell the character object that we're going bye-bye

			### Unregister all our handlers
			OutputEvent.UnregisterHandlers( self )
			TickEvent.UnregisterHandlers( self )

			### Shut down the IO event stream
			@ioEventStream.shutdown if @ioEventStream
			
		end


		#############################################################################
		###	P R O T E C T E D   M E T H O D S
		#############################################################################
		protected

		### (PROTECTED) METHOD: _handleIOEvent( anEvent )
		### IO event handler method
		def _handleIOEvent( event )
			return nil unless @ioEventStream
			@ioEventStream.addEvent( event )
		end

		### (PROTECTED) METHOD: _handleTickEvent
		### Handle server tick events by delegating them to any subordinate objects
		### that need them.
		def _handleTickEvent( event )
			if @currentCharacter then
				@currentCharacter.heartbeat( event.tickNumber )
			end
		end

		### (PROTECTED) METHOD: _handleOtherEvent
		### Handle any event that doesn't have an explicit handler by raising an
		### UnhandledEventError.
		def _handleOtherEvent( event )
			raise UnhandledEventError, event
		end


	end #class Player
end #module MUES

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

require "mues/Namespace"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"

module MUES
	class Player < Object

		include Debuggable
		include Event::Handler

		module Role
			PLAYER		= 0
			CREATOR		= 1
			IMPLEMENTOR	= 2
			ADMIN		= 3
		end
		Role.freeze

		### Class attributes
		@@DefaultPrompt = 'mues> '

		### (PROTECTED) METHOD: initialize( playerDataHash )
		### Initialize a new player object with the hash of attributes specified
		protected
		def initialize( dbInfo )
			checkType( dbInfo, Hash )
			super()

			@remoteIp = nil
			@ioEventStream = nil
			@prompt = @@DefaultPrompt

			@dbInfo = dbInfo

			OutputEvent.RegisterHandlers( self )
			TickEvent.RegisterHandlers( self )
		end

		#############################################################################
		###	P U B L I C   M E T H O D S
		#############################################################################
		public

		### Accessors
		attr_accessor	:ioEventStream, :prompt
		attr_reader		:remoteIp, :dbInfo

		### METHOD: isCreator?
		### Returns true if this player has creator permissions
		def isCreator?
			return @dbInfo['role'] >= Role::CREATOR
		end

		### METHOD: isImplementor?
		### Returns true if this player has implementor permissions
		def isImplementor?
			return @dbInfo['role'] >= Role::IMPLEMENTOR
		end

		### METHOD: isAdmin?
		### Returns true if this player has admin permissions
		def isAdmin?
			return @dbInfo['role'] >= Role::ADMIN
		end

		### METHOD: to_s
		### Returns a stringified version of the player object
		def to_s
			if @remoteIp
				return "#{@name.capitalize} <#{@dbInfo['emailAddress']}> [connected from #{@remoteIp}]"
			else
				return "#{@name.capitalize} <#{@dbInfo['emailAddress']}>"
			end
		end

		### METHOD: disconnect( )
		### Disconnect our IOEventStream and prepare to be destroyed
		def disconnect

			### Tell the character object that we're going bye-bye
			if @currentCharacter
			end

			### Unregister all our handlers
			OutputEvent.UnregisterHandlers( self )
			TickEvent.UnregisterHandlers( self )

			### Shut down the IO event stream
			@ioEventStream.shutdown if @ioEventStream
			
			### Save ourselves
			engine().dispatchEvents( PlayerSaveEvent.new(self) )
		end

		### METHOD: method_missing( aSymbol, *args )
		### Create and call methods that are the same as player data keys
		def method_missing( aSymbol, *args )
			origMethName = aSymbol.id2name
			methName = origMethName.sub( /=$/, '' )
			super unless @dbInfo.has_key?( methName )

			oldVerbose = $VERBOSE
			$VERBOSE = false

			self.class.class_eval <<-"end_eval"
			def #{methName}( arg=nil )
				if !arg.nil?
					@dbInfo["#{methName}"] = arg
				end
				@dbInfo["#{methName}"]
			end
			def #{methName}=( arg )
				self.#{methName}( arg )
			end
			end_eval

			$VERBOSE = oldVerbose

			raise RuntimeError, "Method definition for '#{methName}' failed." if method( methName ).nil?
			method( origMethName ).call( *args )
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

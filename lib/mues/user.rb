#!/usr/bin/ruby
###########################################################################
=begin 
= Player.rb
== Name

MUES::Player - a user connection class for the MUES Engine

== Synopsis

  require "mues/Player"

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

require "date"
require "md5"

require "mues/Namespace"
require "mues/Debugging"
require "mues/Events"
require "mues/Exceptions"
require "mues/IOEventFilters"

module MUES
	class Player < Object

		include Debuggable
		include Event::Handler

		### Class constants
		module Role
			PLAYER		= 0
			CREATOR		= 1
			IMPLEMENTOR	= 2
			ADMIN		= 3
		end
		Role.freeze

		### :SYNC: Changes in this structure should be accompanied by changes in
		### the corresponding table definition in '../sql/mues.player.sql'
		### :FIXME: Obviously, manually keeping these two the same is non-optimal...
		DefaultDbInfo = {
			'username'			=> 'guest',
			'cryptedPass'		=> MD5.new( '' ).hexdigest,
			'realname'			=> 'Guest User',
			'emailAddress'		=> 'guestAccount@localhost',
			'lastLogin'			=> '',
			'lastHost'			=> '',

			'timeCreated'		=> Time.new,
			'firstLoginTick'	=> 0,

			'role'				=> Role::PLAYER,
			'flags'				=> 0,
			'preferences'		=> {},
			'characters'		=> []
		}

		### METHOD: new( playerDataHash )
		### Initialize a new player object with the hash of attributes specified
		protected
		def initialize( dbInfo )
			checkResponse( dbInfo, '[]', '[]=' )
			super()

			@remoteIp = nil
			@ioEventStream = nil
			@activated = false

			@dbInfo = dbInfo

			OutputEvent.RegisterHandlers( self )
			TickEvent.RegisterHandlers( self )
		end

		#############################################################################
		###	P U B L I C   M E T H O D S
		#############################################################################
		public

		### Accessors
		attr_accessor	:ioEventStream
		attr_accessor	:dbInfo

		### METHOD: activated?
		### Returns true if the engine has activated this player object
		def activated?
			@activated
		end

		### METHOD: remoteIp
		### Returns the remote IP (if any) that the client is connected from
		def remoteIp
			@remoteIp
		end

		### METHOD: remoteIp=( newIp )
		### Sets the remote IP that the client is connected from, and sets the
		### player's 'lastHost' attribute.
		def remoteIp=( newIp )
			checkType( newIp, ::String )

			@remoteIp = @dbInfo.lastHost = newIp
		end

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
				return "#{@dbInfo['username'].capitalize} <#{@dbInfo['emailAddress']}> [connected from #{@remoteIp}]"
			else
				return "#{@dbInfo['username'].capitalize} <#{@dbInfo['emailAddress']}>"
			end
		end


		### METHOD: password=( newPassword )
		### Reset the player's password to ((|newPassword|)).
		def password=( newPassword )
			checkType( newPassword, String )

			self.cryptedPass = MD5.new( newPassword ).hexdigest
		end


		### METHOD: activate( anIOEventStream )
		### Activate the player and set up their environment with the given stream
		def activate( stream )
			checkType( stream, MUES::IOEventStream )

			# Create the command shell and macro filters and add them
			shell = CommandShell.new( self )
			macros = MacroFilter.new( self )
			stream.addFilters( shell, macros )

			# Set the stream attribute and flag the object as activated
			@ioEventStream = stream
			@activated = true
		end


		### METHOD: disconnect( )
		### Disconnect our IOEventStream and prepare to be destroyed
		def disconnect

			### Unregister all our handlers
			OutputEvent.UnregisterHandlers( self )
			TickEvent.UnregisterHandlers( self )

			### Shut down the IO event stream
			@activated = false
			@ioEventStream.shutdown if @ioEventStream
			
			### Save ourselves
			engine.dispatchEvents( PlayerSaveEvent.new(self) )
		end


		### METHOD: reconnect( remoteIp, aSocketOutputFilter )
		### Reconnect with a new socket output filter
		def reconnect( remoteIp, newSocketFilter )
			checkType( newSocketFilter, SocketOutputFilter )
			newSocketFilter.puts( "Reconnecting..." )

			### Get the current stream's socket output filter/s and flush 'em
			### before closing it and replacing it with the new one.
			@ioEventStream.removeFiltersOfType( SocketOutputFilter ).each {|filter|
				filter.puts( "[Reconnect from #{remoteIp}]" )
				filter.shutdown
				newFilter.sortPosition = filter.sortPosition
			}
			
			@ioEventStream.addFilter( newFilter )
			@ioEventStream.handleEvents( InputEvent.new("") )
		end


		### METHOD: method_missing( aSymbol, *args )
		### Create and call methods that are the same as player data keys
		def method_missing( aSymbol, *args )
			origMethName = aSymbol.id2name
			methName = origMethName.sub( /=$/, '' )
			super unless @dbInfo.has_key?( methName )

			### :TODO: Does this need to be synchronized? Probably.

			### Turn off -w for this eval
			oldVerbose = $VERBOSE
			$VERBOSE = false

			### Create the new methods
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

			### Restore old -w setting
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

			[]
		end


		### (PROTECTED) METHOD: _handleTickEvent
		### Handle server tick events by delegating them to any subordinate objects
		### that need them.
		def _handleTickEvent( event )
			@ioEventStream.addEvent( event )
		end


		### (PROTECTED) METHOD: _handleOtherEvent
		### Handle any event that doesn't have an explicit handler by raising an
		### UnhandledEventError.
		def _handleOtherEvent( event )
			raise UnhandledEventError, event
		end


	end #class Player
end #module MUES

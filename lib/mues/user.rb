#!/usr/bin/ruby
#################################################################
=begin 
= User.rb
== Name

MUES::User - a user connection class for the MUES Engine

== Synopsis

  require "mues/User"

== Description

Instances of this class represent a remote client who has connected to the
MUES. It contains an IOEventStream object which distributes input and output
between the remote client and the objects with which the user object is
associated, and information about the client.

== Modules
=== MUES::User::AccountType

Namespace for account type constants. Contains:

: AccountType::USER

  Normal user. No special permissions.

: AccountType::CREATOR

  Creator permissions allow the user to start and stop their own Environments,
  examine the state of any object inside an Environment which they have started,
  and fetch limited runtime statistics from the Engine.

: AccountType::IMPLEMENTOR

  Implementor permissions allow the user to start and stop any Environment, view
  the state of any object in any Environment, interact with the Engine to a
  limited degree (shutdown, restart, reload config), view the banlist, etc.

: AccountType::ADMIN

  Unlimited permissions.

== Classes
=== MUES::User
==== Public Methods

--- MUES::User#new( userDataHash )

    Initialize a new user object with the hash of attributes specified

--- MUES::User#<=>( otherUser )

    Comparison operator -- returns 1, 0, or -1 to indicate sort order for the
    receiver and the specified ((|otherUser|)) object. Objects sorted in this
    fashion will be ordered by accounttype, with more permissioned users first, and
    then by username.

--- MUES::User#activate( stream )

    Activate the user object with the given ((|stream|)), which must be an
    instance of ((<MUES::IOEventStream>)) or one of its subclasses.

--- MUES::User#activated?

    Returns (({true})) if the user has been activated (ie., has a connected IO
    stream).

--- MUES::User#dbInfo

    Return the value of the dbInfo attribute.

--- MUES::User#deactivate

    Deactivate the user, shutting down her IO stream.

--- MUES::User#ioEventStream

    Return the value of the ioEventStream attribute.

--- MUES::User#isCreator?

    Returns (({true})) if the user has ((<creator>)) permissions.

--- MUES::User#isImplementor?

    Returns (({true})) if the user has ((<implementor>)) permissions.

--- MUES::User#isAdmin?

    Returns (({true})) if the user has ((<admin>)) permissions.

--- MUES::User#method_missing( aSymbol, *args )

    Create and call methods that are the same as user data keys

--- MUES::User#password=( newPassword )

    Reset the user^s password to ((|newPassword|)).

--- MUES::User#reconnect( stream )

    Reconnect using the socket filter (or equivalent) from the specified
    ((|stream|)) (a ((<MUES::IOEventStream>)) object), disconnecting the current
    one.

--- MUES::User#remoteHost

    Returns the remote host (if any) that the client is connected from as a
    (({String})).

--- MUES::User#remoteHost=( newIp )

    Sets the User^s (({remoteHost})) and (({lastHost})) attributes to the
    specified ((|newIp|)).

--- MUES::User#to_s

    Returns a stringified version of the user object

==== Protected Methods

--- MUES::User#initialize( dbInfo )

    Initialize the user object with the given ((|dbInfo|)) object. The dbInfo
    object must either be a Hash or an object which behaves like one in that it
    must respond to the (({[]})), (({[]=})), and (({has_key?})) methods.

--- MUES::User#_handleIOEvent( anEvent )

    IO event handler method

--- MUES::User#_handleOtherEvent

    Handle any event that doesn^t have an explicit handler by raising an
    UnhandledEventError.

--- MUES::User#_handleTickEvent

    Handle server tick events by delegating them to any subordinate objects
    that need them.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "date"
require "md5"

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/IOEventFilters"

module MUES
	class User < Object ; implements Debuggable

		include Event::Handler

		### Class constants
		Version			= /([\d\.]+)/.match( %q$Revision: 1.11 $ )[1]
		Rcsid			= %q$Id: user.rb,v 1.11 2001/11/01 17:18:35 deveiant Exp $

		# User AccountType constants
		module AccountType
			USER		= 0		# Regular user
			CREATOR		= 1		# Can world-interaction access
			IMPLEMENTOR	= 2		# Has server-interaction access
			ADMIN		= 3		# Unrestricted access

			Name = %w{User Creator Implementor Admin}
		end
		AccountType.freeze

		### :SYNC: Changes in this structure should be accompanied by changes in
		### the corresponding table definition in '../sql/mues.user.sql'
		### :FIXME: Obviously, manually keeping these two the same is non-optimal...
		DefaultDbInfo = {
			'username'			=> 'guest',
			'cryptedPass'		=> MD5.new( '' ).hexdigest,
			'realname'			=> 'Guest User',
			'emailAddress'		=> 'guestAccount@localhost',
			'lastLogin'			=> '',
			'lastHost'			=> '',

			'timeCreated'		=> Time.now,
			'firstLoginTick'	=> 0,

			'accounttype'		=> AccountType::USER,
			'flags'				=> 0,
			'preferences'		=> {},

			'userVersion'		=> Version
		}

		### METHOD: new( userDataHash )
		### Initialize a new user object with the hash of attributes specified
		protected
		def initialize( dbInfo )
			checkResponse( dbInfo, '[]', '[]=', 'has_key?' )
			super()

			@remoteHost = nil
			@ioEventStream = nil
			@activated = false

			@dbInfo = dbInfo
		end

		###################################################################
		###	P U B L I C   M E T H O D S
		###################################################################
		public

		### Accessors
		### :FIXME: Do these need to be accessors? Or can they be readers?
		attr_accessor	:ioEventStream, :dbInfo

		### METHOD: activated?
		### Returns true if the engine has activated this user object
		def activated?
			@activated
		end

		### METHOD: remoteHost
		### Returns the remote IP (if any) that the client is connected from
		def remoteHost
			@remoteHost
		end

		### METHOD: remoteHost=( newIp )
		### Sets the remote IP that the client is connected from, and sets the
		### user's 'lastHost' attribute.
		def remoteHost=( newIp )
			checkType( newIp, ::String )

			@remoteHost = @dbInfo['lastHost'] = newIp
		end

		### METHOD: isCreator?
		### Returns true if this user has creator permissions
		def isCreator?
			return @dbInfo['accounttype'].to_i >= AccountType::CREATOR
		end


		### METHOD: isImplementor?
		### Returns true if this user has implementor permissions
		def isImplementor?
			return @dbInfo['accounttype'].to_i >= AccountType::IMPLEMENTOR
		end


		### METHOD: isAdmin?
		### Returns true if this user has admin permissions
		def isAdmin?
			return @dbInfo['accounttype'].to_i >= AccountType::ADMIN
		end


		### METHOD: to_s
		### Returns a stringified version of the user object
		def to_s
			if self.isCreator?
				return "#{@dbInfo['username'].capitalize} <#{@dbInfo['emailAddress']}> (#{AccountType::Name[@dbInfo['accounttype'].to_i]})"
			else
				return "#{@dbInfo['username'].capitalize} <#{@dbInfo['emailAddress']}>"
			end
		end


		### METHOD: <=>( anotherUser )
		### Comparison operator
		def <=>( otherUser )
			( @dbInfo['accounttype'] <=> otherUser.accounttype ).nonzero? ||
			@dbInfo['username'] <=> otherUser.username
		end

		### METHOD: password=( newPassword )
		### Reset the user's password to ((|newPassword|)). The password will be
		### encrypted before being stored.
		def password=( newPassword )
			checkType( newPassword, String )

			self.cryptedPass = MD5.new( newPassword ).hexdigest
		end


		### METHOD: activate( stream=MUES::IOEventStream )
		### Activate the user and set up their environment with the given stream
		def activate( stream )
			checkType( stream, MUES::IOEventStream )

			# Create the command shell and macro filters and add them
			shell = CommandShell.new( self )
			macros = MacroFilter.new( self )
			stream.addFilters( shell, macros )

			shell.debugLevel = 3

			# Set the stream attribute and flag the object as activated
			@ioEventStream = stream
			@ioEventStream.unpause
			@activated = true

			OutputEvent.RegisterHandlers( self )
			#TickEvent.RegisterHandlers( self )
			return []
		end


		### METHOD: deactivate( )
		### Deactivate our IOEventStream and prepare to be destroyed
		def deactivate
			results = []

			### Unregister all our handlers
			OutputEvent.UnregisterHandlers( self )
			#TickEvent.UnregisterHandlers( self )

			### Shut down the IO event stream
			@activated = false
			results << @ioEventStream.shutdown if @ioEventStream
			results << UserSaveEvent.new(self)
			
			### Return any events that need dispatching
			return results.flatten
		end


		### METHOD: reconnect( anIOEventStream )
		### Reconnect with the client connection from another io stream
		def reconnect( stream )
			checkType( stream, MUES::IOEventStream )

			results = []

			newFilter = stream.removeFiltersOfType( SocketOutputFilter )[0]
			raise RuntimeError, "Cannot reconnect from a stream with no SocketOutputFilter" unless newFilter
			newFilter.puts( "Reconnecting..." )

			### Get the current stream's socket output filter/s and flush 'em
			### before closing it and replacing it with the new one.
			@ioEventStream.removeFiltersOfType( SocketOutputFilter ).each {|filter|
				filter.puts( "[Reconnect from #{newFilter.remoteHost}]" )
				results << filter.shutdown
				newFilter.sortPosition = filter.sortPosition
			}
			
			@ioEventStream.addFilters( newFilter )
			@ioEventStream.addEvents( InputEvent.new("") )

			return results
		end


		### METHOD: method_missing( aSymbol, *args )
		### Create and call methods that are the same as user data keys
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


		###################################################################
		###	P R O T E C T E D   M E T H O D S
		###################################################################
		protected

		### (PROTECTED) METHOD: _handleIOEvent( anEvent )
		### IO event handler method
		def _handleIOEvent( event )
			@ioEventStream.addEvents( event )
		end


		### (PROTECTED) METHOD: _handleTickEvent
		### Handle server tick events by delegating them to any subordinate objects
		### that need them.
		#def _handleTickEvent( event )
		#	[]
		#end


		### (PROTECTED) METHOD: _handleOtherEvent
		### Handle any event that doesn't have an explicit handler by raising an
		### UnhandledEventError.
		def _handleOtherEvent( event )
			raise UnhandledEventError, event
		end


	end #class User
end #module MUES

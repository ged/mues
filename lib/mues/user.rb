#!/usr/bin/ruby
# 
# User.rb contains the MUES::User class. Instances of this class represent a
# remote client who has connected to the MUES and provided the proper
# authentication. It contains a MUES::IOEventStream object which distributes
# input and output between the remote client and the objects with which the user
# object is associated, and information about the client.
# 
# == Synopsis
# 
#   require "mues/User"
# 
# == To Do
#
# * Remove the hard-coded AccountTypes and replace it with configurable
#   types. This will require some deep thought about what to do when types change
#   between multiple runs of the environment, how to specify conversion functions
#   for modified types when there are already users who are of old types, etc.
#
# * Add hooks for persistance via Martin's ObjectStoreService.
#
# == Rcsid
# 
# $Id: user.rb,v 1.18 2002/08/02 20:03:44 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "date"
require "md5"

require "mues/Object"
require "mues/StorableObject"
require "mues/Events"
require "mues/Exceptions"
require "mues/IOEventFilters"

module MUES

	# A user connection class for the MUES::Engine
	class User < MUES::StorableObject ; implements MUES::Debuggable

		include MUES::Event::Handler, MUES::TypeCheckFunctions

		### Class constants
		Version			= /([\d\.]+)/.match( %q$Revision: 1.18 $ )[1]
		Rcsid			= %q$Id: user.rb,v 1.18 2002/08/02 20:03:44 deveiant Exp $

		# User AccountType constants module. Contains the following constants:
		# 
		# [USER]
		#   Normal user. No special permissions.
		# 
		# [CREATOR]
		#   Creator permissions allow the user to start and stop their own Environments,
		#   examine the state of any object inside an Environment which they have
		#   started, and fetch limited runtime statistics from the Engine.
		# 
		# [IMPLEMENTOR]
		#   Implementor permissions allow the user to start and stop any Environment,
		#   view the state of any object in any Environment, interact with the Engine to
		#   a limited degree (shutdown, restart, reload config), view the banlist, etc.
		# 
		# [ADMIN]
		#   Unlimited permissions.
		module AccountType
			USER		= 0		# Regular user
			CREATOR		= 1		# Can world-interaction access
			IMPLEMENTOR	= 2		# Has server-interaction access
			ADMIN		= 3		# Unrestricted access

			Name = %w{User Creator Implementor Admin}
		end
		AccountType.freeze


		### Create a new user object with the hash of attributes specified The
		### valid attributes are:
		###
		### [<tt>:username</tt>]
		###   The login name of the user. Defaults to 'guest'.
		### [<tt>:realname</tt>]
		###   The real name of the user. Defaults to 'Guest User'.
		### [<tt>:emailAddress</tt>]
		###   The user's email address. Defaults to 'guestAccount@localhost'.
		### [<tt>:lastLoginDate</tt>]
		###   The date of the user's last connection.
		### [<tt>:lastHost</tt>]
		###   The hostname or IP of host the user last connected from.
		def initialize( attributes={} )
			checkResponse( attributes, '[]', '[]=', 'has_key?' )
			super()

			@userVersion		= Version.dup
			@remoteHost			= nil
			@ioEventStream		= nil
			@activated			= false

			@username			= attributes[:username]		|| 'guest'
			@realname			= attributes[:realname]		|| 'Guest User'
			@emailAddress		= attributes[:emailAddress] || 'guestAccount@localhost'
			@lastLoginDate		= attributes[:lastLoginDate]
			@lastHost			= attributes[:lastHost]

			@timeCreated		= Time.now
			@firstLoginTick		= 0

			@accounttype		= AccountType::USER
			@flags				= 0
			@preferences		= {}

			@cryptedPass		= '*'
		end



		######
		public
		######

		### :FIXME: Do these need to be accessors? Or can they be readers?

		# The IOEventStream object belonging to this user
		attr_accessor	:ioEventStream

		# The name/IP of the host the user is connected from
		attr_reader		:remoteHost

		# The username of the user
		attr_accessor :username

		# The real name of the player
		attr_accessor :realname

		# The player's email address
		attr_accessor :emailAddress

		# The Date the user last logged in
		attr_accessor :lastLoginDate

		# The host the user last logged in from
		attr_accessor :lastHost

		# The type of account the user has (one of MUES::User::AccountType)
		attr_accessor :accounttype

		# Bitflags for the user (currently unused)
		attr_accessor :flags

		# Hash of preferences for the user
		attr_accessor :preferences

		# Tick number of the user's first login
		attr_reader :firstLoginTick

		# Date from when the user was created
		attr_reader :timeCreated

		# User class version number
		attr_reader :userVersion

		# The user's encrypted password
		attr_reader :cryptedPass


		### Returns true if the engine has activated this user object
		def activated?
			@activated
		end


		### Sets the remote IP that the client is connected from, and sets the
		### user's 'lastHost' attribute.
		def remoteHost=( newIp )
			checkType( newIp, ::String )

			@remoteHost = @lastHost = newIp
		end


		### Returns true if this user has creator permissions
		def isCreator?
			return @accounttype >= AccountType::CREATOR
		end


		### Returns true if this user has implementor permissions
		def isImplementor?
			return @accounttype >= AccountType::IMPLEMENTOR
		end


		### Returns true if this user has admin permissions
		def isAdmin?
			return @accounttype >= AccountType::ADMIN
		end


		### Returns a stringified version of the user object
		def to_s
			if self.isCreator?
				return "%s <%s> (%s)" % [
					@username.capitalize,
					@emailAddress,
					AccountType::Name[@accounttype]
				]
			else
				return "%s <%s>" % [
					@username.capitalize,
					@emailAddress
				]
			end
		end


		### Comparison operator
		def <=>( otherUser )
			( @accounttype <=> otherUser.accounttype ).nonzero? ||
			@username <=> otherUser.username
		end

		### Reset the user's password to ((|newPassword|)). The password will be
		### encrypted before being stored.
		def password=( newPassword )
			newPassword = newPassword.to_s
			@cryptedPass = MD5.new( newPassword ).hexdigest
		end


		### Returns true if the specified password matches the user's.
		def passwordMatches?( pass )
			return MD5.new( pass ).hexdigest == @cryptedPass
		end


		### Activate the user, set up their environment with the given stream,
		### and output the specified 'message of the day', if given.
		def activate( stream, cshell, motd=nil )
			checkType( stream, MUES::IOEventStream )
			checkType( cshell, MUES::CommandShell )

			# Create the command shell and macro filters and add them
			macros = MacroFilter.new( self )
			stream.addFilters( cshell, macros )

			cshell.debugLevel = 3

			# Set the stream attribute and flag the object as activated
			@ioEventStream = stream
			@ioEventStream.unpause
			@ioEventStream.addEvents( OutputEvent.new(motd) ) if motd
			@activated = true

			debugMsg( 1, "MOTD is: #{motd.inspect}" )

			OutputEvent.RegisterHandlers( self )
			#TickEvent.RegisterHandlers( self )
			return []
		end


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


		### Reconnect with the client connection from another io stream
		def reconnect( stream )
			checkType( stream, MUES::IOEventStream )

			results = []

			### :FIXME: This shouldn't explicitly refer to the output filter
			### class, since it may not even be a SocketOutputFilter at all.
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


		#########
		protected
		#########

		### IO event handler method
		def handleIOEvent( event )
			@ioEventStream.addEvents( event )
		end

	end #class User
end #module MUES

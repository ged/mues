#!/usr/bin/ruby
# 
# This file contains the MUES::User class. Instances of this class represent a
# remote client who has connected to the MUES and provided the proper
# authentication.
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
# == Rcsid
# 
# $Id: user.rb,v 1.19 2002/09/12 12:13:43 deveiant Exp $
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
require "digest/md5"

require "mues/Object"
require "mues/StorableObject"
require "mues/Events"
require "mues/Exceptions"

module MUES

	# A user connection class for the MUES::Engine. A user object is an
	# abstraction which contains the data describing a connected user and
	# methods for interacting with that data, but does not contain any IO
	# functionality itself. That task is delegated to a MUES::IOEventStream
	# object which is joined with the user object at activation time. Activation
	# is the process of associating a user object with a particular IO
	# connection and a "command shell" after the user has provided valid
	# authentication. The command shell is an instance of MUES::CommandShell (or
	# a derivative) which the user can use to perform tasks in the MUES such as
	# creating new characters, assuming the roles of existing characters,
	# creating macros, etc.
	class User < MUES::StorableObject ; implements MUES::Debuggable

		include MUES::Event::Handler, MUES::TypeCheckFunctions

		### Class constants
		Version			= /([\d\.]+)/.match( %q$Revision: 1.19 $ )[1]
		Rcsid			= %q$Id: user.rb,v 1.19 2002/09/12 12:13:43 deveiant Exp $

		# Account type constants module for the MUES::User class. Contains the
		# following constants:
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
			Map = begin
				hash = {}
				Name.each_with_index {|name,i| hash[name.downcase] = i}
				hash
			end
		end
		AccountType.freeze


		### Create a new user object with the hash of attributes specified The
		### valid attributes are:
		###
		### [<tt>:accountType</tt>]
		###   The AccountType of the user. One of the constants listed in
		###   MUES::User::AccountType, or a stringified version of one of the
		###   constants (eg., 'creator' or 'CREATOR'); defaults to
		###   MUES::User::AccountType::USER.
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

			# Translate stringified account types
			if attributes[:accountType].kind_of? String
				type = attributes[:accountType].downcase
				raise MUES::Exception, "No such account type #{type}" unless
					AccountType::Map.key?( type )
				attributes[:accountType] = AccountType::Map[ type ]
			end

			@accountType		= attributes[:accountType]	|| AccountType::USER
			@accountType.freeze

			self.taint unless @accountType >= AccountType::IMPLEMENTOR

			@username			= attributes[:username]		|| 'guest'
			@realname			= attributes[:realname]		|| 'Guest User'
			@emailAddress		= attributes[:emailAddress] || 'guestAccount@localhost'
			@lastLoginDate		= attributes[:lastLoginDate]
			@lastHost			= attributes[:lastHost]

			@timeCreated		= Time.now
			@firstLoginTick		= 0

			@flags				= 0
			@preferences		= {}

			@cryptedPass		= '*'
		end



		######
		public
		######

		### :FIXME: Do these need to be accessors? Or can they be readers?

		# The IOEventStream object belonging to this user
		attr_reader		:ioEventStream

		# The name/IP of the host the user is connected from
		attr_reader		:remoteHost

		# The username of the user
		attr_accessor	:username

		# The real name of the player
		attr_accessor	:realname

		# The player's email address
		attr_accessor	:emailAddress

		# The Date the user last logged in
		attr_accessor	:lastLoginDate

		# The host the user last logged in from
		attr_accessor	:lastHost

		# The type of account the user has (one of MUES::User::AccountType)
		attr_reader		:accountType

		# Bitflags for the user (currently unused)
		attr_accessor	:flags

		# Hash of preferences for the user
		attr_accessor	:preferences

		# Tick number of the user's first login
		attr_reader		:firstLoginTick

		# Date from when the user was created
		attr_reader		:timeCreated

		# User class version number
		attr_reader		:userVersion

		# The user's encrypted password
		attr_reader		:cryptedPass


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
			return @accountType >= AccountType::CREATOR
		end


		### Returns true if this user has implementor permissions
		def isImplementor?
			return @accountType >= AccountType::IMPLEMENTOR
		end


		### Returns true if this user has admin permissions
		def isAdmin?
			return @accountType >= AccountType::ADMIN
		end


		### Returns a stringified version of the user object
		def to_s
			if self.isCreator?
				return "%s - %s <%s> (%s)" % [
					@realname,
					@username.capitalize,
					@emailAddress,
					AccountType::Name[@accountType]
				]
			else
				return "%s - %s <%s>" % [
					@realname,
					@username.capitalize,
					@emailAddress
				]
			end
		end


		### Comparison operator
		def <=>( otherUser )
			( @accountType <=> otherUser.accounttype ).nonzero? ||
			@username <=> otherUser.username
		end


		### Reset the user's password to ((|newPassword|)). The password will be
		### encrypted before being stored.
		def password=( newPassword )
			newPassword = newPassword.to_s
			@cryptedPass = Digest::MD5::hexdigest( newPassword )
		end


		### Returns true if the specified password matches the user's.
		def passwordMatches?( pass )
			return Digest::MD5::hexdigest( pass ) == @cryptedPass
		end


		### Activate the user, set up their environment with the given stream,
		### and output the specified 'message of the day', if given.
		def activate( stream, cshell, motd=nil )
			checkType( stream, MUES::IOEventStream )
			checkType( cshell, MUES::CommandShell )

			# Create the command shell and macro filters and add them
			macros = MacroFilter.new( self )
			stream.addFilters( cshell, macros )

			# Set the stream, send the MOTD if it was specified, and flag the
			# object as activated
			@ioEventStream = stream
			@ioEventStream.unpause
			@ioEventStream.addEvents( OutputEvent::new("\n\n" + motd.strip + "\n\n") ) if motd

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

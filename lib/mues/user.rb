#!/usr/bin/ruby
# 
# This file contains the MUES::User class. Instances of this class represent a
# remote client who has connected to the MUES and provided the proper
# authentication.
# 
# == Synopsis
# 
#   require 'mues/user'
# 
# == To Do
#
# * Remove the hard-coded AccountTypes and replace it with configurable
#   types. This will require some deep thought about what to do when types change
#   between multiple runs of the environment, how to specify conversion functions
#   for modified types when there are already users who are of old types, etc.
#
# == Subversion ID
# 
# $Id$
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

require 'mues/object'
require 'mues/storableobject'
require 'mues/events'
require 'mues/exceptions'
require 'mues/filters/macrofilter'
require 'mues/filters/questionnaire'

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

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### Return a MUES::Questionnaire IOEventFilter object suitable for
		### insertion into a user's IOEventStream to query for the information
		### necessary to create a new user. 
		def self::getCreationQuestionnaire
			qnaire = Questionnaire::new( "Create User", *CreateUserQuestions ) {|qnaire|
				user = MUES::User::new( qnaire.answers )
				MUES::ServerFunctions::registerUser( user )

				qnaire.message( "\nUser '%s' created.\n" % user.login.capitalize )
			}
			qnaire.debugLevel = 5
			return qnaire
		end


		### Return a MUES::Questionnaire IOEventFilter object suitable for
		### insertion into a user's IOEventStream to query for a new password.
		def self::getPasswordQuestionnaire( user, isOther )
			questions = nil

			# If we're changing another user's password, don't prompt for the
			# old password
			if isOther
				questions = ChangePasswordQuestions[1..-1]
			else
				questions = ChangePasswordQuestions
			end

			name = "Changing %s's password" % user.login.capitalize
			qnaire = Questionnaire::new( name, *questions ) {|qnaire|
				user.password = qnaire.answers[:newPassword]
				qnaire.message( "Password changed.\n\n" )
			}

			# Add the user to the support data so the questionnaire's validators
			# can get at it
			qnaire.debugLevel = 5
			qnaire.supportData[:user] = user

			return qnaire
		end


		### Return a MUES::Questionnaire IOEventFilter object suitable for
		### insertion into a user's IOEventStream to query for altering an
		### attribute of a user.
		def self::getAttributeQuestionnaire(user, attribute)
			question = CreateUserQuestions.find {|question|
				question[:name] == attribute
			}
			raise RuntimeError,
				"Can't build a questionnaire for '%s': No question with that name." %
				attribute if question.nil?

			question[:question] =
				("Currently: %s\n" % user.send(attribute.intern)) + question[:question]
			qnaire = Questionnaire::new( "Change #{attribute}", question ) {|qnaire|
				MUES::ServerFunctions::unregisterUser( user )
				user.send("#{attribute}=", qnaire.answers[attribute.intern])
				MUES::ServerFunctions::registerUser( user )
				qnaire.message "Changed '%s' for %s to '%s'\n\n" %
					[ attribute, user.login.capitalize, user.send(attribute.intern) ]
			}

			qnaire.debugLevel = 5
			return qnaire
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new user object with the hash of attributes specified. The
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
		### [<tt>:password</tt>]
		###   The user's unencrypted password.
		def initialize( attributes={} )
			checkResponse( attributes, '[]', '[]=', 'has_key?' )
			super()

			@remoteHost			= nil
			@stream				= nil
			@activated			= false

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
			self.password		= attributes[:password] if attributes.has_key?( :password )
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
		alias :login :username

		# The real name of the player
		attr_accessor	:realname

		# The player's email address
		attr_accessor	:emailAddress

		# The Date the user last logged in
		attr_accessor	:lastLoginDate

		# The host the user last logged in from
		attr_accessor	:lastHost

		# Bitflags for the user (currently unused)
		attr_accessor	:flags

		# Hash of preferences for the user
		attr_accessor	:preferences

		# Tick number of the user's first login
		attr_reader		:firstLoginTick

		# Date from when the user was created
		attr_reader		:timeCreated

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


		### Returns a stringified version of the user object
		def to_s 
			"%s - %s <%s>" % [
				@realname,
				@username.capitalize,
				@emailAddress
			]
		end


		### Comparison operator -- compares usernames.
		def <=>( otherUser )
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
		def activate( stream )
			# Set the stream
			@stream = stream
			@stream.unpause
			@activated = true

			self.log.debug "Activating %p" % self

			registerHandlerForEvents( self, MUES::OutputEvent ) #MUES::TickEvent )
			return []
		end


		### Deactivate our IOEventStream and prepare to be destroyed
		def deactivate
			results = []

			# Unregister all our handlers
			unregisterHandlerForEvents( self )

			# Shut down the IO event stream
			@activated = false
			results.replace @stream.shutdown if @stream
			results.flatten!
			
			# Return any events that need dispatching
			debugMsg 1, "Returning %d result events from deactivation." %
				results.length
			return results
		end


		### Reconnect with the client connection from another io stream
		def reconnect( stream )
			checkType( stream, MUES::IOEventStream )

			results = []

			stream.pause
			newFilter = stream.removeFiltersOfType( MUES::OutputFilter )[0]
			raise RuntimeError, "Cannot reconnect from a stream with no OutputFilter" unless newFilter
			newFilter.puts( "Reconnecting..." )
			stream.unpause

			# Get the current stream's socket output filter/s and flush 'em
			# before closing it and replacing it with the new one.
			@stream.pause
			results.replace @stream.stopFiltersOfType( MUES::OutputFilter ) {|filter|
				filter.puts( "[Reconnect from #{newFilter.remoteHost}]" )
				newFilter.sortPosition = filter.sortPosition
			}
			
			@stream.addFilters( newFilter )
			@stream.addEvents( MUES::InputEvent.new("") )
			@stream.unpause

			return results
		end


		### Lull the user for storage (MUES::StorableObject interface).
		def lull!( objStore )
			@remoteHost			= nil
			@stream				= nil
			@activated			= false

			# :FIXME: This should probably be 'super' instead. Needs
			# investigation, though.
			return true
		end




		#########
		protected
		#########

		### IO event handler method
		def handleIOEvent( event )
			@stream.addEvents( event )
		end


		#############################################################
		###	Q U E S T I O N N A I R E S
		#############################################################



	end #class User
end #module MUES

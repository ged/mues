#!/usr/bin/ruby
# 
# A collection of classes used by the MUES::LoginSession class to communicate
# with the MUES::Engine.
#
# This file contains the definitions for the following event classes:
#
# [MUES::LoginSessionEvent]
#	Abstract base class for MUES::LoginSession events.
# 
# [MUES::LoginSessionFailureEvent]
#	A LoginSession event class for indicating a failed login session.
# 
# [MUES::LoginSessionEvent]
#	A LoginSession event class for indicating a successful login session.
# 
# == Synopsis
# 
#   require 'mues/events/loginsessionevents'
# 
# == Rcsid
# 
# $Id: loginsessionevents.rb,v 1.12 2003/10/13 04:02:15 deveiant Exp $
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


require "weakref"

require 'mues/object'
require 'mues/exceptions'
require 'mues/events/privilegedevent'

module MUES

	#################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	#################################################################

	### Abstract base class for LoginSession events.
	class LoginSessionEvent < PrivilegedEvent ; implements MUES::AbstractClass

		include MUES::TypeCheckFunctions

		# The MUES::LoginSession this event is associated with.
		attr_reader	:session

		### Initialize a new LoginSession event with the specified
		### MUES::LoginSession object. This method should be called by
		### derivative classes from their initializers.
		def initialize( aLoginSession ) # :notnew:
			checkType( aLoginSession, LoginSession )
			@session = WeakRef.new( aLoginSession )
			super()
		end
	end


	#################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#################################################################

	### A LoginSession event class for indicating a failed login session. This
	### happens after the user has made too many attempts to authenticate, or
	### when a connection has been denied due to being blacklisted, etc.
	class LoginSessionFailureEvent < LoginSessionEvent

		# A message String indicating why the session failed
		attr_reader :reason

		### Create and return a new event with the specified +session+ (a
		### MUES::LoginSession object) and reason (a String).
		def initialize( session, reason )
			super( session )
			@reason = reason
		end

		### Returns a stringified version of the event
		def to_s
			return "%s (%s)" % [ super(), @reason ]
		end
	end


	### A LoginSession event for passing the information from an authentication
	### attempt to the MUES::Engine for confirmation. It contains the
	### authentication information and two callbacks: one for a successful
	### authentication, and one for failed authentication.
	class LoginSessionAuthEvent < LoginSessionEvent

		### Create a new authorization event with the specified values and
		### return it. The <tt>session</tt> argument is the
		### <tt>LoginSession</tt> that contains the socket connection, the
		### <tt>user</tt> and <tt>pass</tt> arguments are the username and
		### password that has been given by the connecting client, the
		### <tt>filter</tt> is the output filter containing the client
		### connection, and the <tt>sCall</tt> and <tt>fCall</tt> are
		### <tt>String</tt>, <tt>Method</tt>, or <tt>Proc</tt> objects which
		### specify a function to call to indicate successful or failed
		### authentication. If the callback is a <tt>String</tt>, it is assumed
		### to be the name of the method to call on the specified
		### <tt>LoginSession</tt> object.
		def initialize( session, user, pass, filter, sCall, fCall )
			checkEachType( [user,pass], ::String )
			checkType( filter, MUES::OutputFilter )
			checkEachType( [sCall,fCall], ::String, ::Method, ::Proc )

			successCallback = case sCall
							  when String
								  session.method( sCall )
							  when Method, Proc
								  sCall
							  end

			failureCallback = case fCall
							  when String
								  session.method( fCall )
							  when Method, Proc
								  fCall
							  end

			super( session )
			@username			= user
			@password			= pass
			@filter				= filter
			@successCallback	= successCallback
			@failureCallback	= failureCallback
		end


		######
		public
		######

		# The username entered by the user
		attr_reader :username

		# The unencrypted password entered by the user
		attr_reader :password

		# The MUES::OutputFilter that contains the user's connection
		attr_reader :filter

		# The callback (a Method object) for indicating a successful attempt
		attr_reader :successCallback

		# The callback (a Method object) for indicating a failed attempt
		attr_reader :failureCallback


		### Returns the 'peer name' of the MUES::OutputFilter that contains the
		### authenticating user's connection.
		def peerName
			@filter.peerName
		end
		deprecate_method :remoteHost, :peerName


		### METHOD: to_s
		### Returns a stringified version of the event
		def to_s
			return "%s: '%s' with password '%s' from '%s'" % [
				super(),
				@username,
				@password,
				@filter.peerName
			]
		end
	end

end # module MUES


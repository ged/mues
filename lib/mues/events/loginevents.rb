#!/usr/bin/ruby
# 
# A collection of classes that can be used by the login questionnaire to
# communicate with the Engine.
#
# This file contains the definitions for the following event classes:
#
# [MUES::LoginEvent]
#	Abstract base class for MUES::LoginEvent objects.
# 
# [MUES::LoginFailureEvent]
#	A LoginEvent class for indicating a failed login session.
# 
# [MUES::LoginAuthEvent]
#	A LoginEvent class for indicating a successful login session.
# 
# == Synopsis
# 
#   require 'mues/events/loginevents'
# 
# == Subversion ID
# 
# $Id$
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


require 'mues/object'
require 'mues/exceptions'
require 'mues/events/privilegedevent'

module MUES

	#################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	#################################################################

	### Abstract base class for LoginEvent object classes.
	class LoginEvent < PrivilegedEvent ; implements MUES::AbstractClass

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Initialize a new LoginEvent for the given +stream+.
		def initialize( stream )
			@stream = stream
			super()
		end

		######
		public
		######

		# The stream which belongs to the authenticating user.
		attr_reader :stream
	end


	#################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#################################################################

	### A LoginSession event class for indicating a failed login session. This
	### happens after the user has made too many attempts to authenticate, or
	### when a connection has been denied due to being blacklisted, etc.
	class LoginFailureEvent < LoginEvent

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Create and return a new event with the specified +session+ (a
		### MUES::LoginSession object) and reason (a String).
		def initialize( stream, reason )
			super( stream )
			@reason = reason
		end

		######
		public
		######

		# A message String indicating why the session failed
		attr_reader :reason

		### Returns a stringified version of the event
		def to_s
			return "%s (%s)" % [ super(), @reason ]
		end
	end


	### A LoginEvent class for passing the information from an authentication
	### attempt to the MUES::Engine for confirmation. It contains the
	### authentication information and two callbacks: one for a successful
	### authentication, and one for failed authentication.
	class LoginAuthEvent < LoginEvent

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Create a new authorization event with the specified values and
		### return it. The +stream+ specifies the IOEventStream belonging
		### to the authenticating user. The +user+ and +pass+
		### arguments are the username and password that have been offered by
		### the connecting user, the +filter+ is the output filter
		### containing the client connection, and the +sCall+ and
		### +fCall+ are <tt>String</tt>, <tt>Method</tt>, or
		### <tt>Proc</tt> objects which specify a function to call to indicate
		### successful or failed authentication. If the callback is a
		### <tt>String</tt>, it is assumed to be the name of the method to call
		### on the specified <tt>IOEventStream</tt> object.
		def initialize( stream, user, pass, filter, sCall, fCall )
			super( stream )

			@username			= user
			@password			= pass
			@filter				= filter or raise ArgumentError, "No filter"
			@successCallback	= sCall or raise ArgumentError, "No success callback"
			@failureCallback	= fCall or raise ArgumentError, "No failure callback"
		end


		######
		public
		######

		# The username entered by the user
		attr_reader :username

		# The unencrypted password entered by the user
		attr_reader :password

		# The callback (a Method object) for indicating a successful attempt
		attr_reader :successCallback

		# The callback (a Method object) for indicating a failed attempt
		attr_reader :failureCallback

		# The IOEventFilter created for the remote client by the Listener.
		attr_reader :filter


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


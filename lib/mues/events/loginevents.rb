#!/usr/bin/ruby
#######################################################
=begin

=LoginSessionEvents.rb

== Name

LoginSessionEvents - A collection of login session event classes

== Synopsis

  require "mues/events/LoginSessionEvents"

== Description

A collection of classes used by the LoginSession class to communicate with the
Engine.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#######################################################

require "mues/Namespace"
require "mues/Exceptions"

require "mues/events/BaseClass"

module MUES

	#################################################################
	###	A B S T R A C T   E V E N T   C L A S S E S
	#################################################################

	### (ABSTRACT) CLASS: LoginSessionEvent < Event
	class LoginSessionEvent < Event ; implements AbstractClass
		autoload	:LoginSession, "mues/LoginSession"
		attr_reader	:session

		### METHOD: initialize( aLoginSession )
		def initialize( aLoginSession )
			checkType( aLoginSession, LoginSession )
			@session = aLoginSession
			super()
		end
	end


	#################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#################################################################

	### CLASS: LoginSessionFailureEvent < LoginSessionEvent
	class LoginSessionFailureEvent < LoginSessionEvent

		attr_reader :reason

		### METHOD: initialize( aLoginSession, reason )
		def initialize( session, reason )
			super( session )
			@reason = reason
		end

		### METHOD: to_s
		### Returns a stringified version of the event
		def to_s
			return "%s (%s)" % [ super(), @reason ]
		end
	end


	### CLASS: LoginSessionAuthEvent < LoginSessionEvent
	class LoginSessionAuthEvent < LoginSessionEvent

		attr_reader :username, :password, :remoteHost, :successCallback, :failureCallback

		### METHOD: new( aLoginSession, user, pass, remoteHostname, 
		###				  successCallback, failureCallback )
		### Create a new authorization event with the specified values and
		### return it. The ((|session|)) argument is the (({LoginSession})) that
		### contains the socket connection, the ((|user|)) and ((|pass|))
		### arguments are the username and password that has been given by the
		### connecting client, the ((|remoteHostname|)) is the name of the host
		### the client is connecting from, and the ((|successCallback|)) and
		### ((|failureCallback|)) are (({String})), (({Method})), or (({Proc}))
		### objects which specify a function to call to indicate successful or
		### failed authentication. If the callback is a (({String})), it is
		### assumed to be the name of the method to call on the specified
		### (({LoginSession})) object.
		def initialize( session, user, pass, host, sCall, fCall )
			checkEachType( [user,pass], String )
			checkEachType( [sCall,fCall], String, Method, Proc )

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
			@remoteHost			= host
			@successCallback	= successCallback
			@failureCallback	= failureCallback
		end

		### METHOD: to_s
		### Returns a stringified version of the event
		def to_s
			return "%s: '%s' with password '%s' from '%s'" % [
				super(),
				@username,
				@password,
				@remoteHost
			]
		end
	end

end # module MUES


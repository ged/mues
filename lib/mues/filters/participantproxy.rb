#!/usr/bin/ruby
#################################################################
=begin

=ParticipantProxy.rb

== Name

ParticipantProxy - a participant control input filter class

== Synopsis

  require "mues/filters/ParticipantProxy"

== Description

Instances of this class are proxy objects which relay commands to and
output from an in-game participant.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Events"
require "mues/filters/IOEventFilter"

module MUES
	class ParticipantProxy < IOEventFilter

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: participantproxy.rb,v 1.2 2001/09/26 13:27:49 deveiant Exp $
		DefaultSortPosition = 850

		#############################################################
		###	P U B L I C   M E T H O D S
		#############################################################
		public

		attr_reader :user, :role, :env
		abstract :handleInputEvents

		### METHOD: initialize( aUser=MUES::User, aRole=MUES::Role, anEnv= )
		def initialize( aUser, aRole, anEnv )
			checkType( aUser, MUES::User )
			checkType( aRole, MUES::Role )
			checkType( anEnv, MUES::Environment )

			super()

			@user = aUser
			@role = aRole
			@env = anEnv
		end

	end # class ParticipantProxy
end # module MUES


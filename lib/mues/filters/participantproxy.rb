#!/usr/bin/ruby
# 
# This file contains the MUES::ParticipantProxy class, an abstract derivative of
# the MUES::IOEventFilter class. ParticipantProxy objects relay
# MUES::IOEventStream IO to and from a participant in a MUES::Environment. It is
# usually the superclass for more-specific "player" or "avatar" Environment
# classes, or for a connector class associated with the "player" or "avatar"
# class.
# 
# == Synopsis
# 
#   require "mues/filters/ParticipantProxy"
# 
# == Rcsid
# 
# $Id: participantproxy.rb,v 1.9 2002/10/31 02:18:31 deveiant Exp $
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

require "mues/Mixins"
require "mues/Exceptions"
require "mues/Events"
require "mues/filters/InputFilter"
require "mues/User"
require "mues/Role"
require "mues/Environment"

module MUES

	# An abstract proxy class (derived from MUES::IOEventFilter) for relaying
	# MUES::IOEventStream IO to and from a participant in a MUES::Environment.
	class ParticipantProxy < MUES::InputFilter; implements MUES::AbstractClass

		include MUES::TypeCheckFunctions

		# Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
		Rcsid = %q$Id: participantproxy.rb,v 1.9 2002/10/31 02:18:31 deveiant Exp $
		DefaultSortPosition = 850


		### Initialize a new ParticipantProxy object with the specified
		### <tt>user</tt> (a MUES::User object), <tt>role</tt> (a MUES::Role
		### object), and <tt>environment</tt> (a MUES::Environment).
		def initialize( user, role, environment ) # :notnew:
			checkType( user, MUES::User )
			checkType( role, MUES::Role )
			checkType( environment, MUES::Environment )

			super()

			@user			= user
			@role			= role
			@environment	= environment
		end


		######
		public
		######

		# The MUES::User object corresponding to this participant
		attr_reader :user

		# The MUES::Role object the user expects to participate in.
		attr_reader :role

		# The MUES::Environment object the user is a participant in.
		attr_reader :environment
		deprecate_method :env, :environment


		### Disconnect the proxy from its current role and flag it as finished.
		def disconnect
			@environment.removeParticipantProxy( self )
			msg = ">>> Disconnected from %s in %s <<<\n\n" %
				[ @role.description, @environment.name ]
			queueOutputEvents( MUES::OutputEvent::new(msg) )
			self.finish
		end


	end # class ParticipantProxy
end # module MUES


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
# $Id: participantproxy.rb,v 1.7 2002/08/29 07:24:40 deveiant Exp $
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
		Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
		Rcsid = %q$Id: participantproxy.rb,v 1.7 2002/08/29 07:24:40 deveiant Exp $
		DefaultSortPosition = 850


		### Initialize a new ParticipantProxy object with the specified
		### MUES::User, MUES::Role, and MUES::Environment.
		def initialize( aUser, aRole, anEnv ) # :notnew:
			checkType( aUser, MUES::User )
			checkType( aRole, MUES::Role )
			checkType( anEnv, MUES::Environment )

			super()

			@user = aUser
			@role = aRole
			@env = anEnv
		end


		######
		public
		######

		attr_reader :user
		attr_reader :role
		attr_reader :env

	end # class ParticipantProxy
end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::PrivilegedEvent class, a derivative of
# MUES::Event. It is an abstract class which represents events that require
# special privileges for execution, and a commensurate level of restriction on
# how and where they may be created.
# 
# == Synopsis
# 
#   require 'mues/events/PriviledgedEvent'
#
#	class MyPrivilegedEvent < MUES::PrivilegedEvent
#		...
#	end
# 
# == Rcsid
# 
# $Id: privilegedevent.rb,v 1.1 2002/09/12 12:17:07 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues/Mixins'
require 'mues/Object'
require 'mues/events/Event'

module MUES

	### An abstract class which represents events that require special
	### privileges for execution, and a commensurate level of restriction on how
	### and where they may be created.
	class PrivilegedEvent < MUES::Event

		include MUES::SafeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: privilegedevent.rb,v 1.1 2002/09/12 12:17:07 deveiant Exp $

		### Create a new PrivilegedEvent object.
		def initialize( priority=MUES::Event::DefaultPriority )
			checkTaintAndSafe( 2 )

			@callStack = caller(1)

			super( priority )
		end


		######
		public
		######

		# The callstack at this event's instantiation
		attr_reader :callStack

		### Return a stringified version of the event.
		def to_s
			"%s (Privileged): [pri %d] at %s" % [
				self.class.name,
				priority,
				creationTime.to_s
			]
		end

	end # class PrivilegedEvent
end # module MUES


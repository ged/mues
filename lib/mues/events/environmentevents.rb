#!/usr/bin/ruby
# 
# This file contains a collection of environment event classes which are used to
# interact with Environment objects in the MUES. It is included in the list of
# files loaded by doing:
# 
#   require 'mues/events'
#
# The classes defined in this file are:
#
# [MUES::EnvironmentEvent]
#	An abstract class for events used to interact with MUES::Environment
#	objects.
#
# [MUES::LoadEnvironmentEvent]
#	An event class used for instructing the MUES::Engine to load a
#	MUES::Environment.
#
# [MUES::UnloadEnvironmentEvent]
#	An event class used to instruct the MUES::Engine to shut down and unload a
#	MUES::Environment.
#
# 
# == Synopsis
# 
#   require 'mues/events'
# 
#   LoadEnvironmentEvent.new( environmentNameString )
#   UnloadEnvironmentEvent.new( environmentNameString )  
# 
# == Rcsid
# 
# $Id: environmentevents.rb,v 1.10 2003/10/13 04:02:15 deveiant Exp $
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

	### An abstract class for events used to interact with MUES::Environment
	### objects.
	class EnvironmentEvent < PrivilegedEvent ; implements MUES::AbstractClass, MUES::Debuggable

		include MUES::TypeCheckFunctions

		# The user the event is being dispatched for
		attr_reader :user

		### Initialize a new EnvironmentEvent object. If the optional +user+
		### argument (a MUES::User object) is given, the status of the event
		### will be dispatched to the User as an OutputEvent.
		def initialize( user=nil ) # :notnew:
			checkType( user, NilClass, MUES::User )
			@user = user
			super()
		end
	end


	#################################################################
	###	C O N C R E T E   E V E N T   C L A S S E S
	#################################################################

	### An event class used for instructing the MUES::Engine to load an
	### environment.
	class LoadEnvironmentEvent < EnvironmentEvent

		### Create and return a new event to load an instance of the environment
		### specified by +eventClassName+ (the name of the Environment class to
		### load) and associate it with the given +name+. If the optional +user+
		### argument is given (a MUES::User object), the status of the event
		### will be sent to the User as an OutputEvent.
		def initialize( name, envClassName, user=nil )
			checkEachType( [name,envClassName], ::String )
			checkType( user, NilClass, MUES::User )

			@name = name
			@envClassName = envClassName

			super( user )
		end


		######
		public
		#######

		# The name to associate with the new environment
		attr_reader :name

		# The name of the Environment class to load.
		attr_reader :envClassName

	end


	### An event class used to instruct the MUES::Engine to shut down and unload
	### an Environment.
	class UnloadEnvironmentEvent < EnvironmentEvent

		# The name associated with the loaded environment
		attr_reader :name

		### Create and return a new UnloadEnvironmentEvent with the environment
		### associated with the specified +name+ as its target. If the optional
		### +user+ argument is given (a MUES::User object), the status of the
		### event will be sent to the User as an OutputEvent.
		def initialize( name, user=nil )
			checkType( name, ::String )

			@name = name
			super( user )
		end
	end

end # module MUES


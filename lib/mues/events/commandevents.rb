#!/usr/bin/ruby
# 
# This file contains a collection of event classes used by MUES::CommandShell
# commands.
#
# The event classes defined in this file are:
# 
# [MUES::EvalCommandEvent]
#
# == Synopsis
# 
#   require 'mues/events/CommandEvents'
# 
# == Rcsid
# 
# $Id: commandevents.rb,v 1.2 2002/10/23 04:58:58 deveiant Exp $
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

module MUES

	### :TODO: Is it useful to make all of these under a single parent class?
	# class CommandEvent < MUES::PrivilegedEvent
	# end

	### This file
	class EvalCommandEvent < MUES::PrivilegedEvent

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: commandevents.rb,v 1.2 2002/10/23 04:58:58 deveiant Exp $

		### Create a new EvalCommandEvent that will evaluate the specified
		### <tt>code</tt> in the context of the given <tt>contextObject</tt> for
		### the given <tt>user</tt>.
		def initialize( code, contextObject, user )
			@code = code
			@context = contextObject
			@user = user
		end


		######
		public
		######

		# The code to be evaluated
		attr_reader	:code

		# The object that will serve as the context in which to evaluate the
		# code.
		attr_reader :context

		# The user the eval should be executed for
		attr_reader :user


	end # class EvalCommandEvent
end # module MUES


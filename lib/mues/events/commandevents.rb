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
#   require 'mues/events/commandevents'
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
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues/mixins'
require 'mues/object'

module MUES

	### :TODO: Is it useful to make all of these under a single parent class?
	# class CommandEvent < MUES::PrivilegedEvent
	# end

	### This file
	class EvalCommandEvent < MUES::PrivilegedEvent

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


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


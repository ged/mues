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
# $Id: commandevents.rb,v 1.1 2002/10/14 09:36:46 deveiant Exp $
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
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: commandevents.rb,v 1.1 2002/10/14 09:36:46 deveiant Exp $

		### Create a new EvalCommandEvent that will evaluate the specified
		### <tt>code</tt> in the context of the given <tt>contextObject</tt>.
		def initialize( code, contextObject )
			@code = code
			@context = contextObject
		end


		######
		public
		######

		# The code to be evaluated
		attr_reader	:code

		# The object that will serve as the context in which to evaluate the
		# code.
		attr_reader :context



		#########
		protected
		#########


	end # class CommandEvents
end # module MUES


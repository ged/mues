#!/usr/bin/ruby
# 
# This file contains the MUES::Role class, which describe available roles for
# participation within a environment in the context of a specific user. They may
# represent different levels of functionality, different characters, or available
# accounts that are open to a given user.
# 
# == Synopsis
# 
#   require "mues/Role"
# 
#   genevaCharacter = MUES::Role.new( anEnvironment, "geneva", "Female silver-skinned elf with green eyes" )
# 
# 
# == Rcsid
# 
# $Id: role.rb,v 1.6 2002/07/08 15:00:44 deveiant Exp $
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


require 'mues'
require 'mues/Exceptions'
require 'mues/Events'
require 'mues/StorableObject'

module MUES

	### A role class for MUES::Environment objects.
	class Role < MUES::StorableObject ; implements MUES::Debuggable

		include MUES::Event::Handler, MUES::TypeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: role.rb,v 1.6 2002/07/08 15:00:44 deveiant Exp $

		### Create and return a role object for the given environment with the name,
		### and description string specified.
		def initialize( anEnvironment, aNameString, aDescString )
			checkType( anEnvironment, MUES::Environment )
			checkType( aNameString, ::String )
			checkType( aDescString, ::String )

			@environment	= anEnvironment
			@name			= aNameString
			@description	= aDescString

			super()
		end


		######
		public
		######

		# The environment this role belongs to
		attr_accessor :environment

		# The name of the role
		attr_accessor :name

		# The description of the role
		attr_accessor :description


		### Returns the role name and description as a string.
		def to_s
			return "%-15s %-50s" % [ @name, @description ]
		end


		### Comparison operator
		def <=>( otherRole )
			return @environment <=> otherRole.environment
		end

	end # class Role
end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::Role class, which is used to describe available
# roles for participation within a environment in the context of a specific
# user. They may represent different levels of functionality, different
# characters, or available accounts that are open to a given user.
# 
# == Synopsis
# 
#   require 'mues/role'
# 
#	class MyWorld < MUES::Environment
#		...
#		def getAvailableRoles( user )
#			@characters.find_all {|char|
#				char.ownername = user.login
#			}.collect {|char|
#				MUES::Role::new(self, char.name, char.desc)
#			}
#		end
#	end
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
# Please see the file COPYRIGHT for licensing details.
#

require 'mues'
require 'mues/object'
require 'mues/exceptions'
require 'mues/events'

module MUES

	### A role class for MUES::Environment objects.
	class Role < MUES::StorableObject ; implements MUES::Debuggable

		include MUES::Event::Handler, MUES::TypeCheckFunctions

		### Class constants

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		### Create and return a role object for the given <tt>environment</tt> with the
		### <tt>name</tt> and <tt>description</tt> string specified.
		def initialize( environment, name, description )
			checkType( environment, MUES::Environment )
			checkType( name, ::String )
			checkType( description, ::String )

			@environment	= environment
			@name			= name
			@description	= description

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


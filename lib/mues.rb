#!/usr/bin/ruby


#
# The Multi-User Environment Server.
#
# This module provides a collection of modules, functions, and base classes for
# the Multi-User Environment Server. Requiring it loads all the subordinate
# modules necessary to start the server. 
#
#
# == Synopsis
#
#   require 'mues'
#   MUES::Engine.start( 'config.yml' )
#
# == Subversion ID
# 
# $Id$
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE for licensing details.
#
module MUES

	### Make a vector out of the given +version_string+, which makes it easier to compare 
	### with other x.y.z-style version strings.
	def vvec( version_string )
		return version_string.split('.').collect {|v| v.to_i }.pack( 'N*' )
	end
	module_function :vvec

	# Package version constant
	VERSION = '2.0.0'

	# Version vector
	VERSION_VEC = vvec( VERSION )

	unless vvec(RUBY_VERSION) >= vvec('1.9.1')
		raise "MUES requires Ruby 1.9.1 or greater."
	end

	# Load all the parts
	require 'mues/mixins'
	require 'mues/logger'
	require 'mues/constants'
	require 'mues/utils'
	require 'mues/engine'

end # module MUES


#!/usr/bin/ruby

require 'rbconfig'

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
#
#   config = MUES::Config.new( 'muesconfig.yaml' )
#   MUES::Engine.instance.start( config )
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

	# Package version constant
	VERSION = '1.99.0'

	require 'mues_ext'
	require 'mues/engine'

end # module MUES


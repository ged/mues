#!/usr/bin/ruby
# 
# This file contains Constants for use in the Metaclass library.
# 
# == Synopsis
# 
#   require 'metaclass/Constants'
# 
# == Rcsid
# 
# $Id: constants.rb,v 1.1 2002/03/30 19:04:08 deveiant Exp $
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

### The namespace which contains all of the MUES metaclasses.
module Metaclass

	### Container module for scope constants.
	module Scope
		INSTANCE	= 1
		CLASS		= 2
	end

	### Container module for visibility constants.
	module Visibility
		PRIVATE		= 1
		PROTECTED	= 2
		PUBLIC		= 3
	end

end # module Metaclass



#!/usr/bin/ruby
# 
# This file contains Constants for use in the Metaclass library. The constants
# it defines are in the Metaclass::Scope and Metaclass::Visibility modules.
# 
# == Synopsis
# 
#   require 'metaclass/Constants'
# 
# == Rcsid
# 
# $Id: constants.rb,v 1.2 2002/05/16 04:05:25 deveiant Exp $
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

	### Container module for scope constants. The following constants are
	### defined:
	###
	###	[INSTANCE]
	###   Instance scope. The attribute or operation is per-instance.
	###
	### [CLASS]
	###   Class scope. The attribute or operation is per-class.
	module Scope
		INSTANCE	= 1
		CLASS		= 2
	end


	### Container module for visibility constants. The following constants are
	### defined:
	###
	### [PRIVATE]
	###   Visible only to the instance: For operations, this means that they may
	###   only be called in functional form (with an implicit self). For
	###   attributes, this means that the attribute will not have any accessors
	###   generated for it.
	### 
	### [PROTECTED]
	###   Visible only to the class or its descendants. For operations, this
	###   means that they can only be invoked by objects of the defining class
	###   and its subclasses. For attributes, this means that the accessors
	###   generated for it will be designated as <tt>protected</tt>.
	###
	### [PUBLIC]
	###   Visible to anyone. Operations with this visibility, and
	###   accessor/mutator operations generated for attributes with this
	###   visibility will be callable by anyone.
	module Visibility
		PRIVATE		= 1
		PROTECTED	= 2
		PUBLIC		= 3
	end

end # module Metaclass



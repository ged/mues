#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectSpaceVisitor class: A simple no-op
# objectspace visitor superclass that is used by visitor classes that traverse
# an objectspace for MUES subsystems such as MUES::ObjectStore::MemoryManager
# objects.
# 
# 
#
# == Synopsis
# 
#   
# 
# == Rcsid
# 
# $Id: objectspacevisitor.rb,v 1.2 2002/07/07 18:32:41 deveiant Exp $
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

require 'mues'


module MUES

	### The base class for an objectspace visitor. Derivatives of this class are
	### an encapsulation of operations that need to traverse an environment's
	### object space and perform some task for a MUES subsystem.
	class ObjectSpaceVisitor < MUES::Object

		### Class constants
		Version	= %q$Revision: 1.2 $
		RcsId	= %q$Id: objectspacevisitor.rb,v 1.2 2002/07/07 18:32:41 deveiant Exp $


		### Instantiate and return a new ObjectSpaceVisitor object.
		def initialize
			super()
		end


		######
		public
		######


		### I'm not sure of the interface here. It should be some sort of
		### visit() method, but the problem is made more complex by the fact
		### that we really can't know the interface from either side. We need
		### some way of providing the glue between two interfaces we don't know.
		def visit
		end

	end # class ObjectSpaceVisitor

end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectSpaceVisitor class: A simple no-op
# objectspace visitor superclass that is used by visitor classes that traverse
# an objectspace for MUES subsystems such as MUES::ObjectStore::GarbageCollector
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
# $Id: objectspacevisitor.rb,v 1.1 2002/05/28 20:41:33 deveiant Exp $
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

	### The base class for the garbage collector visitor. Derivatives of
	### this class are an encapsulation of the interaction between the
	### garbage collection strategy and the particulars of whatever class
	### heirarchy's instances are being stored in the ObjectStore. Instances
	### of this class just return false for every object, so it is really
	### only useful as a base class.
	class ObjectSpaceVisitor < MUES::Object

		### Instantiate and return a new GarbageCollectorVisitor object.
		def initialize
			super()
		end


		######
		public
		######

		### Visit the StorableObject specified by <tt>object</tt>, returning
		### true if the object should be swapped out.
		def visit( object )
			return false
		end
	end # class ObjectSpaceVisitor

end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectSpaceVisitor class: A simple no-op
# objectspace visitor superclass that is used by visitor classes that traverse
# an objectspace for MUES subsystems such as MUES::ObjectStore::MemoryManager
# objects.
# 
# This is designed to be used in the following fashion: subclass this class for
# each of the object behaviors you wish to implement, appending 'Visitor' to the
# behavior name, i.e. MethodNameVisitor < MUES::ObjectSpaceVisitor.  Then, for
# each type of object to be able to exhibit this behavior, define a method on
# the subclassed visitor named 'visitClassName' that accepts an object.  This
# should then be used to enact the desired behavior on said object.  Finally,
# all objects that deem themselves capable of being visited must define a method
# on themselves #accept, which accepts one argument (a visitor object), and
# calls the visit method on that visitor with it's self as the argument.  This
# can also be a call the the visitClassName method, if you want to skip a step
# (but then YOU will have to change that if you ever change the class's name, or
# subclass that class so as to break its ability to be treated as a ClassName
# object!).
#
# == Synopsis
# 
#	class Foo
#		def accept( visitor )
#			visitor.visit(self)
#		end
#		def myMethod
#			return 42
#		end
#	end
#
#	class Bar < Foo
#		def myMethodEmulator
#			return 6 * 7
#		end
#	end
#
#   class MyMethodVisitor < MUES::ObjectSpaceVisitor
#		def visitFooClass( foo )
#			foo.myMethod()
#		end
#		def visitBarClass( bar )
#			bar.myMethodEmulator()
#		end
#	end
#
#	f = Foo.new
#	b = Bar.new
#	v = MyMethodVisitor.new
#
#	puts "life is what life does" if
#		f.accept(v) == b.accept(v)
# 
# == Rcsid
# 
# $Id: objectspacevisitor.rb,v 1.3 2002/07/10 23:46:53 stillflame Exp $
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
		Version	= %q$Revision: 1.3 $
		RcsId	= %q$Id: objectspacevisitor.rb,v 1.3 2002/07/10 23:46:53 stillflame Exp $


		### Instantiate and return a new ObjectSpaceVisitor object.
		def initialize
			super()
		end


		######
		public
		######


		### Determins which method to call based on the class of the object
		### passed in, then calls it with that object as the argument.  When
		### subclassing, all that needs be defined is the various specific
		### visitClassName methods.
		def visit( obj )
			self.send( "visit#{obj.class.name.gsub(/::/, '')}", obj )
		end

		### Throws an error for all visitClassName methods that aren't handled.
		def method_missing( id, *args )
			if id.to_s =~ /^visit(\w+)/
				raise TypeError, "The class %s does not support the visitor enabled %s behavior" % [
					$1,
					self.class.name.split('::')[-1].gsub(/(Visitor)?/, '') ]
			else
				super(id, *args)
			end
		end

	end # class ObjectSpaceVisitor

end # module MUES


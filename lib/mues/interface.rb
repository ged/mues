#!/usr/bin/ruby
# 
# This file contains the Metaclass::Interface metaclass, which is used to add
# interfaces to instances of Metaclass::Class. Interfaces in this system are a
# bit different than those in the UML -- they can be used to actually add
# default functionality to a class which implements it, instead of simply
# expressing requirements.
# 
# == Synopsis
# 
#   require "metaclasses"
# 
#   # Instantiate the interface
#   iface = Metaclass::Interface::new( "Comparable" )
#
#   # Create a comparison operator method
#   ssop = Metaclass::Operation::new( "<=>", <<-"EOCODE" )
#       return self.id <=> otherObj.id
#   EOCODE
#   ssop << Metaclass::Parameter::new( 'otherObj' )
#
#   # Add the operation to the interface
#   iface << ssop
# 
# == Rcsid
# 
# $Id: interface.rb,v 1.5 2002/06/04 14:44:41 deveiant Exp $
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

require 'metaclass/Constants'
require 'metaclass/Operation'
require 'metaclass/Attribute'


module Metaclass

	### The Metaclass::Interface metaclass, which is used to add interfaces to
	### instances of Metaclass::Class. Interfaces in this system are a bit
	### different than those in the UML -- they can be used to actually add
	### default functionality to a class which implements it, instead of simply
	### expressing requirements.
	class Interface

		# Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
		Rcsid = %q$Id: interface.rb,v 1.5 2002/06/04 14:44:41 deveiant Exp $


		# Mix in instance vars, accessors, and methods for attributes and
		# operations
		include Metaclass::Operation::Methods
		include Metaclass::Attribute::Methods


		### Create and return a new Metaclass::Interface object with the
		### specified name. If the superclass is specified, it must be another
		### Metaclass::Interface object.
		def initialize( name, superclass=nil )
			raise TypeError, "Superclass must be a Metaclass::Interface." unless
				superclass.nil? || superclass.kind_of?( Metaclass::Interface )

			@moduleObj	= nil
			@name		= name
			# @superclass	= superclass

			super()
		end

		
		######
		public
		######

		# The interface name
		attr_reader :name


		### Return a stringified representation of the interface object.
		def inspect
			"The %s interface <Metaclass::Interface (%d op/%d attr)>" % [
				self.name,
				self.operations.length,
				self.attributes.length,
				# self.interfaces.length # <- Interfaces can't have interfaces yet
			]
		end


		### Append operator: Adds the specified <tt>metaObject</tt> to the
		### appropriate attribute, and returns itself. Valid
		### <tt>metaObject</tt>s are Metaclass::Attribute and
		### Metaclass::Operation objects.
		def <<( metaObject )
			case metaObject

			when Metaclass::Attribute
				addAttribute( metaObject )

			when Metaclass::Operation
				addOperation( metaObject )

 			#when Metaclass::Interface
 			#	addInterface( metaObject )

			else
				raise ArgumentError, "Can't append a '#{metaObject.type.name}' to a #{self.type.name}."
			end

			return self
		end


		### Return the code necessary to add the receiver's class operations to
		### the current scope. This overrides the class operations construction
		### method defined by the Metaclass::Operation::Functions mixin, as we
		### need to do some special trickery with Module#append_features to add
		### methods to an including class.
		def classOperationsDeclaration( includeComments = true )
			decl = []

			unless @classOperations.empty?
				decl << "### Class operations" if includeComments
				decl << "def self.append_features( klass )" <<
					"    super( klass )" <<
					"    klass.module_eval {"
				decl << @classOperations.sort {|x,y|
					x[1] <=> y[1]
				}.collect {|opname,op|
					op.methodDefinition(opname,includeComments).collect{|line| "    #{line}"}
				}
				
				decl << "    }" << "end"
				decl << ""
			end

			return decl
		end


		### Return the interface as evalable code. If
		### <tt>includeModuleDeclaration</tt> is <tt>true</tt>, the code is
		### wrapped in a module declaration. If <tt>includeComments</tt> is true,
		### comments will be included in the generated code to add to its
		### legibility.
		def moduleDefinition( includeModuleDeclaration = true, includeComments = true )
			decl = []

			### Assemble the class attributes, class operations, and instance
			### operations declarations.
			decl <<
				self.classAttributesDeclaration( includeComments ) <<
				self.classOperationsDeclaration( includeComments ) <<
				self.operationsDeclaration( includeComments )

			### Add the class declaration part if requested to do so
			if includeModuleDeclaration
				decl.unshift "module #{@name}"
				return decl.flatten.join("\n    ") + "\nend\n\n"
			else
				return decl.flatten.join("\n")
			end
		end


		### Return the instantiated interface (Module) object, if it's been
		### created. If not, returns <tt>nil</tt>.
		def instance
			return @moduleObj
		end


		### Return a new Module object for the interface
		def moduleObj
			
			iface = self

			# Instantiate a new module object and define its innards if it
			# hasn't been done yet
			@moduleObj ||= Module::new {
				modDef = iface.moduleDefinition( false, false )
				self.module_eval modDef
			}
		end



		### Mixin module that provides Metaclass::Interface accessor methods and
		### instance variables for classes which include it.
		module Methods

			### Initialize the @interfaces instance variable for including
			### classes (or ones that call super(), anyway.
			def initialize( *args ) # :notnew
				@interfaces = []
				super( *args )
			end


			######
			public
			######

			# The array of interfaces this class implements
			attr_reader :interfaces

			### Test for inclusion of the specified interface, which may be either a
			### Metaclass::Interface object or the name of one, in the
			### class. Returns true if the specified interface is included.
			def includesInterface?( interface )
				if interface.kind_of? Metaclass::Interface
					return @interfaces.include? interface
				else
					return true if @interfaces.detect {|iface| iface.name == interface.to_s}
				end
			end


			### Add the specified interface (a Metaclass::Interface object) to the
			### class. Returns +true+ if the interface was successfully added.
			def addInterface( interface )
				raise ArgumentError, "Illegal argument 1: Metaclass::Interface object." unless
					interface.kind_of?( Metaclass::Interface )

				self.interfaces << interface
				return true
			end


			### Remove the specified interface (a Metaclass::Interface object) from
			### the class. Returns the removed interface on success, or <tt>nil</tt>
			### if the interface wasn't found.
			def removeInterface( interface )
				raise ArgumentError, "Illegal argument 1: Metaclass::Interface object." unless
					interface.kind_of?( Metaclass::Interface ) || interface.kind_of?( ::String )

				# Look for an remove the specified interface
				rval = @interfaces.find {|iface|
					iface == interface || iface.name == interface
				}
				
				# If we found an interface to remove, remove the stuff it added, too.
				if rval
					@interfaces.delete( rval )
					# Remove interface-added ops, attributes, sub-interfaces
				end

				return rval
			end			


		end


	end # class Interface

end # module Metaclass


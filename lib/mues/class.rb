#!/usr/bin/ruby
#
# This file contains the class definition for Metaclass::Class, which is a
# metaclass used to build class definitions.
#
# == Synopsis
#
#	require 'metaclass/Class'
#
#	myClass = Metaclass::Class.new( "MyClass" )
#
#	myClass << Metaclass::Attribute.new( "name", Metaclass::Scope::INSTANCE ) << 
#		Metaclass::Attribute.new( "size", Metaclass::Scope::CLASS )
#
#	myClass << Metaclass::Operation.new( "initialize", <<-'EOM' )
#			@name = name
#			@@size += 1
#		EOM 
#	myClass.operations['initialize'].addArgument( :name, String )
#
#	myClass << Metaclass::Operation.new( "to_s", <<-'EOM' )
#		return "#{@name} (size #{@@size})"
#	EOM
#
#	eval myClass.classDefinition
#
#	myInstance = MyClass.new( "a name" )
#	puts myInstance.to_s
#
# == Rcsid
# 
# $Id: class.rb,v 1.11 2002/06/23 04:46:06 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require 'metaclass/Constants'
require 'metaclass/Attribute'
require 'metaclass/Operation'
require 'metaclass/Interface'


### A container namespace for Metaclass classes. Avoids collision with Ruby's
### builtin classes.
module Metaclass

	### An exception for indicating a problem in a Class metaclass object.
	class ClassException < ScriptError; end


	### A "Class" metaclass. Instances of this class are objects which can be used
	### to build other classes.
	class Class

		Version = /([\d\.]+)/.match( %q$Revision: 1.11 $ )[1]
		Rcsid = %q$Id: class.rb,v 1.11 2002/06/23 04:46:06 deveiant Exp $

		# Mix in comparison methods
		include Comparable

		# Mix in instance vars, accessors, and methods for associated classes
		include Metaclass::Attribute::Methods
		include Metaclass::Operation::Methods
		include Metaclass::Interface::Methods


		### Create and return a new Class metaclass object with the specified
		### +name+, and optional +superclass+.
		def initialize( name, superclass=nil )
			raise ArgumentError,
				"Superclass must be a Class or a Metaclass::Class." unless
				superclass.nil? || superclass.kind_of?( ::Class ) ||
				superclass.kind_of?( Metaclass::Class )

			# If the BaseClass class isn't loaded yet, load it
			unless Metaclass.const_defined? :BaseClass
				require 'metaclass/BaseClass'
			end

			@name		= name
			@superclass	= superclass || Metaclass::BaseClass::instance
			@classObj	= nil

			# Initialize attributes, operations, and interface instance vars
			super()
		end

		
		######
		public
		######

		# The class name
		attr_reader :name

		# The class's parent class
		attr_reader :superclass


		### Return a stringified representation of the class object.
		def inspect
			"The %s class <Metaclass::Class (%d op/%d attr/%d ifcs)>" % [
				self.name,
				self.operations.length,
				self.attributes.length,
				self.interfaces.length
			]
		end


		### Append operator: Adds the specified <tt>metaObject</tt> to the
		### appropriate attribute, and returns itself. Valid
		### <tt>metaObject</tt>s are Metaclass::Attribute, Metaclass::Operation,
		### and Metaclass::Interface objects.
		def <<( metaObject )
			case metaObject

			when Metaclass::Attribute
				addAttribute( metaObject )

			when Metaclass::Operation
				addOperation( metaObject )

			when Metaclass::Interface
				addInterface( metaObject )

			else
				raise ArgumentError, "Can't append a '#{metaObject.type.name}' to a #{self.type.name}."
			end

			return self
		end


		### Comparable method (Heirarchy query): A class is <em>greater
		### than</em> another if it is included in, or is an ancestor of the
		### <tt>otherClass</tt>. This method (and all the rest defined by
		### Comparable behave accordingly).
		def <=>( otherClass )
			raise ArgumentError,
				"Cannot compare a #{self.type.name} and a #{otherClass.type.name}" unless
				otherClass.kind_of?( Metaclass::Class )

			return 0 if otherClass.name == self.name
			return 1 if otherClass.ancestors.detect {|k| k.equal? self}
			return -1 if @superclass.ancestors.detect {|k| k.equal? otherClass}
			return 0
		end


		### Returns true if the receiver is between the specified classes in the
		### inheritance hierarchy.
		def between?( classOne, classTwo )
			raise ArgumentError,
				"Illegal argument 1: Cannot compare a #{classOne.type.name} with a #{self.type.name}" unless
				classOne.kind_of? Metaclass::Class
			raise ArgumentError,
				"Illegal argument 2: Cannot compare a #{classTwo.type.name} with a #{self.type.name}" unless
				classTwo.kind_of? Metaclass::Class

			return true if (classOne < self && self < classTwo) || (classTwo < self && self < classOne)
		end


		### Return an array of the ancestor classes of the
		### receiver (including the receiver itself) in the
		### same order as the standard Ruby Module#ancestors
		### method (0=class itself; 1=immediate superclass;
		### continuing to the most general).
		def ancestors
			if @superclass
				[ self, *@superclass.ancestors ].flatten
			else
				[ self ]
			end
		end


		### Returns true if the class object is an abstract class (ie., has one
		### or more operations without implementations).
		def abstract?
			seenOps = {}
			catch( :foundVirtual ) {
				self.ancestors.each {|klass|
					next unless klass.is_a? Metaclass::Class
					klass.operations.each {|name,op|
						next if seenOps[name]
						if op.virtual?
							throw :foundVirtual, true
						else
							seenOps[name] = true
						end
					}
				}
				return false
			}
		end


		### Return the metaclass as evalable code. If
		### <tt>includeClassDeclaration</tt> is <tt>true</tt>, the code is
		### wrapped in a class declaration. If <tt>includeComments</tt> is true,
		### comments will be included in the generated code to add to its
		### legibility.
		def classDefinition( includeClassDeclaration = true, includeComments = true )
			decl = []

			### Add code to make :new a private class method if this class is an
			### abstract class.
			if self.abstract?
				decl << "private_class_method :new"
			else
				decl << "public_class_method :new"
			end

			### Assemble the class attributes, class operations, and instance
			### operations declarations.
			decl <<
				self.classAttributesDeclaration( includeComments ) <<
				self.classOperationsDeclaration( includeComments ) <<
				self.operationsDeclaration( includeComments )
 
			### Add the class declaration part if requested to do so
			if includeClassDeclaration
				if @superclass
					decl.unshift "class #{@name} < #{@superclass.name}"
				else
					decl.unshift "class #{@name}"
				end
				return decl.flatten.join("\n    ") + "\nend\n\n"
			else
				return decl.flatten.join("\n")
			end
		end


		### Return the instantiated Class object, if it's been
		### created. If not, returns <tt>nil</tt>
		def instance
			return @classObj
		end


		### Return the anonymous class object associated with the receiver.
		def classObj
			return @classObj unless @classObj.nil?

			# Grab some stuff from this scope before we dive into the new
			# class's scope
			metaclass = self

			# Ladder idiom -- define a new anonymous class if it's not
			# instantiated already, and eval the class definition sans
			# declaration in the new class
			@classObj ||= ::Class::new( self.superclass.classObj ) {
				
				# Apply the class's interfaces to the class if they aren't
				# already
				metaclass.interfaces.each {|iface|
					mod = iface.moduleObj
					include( mod ) unless self.include?( mod )
				}
				
				# Now eval the class definition
				klassDef = metaclass.classDefinition( false, false )
				self.class_eval klassDef
			}
		end


		### Instantiate the class.
		def new( *args )
			self.classObj.new( *args )
		end

	end # class Class

end # module Metaclass



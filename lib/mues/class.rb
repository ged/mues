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
# $Id: class.rb,v 1.3 2002/03/30 19:13:11 deveiant Exp $
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

### A container namespace for Metaclass classes. Avoids collision with Ruby's
### builtin classes.
module Metaclass

	autoload :Operation, "metaclass/Operation"
	autoload :Parameter, "metaclass/Parameter"
	autoload :Interface, "metaclass/Interface"
	autoload :Attribute, "metaclass/Attribute"
	autoload :Asscociation, "metaclass/Association"


	### An exception for indicating a problem in a Class metaclass object.
	class ClassException < ScriptError; end


	### A "Class" metaclass. Instances of this class are objects which can be used
	### to build other classes.
	class Class

		include Comparable

		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: class.rb,v 1.3 2002/03/30 19:13:11 deveiant Exp $


		### Create and return a new Class metaclass object with the specified
		### +name+, and optional +superclass+.
		def initialize( name, superclass=nil )
			raise TypeError, "Superclass must be a Class or a Metaclass::Class." unless
				superclass.nil? || superclass.kind_of?( Class ) || superclass.kind_of?( Metaclass::Class )

			@name				= name
			@operations			= {}
			@classOperations	= {}
			@attributes			= {}
			@classAttributes	= {}
			@interfaces			= []

			@superclass			= superclass
		end

		
		######
		public
		######

		# The class name
		attr_reader :name

		# The Hash of operations belonging to instances this class, keyed by name
		attr_reader :operations

		# The Hash of class operations belonging to this class, keyed by name
		attr_reader :classOperations

		# The Hash of attributes belonging to this class, keyed by name
		attr_reader :attributes

		# The Hash of class attributes belonging to this class, keyed by name
		attr_reader :classAttributes

		# The array of interfaces this class implements
		attr_reader :interfaces

		# The class's parent class
		attr_reader :superclass


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
				raise TypeError, "Can't append a '#{metaObject.type.name}' to a #{self.type.name}."
			end

			return self
		end


		### Add the specified attribute (a Metaclass::Attribute object) to the
		### class. If the optional +name+ argument is given, it will be used as
		### the association name instead of the attribute's own name. If the
		### attribute's visibility is either PUBLIC or PROTECTED, and there
		### aren't already synonymous operations defined, accessor and mutator
		### operation objects will be added as well. Returns true if the
		### attribute was successfully added.
		def addAttribute( attribute, name=nil, readOnly=false )
			raise TypeError, "Illegal argument 1: Metaclass::Attribute object." unless
				attribute.kind_of?( Metaclass::Attribute )

			# Normalize the name and set the attribute in the appropriate
			# attribute hash
			name ||= attribute.name
			if attribute.scope == Scope::INSTANCE
				@attributes[ name ] = attribute
			else
				@classAttributes[ name ] = attribute
			end

			# Pick the appropriate operations hash to use based on the scope of
			# the attribute
			targetOps = if attribute.scope == Scope::INSTANCE
							@operations
						else
							@classOperations
						end

			# Add any accessors/mutators which are called for
			if attribute.visibility >= Scope::PROTECTED
				
				# If there's not already an accessor, add one
				unless targetOps.key? name
					targetOps[ name ] = attribute.makeAccessorOp
				end

				# ...same for a mutator unless the attribute's read-only
				unless readOnly || targetOps.has_key?("#{name}=")
					targetOps[ "#{name}=" ] = attribute.makeMutatorOp
				end
			end

		end


		### Comparable method (Heirarchy query): A class is <em>greater
		### than</em> another if it is included in, or is an ancestor of the
		### <tt>otherClass</tt>. This method (and all the rest defined by
		### Comparable behave accordingly).
		def <=>( otherClass )
			return 0 unless otherClass.kind_of?( Metaclass::Class ) && otherClass != self

			return -1 if @superclass.ancestors.detect {|k| k == otherClass}
			return 1 if otherClass.ancestors.detect {|k| k == self}
			return 0
		end


		### Return a stringified representation of the class object.
		def inspect
			@name
		end


		### Return an array of the ancestor classes of the receiver (including
		### the receiver itself).
		def ancestors
			if @superclass
				[ self, @superclass.ancestors ].flatten
			else
				[ self ]
			end
		end


		### Return the metaclass as evalable code. If
		### <tt>includeClassDeclaration</tt> is <tt>true</tt>, the code is
		### wrapped in a class declaration. If <tt>includeComments</tt> is true,
		### comments will be included in the generated code to add to its
		### legibility.
		def classDefinition( includeClassDeclaration = true, includeComments = true )
			decl = []

			### Add interfaces to the declaration
			if @interfaces.length > 0
				decl << "### Interfaces"
			end

			### Add attributes to the declaration
			if @attributes.length > 0
				decl << "### Attributes"
				decl << @attributes.sort {|x,y|
					x[1] <=> y[1]
				}.collect {|attrname,attr|
					if attr.validTypes.length > 0
						"attr_typechecked_accessor :#{attrname}, #{attr.validTypes.inspect}"
					else
						"attr_accessor :#{attrname}"
					end
				}

				decl << ""
			end

			### Add operations to the declaration
			if @operations.length > 0
				decl << "### Operations" if includeComments
				decl << @operations.sort {|x,y|
					x[1] <=> y[1]
				}.collect {|opname,op|
					op.methodDefinition(opname,includeComments)
				}

				decl << ""
			end

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
	end # class Class

end # module Metaclass



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
# $Id: class.rb,v 1.6 2002/04/09 06:59:51 deveiant Exp $
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

	### An exception for indicating a problem in a Class metaclass object.
	class ClassException < ScriptError; end


	### A "Class" metaclass. Instances of this class are objects which can be used
	### to build other classes.
	class Class

		include Comparable

		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: class.rb,v 1.6 2002/04/09 06:59:51 deveiant Exp $


		### Create and return a new Class metaclass object with the specified
		### +name+, and optional +superclass+.
		def initialize( name, superclass=nil )
			raise ArgumentError, "Superclass must be a Class or a Metaclass::Class." unless
				superclass.nil? || superclass.kind_of?( ::Class ) || superclass.kind_of?( Metaclass::Class )

			@name				= name
			@operations			= {}
			@classOperations	= {}
			@attributes			= {}
			@classAttributes	= {}
			@interfaces			= []

			# If the BaseClass class isn't loaded yet, load it
			unless Metaclass.const_defined? :BaseClass
				require 'metaclass/BaseClass'
			end

			@superclass			= superclass || Metaclass::BaseClass::instance

			# The generated anonymous class
			@classObj			= nil
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


		### Return a stringified representation of the class object.
		def inspect
			"The %s class <Metaclass::Class (%d op/%d attr/%d ifcs)>" % [
				self.name,
				self.operations.length,
				self.attributes.length,
				self.interfaces.length
			]
		end


		### Test for the attribute specified. Returns true if instances of the
		### class have an attribute with the specified attribute, which may be a
		### Metaclass::Attribute object, or a String containing the name of the
		### attribute to test for.
		def hasAttribute?( attribute )
			if attribute.kind_of? Metaclass::Attribute
				return true if @attributes.has_value? attribute
			else
				return @attributes.has_key? attribute.to_s
			end
		end

		
		### Test for the class attribute specified. Returns true if instances of
		### the class have an attribute with the specified attribute, which may
		### be a Metaclass::Attribute object, or a String containing the name of
		### the attribute to test for.
		def hasClassAttribute?( attribute )
			if attribute.kind_of? Metaclass::Attribute
				return true if @classAttributes.has_value? attribute
			else
				return @classAttributes.has_key? attribute.to_s
			end
		end

		
		### Test for the operation specified. Returns true if instances of the
		### class have an operation with the specified operation, which may be a
		### Metaclass::Operation object, or a String containing the name of the
		### operation to test for.
		def hasOperation?( operation )
			if operation.kind_of? Metaclass::Operation
				return true if @operations.has_value? operation
			else
				return @operations.has_key? operation.to_s
			end
		end

		
		### Test for the class operation specified. Returns true if instances of
		### the class have an operation with the specified operation, which may
		### be a Metaclass::Operation object, or a String containing the name of
		### the operation to test for.
		def hasClassOperation?( operation )
			if operation.kind_of? Metaclass::Operation
				return true if @classOperations.has_value? operation
			else
				return @classOperations.has_key? operation.to_s
			end
		end


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


		### Add the specified attribute (a Metaclass::Attribute object) to the
		### class. If the optional +name+ argument is given, it will be used as
		### the association name instead of the attribute's own name. If the
		### attribute's visibility is either PUBLIC or PROTECTED, and there
		### aren't already synonymous operations defined, accessor and mutator
		### operation objects will be added as well. Returns true if the
		### attribute was successfully added.
		def addAttribute( attribute, name=nil, readOnly=false )
			raise ArgumentError, "Illegal argument 1: Metaclass::Attribute object." unless
				attribute.kind_of?( Metaclass::Attribute )

			# Normalize the name
			name ||= attribute.name

			# Add attribute and accessor/mutator
			if attribute.scope == Scope::INSTANCE
				@attributes[ name ] = attribute

				# Add any accessors/mutators which are called for
				if attribute.visibility >= Visibility::PROTECTED
					# If there's not already an accessor, add one
					unless self.hasOperation? name
						self.addOperation( attribute.makeAccessorOp, name )
					end

					# ...same for a mutator unless the attribute's read-only
					unless readOnly || self.hasOperation?("#{name}=")
						self.addOperation( attribute.makeMutatorOp, "#{name}=" )
					end
				end
			else
				@classAttributes[ name ] = attribute

				# Add any accessors/mutators which are called for
				if attribute.visibility >= Visibility::PROTECTED
					# If there's not already an accessor, add one
					unless self.hasClassOperation? name
						self.addOperation( attribute.makeAccessorOp, name )
					end

					# ...same for a mutator unless the attribute's read-only
					unless readOnly || self.hasClassOperation?("#{name}=")
						self.addOperation( attribute.makeMutatorOp, "#{name}=" )
					end
				end

			end

			return true
		end


		### Remove the specified attribute (a Metaclass::Attribute object or a
		### String containing the name of the attribute), from the class. If an
		### accessor and/or mutator was added to the class by the attribute,
		### those too will be removed. Returns the removed attribute on success,
		### or <tt>nil</tt> if the specified attribute was not found.
		def removeAttribute( attribute )
			raise ArgumentError,
				"Expected a Metaclass::Attribute or a String, not a #{attribute.type.name}" unless
				attribute.kind_of?( Metaclass::Attribute ) || attribute.kind_of?( String )

			# Look for and remove the specified attribute
			rval = @attributes.find {|name,attrObj|
				attrObj == attribute || name == attribute
			}

			# If we found the pair, remove them and their associated operations, if present
			if rval
				rval = @attributes.delete( rval[0] )
				self.removeOperation( rval.makeAccessorOp )
				self.removeOperation( rval.makeMutatorOp )
			end

			return rval
		end


		### Add the specified operation (a Metaclass::Operation object) to the
		### class. If the optional +name+ argument is given, it will be used as
		### the method name instead of the operation's own name. Returns true if the
		### operation was successfully added.
		def addOperation( operation, name=nil )
			raise ArgumentError, "Illegal argument 1: Metaclass::Operation object." unless
				operation.kind_of?( Metaclass::Operation )

			# Normalize the name and set the operation in the appropriate
			# operation hash
			name ||= operation.name
			if operation.scope == Scope::INSTANCE
				@operations[ name ] = operation
			else
				@classOperations[ name ] = operation
			end

			# If the class object's already been instantiated, turn off warnings
			# about redefinition, and eval the new method into the class object
			if @classObj
				oldVerbose = $VERBOSE
				$VERBOSE = false
				@classObj.class_eval { operation.methodDefinition(name) }
				$VERBOSE = oldVerbose
			end

			return true
		end


		### Remove the specified operation (a Metaclass::Operation object, or a
		### String containing the name associated with the operation). Returns
		### the removed operation if successful, or <tt>nil</tt> if the
		### specified operation was not found.
		def removeOperation( operation )
			raise ArgumentError,
				"Expected a Metaclass::Operation or a String, not a #{operation.type.name}" unless
				operation.kind_of?( Metaclass::Operation ) || operation.kind_of?( String )

			# Look for and remove the specified attribute
			rval = @operations.find {|name,opObj|
				opObj == operation || name == operation
			}

			# If we found the pair, remove them and their associated operations, if present
			if rval
				if @classObj
					@classObj.class_eval { remove_method rval[0].intern }
				end

				rval = @operations.delete( rval[0] )
			end

			return rval
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


		### Return an array of the ancestor classes of the receiver (including
		### the receiver itself).
		def ancestors
			if @superclass
				[ self, *@superclass.ancestors ].flatten
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
			if @interfaces.length.nonzero?
				decl << "### Interfaces"
				decl << @interfaces.collect {|iface|
					iface.declaration
				}
			end

			### Add operations to the declaration
			unless @operations.empty?
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


		### Return the anonymous class object associated with the receiver.
		def classObj
			klassDef = self.classDefinition( false, false )

			# Ladder idiom -- define a new anonymous class if it's not
			# instantiated already, and eval the class definition sans
			# declaration in the new class
			@classObj ||= ::Class::new( self.superclass.classObj ) {
				self.class_eval klassDef
			}
		end


		### Instantiate the class.
		def new( *args )
			self.classObj.new( *args )
		end

	end # class Class

end # module Metaclass



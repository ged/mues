#!/usr/bin/ruby
# 
# This file contains the MUES::Metaclass::Attribute metaclass: Instances of this class
# are used to add attributes to MUES::Metaclass::Class objects.
# 
# == Synopsis
#
#	require 'mues/metaclass/Attribute'
#	include MUES::Metaclass
# 
#   locationAttr = Attribute.new( "location", LocationVector )
#   nameAttr = Attribute.new( "name", String )
# 
#   someClass.addAttributes( locationAttr, nameAttr )
# 
# == Rcsid
# 
# $Id: attribute.rb,v 1.9 2002/10/04 05:06:43 deveiant Exp $
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

require 'mues/Mixins'

require 'mues/metaclass/Constants'
require 'mues/metaclass/AccessorOperation'
require 'mues/metaclass/MutatorOperation'

module MUES
	module Metaclass

		### Attribute metaclass for Metaclass::Class objects.
		class Attribute

			include Comparable, MUES::TypeCheckFunctions

			# The default scope of new Attribute objects
			DEFAULT_SCOPE = Scope::INSTANCE
			DEFAULT_VISIBILITY = Visibility::PUBLIC

			Version = /([\d\.]+)/.match( %q{$Revision: 1.9 $} )[1]
			Rcsid = %q$Id: attribute.rb,v 1.9 2002/10/04 05:06:43 deveiant Exp $

			### Create and return a new attribute with the specified name. If the
			### optional <tt>validTypes</tt> argument is specified, the attribute
			### will be type-checked in any generated code that uses it. The +scope+
			### argument controls whether the attribute is scoped per-class or
			### per-instance, and the +visibility+ argument controls the
			### accessability of any accessor methods generated in host classes.
			def initialize( name, validTypes=[], scope=DEFAULT_SCOPE, visibility=DEFAULT_VISIBILITY )
				checkType( name, ::String, ::Symbol )
				name = name.id2name if name.is_a? Symbol

				# Test to be sure that validTypes is either a Class, a
				# Metaclass::Class, or an array of either
				validTypes = [ validTypes ] unless validTypes.is_a?( Array )
				checkEachType( validTypes, ::Class, Metaclass::Class )

				raise TypeError, "Illegal value for scope." unless
					scope == Scope::INSTANCE || scope == Scope::CLASS


				@name = name
				@scope = scope
				@visibility = visibility
				@validTypes = validTypes.flatten.compact
				@defaultValue = nil

				@accessorOp = nil
				@mutatorOp = nil
			end


			######
			public
			######

			# The attribute name
			attr_accessor :name
			
			# The Array of valid types for this attribute
			attr_accessor :validTypes

			# The scope of the attribute (one of the constants in
			# Metaclass::Scope).
			attr_accessor :scope

			# The visibility of the attribute (one of the constants in
			# Metaclass::Visibility).
			attr_accessor :visibility

			# The default value for the attribute
			attr_accessor :defaultValue


			### <tt>Comparable</tt> interface method. Returns -1, 0, or 1 if this
			### attribute should sort higher, the same, or lower than the specified
			### <tt>otherAttribute</tt>. In truth, this method will only return '0'
			### if <tt>otherAttribute</tt> is the same as the receiver.
			def <=>( otherAttribute )
				raise TypeError,
					"Cannot compare an attribute with #{otherAttribute.inspect}:"+
					"#{otherAttribute.class.name}" unless
					otherAttribute.kind_of?( Metaclass::Attribute )

				return (@scope <=> otherAttribute.scope).nonzero? ||
					(@name <=> otherAttribute.name).nonzero? ||
					self.id <=> otherAttribute.id
			end


			### Returns a Metaclass::Operation object suitable for addition to a
			### Metaclass::Class object as an accessor method. <em>Aliases:</em>
			### makeAccessorOp.
			def getAccessorOp
				if self.visibility >= Visibility::PROTECTED
					@accessorOp ||= Metaclass::AccessorOperation.new( self.name,
																	 self.scope,
																	 self.visibility )
				else
					@accessorOp = nil
				end

				return @accessorOp
			end
			alias :makeAccessorOp :getAccessorOp


			### Returns a Metaclass::Operation object suitable for addition to a
			### Metaclass::Class object as a mutator method. If the receiver has a
			### list of #validTypes, the mutator will do type-checking for one of
			### those types with <tt>kind_of?</tt>. <em>Aliases:</em> makeMutatorOp.
			def getMutatorOp
				if self.visibility >= Visibility::PROTECTED
					@mutatorOp ||= Metaclass::MutatorOperation.new( "#{self.name}",
																   self.validTypes,
																   self.scope,
																   self.visibility )
				else
					@mutatorOp = nil
				end

				return @mutatorOp
			end
			alias :makeMutatorOp :getMutatorOp



			### Mixin module that provides Metaclass::Attribute accessor methods for
			### classes which include them.
			module Methods

				### Initialize @operations and @classOperations instance variables
				### for including classes (or ones that call super(), anyway.
				def initialize( *args ) # :notnew
					@attributes			= {}
					@classAttributes	= {}

					super( *args )
				end


				######
				public
				######

				# The Hash of attributes belonging to this class, keyed by name
				attr_reader :attributes

				# The Hash of class attributes belonging to this class, keyed by name
				attr_reader :classAttributes


				### Test for the attribute specified. Returns true if instances of the
				### class have an attribute with the specified attribute, which may be a
				### Metaclass::Attribute object, or a String containing the name of the
				### attribute to test for.
				def hasAttribute?( attribute )
					if attribute.kind_of? Metaclass::Attribute
						return true if @attributes.has_value? attribute
					else
						return @attributes.has_key?( attribute.to_s )
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
						return @classAttributes.has_key?( attribute.to_s )
					end
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

					# Add attribute and accessor/mutator if the receiver supports
					# operations.
					if self.class.included_modules.include? Metaclass::Operation::Methods

						# Add instance methods if the attribute is scoped to the
						# instance.
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

							# Otherwise, add class accessors
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
						"Expected a Metaclass::Attribute or a String, not a #{attribute.class.name}" unless
						attribute.kind_of?( Metaclass::Attribute ) || attribute.kind_of?( String )

					# Look for and remove the specified attribute
					rval = @attributes.find {|name,attrObj|
						attrObj.eql?( attribute ) || name.eql?( attribute )
					}

					# If we found the pair, remove them and their associated operations, if present
					if rval
						rval = @attributes.delete( rval[0] )
						if self.class.included_modules.include? Metaclass::Operation::Methods
							self.removeOperation( rval.makeAccessorOp )
							self.removeOperation( rval.makeMutatorOp )
						end
					end

					return rval
				end


				### Return the code necessary to add the receiver's class attributes
				### to the current scope
				def classAttributesDeclaration( includeComments=true )
					decl = []

					unless @classAttributes.empty?
						decl << "### Class variables" if includeComments
						decl << @classAttributes.sort {|x,y|
							x[1] <=> y[1]
						}.collect {|varname,var|
							"@@#{varname} = " + var.defaultValue.inspect
						}
						
						decl << ""
					end

					return decl
				end			

			end # module Methods
		end # class Attribute

	end # module Metaclass
end # module MUES

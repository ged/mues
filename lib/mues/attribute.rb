#!/usr/bin/ruby
# 
# This file contains the Metaclass::Attribute metaclass: Instances of this class
# are used to add attributes to Metaclass::Class objects.
# 
# == Synopsis
# 
#   locationAttr = Metaclass::Attribute.new( "location", LocationVector )
#   nameAttr = Metaclass::Attribute.new( "name", String )
# 
#   someClass.addAttributes( locationAttr, nameAttr )
# 
# == Rcsid
# 
# $Id: attribute.rb,v 1.6 2002/05/16 04:04:45 deveiant Exp $
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
require 'metaclass/AccessorOperation'
require 'metaclass/MutatorOperation'

module Metaclass

	### Attribute metaclass for Metaclass::Class objects.
	class Attribute

		include Comparable

		# The default scope of new Attribute objects
		DEFAULT_SCOPE = Scope::INSTANCE
		DEFAULT_VISIBILITY = Visibility::PUBLIC

		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: attribute.rb,v 1.6 2002/05/16 04:04:45 deveiant Exp $

		### Create and return a new attribute with the specified name. If the
		### optional <tt>validTypes</tt> argument is specified, the attribute
		### will be type-checked in any generated code that uses it. The +scope+
		### argument controls whether the attribute is scoped per-class or
		### per-instance, and the +visibility+ argument controls the
		### accessability of any accessor methods generated in host classes.
		def initialize( name, validTypes=nil, scope=DEFAULT_SCOPE, visibility=DEFAULT_VISIBILITY )
			name = name.id2name if name.is_a? Symbol

			raise TypeError, "Illegal attribute name #{name}" unless
				name.kind_of? String

			# Test to be sure that validTypes is either nil, a Class, a
			# Metaclass::Class, or an array of either kind of Class
			unless ( validTypes == nil || 
					 validTypes.type === ::Class || 
					 validTypes.type == Metaclass::Class || 
					 (validTypes.is_a?( Array ) && 
                      !validTypes.find {|x| !x.type === ::Class && !x.type == Metaclass::Class}) 
					)
				raise TypeError, "ValidType must be a Class or an array of classes, not a '#{validTypes.type.inspect}'" 
			end
			raise TypeError, "Illegal value for scope." unless
				scope == Scope::INSTANCE || scope == Scope::CLASS

			@name = name
			@scope = scope
			@visibility = visibility
			@validTypes = validTypes.to_a.flatten.compact
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
		# Metaclass::Scope).
		attr_accessor :visibility

		# The default value for the attribute
		attr_accessor :defaultValue


		### <tt>Comparable</tt> interface method. Returns -1, 0, or 1 if this
		### attribute should sort higher, the same, or lower than the specified
		### <tt>otherAttribute</tt>. In truth, this method will only return '0'
		### if <tt>otherAttribute</tt> is the same as the receiver.
		def <=>( otherAttribute )
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

	end

end

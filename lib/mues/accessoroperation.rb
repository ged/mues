#!/usr/bin/ruby
# 
# This file contains the MUES::Metaclass::AccessorOperation class: An attribute
# accessor specialization of MUES::Metaclass::Operation. It is used to create
# accessor methods for MUES::Metaclass::Class objects.
# 
# == Synopsis
#
#   ...
#   myClass << MUES::Metaclass::AccessorOperation.new( "name" )
#
#	eval myClass.classDefinition
#
#	# Assuming the argument to the constructor sets the @name instance variable...
#	myInstance = MyClass.new( "A name" )
#	puts myInstance.name
# 
# == Rcsid
# 
# $Id: accessoroperation.rb,v 1.3 2002/10/04 04:05:38 deveiant Exp $
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

require 'mues/metaclass/Operation'

module MUES
	module Metaclass

		### An attribute accessor specialization of Metaclass::Operation.
		class AccessorOperation < Metaclass::Operation

			### Class constants
			Version = /([\d\.]+)/.match( %q{$Revision: 1.3 $} )[1]
			Rcsid = %q$Id: accessoroperation.rb,v 1.3 2002/10/04 04:05:38 deveiant Exp $

			### Create a new AccessorOperation object.
			def initialize( name, scope=Operation::DEFAULT_SCOPE, visibility=Operation::DEFAULT_VISIBILITY )
				case scope
				when Scope::CLASS
					super( name, "@@#{name}", scope, visibility )
				else
					super( name, "@#{name}", scope, visibility )
				end
			end

		end # class AccessorOperation

	end # module Metaclass
end # module MUES


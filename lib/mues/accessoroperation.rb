#!/usr/bin/ruby
# 
# This file contains the AccessorOperation class: An attribute accessor
# specialization of Metaclass::Operation. It is used to create accessor methods
# for Metaclass::Class objects.
# 
# == Synopsis
#
#   ...
#   myClass << Metaclass::AccessorOperation.new( "name" )
#
#	eval myClass.classDefinition
#
#	# Assuming the argument to the constructor sets the @name instance variable...
#	myInstance = MyClass.new( "A name" )
#	puts myInstance.name
# 
# == Rcsid
# 
# $Id: accessoroperation.rb,v 1.1 2002/03/30 19:04:08 deveiant Exp $
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

require 'metaclass/Operation'

module Metaclass

	### An attribute accessor specialization of Metaclass::Operation.
	class AccessorOperation < Metaclass::Operation

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: accessoroperation.rb,v 1.1 2002/03/30 19:04:08 deveiant Exp $

		### Create a new AccessorOperation object.
		def initialize( name, scope=Operation::DEFAULT_SCOPE, visibility=Operation::DEFAULT_VISIBILITY )
			super( name, "@#{name}", scope, visibility )
		end

	end # class AccessorOperation
end # module Metaclass

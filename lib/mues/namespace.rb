#!/usr/bin/ruby
# 
# This file contains the Metaclass::Namespace class. Instances of this class are
# convenience objects that allow the definition of metaclasses to be made in a
# namespace separate from the main Ruby namespace.
# 
# == Synopsis
# 
#   require "metaclass/Namespace"
# 
#   ns = MetaClass::Namespace.new( "SomeName" )
#   ns.addClass( metaclass )
# 
#   eval "#{ns}"
# 
# == Rcsid
# 
# $Id: namespace.rb,v 1.3 2002/03/30 19:16:24 deveiant Exp $
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

module Metaclass

	autoload :Class, 'metaclass/Class'

	### A namespace metaclass
	class Namespace

		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: namespace.rb,v 1.3 2002/03/30 19:16:24 deveiant Exp $

		### Create and return a new namespace object with the specified +name+.
		def initialize( name )
			@name = name
			@classes = []
		end


		######
		public
		######

		# The name of the namespace
		attr_accessor :name

		# The Array of classes within the namespace
		attr_accessor :classes

		### Add the specified metaclass classes to the namespace.
		def addClasses( *classes )
			@classes.push classes
			@classes.flatten!
		end

		### Return the namespace as evalable code
		def to_s
			"module #{@name}\n" + @classes.sort.reverse.collect {|k| k.classDefinition(true,true)}.join("\n") + "end"
		end
	end
end

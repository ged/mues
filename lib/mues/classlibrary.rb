#!/usr/bin/ruby
# 
# This file contains the MUES::ClassLibrary class, which is an interface object
# for environment metaclass libraries. Instances of this class contain a library
# of MUES::Metaclass objects which can be instantiated outside of the main Ruby
# namespace, and can be stored and manipulated at runtime with greater ease.
# 
# == Synopsis
# 
#   require 'mues/classlibrary'
# 
#	lib = MUES::ClassLibrary::new( "FaerieMUD" )
#	obj = lib.newObject( "MyClass" )
#
# == Rcsid
# 
# $Id: classlibrary.rb,v 1.12 2003/10/13 04:02:17 deveiant Exp $
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

require "mues"
require 'mues/object'
require 'mues/events'
require 'mues/exceptions'
require 'mues/metaclasses'

module MUES

	### An error class for problems in metaclass objects.
	class ClassError < Exception; end

	### An AbstractFactory class for environment metaclass libraries
	class ClassLibrary < Object
		include MUES::TypeCheckFunctions

		Version = /([\d\.]+)/.match( %q{$Revision: 1.12 $} )[1]
		Rcsid = %q$Id: classlibrary.rb,v 1.12 2003/10/13 04:02:17 deveiant Exp $

		### Return a new ClassLibrary object with the specified name.
		def initialize( libraryName="unnamed" )
			super()

			@name		= libraryName
			@classes	= {}
			@interfaces	= {}
		end


		######
		public
		######

		### Returns the name of the class library.
		attr_reader :name


		### Create a new class object with the given name and insert it into the
		### library.
		def createClass( className, superclass=nil )
			raise ArgumentError,
				"Name collision -- class '#{className}' already exists" if
				@classes.key?( className )

			@classes[ className ] = Metaclass::Class::new( className )
		end
		
	end
end


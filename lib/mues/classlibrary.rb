#!/usr/bin/ruby
# 
# This file contains the MUES::ClassLibrary class, which is an interface object
# for environment metaclass libraries. Instances of this class contain a library
# of MUES::Metaclass objects which can be instantiated outside of the main Ruby
# namespace, and can be stored and manipulated at runtime with greater ease.
# 
# == Synopsis
# 
#   require "mues/ClassLibrary"
# 
#	lib = MUES::ClassLibrary::new( "FaerieMUD" )
#	obj = lib.newObject( "MyClass" )
#
# == Rcsid
# 
# $Id: classlibrary.rb,v 1.10 2003/08/04 02:36:15 deveiant Exp $
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
require "mues/Object"
require "mues/Events"
require "mues/Exceptions"
require "mues/Metaclasses"

module MUES

	### An error class for problems in metaclass objects.
	class ClassError < Exception; end

	### An AbstractFactory class for environment metaclass libraries
	class ClassLibrary < Object

		Version = /([\d\.]+)/.match( %q{$Revision: 1.10 $} )[1]
		Rcsid = %q$Id: classlibrary.rb,v 1.10 2003/08/04 02:36:15 deveiant Exp $

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

		
	end
end


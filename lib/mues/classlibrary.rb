#!/usr/bin/ruby
# 
# This file contains the MUES::ClassLibrary class, which is an AbstractFactory
# class for environment metaclass libraries. Instances of this class contain a
# library of Environment classes which can be instantiated outside of the main
# Ruby namespace, and can be recombined and manipulated at runtime with greater
# ease.
# 
# == Synopsis
# 
#   require "mues/ClassLibrary"
# 
#   class MyLibrary < MUES::ClassLibrary
# 	
# 	  def initialize
# 	    ...
# 	  end
# 
#   end
#   
# == Rcsid
# 
# $Id: classlibrary.rb,v 1.9 2002/10/04 10:01:45 deveiant Exp $
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

require "mues/Object"
require "mues/Events"
require "mues/Exceptions"
require "mues/Metaclasses"

module MUES

	### An error class for problems in metaclass objects.
	class ClassError < Exception; end

	### An AbstractFactory class for environment metaclass libraries
	class ClassLibrary < Object

		Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
		Rcsid = %q$Id: classlibrary.rb,v 1.9 2002/10/04 10:01:45 deveiant Exp $

		### Return a new ClassLibrary object with the specified name.
		def initialize( libraryName )
			super
			@name = libraryName
			@classes = {}
			@interfaces = {}
			@namespaces = {}
		end


		######
		public
		######

		### Returns the name of the class library.
		attr_reader :name

		### Add an interface to the library, either by the name specified or the
		### same name as the name attribute of the interface object if no name
		### is specified.
		def addInterface( interface, altInterfaceName = nil )
			interfaceName = if altInterfaceName.nil?
							then interface.name
							else altInterfaceName
							end

			@interfaces[ interfaceName ] = klass
		end

		### Add a class to the library.If no <tt>alternateClassName</tt> is
		### specified, <tt>klass.name</tt> will be used.
		def addClass( klass, altClassName = nil )
			klassName = if altClassName.nil?
						then klass.name
						else altClassName
						end

			@classes[ klassName ] = klass
		end

		### Returns the ancestors of the class specified as an Array.
		def getClassAncestry( className )
			return []
		end

		### Returns the eval-able definition of the class specified.
		def getClassDefinition( className )
			return ""
		end

	end
end


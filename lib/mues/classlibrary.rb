#!/usr/bin/ruby
###########################################################################
=begin

=ClassLibrary.rb

== Name

ClassLibrary - World object class library service

== Synopsis

  require "mues/ClassLibrary"
  require "metaclass/Classes"

  cl = MUES::ClassLibrary.new( "MyLibrary" )
  
== Description

A metaclass collection container object class.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"

require "metaclass/Class"

module MUES
	class ClassError < Exception; end
	class ClassLibrary < Object

		Version = /([\d\.]+)/.match( %q$Revision: 1.3 $ )[1]
		Rcsid = %q$Id: classlibrary.rb,v 1.3 2001/04/06 08:19:20 deveiant Exp $

		attr_reader :name

		### METHOD: initialize( libraryName )
		### Initializes a class library object, setting the name of the library
		### to the one given.
		def initialize( libraryName )
			super
			@name = libraryName
			@classes = {}
			@interfaces = {}
			@namespaces = {}
		end

		### METHOD: addInterface( interface[, altInterfaceName] )
		### Adds an interface to the library, either by the name specified or
		### the same name as the name attribute of the interface object if no
		### name is specified.
		def addInterface( interface, altInterfaceName = nil )
			interfaceName = if altInterfaceName.nil?
							then interface.name
							else altInterfaceName
							end

			@interfaces[ interfaceName ] = klass
		end

		### METHOD: addClass( classObject[, altClassName] )
		### Adds a class to the library, either by the name specified or the
		### same name as the name attribute of the class object if no name is
		### specified.
		def addClass( klass, altClassName = nil )
			klassName = if altClassName.nil?
						then klass.name
						else altClassName
						end

			@classes[ klassName ] = klass
		end

		### METHOD: getClassAncestry( className )
		### Returns the ancestors of the class specified as an Array.
		def getClassAncestry( className )
			return []
		end

		### METHOD: getClassDefinition( className )
		### Returns the eval-able definition of the class specified.
		def getClassDefinition( className )
			return ""
		end

	end
end


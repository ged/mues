#!/usr/bin/ruby
###########################################################################
=begin

=ClassLibrary.rb

== Name

ClassLibrary - World object class library service

== Synopsis

  

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/MUES"
require "mues/Events"
require "mues/Exceptions"

require "metaclass/Class"

module MUES
	class ClassError < Exception; end
	class ClassLibrary < Object

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: classlibrary.rb,v 1.1 2001/03/15 02:22:16 deveiant Exp $

		attr_reader :name

		def initialize( libraryName )
			super
			@name = libraryName
			@classes = {}
		end

		def addClass( klass, klassName = nil )
			if klassName.nil?
				klassName = klass.name
			end

			@classes[ klassName ] = klass
		end

		def getClassAncestry( className )
			return []
		end

		def getClassDefinition( className )
			return ""
		end

	end
end


#!/usr/bin/ruby
###########################################################################
=begin

=Attribute.rb

== Name

MetaClass::Attribute - An class attribute metaclass

== Synopsis

  locationAttr = MetaClass::Attribute.new( "location", LocationVector )
  nameAttr = MetaClass::Attribute.new( "name", String )

  someClass.addAttributes( locationAttr, nameAttr )

== Description

Instances of this class are used to add attributes to MetaClass::Class objects.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

module MetaClass

	class Attribute < Object

		module Constants
			SCOPE_GLOBAL = 0
			SCOPE_CLASS = 1
			SCOPE_INSTANCE = 2

			SCOPE_DEFAULT = SCOPE_INSTANCE
		end
		include Constants

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: attribute.rb,v 1.2 2001/05/14 12:36:59 deveiant Exp $

		attr_accessor :name, :validTypes, :scope

		### METHOD: initialize( name, validType = Object, scope = SCOPE_DEFAULT )
		def initialize( name, validTypes = nil, scope = SCOPE_DEFAULT )
			unless ( validTypes == nil || validTypes.type === ::Class || validTypes.type == Class ||
					(validTypes.is_a?( Array ) && !validTypes.find {|x| !x.type === ::Class && !x.type == Class}) )
				raise TypeError, "ValidType must be a Class or an array of classes, not a '#{validTypes.type.inspect}'" 
			end
			raise TypeError, "Illegal value for scope." unless
				[ SCOPE_INSTANCE, SCOPE_GLOBAL, SCOPE_CLASS ].find {|k| k == scope}

			@name = name
			@scope = scope
			@validTypes = validTypes.to_a.flatten.compact
		end

		### METHOD: <=>( otherAttribute )
		def <=>( otherAttribute )
			return (
					@scope <=> otherAttribute.scope	||
					@name <=> otherAttribute.name	||
					self.id <=> otherAttribute.id )
		end

	end

end

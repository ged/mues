#!/usr/bin/ruby
###########################################################################
=begin

=Namespace.rb

== Name

Namespace - A namespace metaclass

== Synopsis

  require "metaclass/Namespace"

  ns = MetaClass::Namespace.new( "SomeName" )
  ns.addClass( metaclass )

  eval "#{ns}"

== Description

Instances of this class are convenience objects that allow the definition of
metaclasses to be made in a namespace separate from the main Ruby namespace.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

module MetaClass
	class Namespace < Object

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: namespace.rb,v 1.1 2001/03/15 02:24:22 deveiant Exp $

		attr_accessor :name, :classes

		def initialize( name )
			@name = name
			@classes = []
		end

		def addClasses( *classes )
			@classes.push classes
			@classes.flatten!
		end

		def to_s
			"module #{@name}\n" + @classes.sort.reverse.collect {|k| k.classDefinition(true,true)}.join("\n") + "end"
		end
	end
end

#!/usr/bin/ruby
###########################################################################
=begin

=Classes.rb

== Name

Classes - Metaclass collection module

== Synopsis

  require "metaclass/Classes"

  klass = Metaclass::Class.new( "MyClass" )
  interface = Metaclass::Interface( "Implementable" )
  interface.addClass( klass )

  ...etc.

== Description

This module is just a convenient way of requiring all of the metaclass modules
in one (({require})).

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "metaclass/Association"
require "metaclass/Attribute"
require "metaclass/Class"
require "metaclass/Interface"
require "metaclass/Method"
require "metaclass/Namespace"
require "metaclass/Operation"


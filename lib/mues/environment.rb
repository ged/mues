#!/usr/bin/ruby
###########################################################################
=begin

=World.rb
== Name

World - MUES World object class

== Synopsis

  require "mues/World"
  require "mues/Config"

  worldConf = MUES::Config.new( "world.conf" )
  world = World.new( "testworld", worldConf )
  world.begin( tickNumber )

== Description

This is an abstract factory class for MUES world objects.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"

module MUES
	class World < Object ; implements AbstractClass

		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: environment.rb,v 1.4 2001/06/25 14:09:56 deveiant Exp $


	end
end



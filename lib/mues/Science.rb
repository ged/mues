#!/usr/bin/ruby -w
###########################################################################
=begin

=Science.rb

== Name

Science - Abstract base class for world "science" classes

== Synopsis

  class WorldEconomy < Science
	  def initialize
	  end
  end

== Description

This is an abstract base class for world "science" object classes. World
sciences are world-specific subsystems that either require privileged access to
information or are used as general function groups throughout the world classes.

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
	class Science < Object ; implements AbstractClass

		Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
		Rcsid = %q$Id: Science.rb,v 1.4 2001/06/25 14:09:44 deveiant Exp $

	end
end


#!/usr/bin/ruby
###########################################################################
=begin

=CharacterController.rb

== Name

CharacterController - a character control input filter class

== Synopsis

  require "mues/filters/CharacterController"

== Description

Instances of this class are controller objects which relay commands to and
output from an in-game character.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/filters/IOEventFilter"

module MUES
	class CharacterController < IOEventFilter

		Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
		Rcsid = %q$Id: CharacterController.rb,v 1.2 2001/05/14 12:32:55 deveiant Exp $
		DefaultSortPosition = 850


	end # class CharacterController
end # module MUES


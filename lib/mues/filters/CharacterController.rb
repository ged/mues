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

		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: CharacterController.rb,v 1.1 2001/03/29 02:34:27 deveiant Exp $


	end # class CharacterController
end # module MUES


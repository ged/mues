#!/usr/bin/ruby
###########################################################################
=begin 

= Events.rb

== Name

MUES::Events - a collection of event classes for the MUES Engine

== Synopsis

  require "mues/Events"

  event = MUES::EngineShutdownEvent.new
  eventQueue.priorityEnqueue( event )

== Description

This module is a collection of event classes for system-level events in the
FaerieMUD server. World events are subclasses of MUES::WorldEvent, and are
defined in the game object library.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

== To Do

* Work priority into the class heirarchy so you can optionally pass a priority
  to the constructor of any subclass.

=end

###########################################################################

require "mues/events/BaseClass"
require "mues/events/IOEvents"
require "mues/events/LoginSessionEvents"
require "mues/events/PlayerEvents"
require "mues/events/SystemEvents"
require "mues/events/WorldEvents"





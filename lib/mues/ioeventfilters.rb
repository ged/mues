#!/usr/bin/ruby
###########################################################################
=begin
= IOEventFilters.rb
== Name

MUES::IOEventFilters - Filter classes for MUES::IOEventStream objects.

== Synopsis

  require "mues/IOEventFilters"
  require "mues/IOEventStream"
  require "mues/Events"

  stream = MUES::IOEventStream.new
  soFilter = MUES::SocketOutputFilter( aSocket )
  shFilter = MUES::CommandShell( aPlayerObject )
  snFilter = MUES::SnoopFilter( anIOEventStream )

  stream.addFilters( soFilter, shFilter, snFilter )

== Description

This is a collection module for requiring all the IOEventFilter classes at once.

== Author

Michael Granger E<lt>ged@FaerieMUD.orgE<gt>

Copyright (c) 2000, The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

###########################################################################

require "mues/filters/CharacterController"
require "mues/filters/ClientOutputFilter"
require "mues/filters/CommandShell"
require "mues/filters/DefaultInputFilter"
require "mues/filters/DefaultOutputFilter"
require "mues/filters/IOEventFilter"
require "mues/filters/LoginProxy"
require "mues/filters/MacroFilter"
require "mues/filters/SnoopFilter"
require "mues/filters/SocketOutputFilter"


#!/usr/bin/ruby
#
# This file is a container for expediently loading all of the MUES::IOEventFilter
# classes for MUES::IOEventStream objects.
# 
# == Synopsis
# 
#   require "mues/IOEventFilters"
#   require "mues/IOEventStream"
#   require "mues/Events"
# 
#   stream = MUES::IOEventStream.new
#   soFilter = MUES::SocketOutputFilter( aSocket )
#   shFilter = MUES::CommandShell( aPlayerObject )
#   snFilter = MUES::SnoopFilter( anIOEventStream )
# 
#   stream.addFilters( soFilter, shFilter, snFilter )
# 
# == Rcsid
# 
# $Id: ioeventfilters.rb,v 1.7 2002/09/12 11:36:58 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "mues/filters/IOEventFilter"
require "mues/filters/OutputFilter"
require "mues/filters/InputFilter"
require "mues/filters/DefaultOutputFilter"
require "mues/filters/DefaultInputFilter"

require "mues/filters/ClientOutputFilter"
require "mues/filters/SocketOutputFilter"
require "mues/filters/TelnetOutputFilter"
require "mues/filters/ConsoleOutputFilter"

require "mues/filters/CommandShell"
require "mues/filters/LoginProxy"
require "mues/filters/MacroFilter"
require "mues/filters/SnoopFilter"
require "mues/filters/ParticipantProxy"


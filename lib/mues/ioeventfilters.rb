#!/usr/bin/ruby
#
# This file is a container for expediently loading all of the MUES::IOEventFilter
# classes for MUES::IOEventStream objects.
# 
# == Synopsis
# 
#   require 'mues/ioeventfilters'
#   require 'mues/ioeventstream'
#   require 'mues/events'
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
# $Id: ioeventfilters.rb,v 1.9 2003/10/13 04:02:17 deveiant Exp $
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

require 'mues/filters/ioeventfilter'
require 'mues/filters/outputfilter'
require 'mues/filters/inputfilter'
require 'mues/filters/defaultoutputfilter'
require 'mues/filters/defaultinputfilter'

require 'mues/filters/clientoutputfilter'
require 'mues/filters/socketoutputfilter'
require 'mues/filters/telnetoutputfilter'
require 'mues/filters/consoleoutputfilter'

require 'mues/filters/commandshell'
require 'mues/filters/eventdelegator'
require 'mues/filters/macrofilter'
require 'mues/filters/snoopfilter'
require 'mues/filters/participantproxy'


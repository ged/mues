#!/usr/bin/ruby -w
#
# Log is a log handle class. Creating one will open a filehandle to a specified
# file, and any message sent to it at a level at or above the specified logging
# level will be appended to the file, along with a timestamp and an annotation of
# the level.
# 
# == Synopsis
# 
#   require "mues/Log"
# 
#   log = Log.new( "/tmp/mud.log", "debug" )
#   log.debug( "This log message will show up." )
#   log.level = "info"
#   log.debug( "This one won't." )
#   log.info( "But this one will." )
#   log.close
# 
# == Rcsid
# 
# $Id: log.rb,v 1.5 2002/07/07 18:31:37 deveiant Exp $
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

require 'log4r'
require 'log4r/configurator'

module MUES

	### A log class for MUES systems.
	class Log < Log4r::Logger
		
	end

end #module MUES


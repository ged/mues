#!/usr/bin/ruby -w
#
# This file contains the MUES::Log class, a subclass of Log4r::Logger. It adds
# the 'notice' and 'crit' log levels to Log4r's default levels, and provides some
# class methods for accessing the logging subsystem of the MUES::Engine before
# logging has been set up; all other functionality is delegated to Log4r.
#
# By default, any logs which are written before configuration are sent to
# Log4r's STDERR outputter. To change this behaviour, define a 'MUES' logger
# before anything is logged (ie., before MUES::Engine.start is called). See the
# Synopsis for an example.
#
# Any MUES::Object can also call #log on itself to get a per-class logging
# handle, which can be turned on and off hierarchically with its superclasses,
# and will appear in the logs with its class name prepended.
#
# See the Log4r docs for more about how this works, and how to specify what log
# events go where, and what format they appear in.
# 
# == Synopsis
# 
#   require 'mues'
#   require "mues/Log"
# 
#   logger = MUES::Log.new( 'MUES' )
#	logger.outputters = Log4r::FileOutputter::new( :filename => 'mylog', :trunc => true )
#	logger.level = MUES::Log::INFO
#
#	class MyClass < MUES::Object
#
#		def self.fooMethod
#			MUES::Log.debug( "In server start routine" )
#			MUES::Log.info( "Server is not yet configured." )
#			MUES::Log.notice( "Server is starting up." )
#		end
#
#		def initialize
#			self.log.info( "Initializing another MyClass object." )
#		end
#	end
#
# == Rcsid
# 
# $Id: log.rb,v 1.6 2002/08/01 02:51:36 deveiant Exp $
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

require 'mues'
require 'mues/Config'

require 'log4r'
require 'log4r/logger'
require 'log4r/outputter/outputter'
require 'log4r/formatter/patternformatter'

BEGIN {
	require 'log4r/configurator'
	require 'log4r/logger'

	module MUES
		class Log < Log4r::Logger
			LogLevels = [ :debug, :info, :notice, :warn, :error, :crit, :fatal ]
		end
	end

	# Add more granularity to the default log levels (strangely similar to Apache's
	# levels)
	oldv = $VERBOSE
	$VERBOSE = false
	constantNames = MUES::Log::LogLevels.collect {|sym| sym.to_s.upcase.intern}
	Log4r::Configurator.custom_levels( *constantNames )
	$VERBOSE = oldv
}


module MUES

	### A log class for MUES systems.
	class Log < Log4r::Logger

		include MUES::TypeCheckFunctions

		### Class constants
		# Versioning stuff
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: log.rb,v 1.6 2002/08/01 02:51:36 deveiant Exp $


		### Class methods

		### Set up the logging subsytem with the logging section of the
		### specified config (a MUES::Config object).
		def self.configure( config )
			checkType( config, MUES::Config )

			# Configure the logger with the log4r section of the config file
			Log4r::Configurator::load_xml_string( config.logging.logConfig )

			# Instantiate the base logger level
			self.mueslogger.info( "Logging configured and started." )
		end

		
		### Return the global MUES logger, setting it up if it hasn't been
		### already.
 		def self.mueslogger
			unless self['MUES']
				oldv = $VERBOSE
				$VERBOSE = false
				logger = Log4r::Logger::new( 'MUES' )
				logger.outputters = Log4r::Outputter.stderr
				Log4r::Outputter.stderr.formatter =
					Log4r::PatternFormatter::new( :pattern => '\e[1;32m[%d] [%l] %C:\e[0m %.1024m',
												  :date_pattern => '%Y/%m/%d %H:%M %Z' )
				logger.level = LogLevels.index( :debug )
				$VERBOSE = oldv
			end
			return self['MUES']
		end


		### Autoload global logging methods for the log levels
		def self.method_missing( sym, *args, &block )
			return super( sym, *args ) unless
				LogLevels.include?( sym )

			methodName = sym.to_s
			self.mueslogger.debug( "Autoloading class log method '#{methodName}'." )
			self.instance_eval %{
				def #{methodName}( *args, &block )
					self.mueslogger.#{methodName}( *args, &block )
				end
			}

			self.mueslogger.send( sym, *args, &block )
		end

	end

end #module MUES


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
# $Id: log.rb,v 1.4 2002/04/01 16:27:31 deveiant Exp $
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

require "tempfile"
require "mues"

module MUES

	### A log class for MUES systems.
	class Log < Object

		### Valid logging levels
		@@Levels = {
			"debug"		=> 0,
			"info"		=> 1,
			"notice"	=> 2,
			"error"		=> 3,
			"crit"		=> 4,
			"fatal"		=> 5
		}


		### Create and return a new log object opened to the file specified by
		### +filename+, and set to <tt>initLevel</tt>.
		def initialize( filename=nil, initLevel="debug" )
			super()

			self.level = initLevel
			if filename.is_a?( String ) then
				@fh = File.open( filename, File::CREAT|File::APPEND|File::WRONLY )
			elsif filename.is_a?( IO ) then
				@fh = filename
			else
				@fh = Tempfile.new( "log.$$" )
			end

			return self
		end


		######
		public
		######

		# The current log level
		attr_reader :level

		### Set the log level to <tt>levelName</tt>, which must be one of
		### <tt>'debug'</tt>, <tt>'info'</tt>, <tt>'notice'</tt>, <tt>'error'</tt>,
		### <tt>'crit'</tt>, or <tt>'fatal'</tt>.
		def level=( lvl )
			raise ArgumentError "No such level '#{lvl}'" unless @@Levels.has_key?( lvl )
			@level = @@Levels[ lvl ]
		end


		### Close the log file.
		def close
			@fh.close
		end


		### Return true if the log's filehandle is closed.
		def closed?
			@fh.closed?
		end


		### Handle calls to log level write methods
		def method_missing( sym, *args )
			methName = sym.id2name

			### Call our superclass's method_missing if we don't know how to create
			### the given method
			super unless @@Levels.has_key?( methName )

			### Eval the new method in the context of our class
			self.class.class_eval <<-"end_eval"
			def #{methName}( *methodArgs )
				return nil unless @level <= @@Levels["#{methName}"]
				_write( "#{methName}", methodArgs )
			end
			end_eval
			
			### Get the new method now and call it unless it's non-existant, in
			### which case we raise an exception
			newMethod = method( methName )
			raise RuntimeError, "Method definition failed" if newMethod.nil?
			newMethod.call( args )
		end

		
		#########
		protected
		#########

		### Write a message composed of a timestamp and the joined stringified
		### <tt>*args</tt> to the logfile.
		def _write( level, *args )
			raise LogError, "Cannot write to closed log" if @fh.closed?
			@fh.puts( "[" + Time.now.ctime + "] [#{level}] " + args.collect {|thingie| thingie.to_s}.join('') )
			@fh.flush
		end


	end #class Log

end #module MUES


#!/usr/bin/ruby -w
###########################################################################
=begin

= Log.rb
== Name

Log.rb - A log handle class for the MUES server

== Synopsis

  require "mues/Log"

  log = Log.new( "/tmp/mud.log", "debug" )
  log.debug( "This log message will show up." )
  log.level = "info"
  log.debug( "This one won't." )
  log.info( "But this one will." )
  log.close

== Description

Log is a log handle class. Creating one will open a filehandle to the specified
file, and any message sent to it at a level at or above the specified logging
level will be appended to the file, along with a timestamp and an annotation of
the level.

== Classes
=== MUES::Log

==== Public Methods

--- MUES::Log#close

    Close the log file.

--- MUES::Log#closed?

    Return true if the log^s filehandle is closed.

--- MUES::Log#initialize( filename, level )

    Open the log to the specified file name

--- MUES::Log#level

    Return the current log level

--- MUES::Log#level=( levelName )

    Set the log level to ((|levelName|)), which must be one of
    (({debug})), (({info})), (({notice})), (({error})), (({crit})), or
    (({fatal})).

--- MUES::Log#method_missing( aSymbol, *args )

    Generate log level write methods as they are used.

==== Protected Methods

--- MUES::Log#_write( *args )

    Write a message composed of a timestamp and the joined stringified *args to the logfile

== Author

Michael Granger ((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "tempfile"
require "mues/Namespace"

module MUES

	class Log < Object

		###############################################################################
		###	C L A S S   D A T A
		###############################################################################
		@@Levels = {
			"debug"		=> 0,
			"info"		=> 1,
			"notice"	=> 2,
			"error"		=> 3,
			"crit"		=> 4,
			"fatal"		=> 5
		}

		###############################################################################
		###	P U B L I C   M E T H O D S
		###############################################################################

		### METHOD: initialize( filename, level )
		### Open the log to the specified file name
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


		### METHOD: level
		### Return the current log level
		def level
			return @level
		end


		### METHOD: level=( levelName )
		### Set the log level to ((|levelName|)), which must be one of
		### (({debug})), ({{info})), (({notice})), (({error})), (({crit})), or
		### (({fatal})).
		def level=( lvl )
			raise ArgumentError "No such level '#{lvl}'" unless @@Levels.has_key?( lvl )
			@level = @@Levels[ lvl ]
		end


		### METHOD: close
		### Close the log file.
		def close
			@fh.close
		end


		### METHOD: closed?
		### Return true if the log's filehandle is closed.
		def closed?
			@fh.closed?
		end


		### METHOD: method_missing( aSymbol, *args )
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


		###############################################################################
		###	P R O T E C T E D   M E T H O D S
		###############################################################################
		protected

		### (PROTECTED) METHOD: _write( *args )
		### Write a message composed of a timestamp and the joined stringified *args to the logfile
		def _write( level, *args )
			raise LogError, "Cannot write to closed log" if @fh.closed?
			@fh.puts( "[" + Time.now.ctime + "] [#{level}] " + args.collect {|thingie| thingie.to_s}.join('') )
			@fh.flush
		end

	end #class Log

end #module MUES


#!/usr/bin/ruby
#
# This file contains the MUES::Logger class, a hierarchical logging class for
# the MUES framework. It provides a generalized means of logging from inside
# MUES classes, and then selectively outputting/formatting log messages from
# points within the hierarchy.
#
# A lot of concepts in this class were stolen from Log4r, though it's all
# original code, and works a bit differently.
# 
# == Synopsis
# 
#   require 'MUES/object'
#   require 'MUES/logger'
# 
#   logger = MUES::Logger::global
#	logfile = File::open( "global.log", "a" )
#	logger.outputters += MUES::Logger::Outputter::new(logfile)
#	logger.level = :debug
#
#	class MyClass < MUES::Object
#
#		def self::fooMethod
#			MUES::Logger.debug( "In server start routine" )
#			MUES::Logger.info( "Server is not yet configured." )
#			MUES::Logger.notice( "Server is starting up." )
#		end
#
#		def initialize
#			self.log.info( "Initializing another MyClass object." )
#		end
#	end
#
# == Rcsid
# 
# $Id: logger.rb,v 1.1 2003/11/27 06:02:11 deveiant Exp $
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


module MUES

	### A log class for MUES systems.
	class Logger

		require 'mues/logger/outputter'

		# CVS version tag
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]

		# CVS id tag
		Rcsid = %q$Id: logger.rb,v 1.1 2003/11/27 06:02:11 deveiant Exp $

		# Log levels array (in order of decreasing verbosity)
		Levels = [
			:debug,
			:info,
			:notice,
			:warning,
			:error,
			:crit,
			:alert,
			:emerg,
		].inject({}) {|hsh, sym| hsh[ sym ] = hsh.length; hsh}

		# Constant for debugging the logger - set to true to output internals to
		# $stderr.
		DebugLogger = false


		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		@loggers = {}

		class << self
			# The hierarchy of all MUES::Logger objects.
			attr_reader :loggers
		end


		### Return the MUES::Logger for the given module +mod+, which can be a
		### Module object, a Symbol, or a String.
		def self::[]( mod )
			names = mod.to_s.split( /::/ )
			unless @loggers.key?( names.first )
				@loggers[ names.first ] = new( names.first )
			end
			names.inject( @loggers ) {|logger,key| logger[key]}
		end


		### Return the global MUES logger, setting it up if it hasn't been
		### already.
 		def self::global
			return self[MUES]
		end


		### Configure the logger with the given +config+ (a MUES::Config
		### object).
		def self::configure( config )
			config.logging.each {|logger, cfg|
				if cfg.key?( :level )
					self[ logger ].level = cfg[:level].to_s.intern
				end

				if cfg.key?( :outputters )
					op = []

					case cfg[:outputters]
					when String
						op << Outputter::create( cfg[:outputters] )

					when Hash
						op.replace cfg[:outputters].collect do |kind,args|
							Outputter::create( kind, *args )
						end

					when Array
						op.replace cfg[:outputters].collect do |kind,args|
							Outputter::create( kind, *args )
						end

					else
						raise TypeError,
							"Illegal outputters specification: %p" %
							cfg[:outputters]
					end
				end
			}
		end


		### Autoload global logging methods for the log levels
		def self::method_missing( sym, *args )
			return super unless Levels.key?( sym )

			self.global.debug( "Autoloading class log method '#{sym}'." )
			(class << self; self; end).class_eval {
				define_method( sym ) {|*args|
					self.global.send( sym, *args )
				}
			}

			self.global.send( sym, *args )
		end


		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create and return a new MUES::Logger object with the given +name+
		### at the specified +level+, with the specified +superlogger+. Any
		### +outputters+ that are specified will be added.
		def initialize( name, level=:info, superlogger=nil, *outputters )
			debugMsg "Creating logger for #{name}"
			
			@name = name
			@outputters = outputters
			@subloggers = {}
			@superlogger = superlogger
			@trace = false

			self.level = level
		end


		######
		public
		######

		# The name of this logger
		attr_reader :name

		# The outputters attached to this branch of the logger tree.
		attr_accessor :outputters

		# The logger object that is this logger's parent (if any).
		attr_reader :superlogger

		# The branches of the logging hierarchy that fall below this one.
		attr_accessor :subloggers

		# Set to a true value to turn tracing on
		attr_accessor :trace


		### Return the level of this logger as a Symbol.
		def level
			Levels.invert[ @level ]
		end


		### Set the level of this logger to +level+. The +level+ can be a
		### String, a Symbol, or an Integer.
		def level=( level )
			case level
			when String
				@level = Levels[ level.intern ]
			when Symbol
				@level = Levels[ level ]
			when Integer
				@level = level
			else
				raise ArgumentError, "Illegal level specification: %s" %
					level.class.name
			end
		end


		### Return a uniquified Array of the loggers which are more-generally
		### related hierarchically to the receiver, inclusive.
		def hierloggers
			loggers = [ self ]
			while (( logger = loggers.last.superlogger ))
				loggers.push( logger )
				debugMsg "hierloggers: adding #{logger.name}"
				yield( logger ) if block_given?
			end
			return loggers
		end


		### Return a uniquified Array of all outputters for this logger and all
		### of the loggers above it in the logging hierarchy.
		def hieroutputters
			outputters = @outputters.dup
			if block_given?
				outputters.each {|outputter| yield(outputter)}
			end

			self.hierloggers {|logger|
				outpary = logger.outputters
				newoutpary = outpary - (outpary & outputters)
				debugMsg "hieroutputters: adding outputters: %s" %
					newoutpary.collect {|outp| outp.description}.join(", ")
				if block_given?
					newoutpary.each {|outputter| yield(outputter)}
				end
				outputters += newoutpary
			}

			return outputters
		end


		### Write the given +args+ to any connected outputters. If the first
		### item in +args+ is a String and contains %<char> codes, the message
		### will formed by using the first argument as a format string in
		### +sprintf+ with the remaining items. Otherwise, the message will be
		### formed by catenating the results of calling #formatObject on each of
		### them.
		def write( level, *args )
			msg, frame = nil

			msg = args.collect {|obj| self.stringifyObject(obj)}.join

			# If tracing is turned on, pick the first frame in the stack that
			# isn't in this file, or the last one if that fails to yield one.
			if @trace
				re = Regexp::new( Regexp::quote(__FILE__) + ":\d+:" )
				frame = caller(1).find {|fr| re !~ fr} || caller(1).last
			end

			time = Time::now
			debugMsg "In write for %s - %d hieroutputters..." %
				[ self.name, self.hieroutputters.nitems ]

			# Send the output to each outputter registered for this logger.
			self.hieroutputters {|outp|
				outp.write( time, level, self.name, frame, msg )
			}
		end


		### Return the sublogger for the given module +mod+ (a Module, a String,
		### or a Symbol) under this logger. A new one will instantiated if it
		### does not already exist.
		def []( mod )
			@subloggers[ mod.to_s ] ||=
				self.class.new( @name + "::" + mod.to_s, self.level, self )
		end


		#########
		protected
		#########

		### Dump the given object for output in the log.
		def stringifyObject( obj )
			return case obj
				   when Exception
					   "%s:\n    %s" % [ obj.message, obj.backtrace("\n    ") ]
				   when String
					   obj
				   else
					   obj.inspect
				   end
		end

		### Auto-install logging methods (ie., methods whose names match one of
		### MUES::Logger::Levels.
		def method_missing( id, *args )
			super unless MUES::Logger::Levels.member?( id )

			self.class.class_eval {
				define_method( id ) {|*args|
					return false if !Levels.key?(id) || Levels[	id ] < @level 
					if block_given?
						self.write( id, yield(*args) )
					else
						self.write( id, *args )
					end
				}
			}

			self.send( id, *args )
		end


		#######
		private
		#######

		### Output a debugging message if DebugLogger is true.
		if DebugLogger
			def debugMsg( *parts ) # :nodoc:
				$stderr.puts parts.join('')
			end
		else
			def debugMsg( *parts ); end # :nodoc:
		end



	end # class Logger

end #module MUES

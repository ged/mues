#!/usr/bin/env ruby

require 'mues/mixins'

# A hierarchical logging class for the MUES framework. It provides a
# generalized means of logging from inside MUES classes, and then selectively
# outputting/formatting log messages from points within the hierarchy.
#
# A lot of concepts in this class were stolen from Log4r, though it's all
# original code, and works a bit differently.
#
# == Synopsis
#   
#   require 'mues/logger'
#   require 'mues/mixins'
#   
#   logger = MUES::Logger.global
#   logfile = File.open( "global.log", "a" )
#   logger.outputters << MUES::Logger::Outputter.new( logfile )
#   logger.level = :debug
#
#   class MyClass
#       include MUES::Loggable
#
#       def self::fooMethod
#           MUES::Logger.debug( "In server start routine" )
#           MUES::Logger.info( "Server is not yet configured." )
#           MUES::Logger.notice( "Server is starting up." )
#       end
#
#       def initialize
#           self.log.info( "Initializing another MyClass object." )
#       end
#   end
#
# == Subversion Id
#
#   $Id$
#   
# == Authors
#   
# * Michael Granger <ged@FaerieMUD.org>
#   
# :include: LICENSE
#
#--
#
# Please see the file LICENSE in the BASE directory for licensing details.
#
class MUES::Logger
	require 'mues/logger/outputter'

    include MUES::Configurable
    config_key :logging


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Construct a log levels Hash on the fly
	LEVELS = [
		:debug,
		:info,
		:notice,
		:warning,
		:error,
		:crit,
		:alert,
		:emerg,
	].inject({}) {|hsh, sym| hsh[ sym ] = hsh.length; hsh}
	LEVEL_NAMES = LEVELS.invert

	### Module for adding internals debugging to the Logger class
	module DebugLogger # :nodoc:
		def debug_msg( *parts ) # :nodoc:
			# $deferr.puts parts.join('') if $DEBUG
		end
	end

	include DebugLogger
	extend DebugLogger



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	# Loggers for Modules, keyed by Module
	@logger_map = Hash.new do |h,mod|
		h[ mod ] = self.new( mod )
	end
	class << self; attr_reader :logger_map ; end


    ### Configure logging from the 'logging' section of the config.
    def self::configure( config, dispatcher )

		self.reset
		defaultoutputter = MUES::Logger::Outputter.create( 'file:stderr' )

		config.each do |klass, setting|
			level, uri = self.parse_log_setting( setting )

			# Use the Apache log as the outputter if none is configured
			if uri.nil?
				outputter = defaultoutputter
			else
				outputter = MUES::Logger::Outputter.create( uri )
			end

			# The 'global' entry configures the global logger
			if klass == :global
				self.global.level = level
				self.global.outputters << outputter
				next
			end

			# If the class bit is something like 'applet', then transform
			# it into 'MUES::Applet'
			if klass.to_s.match( /^[a-z][a-zA-Z]+$/ )
				realclass = "MUES::%s" % klass.to_s.sub(/^([a-z])/){ $1.upcase }
			else
				realclass = klass.to_s
			end

			MUES::Logger[ realclass ].level = level
			MUES::Logger[ realclass ].outputters << outputter
		end

    end


	### Parse the configuration for a given class's logger. The configuration
	### is in the form:
	###   <level> [<outputter_uri>]
	### where +level+ is one of the logging levels defined by this class (see
	### the LEVELS constant), and the optional +outputter_uri+ indicates which
	### outputter to use, and how it should be configured. See 
	### MUES::Logger::Outputter for more info.
	###
	### Examples:
	###   notice
	###   debug file:///tmp/broker-debug.log
	###   error dbi://www:password@localhost/www.errorlog?driver=postgresql
	###
	def self::parse_log_setting( setting )
		level, rawuri = setting.split( ' ', 2 )
		uri = rawuri.nil? ? nil : URI.parse( rawuri )

		return level.to_sym, uri
	end


	### Return the MUES::Logger for the given module +mod+, which can be a
	### Module object, a Symbol, or a String.
	def self::[]( mod=nil )
		return self.global if mod.nil?

		case mod
		when Module
			return self.logger_map[ mod ]

		# If it's a String, try to map it to a class name, falling back on the global
		# logger if that fails
		when String
			mod = mod.split('::').
				inject( Object ) {|k, modname| k.const_get(modname) } rescue Object
			return self.logger_map[ mod ]
		else

			return self.logger_map[ mod.class ]
		end

	end


	### Return the global MUES logger, setting it up if it hasn't been
	### already.
	def self::global
		self.logger_map[ Object ]
	end


	### Reset the logging subsystem. Clears out any registered loggers and 
	### their associated outputters.
	def self::reset
		self.logger_map.clear
	end


	### Autoload global logging methods for the log levels
	def self::method_missing( sym, *args )
		return super unless LEVELS.key?( sym )

		self.global.debug( "Autoloading class log method '#{sym}'." )
		(class << self; self; end).class_eval do
			define_method( sym ) do |*args|
				self.global.send( sym, *args )
			end
		end

		self.global.send( sym, *args )
	end


	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create and return a new MUES::Logger object for the given +mod+ (a Module object). If
	### It will be configured at the given +level+. Any +outputters+ that are specified will be 
	### added.
	def initialize( mod, level=:info, *outputters )
		@module     = mod
		@outputters = outputters
		@trace      = false
		@level      = nil

		# Cached Array of modules and classes between 
		# this logger's module and Object
		@supermods  = nil

		# Level to force messages written to this logger to
		@forced_level = nil

		self.level  = level
	end


	######
	public
	######

	# The module this logger is associated with
	attr_reader :module

	# The outputters attached to this branch of the logger tree.
	attr_accessor :outputters

	# Set to a true value to turn tracing on
	attr_accessor :trace

	# The integer level of the logger.
	attr_reader :level

	# The level to force messages written to this logger to
	attr_accessor :forced_level


	### Return a human-readable string representation of the object.
	def inspect
		"#<%s:0x%0x %s [level: %s, outputters: %d, trace: %s]>" % [
			self.class.name,
			self.object_id * 2,
			self.readable_name,
			self.readable_level,
			self.outputters.length,
			self.trace ? "on" : "off",
		]
	end


	### Return a (more-detailed) human-readable string representation of the object.
	def inspect_details( level=0 )
		indent = '  ' * (level + 1)

		prelude = "<< %s [level: %s, trace: %s] >>" % [
			self.readable_name,
			self.readable_level,
			self.trace ? "on" : "off",
		  ]

		details = []
		unless self.outputters.empty?
			details << "Outputters:" << self.outputters.map {|op| op.inspect }
		end
		details = details.flatten.compact.map {|line| indent + line }

		if level.zero?
			return [ prelude, *details ].join( "\n" )
		else
			return [ prelude, *details ]
		end
	end


	### Return the name of the logger formatted to be suitable for reading.
	def readable_name
		return '(global)' if self.module == Object
		return self.module.inspect if self.module.name.nil?
		return self.module.name
	end


	### Return the logger's level as a Symbol.
	def readable_level
		return LEVEL_NAMES[ @level ]
	end


	### Set the level of this logger to +level+. The +level+ can be a
	### String, a Symbol, or an Integer.
	def level=( level )
		# debug_msg ">>> Setting log level for %s to %p" %
			# [ self.name.empty? ? "[Global]" : self.name, level ]

		case level
		when String
			@level = LEVELS[ level.to_sym ]
		when Symbol
			@level = LEVELS[ level ]
		when Integer
			@level = level
		else
			@level = nil
		end

		# If the level wasn't set correctly, raise an error after setting
		# the level to something reasonable.
		if @level.nil?
			@level = LEVELS[ :notice ]
			raise ArgumentError, "Illegal log level specification: %p for %s" %
				[ level, self.readable_name ]
		end
	end


	### Return the MUES::Logger for this instance's module's parent class if it's a Class, 
	### and the global logger otherwise.
	def superlogger
		if @module == Object
			return nil
		elsif @module.respond_to?( :superclass )
			MUES::Logger[ @module.superclass ]
		else
			MUES::Logger.global
		end
	end


	### Return the Array of modules and classes the receiver's module includes 
	### or inherits, inclusive of the receiver's module itself.
	def supermods
		unless @supermods
			objflag = false
			@supermods = self.module.ancestors.partition {|mod| objflag ||= (mod == Object) }.last
			@supermods << Object
		end

		return @supermods
	end



	### Return a uniquified Array of the loggers which are more-generally related 
	### hierarchically to the receiver, inclusive, and whose level is +level+ or 
	### lower.
	def hierloggers( level=:emerg )
		level = LEVELS[ level ] if level.is_a?( Symbol )

		loggers = []
		self.supermods.each do |mod|
			logger = self.class.logger_map[ mod ]
			next unless logger.level <= level

			loggers << logger
			yield( logger ) if block_given?
		end

		return loggers
	end


	### Return a uniquified Array of all outputters for this logger and all of the 
	### loggers above it in the logging hierarchy that are set to +level+ or lower. 
	### If called with a block, it will be called once for each outputter and the first 
	### logger to which it is attached.
	def hieroutputters( level=LEVELS[:emerg] )
		outputters = []

		# Look for loggers which are higher in the hierarchy
		self.hierloggers( level ) do |logger|
			outpary = logger.outputters || []
			newoutpary = outpary - (outpary & outputters)

			# If there are any outputters which haven't already been seen,
			# output to them.
			unless newoutpary.empty?
				# debug_msg "hieroutputters: adding: %s" %
					# newoutpary.collect {|outp| outp.description}.join(", ")
				if block_given?
					newoutpary.each {|outputter| yield(outputter, logger)}
				end
				outputters += newoutpary
			end
		end

		return outputters
	end


	### Write the given +args+ to any connected outputters if +level+ is
	### less than or equal to this logger's level.
	def write( level, *args )
		# debug_msg "Writing message at %p from %s: %p" % [ level, caller(2).first, args ]

		msg, frame = nil, nil
		time = Time.now

		# If tracing is turned on, pick the first frame in the stack that
		# isn't in this file, or the last one if that fails to yield one.
		if @trace
			frame = caller(1).find {|fr| fr !~ %r{mues/logger\.rb} } ||
			 	caller(1).last
		end

		level = @forced_level if @forced_level

		# Find the outputters that need to be written to, then write to them.
		self.hieroutputters( level ) do |outp, logger|
			# debug_msg "Got outputter %p" % outp
			msg ||= args.collect {|obj| self.stringify_object(obj) }.join
			outp.write( time, level, self.readable_name, frame, msg )
		end
	end


	### Append the given +obj+ to the logger at +:debug+ level. This is for 
	### compatibility with objects that append to $stderr for their logging
	### (e.g., net/protocols-based libraries).
	def <<( obj )
		self.write( :debug, obj )
		return self
	end


	#########
	protected
	#########

	### Dump the given object for output in the log.
	def stringify_object( obj )
		return case obj
			   when Exception
				   "%s:\n    %s" % [ obj.message, obj.backtrace.join("\n    ") ]
			   when String
				   obj
			   else
				   obj.inspect
			   end
	end


	### Auto-install logging methods (ie., methods whose names match one of
	### MUES::Logger::LEVELS.
	def method_missing( sym, *args )
		name = sym.to_s
		level = name[/\w+/].to_sym
		return super unless MUES::Logger::LEVELS.member?( level )
		code = nil

		case name
		when /^\w+\?/
			code = self.make_level_predicate_method( level )

		when /^\w+$/
			code = self.make_writer_method( level )

		else
			return super
		end

		self.class.send( :define_method, sym, &code )
		return self.method( sym ).call( *args )
	end


	### Return a Proc suitable for installing as a predicate method for the given 
	### logging level.
	def make_level_predicate_method( level )
		numeric_level = LEVELS[level]
		Proc.new { self.level < numeric_level }
	end


	### Return a Proc suitable for installing as a log-writing method for the given
	### logging level.
	def make_writer_method( level )
		Proc.new {|*args| self.write(level, *args)}
	end

end # class MUES::Logger


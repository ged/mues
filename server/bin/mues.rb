#!/usr/bin/ruby
#
# This is a simple MUES startup script. It takes one optional argument: the path
# to a configuration file.
#
# == Synopsis
#
#   $ mues.rb [configfile]
#
# == Subversion ID
# 
# $Id$
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

# Set the include path and config file based on where this file is executing
BEGIN {
	srvDir = File::dirname( File::expand_path(File::dirname( $0 )) )
	baseDir = File::dirname( srvDir )

	libDir = File::join( baseDir, "lib" )
	unless $LOAD_PATH.include?( libDir )
		$deferr.puts "Adding #{libDir} to $LOAD_PATH..." if $DEBUG
		$LOAD_PATH.unshift( libDir )
	end

	extDir = File::join( baseDir, "ext" )
	unless $LOAD_PATH.include?( extDir )
		$deferr.puts "Adding #{extDir} to $LOAD_PATH..." if $DEBUG
		$LOAD_PATH.unshift( extDir )
	end
}


require 'optparse'

require "mues"
require "mues/logger"


def debugMsg( *args )
	return unless $DEBUG
	$deferr.puts args.join
end


### Main function
def main

	# Initial option values
	fork = false
	loglevel = "info"
	initmode = false
	debugLevel = 0
	loadLibraries = []

	# Read command-line options
	ARGV.options do |oparser|
		debugMsg "oparser is: %p" % oparser
		oparser.banner = "Usage: #$0 [OPTIONS] CONFIGFILE"

		# Debugging output
		oparser.on( "--debug", "-d", TrueClass, "Turn debugging on" ) {|*args|
			debugMsg "Inside an #on, args are: %p" % args
			$DEBUG = true
			debugMsg "Turned debugging on."

			debugLevel += 1
			debugMsg "Engine debug level is now: %d" % debugLevel
		}

		# Verbose output
		oparser.on( "--verbose", "-v", TrueClass, "Make progress verbose" ) {
			$VERBOSE = true
			debugMsg "Turned verbose on."
		}

		# Fork the server
		oparser.on( '--fork', '-f', TrueClass, 'Fork and detach after starting' ) {
			fork = true
			debugMsg "Turned forking on"
		}

		# Handle the 'help' option
		oparser.on( "--help", "-h", "Display this text." ) {
			$stderr.puts oparser
			exit!(0)
		}

		# Set the global logging level
		levels = MUES::Logger::Levels.
			sort {|a,b| a[1] <=> b[1]}.
			collect {|pair| pair[0]}.
			join(", ")
		oparser.on( '--loglevel=LEVEL', '-l', String, "Logging level (one of #{levels})" ) {|arg|
			unless MUES::Logger::Levels.include?( arg.intern )
				$deferr.puts "ERR: Log level must be one of %s, not '%s'" % [ levels, arg ]
				exit( 1 )
			end

			MUES::Logger.global.level = arg
		}

		# Log to console
		oparser.on( '--console', '-c', FalseClass, "Output the global log to the console" ) {
			if fork
				$deferr.puts "ERR: cannot --fork is mutually exclusive with --console logging"
				exit( 1 )
			end

			MUES::Logger.global.outputters << MUES::Logger::Outputter.create( 'file', $deferr )
		}

		# Start the server in init mode
		oparser.on( '--init', '-i', FalseClass, "Init mode" ) {
			initmode = true
			puts "Will start the server in 'init' mode."
		}

		# Load an extra module or two
		oparser.on( '--load=MODULE', String, "Load an auxilliary library before starting" ) {|arg|
			require( arg )
		}

		oparser.parse!
	end

	configFile = ARGV.shift

	# Instantiate the configuration object, aborting if we can't find it
	begin
		config = if configFile 
					 MUES::Config::load( configFile )
				 else
					 MUES::Config::new
				 end
		config.engine.debugLevel = debugLevel
	rescue Errno::ENOENT
		$stderr.puts( "Cannot find config file '#{configFile}'.\nPlease double-check the path and try again." )
		exit 1
	end

	# Instantiate the server object
	engine = MUES::Engine::instance

	# Start up and run the server as a daemon
	if fork
		puts "Starting the MUES server in the background...\n"

		# Fork into the background
		daemonize( config )
	else
		puts "Starting the MUES server in the foreground...\n"
	end

	engine.start( config, initmode )
end


### Become a daemon process
def daemonize( config )

	raise RuntimeError, "Sorry... forking doesn't forking work yet. =:)"

	# First fork (parent exits)
	if Process.fork 
		$stderr.puts "Parent exiting."
		exit!(0)
	end

	# Become session leader
	$stderr.puts "First child becoming session leader."
	Process.setsid

	# Second fork (first child exits)
	if Process.fork
		$stderr.puts "First child exiting."
		exit!(0)
	end

	# Set CWD to the root dir and set umask
	Dir.chdir( "/" )
	File.umask( 0 )

	# Close STDIN and STDOUT and reopen them to /dev/null
	File.open( "/dev/null", File::TRUNC|File::RDWR ) {|devnull|
		$stdin.close	&& $stdin.reopen( devnull )
		$stdout.close	&& $stdout.reopen( devnull )
		$stderr.close	&& $stderr.reopen( debuglog )
	}

	return true
end


main

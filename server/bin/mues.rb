#!/usr/bin/ruby
#
# This is a simple MUES startup script. It takes one optional argument: the path
# to a configuration file.
#
# == Synopsis
#
#   $ mues.rb [configfile]
#
# == Rcsid
# 
# $Id: mues.rb,v 1.9 2002/09/12 12:45:19 deveiant Exp $
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

require "getoptlong"

Options = [
	[ "--fork",		"-f",		GetoptLong::NO_ARGUMENT ],
	[ "--loglevel",	"-l",		GetoptLong::REQUIRED_ARGUMENT ],
	[ "--init",		"-i",		GetoptLong::NO_ARGUMENT ],
	[ "--debug",	"-d",		GetoptLong::REQUIRED_ARGUMENT ],
]


### Set the include path and config file based on where we're executing from
baseDir = File::expand_path( File::dirname($0) ).sub( %r{\Wbin$}, '' )
libDir = File::join( baseDir, "lib" )

require "mues"


### Main function
def main

	# Initial option values
	fork = false
	loglevel = "info"
	initmode = false
	debugLevel = 0

	# Read command-line options
	opts = GetoptLong::new( *Options )
	opts.each do |opt, arg|
		case opt

		when '--fork'
			fork = true

		when '--loglevel'
			raise "Log level must be one of "+
				MUES::Log::LogLevels.collect {|ll| ll.to_s}.join(', ') +
				", no '#{arg}'" unless MUES::Log::LogLevels.include?( arg.intern )
			loglevel = arg

		when '--init'
			initmode = true
			puts "Will start the server in 'init' mode."

		when '--debug'
			debugLevel = arg.to_i

		else
			MUES::Log.error( "No such option '#{opt}'" )
		end
			
	end

	configFile = ARGV.shift

	# Instantiate the configuration object, aborting if we can't find it
	begin
		config = if configFile 
					 MUES::Config::new( configFile )
				 else
					 MUES::Config::new
				 end
	rescue Errno::ENOENT
		$stderr.puts( "Cannot find config file '#{configFile}'.\nPlease double-check the path and try again." )
		exit 1
	end

	# Instantiate the server object
	engine = MUES::Engine::instance
	engine.debugLevel = debugLevel

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

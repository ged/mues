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
# $Id: mues.rb,v 1.8 2002/04/01 16:29:13 deveiant Exp $
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


### Set the include path and config file based on where we're executing from
if $0 =~ /server#{File::Separator}bin#{File::Separator}/
	baseDir = $0.gsub( /server#{File::Separator}bin#{File::Separator}.*/, '' )
	baseDir = '.' if baseDir.empty?
	$: << File.join( baseDir, "lib" )
	DefaultConfigFile = File.join( baseDir, "MUES.cfg" )
elsif $0 =~ /#{File::Separator}bin#{File::Separator}/
	baseDir = $0.gsub( /#{File::Separator}bin#{File::Separator}.*/, '' )
	baseDir = '.' if baseDir.empty?
	DefaultConfigFile = File.join( baseDir, "MUES.cfg" )
else
	DefaultConfigFile = "MUES.cfg"
end


require "mues"


### Main function
def main

	configFile = ARGV.shift || DefaultConfigFile

	# Instantiate the configuration object, aborting if we can't find it
	begin
		config = MUES::Config.new( configFile )
	rescue Errno::ENOENT
		$stderr.puts( "Cannot find config file '#{configFile}'.\nPlease double-check the path and try again." )
		exit 1
	end

	# Instantiate the server object
	engine = MUES::Engine.instance
	engine.debugLevel = config['engine']['debuglevel']

	# Start up and run the server as a daemon
	if config['startasdaemon']
		puts "Starting the MUES server in the background...\n"

		# Fully-qualify the root dir while we still have a cwd
		config['rootdir'] = File.expand_path( config['rootdir'] )

		# Fork into the background
		daemonize( config )
	else
		puts "Starting the MUES server in the foreground...\n"
	end

	engine.start( config )
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
	}

	# Close STDERR and reopen it to a debug log in the root directory
	File.open( File.join(config['rootdir'],'MUES.debug'), File::TRUNC|File::WRONLY|File::CREAT ) {|debuglog|
		$stderr.close && $stderr.reopen( debuglog )
	}

	return true
end


main

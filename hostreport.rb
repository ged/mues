#!/usr/bin/ruby
# 
# Build and output a report of the machine the program is running on, including
# versions of relevant modules/classes. This is useful to help us narrow down
# the problem when reporting bugs and diagnosing problems.
# 
# == Synopsis
# 
#   $ hostreport [OPTIONS]
#
# === Options
#
# [-o, --output=filename]
#	Save the report to the specified file. By default, output goes to STDOUT.
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
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

base = File::dirname( __FILE__ )
$LOAD_PATH.unshift "#{base}/lib", "#{base}/ext"

require "#{base}/utils.rb"
include UtilityFunctions

require 'rbconfig'
include Config

require 'getoptlong'
Options = [
	[ "--output",	"-o",		GetoptLong::REQUIRED_ARGUMENT ],
]

require 'mues'
require 'mues/listeners/TelnetListener'
require 'mues/listeners/SocketListener'
require 'mues/listeners/ConsoleListener'
include MUES


VersionClasses = []
ObjectSpace.each_object( Class ) {|c|
	next unless c <= MUES::Object
	next if c < MUES::Event || c < ::Exception
	next if c.name =~ /(?:CommandShell|Config)::/

	VersionClasses.push( c )
}

DependClasses = {
	'HashSlice' => {}.methods.include?("__bracketBracket__"),
	'Poll'		=> Poll::Version,
	'REXML'		=> REXML::Version,
	'Log4r'		=> Log4r::Log4rVersion,
}
	
	

def main
	# Defaults
	output = $defout

	opts = GetoptLong::new( *Options )
	opts.each do |opt, arg|
		case opt

		when '--output'
			if File::exists?( arg )
				answer = promptWithDefault( "File '#{arg}' exists. Overwrite?", "n" )
				abort( "Not overwriting '#{arg}'." ) unless answer =~ /^y/i
			end
			output = File::open( arg, File::WRONLY|File::CREAT )

		when '--verbose'
			$VERBOSE = true

		else
			MUES::Log.error( "No such option '#{opt}'" )
		end
		
	end


	header "Generating host report..."

	# Header
	output << "Host report for %s" % hostname() << "\n" <<
		"Built for %s on %s." % [username(), Time::now.to_s] << "\n" <<
		("-" * 72) << "\n"

	# Ruby info
	output <<  ">> Ruby\n\n" <<
		"Ruby interpreter is: %s" % File::join( CONFIG['bindir'], CONFIG['ruby_install_name'] ) << "\n" <<
		"Version: ruby %s (%s) [%s]" % [RUBY_VERSION, RUBY_RELEASE_DATE, RUBY_PLATFORM] << "\n" <<
		"Config: %s\n" % CONFIG['configure_args'] << "\n\n"

	# MUES info
	output << ">> MUES Library\n\n" <<
		versions( *VersionClasses ) << "\n"

	# Dependency info
	output << ">> Dependencies\n\n" <<
		dependencies( DependClasses ) << "\n\n"
		
end



### Utility functions

def hostname
	rval = `hostname`.chomp
	return rval.empty? ? "(unknown)" : rval
end

def username

	# This could be much more platform-aware, but I don't have any other
	# platforms to test on, so...
	if RUBY_PLATFORM =~ /win32/
		ENV['USERNAME']
	else
		require 'etc'
		Etc::getpwuid.name
	end
end

def versions( *classes )
	classes.
		sort    {|a,b| a.name <=> b.name }.
		collect {|c| "  %s: %s\n" % [ c.name, c.version.to_s ] }
end

def dependencies( modules )
	modules.collect {|name, version|
		"  %s: %s\n" % [ name, version.to_s ]
	}
end

main


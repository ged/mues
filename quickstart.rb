#!/usr/bin/env ruby
#
#	MUES Quickstart Script
#	$Id: quickstart.rb,v 1.10 2003/09/12 04:16:55 deveiant Exp $
#
#	Copyright (c) 2001-2003, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require 'rbconfig'
require 'ftools'
require "./utils.rb"

include Config
include UtilityFunctions

# Set interrupt handler to restore tty before exiting
stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }

$Ruby = File::join( CONFIG["bindir"], CONFIG["ruby_install_name"] )

# Define required libraries
RequiredLibraries = [
	# libraryname, nice name, RAA URL, Download URL
	[ 'io/reactor', "IO-Reactor", 
		'http://raa.ruby-lang.org/list.rhtml?name=IO-Reactor',
		'http://www.devEiate.org/code/IO-Reactor-0.05.tar.gz' ],
	[ 'rexml/document', 'REXML',
		'http://raa.ruby-lang.org/list.rhtml?name=REXML',
		'http://www.germane-software.com/archives/rexml_2.5.2.tgz' ],
	[ 'forwardable', "Forwardable",
		'http://raa.ruby-lang.org/list.rhtml?name=forwardable',
		'ftp://ftp.ruby-lang.org/pub/ruby/contrib/forwardable-1.1.tgz' ],
	[ 'hashslice', "HashSlice",
		'http://raa.ruby-lang.org/list.rhtml?name=HashSlice',
		'http://www.deveiate.org/code/Ruby-HashSlice-1.03.tar.bz2' ],
	[ 'pp', 'PrettyPrinter',
		'http://raa.ruby-lang.org/list.rhtml?name=pp',
		'http://cvs.m17n.org/~akr/pp/download.html' ],
	[ 'log4r', 'Log4R',
		'http://raa.ruby-lang.org/list.rhtml?name=log4r',
		'http://prdownloads.sourceforge.net/log4r/log4r-1.0.4.tgz?download' ],

]


### Main function
def main
	header "MUES Quickstart Script"

	$LOAD_PATH.unshift "ext", "lib"

	for lib in RequiredLibraries
		testForRequiredLibrary( *lib )
	end

	unless File::exists?( "ext/mues.so" )
		message "Building C extensions...\n"
		begin
			Dir::chdir( "ext" ) {
				load( "extconf.rb", true )
				system( "make" )
			}
		rescue => e
			abort "Build failed. Please check your environment or try \n"\
			      "building the extensions in ext/ by hand. \n"\
			      "Error => %s\n\t%s\n\n" %
				[ e.message, e.backtrace.join("\n\t") ]
		end
	end

	unless File::exists?( "server/config.xml" )
		message "Copying example minimal config to config.xml..."
		File.copy( "server/minimal-config.xml", "server/config.xml", true )
		message "done.\n"

		if promptWithDefault( "Edit the configuration? (highly recommended) [Yn]", 'y' ) =~ /y/i
			editor = ENV['EDITOR'] || ENV['VISUAL'] || findProgram( 'emacs' ) || findProgram( 'vi' ) || ''
			editor = promptWithDefault( "Editor to use for editing config file? [#{editor}]", editor )
			message "Invoking editor: #{editor} server/config.xml\n"
			system( editor, "server/config.xml" ) or abort( "Editor session failed: #{$?}" )
		end
	end

	unless File::directory?( "server/log" )
		message "Creating server directories in ./server..."
		File::mkpath( "server/log" )
	end

	print "\n\n"

	writeLine( 55 )
	message "The server will start in 'init' mode; You can log in\n"\
		    "with 'admin' as the username and an empty password (just\n"\
            "hit enter).\n"
	writeLine( 55 )

	message ">>> Starting server...\n\n"

	exec( $Ruby, "-I", "lib", "-I", "ext", "server/bin/mues.rb", '--init', "server/config.xml", *ARGV )

end

main	




#!/usr/bin/ruby
#
#	MUES Quickstart Script
#	$Id: quickstart.rb,v 1.2 2001/11/01 19:51:04 deveiant Exp $
#
#	Copyright (c) 2001, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require 'ftools'
require "./utils.rb"

include UtilityFunctions

# Set interrupt handler to restore tty before exiting
stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }

# Define required libraries
RequiredLibraries = [
	# libraryname, nice name, RAA URL, Download URL
	[ 'pp', "Ruby Pretty-Printing", 
		'http://www.ruby-lang.org/en/raa-list.rhtml?name=pp',
		'http://cvs.m17n.org/~akr/pp/download.html' ]
]


### Main function
def main
	header "MUES Quickstart Script"

	for lib in RequiredLibraries
		testForRequiredLibrary( *lib )
	end

	unless FileTest.exists?( "server/MUES.cfg" )
		message "Copying example config to MUES.cfg..."
		File.copy( "server/MUES.cfg.example", "server/MUES.cfg", true )
		message "done.\n"
	end

	if promptWithDefault( "Edit the configuration? (highly recommended) [Yn]", 'y' ) =~ /y/i
		editor = ENV['EDITOR'] || ENV['VISUAL'] || findProgram( 'emacs' ) || findProgram( 'vi' ) || ''
		editor = promptWithDefault( "Editor to use for editing config file? [#{editor}]", editor )
		message "Invoking editor: #{editor} server/MUES.cfg\n"
		system( editor, "server/MUES.cfg" ) or abort( "Editor session failed: #{$?}" )
	end

	if promptWithDefault( "Add a user to the configured objectstore? [Yn]", 'y' ) =~ /y/i
		newUsername = ''
		until newUsername.length >= 3
			newUsername = prompt( "Username" )
			error "Username must be at least 3 characters in length." unless newUsername.length >= 3
		end
		
		require "server/bin/createUser.rb"
		u = UserTool.new
		u.createUser( newUsername, "server/MUES.cfg" )
	end

	message "Starting server..."
	exec( "server/bin/mues.rb", "server/MUES.cfg" )

end

main	




#!/usr/bin/ruby
#
#	MUES Distribution Maker Script
#	$Id: makedist.rb,v 1.1 2001/11/01 15:52:08 deveiant Exp $
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

# Version information
Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
Rcsid = %q$Id: makedist.rb,v 1.1 2001/11/01 15:52:08 deveiant Exp $

# Set interrupt handler to restore tty before exiting
stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }

# Define the manifest of files to include, globs okay
MANIFEST = %w{
  t/**/*
  lib/**/*
  sql/*
  docs/stylesheets/rd.css
  docs/MUES.rd
  docs/makedocs.rb
  docs/TableAdapter.rd
  README
  QUICKSTART
  install.rb
  Artistic
  quickstart.rb
  server/bin/deleteUser.rb
  server/bin/mues.rb
  server/bin/showUser.rb
  server/bin/createUser.rb
  server/environments/*
  server/shellCommands/**/*
  server/MUES.cfg.example
  INSTALL
  utils.rb
}

# The list of regexen that eliminate files from the MANIFEST
ANTIMANIFEST = [
	/makedist\.rb/,
	/\bCVS\b/,
	/~$/,
	/^#/,
	%r{docs/html},
	%r{docs/man},
	/^TEMPLATE/
]

### Main function
def main
	filelist = []

	header "MUES Distribution Maker"

	message "Finding necessary programs...\n"
	tarProg = findProgram( 'tar' ) or abort( "Cannot find the 'tar' program in your path." )
	rmProg = findProgram( 'rm' ) or abort( "Cannot find the 'rm' program in your path." )

	message "Building manifest..."
	for pat in MANIFEST
		filelist |= Dir.glob( pat ).find_all {|f| FileTest.file?(f)}
	end
	origLength = filelist.length
	message "Found #{origLength} files.\n"

	message "Vetting manifest..."
	for regex in ANTIMANIFEST
		$stderr.puts "Pattern /#{regex.source}/ removed: " + filelist.find_all {|file| regex.match(file)}.join(', ')
		filelist.delete_if {|file| regex.match(file)}
	end
	message "removed #{origLength - filelist.length} files.\n"

	#puts "Filelist:\n\t" + filelist.join("\n\t")

	defaultVersion = "%0d.%02d" % Version.split(/\./)
	version = promptWithDefault( "Distribution version [#{defaultVersion}]", defaultVersion )

	distName = "MUES-%s" % version
	archiveName = "%s.tar.gz" % distName
	message "Making distribution directory #{distName}..."
	Dir.mkdir( distName ) unless FileTest.directory?( distName )
	for file in filelist
		File.makedirs( File.dirname(File.join(distName,file)) )
		File.link( file, File.join(distName,file) )
	end
	message "Making tarball #{archiveName}..."
	system( tarProg, '-czf', archiveName, distName ) or abort( "tar failed: #{$?}" )
	message "removing dist build directory..."
	system( rmProg, '-rf', distName )
	message "done.\n\n"
end

main	




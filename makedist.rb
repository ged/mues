#!/usr/bin/ruby
#
#	MUES Distribution Maker Script
#	$Id: makedist.rb,v 1.6 2002/03/30 19:09:08 deveiant Exp $
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
Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
Rcsid = %q$Id: makedist.rb,v 1.6 2002/03/30 19:09:08 deveiant Exp $
ReleaseVersion = 0.01

# Set interrupt handler to restore tty before exiting
stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }

@@Programs = {
	'tar'	=> nil,
	'rm'	=> nil,
	'zip'	=> nil
}

# Define the manifest of files to include, globs okay
MANIFEST = %w{
  Artistic
  ChangeLog
  INSTALL
  QUICKSTART
  README
  docs/MUES.rd
  docs/TableAdapter.rd
  docs/makedocs.rb
  docs/stylesheets/rd.css
  install.rb
  lib/**/*
  quickstart.rb
  server/MUES.cfg.example
  server/bin/createUser.rb
  server/bin/deleteUser.rb
  server/bin/mues.rb
  server/bin/showUser.rb
  server/environments/*
  server/shellCommands/**/*
  sql/*
  t/**/*
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
	/^TEMPLATE/,
	/\.cvsignore/
]

Distros = [

	# Tar+gzipped
	{
		'type'		=> 'Tar+Gzipped',
		'makeProc'	=> Proc.new {|distName|
			gzArchiveName = "%s.tar.gz" % distName
			if FileTest.exists?( gzArchiveName )
				message "Removing old archive #{gzArchiveName}..."
				File.delete( gzArchiveName )
			end
			system( @@Programs['tar'], '-czf', gzArchiveName, distName ) or abort( "tar+gzip failed: #{$?}" )
		}
	},

	# Tar+bzipped
	{
		'type'		=> 'Tar+Bzipped',
		'makeProc'	=> Proc.new {|distName|
			bzArchiveName = "%s.tar.bz2" % distName
			if FileTest.exists?( bzArchiveName )
				message "Removing old archive #{bzArchiveName}..."
				File.delete( bzArchiveName )
			end
			system( @@Programs['tar'], '-cjf', bzArchiveName, distName ) or abort( "tar failed: #{$?}" )
		}
	},

	{
		'type'		=> 'Zipped',
		'makeProc'	=> Proc.new {|distName|
			zipArchiveName = "%s.zip" % distName
			if FileTest.exists?( zipArchiveName )
				message "Removing old archive #{zipArchiveName}..."
				File.delete( zipArchiveName )
			end
			system( @@Programs['zip'], '-lrq9', zipArchiveName, distName ) or abort( "zip failed: #{$?}" )
		}
	},
]


### Main function
def main
	filelist = []

	header "MUES Distribution Maker"

	message "Finding necessary programs...\n"
	for prog in @@Programs.keys
		message "  #{prog}: "
		@@Programs[ prog ] = findProgram( prog )
		message( (@@Programs[prog] || '(not found)') + "\n" )
	end

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

	version = promptWithDefault( "Distribution version [#{ReleaseVersion}]", ReleaseVersion )
	distName = "MUES-%s" % version

	message "Making distribution directory #{distName}..."
	Dir.mkdir( distName ) unless FileTest.directory?( distName )
	for file in filelist
		File.makedirs( File.dirname(File.join(distName,file)) )
		File.link( file, File.join(distName,file) )
	end

	for distro in Distros
		message "Making #{distro['type']} distribution..."
		distro['makeProc'].call( distName )
		message "done.\n"
	end

	if @@Programs['rm']
		message "removing dist build directory..."
		system( @@Programs['rm'], '-rf', distName )
		message "done.\n\n"
	else
		message "Cannot clean dist build directory: no 'rm' program was found."
	end
end

main	




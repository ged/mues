#!/usr/bin/ruby
# 
# This is a fix for the change in the directory layout that moved lib/metaclass
# under the lib/mues directory.
# 
#

$LOAD_PATH.unshift '.'

require 'fileutils'
require 'utils'
include UtilityFunctions

# Find program paths
$programs = {
	:cvs	=> findProgram( 'cvs' ),
	:diff	=> findProgram( 'diff' ),
	:patch	=> findProgram( 'patch' ),
	:pager	=> ENV.key?( 'PAGER' ) ? findProgram( ENV['PAGER'] ) : findProgram('less'),
}


def main
	header "Metaclass Reparenting Fixup Script"

	message "Checking for old layout..."
	unless File.directory?( "lib/mues/metaclass" )
		message "yep.\n"
	else
		message "you appear to already have this fix applied.\n"
		answer = promptWithDefault( "Try to apply anyway?", "n" )
		exit unless answer =~ /^y/i
	end

	message "Updating CVS files..."
	editInPlace( "lib/CVS/Entries" ) {|line|
		line =~ %r{metaclass} ? "" : line
	}
	editInPlace( "tests/CVS/Entries" ) {|line|
		line =~ %r{metaclass} ? "" : line
	}

	message "Updating lib/ from CVS...\n"
	system( $programs[:cvs], 'update', '-dP', 'lib/mues/metaclass', 'lib/mues/Metaclasses.rb' )

	message "Updating tests/ from CVS...\n"
	system( $programs[:cvs], 'update', '-dP', 'tests/mues/metaclass' )

	[
		['lib/metaclass', 'lib/mues/metaclass'],
		['lib/metaclasses.rb', 'lib/mues/Metaclasses.rb'],
		['tests/metaclass', 'tests/mues/metaclass' ],
	].each {|pair| offerPatch( *pair ) }

	answer = promptWithDefault( "Remove old sources?", "n" )
	if answer =~ /^y/i
		FileUtils::rm_rf( ["lib/metaclass","lib/metaclasses.rb","tests/metaclass"], :verbose )
	end

	message "Done."
end


### Offer to propagate changes from old to new (either of which may be a file or
### directory) if any changes exist.
def offerPatch( old, new )
	patch = nil

	if File.directory?( old )
		raise "Cannot patch a directory '%s' against a %s" %
			[ old, File::ftype(new) ] unless File.directory?( new )
		patch = shellCommand( $programs[:diff], '-ubrN', '-x', 'CVS', new, old )
	elsif File.file?( old )
		raise "Cannot patch a file '%s' against a %s'" %
			[ old, File::ftype(new) ] unless File.file?( new )
		patch = shellCommand( $programs[:diff], '-ub', %q:-I'\$\(Id\|Revision\|Log\)':, new, old )
	else
		raise "I don't know how to patch a %s against a %s" % [ File::ftype(old), File::ftype(new) ]
	end

	unless patch.empty?
		message "There are changes in %s that are not in %s\n" % [ old, new ]
		answer = promptWithDefault( "Do you wish to see them?", 'y' )

		if answer =~ /^y/i
			IO::popen( $programs[:pager], "w" ) {|fh|
				fh.puts ">>> This diff shows changes to %s that were "\
					"not in the CVS version of %s. <<<\n\n" % [ old, new ]
				fh.puts patch
			}
		end

		answer = promptWithDefault( "Would you like to apply the changes to #{new}?", "y" )
		
		if answer =~ /^y/i
			targetDir = '.'
			targetDepth = new.scan( %r:/(?=.): ).length

			if File.directory?( new )
				targetDir = new
			elsif File.file?(new) && %r:(.*)/:.match(new)
				targetDir = $1
			end

			Dir::chdir( targetDir ) {
				patchCmd = "%s -Np%d" % [$programs[:patch], targetDepth]
				message "Patching with: '%s' from %s..." % [ patchCmd, targetDir ]
				patchPipe = IO::popen( patchCmd, "w" )
				patchPipe.sync = true
				patchPipe.print( patch )
				message "done.\n"
			}

			$stdout.flush
			$stderr.flush
		end
	end
end


main

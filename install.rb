#!/usr/bin/ruby
#
#	MUES Install Script
#	$Id$
#
#	Thanks to Masatoshi SEKI for ideas found in his install.rb.
#
#	Copyright (c) 2001, 2002, 2003, 2004, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require './utils.rb'
include UtilityFunctions

require 'rbconfig'
require 'find'
require 'ftools'

include Config

$version	= %q$Rev$
$rcsId		= %q$Id$

stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }

# Define required libraries
RequiredLibraries = [
	# libraryname, nice name, RAA URL, Download URL
	[ 'io/reactor', "IO-Reactor", 
		'http://raa.ruby-lang.org/list.rhtml?name=IO-Reactor',
		'http://www.devEiate.org/code/IO-Reactor-0.05.tar.gz' ],
	[ 'pluginfactory', "PluginFactory", 
		'http://raa.ruby-lang.org/list.rhtml?name=pluginfactory',
		'http://www.devEiate.org/code/PluginFactory-0.01.tar.gz' ],
	[ 'forwardable', "Forwardable",
		'http://raa.ruby-lang.org/list.rhtml?name=forwardable',
		'ftp://ftp.ruby-lang.org/pub/ruby/contrib/forwardable-1.1.tgz' ],
	[ 'hashslice', "HashSlice",
		'http://raa.ruby-lang.org/list.rhtml?name=HashSlice',
		'http://www.deveiate.org/code/Ruby-HashSlice-1.03.tar.bz2' ],
	[ 'pp', 'PrettyPrinter',
		'http://raa.ruby-lang.org/list.rhtml?name=pp',
		'http://cvs.m17n.org/~akr/pp/download.html' ],
]

class Installer

	@@PrunePatterns = [
		/CVS/,
		/~$/,
		%r:(^|/)\.:,
		/authorsection/,
		/\.tpl$/,
	]

	def initialize( testing=false )
		@ftools = (testing) ? self : File
	end

	### Make the specified dirs (which can be a String or an Array of Strings)
	### with the specified mode.
	def makedirs( dirs, mode=0755, verbose=false )
		dirs = [ dirs ] unless dirs.is_a? Array

		oldumask = File::umask
		File::umask( 0777 - mode )

		for dir in dirs
			if @ftools == File
				File::mkpath( dir, $verbose )
			else
				$stderr.puts "Make path %s with mode %o" % [ dir, mode ]
			end
		end

		File::umask( oldumask )
	end

	def install( srcfile, dstfile, mode=nil, verbose=false )
		dstfile = File.catname(srcfile, dstfile)
		unless FileTest.exist? dstfile and File.cmp srcfile, dstfile
			$stderr.puts "   install #{srcfile} -> #{dstfile}"
		else
			$stderr.puts "   skipping #{dstfile}: unchanged"
		end
	end

	public

	def installFiles( src, dstDir, mode=0444, verbose=false )
		directories = []
		files = []
		
		if File.directory?( src )
			Find.find( src ) {|f|
				Find.prune if @@PrunePatterns.find {|pat| f =~ pat}
				next if f == src

				if FileTest.directory?( f )
					directories << f.gsub( /^#{src}#{File::Separator}/, '' )
					next 

				elsif FileTest.file?( f )
					files << f.gsub( /^#{src}#{File::Separator}/, '' )

				else
					Find.prune
				end
			}
		else
			files << File.basename( src )
			src = File.dirname( src )
		end
		
		dirs = [ dstDir ]
		dirs |= directories.collect {|d| File.join(dstDir,d)}
		makedirs( dirs, 0755, verbose )
		files.each {|f|
			srcfile = File.join(src,f)
			dstfile = File.dirname(File.join( dstDir,f ))

			if verbose
				if mode
					$stderr.puts "Install #{srcfile} -> #{dstfile} (mode %o)" % mode
				else
					$stderr.puts "Install #{srcfile} -> #{dstfile}"
				end
			end

			@ftools.install( srcfile, dstfile, mode, verbose )
		}
	end

end

if $0 == __FILE__
	header "MUES Installer #$version"

	unless RUBY_VERSION >= "1.8.1" || ENV['NO_VERSION_CHECK']
		abort "MUES will not run under this version of Ruby. It requires at least 1.8.1.\n" +
			"Re-run again with NO_VERSON_CHECK set to ignore this check."
	end

	for lib in RequiredLibraries
		testForRequiredLibrary( *lib )
	end

	viewOnly = ARGV.include? '-n'
	verbose = ARGV.include? '-v'

	serverDir = File.expand_path( promptWithDefault("Server directory", "/usr/local/mues") )

	debugMsg "Sitelibdir = '#{CONFIG['sitelibdir']}'"
	sitelibdir = CONFIG['sitelibdir']
	debugMsg "Sitearchdir = '#{CONFIG['sitearchdir']}'"
	sitearchdir = CONFIG['sitearchdir']

	unless File.exists?( "ext/mues.#{Config::CONFIG['DLEXT']}" )
		message "Compiling C extensions\n"
		Dir.chdir( "ext" ) {
			Kernel::load( "extconf.rb", true ) or
				raise "Extension configuration failed."
			system( 'make' ) or
				raise "Make failed."
		}
	else
		message "C extensions already compiled.\n"
	end

	message "Installing\n"
	i = Installer.new( viewOnly )
	i.installFiles( "lib", sitelibdir, 0444, verbose )
	i.installFiles( "ext/mues.#{Config::CONFIG['DLEXT']}", sitearchdir, 0755, verbose )
	i.installFiles( "server/bin", "#{serverDir}/bin", 0755, verbose )
	i.installFiles( "server/shellCommands", "#{serverDir}/shellCommands", 0644, verbose )
	i.installFiles( "server/environments", "#{serverDir}/environments", 0644, verbose )
	i.installFiles( "server/questionnaires", "#{serverDir}/environments", 0644, verbose )
	i.installFiles( "server/config.yml", serverDir, 0644, verbose )
end
	




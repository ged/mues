#!/usr/bin/ruby
#
#	MUES Install Script
#	$Id: install.rb,v 1.4 2002/09/14 13:28:06 deveiant Exp $
#
#	Thanks to Masatoshi SEKI for ideas found in his install.rb.
#
#	Copyright (c) 2001, 2002, The FaerieMUD Consortium.
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
require 'readline'

include Config
include Readline

$version	= %q$Revision: 1.4 $
$rcsId		= %q$Id: install.rb,v 1.4 2002/09/14 13:28:06 deveiant Exp $

stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }


class Installer

	@@PrunePatterns = [
		/CVS/,
		/~$/,
		/^\./,
	]

	def initialize( testing=false )
		@ftools = (testing) ? self : File
	end

	### Modified version of ftools' File.makedirs that has sane args
	def makedirs( dirs, mode=0755, verbose=false )
		dirs = [ dirs ] unless dirs.is_a? Array
		for dir in dirs
			if FileTest.directory? dir
				$stderr.puts( "No need to make #{dir}: already exists." ) if @ftools == self
				next
			end
			parent = File.dirname( dir )
			makedirs( parent, mode, verbose ) unless FileTest.directory? parent
			$stderr.print( "   mkdir ", dir, "\n" ) if verbose
			if File.basename(dir) != ""
				if @ftools == File
					Dir.mkdir dir, mode
				else
					$stderr.puts "Make directory %s with mode %o" % [ dir, mode ]
				end
			end
		end
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

	unless RUBY_VERSION >= "1.7.2" || ENV['NO_VERSION_CHECK']
		abort "MUES will not run under this version of Ruby. It requires at least 1.7.2 (CVS)."
	end

	viewOnly = ARGV.include? '-n'
	verbose = ARGV.include? '-v'

	serverDir = File.expand_path( promptWithDefault("Server directory", "/usr/local/mues") )

	debugMsg "Sitelibdir = '#{CONFIG['sitelibdir']}'"
	sitelibdir = CONFIG['sitelibdir']
	debugMsg "Sitearchdir = '#{CONFIG['sitearchdir']}'"
	sitearchdir = CONFIG['sitearchdir']

	message "Compiling C extensions\n"
	Dir.chdir( "ext" ) {
		Kernel::load( "extconf.rb", true ) or
			raise "Extension configuration failed."
		system( 'make' ) or
			raise "Make failed."
	}

	message "Installing\n"
	i = Installer.new( viewOnly )
	i.installFiles( "lib", sitelibdir, 0444, verbose )
	i.installFiles( "ext/mues.so", sitearchdir, 0755, verbose )
	i.installFiles( "server/bin", "#{serverDir}/bin", 0755, verbose )
	i.installFiles( "server/shellCommands", "#{serverDir}/shellCommands", 0644, verbose )
	i.installFiles( "server/environments", "#{serverDir}/environments", 0644, verbose )
	i.installFiles( "server/minimal-config.xml", serverDir, 0644, verbose )
end
	




#!/usr/bin/ruby
#
#	MUES Install Script
#	$Id: install.rb,v 1.1 2001/11/01 15:52:08 deveiant Exp $
#
#	Thanks to Masatoshi SEKI for ideas found in his install.rb.
#
#	Copyright (c) 2001, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require 'rbconfig'
require 'find'
require 'ftools'
require 'readline'

include Config
include Readline

stty_save = `stty -g`.chomp
trap("INT") { system "stty", stty_save; exit }


class Installer

	protected
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
				Find.prune if f =~ /^\./;

				next if f == src || f =~ /~$/

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

def prompt( promptString )
	promptString.chomp!
	return readline( "#{promptString}: " ).strip
end

if $0 == __FILE__
	viewOnly = false
	verbose = false

	ARGV.each {|arg|

		case arg
		when "-n"
			viewOnly = true

		when "-v"
			verbose = true

		else
			$stderr.puts( "Usage: #{$0} [-n]" )
		end
	}

	serverDir = File.expand_path( prompt "Server directory [/usr/local/mues]" )
	serverDir = "/usr/local/mues" if serverDir.empty?

	i = Installer.new( viewOnly )
	i.installFiles( "lib", CONFIG['sitelibdir'], 0444, verbose )
	i.installFiles( "server/bin", "#{serverDir}/bin", 0755, verbose )
	i.installFiles( "server/shellCommands", "#{serverDir}/shellCommands", 0644, verbose )
	i.installFiles( "server/environments", "#{serverDir}/environments", 0644, verbose )
	i.installFiles( "server/MUES.cfg.example", serverDir, 0644, verbose )
end
	




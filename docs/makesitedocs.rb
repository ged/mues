#!/usr/bin/ruby
#
#	MUES Documentation Generation Script
#	$Id: makesitedocs.rb,v 1.8 2002/08/02 20:12:14 deveiant Exp $
#
#	Copyright (c) 2001,2002 The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

# Muck with the load path and the cwd
$filename = __FILE__
$basedir = File::expand_path( $0 ).sub( %r{/docs/makesitedocs.rb}, '' )
unless $basedir.empty? || Dir.getwd == $basedir
	$stderr.puts "Changing working directory from '#{Dir.getwd}' to '#$basedir'"
	Dir.chdir( $basedir ) 
end

$LOAD_PATH.unshift "docs/lib"

# Load modules
require 'getoptlong'
require 'rdoc/rdoc'
#require 'rdoc/parsers/parse_faeriemud_rb'
require 'utils'
include UtilityFunctions

opts = GetoptLong.new
opts.set_options(
	[ '--debug',	'-d',	GetoptLong::NO_ARGUMENT ],
	[ '--verbose',	'-v',	GetoptLong::NO_ARGUMENT ],
	[ '--upload',	'-u',	GetoptLong::OPTIONAL_ARGUMENT ]
)

$docsdir = "docs/html"
$libdirs = %w{lib ext/mues server README INSTALL QUICKSTART CONFIGURATION}
opts.each {|opt,val|
	case opt

	when '--debug'
		$debug = true

	when '--verbose'
		$verbose = true

	when '--upload'
		$upload = unless val.empty?
					  val
				  else
					  'ssh://oberon/www/mues.FaerieMUD.org/public/rdoc'
				  end
		debugMsg "Setting upload arg to #$upload"

	end
}


header "Making documentation in #$docsdir from files in #{$libdirs.join(', ')}."
message "Will upload to '#$upload'" if $upload

flags = [
	'--all',
	'--inline-source',
	'--main', 'README',
	'--fmt', 'html',
	'--include', 'docs',
	'--template', 'mues',
	'--op', $docsdir,
	'--title', "Multi-User Environment Server (MUES)"
]

flags += [ '--quiet' ] unless $verbose
message "Running 'rdoc #{flags.join(' ')} #{$libdirs.join(' ')}'\n" if $verbose


unless $debug
	begin
		r = RDoc::RDoc.new
		r.document( flags + $libdirs  )
	rescue RDoc::RDocError => e
		$stderr.puts e.message
		exit(1)
	end
end

if $upload
	header "Uploading new docs snapshot to #$upload."
	case $upload
	
	# SSH target
	when %r{^ssh://(.*)}
		target = $1
		if target =~ %r{^([^/]+)/(.*)}
			host, path = $1, $2
			path = "/" + path unless path =~ /^(\/|\.)/
			cmd = "tar -C docs/html -cf - . | ssh #{host} 'tar -C #{path} -xvf -'"
			unless $debug
				system( cmd )
			else
				message "Would have uploaded using the command:\n    #{cmd}\n\n"
			end
		else
			error "--upload ssh://host/path"
		end
	when %r{^file://(.*)}
		targetdir = $1
		targetdir.gsub!( %r{^file://}, '' )

		File.makedirs targetdir, true
		Dir["docs/html/**/*"].each {|file|
			fname = file.gsub( %r{docs/html/}, '' )
			if File.directory? file
				unless $debug
					File.makedirs File.join(targetdir, fname), true
				else
					message %{File.makedirs %s, true\n} % File.join(targetdir, fname)
				end
			else
				unless $debug
					File.install( file, File.join(targetdir, fname), 0444, true )
				else
					message %{File.install( %s, %s, 0444, true )\n} % [
						file,
						File.join(targetdir, fname),
					]
				end
			end
		}

	else
		raise "I don't know how to upload to urls like #$upload."
	end
end


# rdoc \
#	--all \
#	--inline_source \
#	--main "lib/mues.rb" \
#	--fmt myhtml \
#	--include docs \
#	--template faeriemud \
#	--title "Multi-User Environment Server (MUES)" \
#		lib server

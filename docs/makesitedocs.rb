#!/usr/bin/ruby
#
#	MUES Documentation Generation Script
#	$Id: makesitedocs.rb,v 1.3 2002/03/30 19:08:07 deveiant Exp $
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
require "utils"
include UtilityFunctions

opts = GetoptLong.new
opts.set_options(
	[ '--debug',	'-d',	GetoptLong::NO_ARGUMENT ],
	[ '--verbose',	'-v',	GetoptLong::NO_ARGUMENT ],
	[ '--upload',	'-u',	GetoptLong::NO_ARGUMENT ]
)

$docsdir = "docs/html"
$libdirs = %w{lib server README}
opts.each {|opt,val|
	case opt

	when '--debug'
		$debug = true

	when '--verbose'
		$verbose = true

	when '--upload'
		$upload = true

	end
}


header "Making documentation in #$docsdir from files in #{$libdirs.join(', ')}."

flags = [
	'--all',
	'--inline-source',
	'--main', 'README',
	'--fmt', 'myhtml',
	'--include', 'docs',
	'--template', 'faeriemud',
	'--op', $docsdir,
	'--title', "Multi-User Environment Server (MUES)"
]

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
	if ENV['HOSTNAME'] =~ /faeriemud/i
		header "Uploading new docs snapshot to oberon.FaerieMUD.org."
		unless $debug
			system( "tar -C docs/html -cf - . | ssh oberon 'tar -C /www/mues.FaerieMUD.org/public/rdoc -xvf -'" )
		end
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

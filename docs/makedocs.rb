#!/usr/bin/ruby
#
#	MUES Documentation Generation Script
#	$Id: makedocs.rb,v 1.3 2002/03/01 11:17:07 deveiant Exp $
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

# Load modules
require 'getoptlong'
require 'rdoc/rdoc'
require "utils"
include UtilityFunctions

opts = GetoptLong.new
opts.set_options(
	[ '--debug',	'-d',	GetoptLong::NO_ARGUMENT ],
	[ '--verbose',	'-v',	GetoptLong::NO_ARGUMENT ],
)

$docsdir = "docs/html"
$libdirs = %w{lib server}
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
	'--inline_source',
	'--main', 'lib/mues.rb',
	'--include', 'docs',
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

# rdoc \
#	--all \
#	--inline_source \
#	--main "lib/mues.rb" \
#	--title "Multi-User Environment Server (MUES)" \
#		lib server

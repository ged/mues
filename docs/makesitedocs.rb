#!/usr/bin/ruby
#
#	MUES RDoc Documentation Generation Script
#	$Id: makesitedocs.rb,v 1.11 2002/10/22 18:17:55 deveiant Exp $
#
#	Copyright (c) 2001,2002 The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

# Muck with the load path and the cwd
unless File.exists?( 'lib/mues.rb' )
	filename = __FILE__
	basedir = File::expand_path( $0 ).sub( %r{/docs/makedocs.rb}, '' )
	unless $basedir.empty? || Dir.getwd == $basedir
		$stderr.puts "Changing working directory from '#{Dir.getwd}' to '#$basedir'"
		Dir.chdir( $basedir ) 
	end
end

# Load modules
require 'getoptlong'
require 'docs/makedocs.rb'

opts = GetoptLong.new
opts.set_options(
	[ '--debug',	'-d',	GetoptLong::NO_ARGUMENT ],
	[ '--verbose',	'-v',	GetoptLong::NO_ARGUMENT ],
	[ '--upload',	'-u',	GetoptLong::OPTIONAL_ARGUMENT ],
	[ '--diagrams', '-D',	GetoptLong::NO_ARGUMENT ],
	[ '--template',	'-T',	GetoptLong::REQUIRED_ARGUMENT ],
	[ '--output',	'-o',	GetoptLong::REQUIRED_ARGUMENT ]
)

upload = nil
diagrams = false
template = 'mues'
docsdir = "docs/html"

opts.each {|opt,val|
	case opt

	when '--debug'
		$DEBUG = true

	when '--verbose'
		$VERBOSE = true

	when '--upload'
		upload = val.empty? ? 'ssh://oberon/www/mues.FaerieMUD.org/public/rdoc' : val

	when '--diagrams'
		diagrams = true

	when '--output'
		docsdir = val
	end
}

makeDocs( docsdir, template, upload, diagrams )

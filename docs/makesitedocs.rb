#!/usr/bin/ruby
#
#	MUES RDoc Documentation Generation Script
#	$Id: makesitedocs.rb,v 1.10 2002/10/17 14:48:02 deveiant Exp $
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

debug = false
verbose = false
upload = nil
diagrams = false
template = 'mues'
docsdir = "docs/html"

opts.each {|opt,val|
	case opt

	when '--debug'
		debug = true

	when '--verbose'
		verbose = true

	when '--upload'
		upload = val ? val : 'ssh:///www/mues.FaerieMUD.org/public/rdoc'

	when '--diagrams'
		diagrams = true

	when '--output'
		docsdir = val
	end
}

$DEBUG = true if debug
$VERBOSE = true if verbose

makeDocs( docsdir, template, upload, diagrams )

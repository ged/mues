#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname( __FILE__ ).dirname

	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include( libdir.to_s )
}

#
#	MUES Quickstart Script
#	$Id$
#
#	Copyright (c) 2001-2004, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

require 'mues/engine'

$0 = '[MUES Engine]'

MUES::Engine.start( *ARGV )


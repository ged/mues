#!/usr/bin/env ruby

require 'pathname'

BASEDIR = Pathname( __FILE__ ).dirname.parent.parent
LIBDIR  = BASEDIR + 'lib'

$LOAD_PATH.unshift( LIBDIR.to_s ) unless $LOAD_PATH.include?( LIBDIR.to_s )

require 'mues/utils'
include MUES::UtilityFunctions



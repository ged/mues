#!/usr/bin/ruby
#
# The Multi-User Environment Server.
#
# This module provides a collection of modules, functions, and base classes for
# the Multi-User Environment Server. Requiring it loads all the subordinate
# modules necessary to start the server. 
#
#
# == Synopsis
#
#   require "mues"
#
#   config = MUES::Config::new( "muesconfig.xml" )
#   MUES::Engine::instance.start( config )
#
# == Rcsid
# 
# $Id: mues.rb,v 1.28 2003/10/13 04:02:17 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require 'rbconfig'

# The base namespace under which all MUES components exist.
module MUES ; end

unless RUBY_VERSION >= "1.8.0" || ENV['NO_VERSION_CHECK']
	fail "MUES requires at least Ruby 1.8.0. This is #{RUBY_VERSION}."
end

require "mues.#{Config::CONFIG['DLEXT']}"
require 'mues/engine'



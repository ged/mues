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
# $Id: mues.rb,v 1.24 2002/08/02 20:10:10 deveiant Exp $
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

# The base namespace under which all MUES components exist.
module MUES ; end

unless RUBY_VERSION >= "1.7.2" || ENV['NO_VERSION_CHECK']
	fail "MUES requires at least Ruby 1.7.2. This is #{RUBY_VERSION}."
end

###
### Add a couple of syntactic sugar aliases to the Module class.  (Borrowed from
### Hipster's component "conceptual script" - http://www.xs4all.nl/~hipster/):
###
### [<tt>Module::implements</tt>]
###     An alias for <tt>include</tt>. This allows syntax of the form:
###       class MyClass < MUES::Object; implements MUES::Debuggable, AbstracClass
###         ...
###       end
###
### [<tt>Module::implements?</tt>]
###     An alias for <tt>Module#<</tt>, which allows one to ask
###     <tt>SomeClass.implements?( Debuggable )</tt>.
###
class Module

	# Syntactic sugar for mixin/interface modules
	alias :implements :include
	alias :implements? :include?
end

require 'mues/Engine'



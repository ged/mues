#!/usr/bin/ruby
# 
# This file is the base require for the Metaclass classes -- it loads all the
# required subordinate modules and sets up the Metaclass namespace with constants
# and functions that the other modules share.
# 
# == Synopsis
# 
#   require "metaclasses"
# 
#   myClass = Metaclass::Class.new( "MyClass" )
#   implementable = Metaclass::Interface( "Implementable" )
#   myClass << implementable
# 
#   ...etc.
# 
# == Rcsid
#
# $Id: metaclasses.rb,v 1.2 2002/03/30 19:10:01 deveiant Exp $
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

require 'metaclass/Constants'
require 'metaclass/Association'
require 'metaclass/Attribute'
require 'metaclass/Interface'
require 'metaclass/Namespace'
require 'metaclass/Operation'
require 'metaclass/Parameter'
require 'metaclass/Class'


#!/usr/bin/ruby
# 
# This file is the base require for the MUES::Metaclass classes -- it loads all
# the required subordinate modules and sets up the MUES::Metaclass namespace
# with constants and functions that the other modules share.
# 
# == Synopsis
# 
#   require "mues/metaclasses"
# 
#   myClass = MUES::Metaclass::Class.new( "MyClass" )
#   implementable = MUES::Metaclass::Interface( "Implementable" )
#   myClass << implementable
# 
#   ...etc.
# 
# == Rcsid
#
# $Id: metaclasses.rb,v 1.4 2002/10/04 04:03:38 deveiant Exp $
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

require 'mues/metaclass/Constants'
require 'mues/metaclass/Association'
require 'mues/metaclass/Attribute'
require 'mues/metaclass/Interface'
require 'mues/metaclass/Namespace'
require 'mues/metaclass/Operation'
require 'mues/metaclass/Parameter'
require 'mues/metaclass/Class'
require 'mues/metaclass/AccessorOperation'
require 'mues/metaclass/MutatorOperation'



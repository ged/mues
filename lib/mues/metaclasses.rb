#!/usr/bin/ruby
# 
# This file is the base require for the MUES::Metaclass classes -- it loads all
# the required subordinate modules and sets up the MUES::Metaclass namespace
# with constants and functions that the other modules share.
# 
# == Synopsis
# 
#   require 'mues/metaclasses'
# 
#   myClass = MUES::Metaclass::Class.new( "MyClass" )
#   implementable = MUES::Metaclass::Interface( "Implementable" )
#   myClass << implementable
# 
#   ...etc.
# 
# == Rcsid
#
# $Id: metaclasses.rb,v 1.5 2003/10/13 04:02:16 deveiant Exp $
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

require 'mues/metaclass/constants'
require 'mues/metaclass/association'
require 'mues/metaclass/attribute'
require 'mues/metaclass/interface'
require 'mues/metaclass/namespace'
require 'mues/metaclass/operation'
require 'mues/metaclass/parameter'
require 'mues/metaclass/class'
require 'mues/metaclass/accessoroperation'
require 'mues/metaclass/mutatoroperation'



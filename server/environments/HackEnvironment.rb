#!/usr/bin/ruby
#
# This file contains the MUES::HackEnvironment class, a NetHack-like environment
# created mostly for the purpose of filling the role of homework for stillflame.
# For that role, this environment will implement the topological behaviors of
# the world using a graph data-structure, and will likely add a few fairly
# stupid features simply to better express this fact.
#
# == Synopsis
#
#	mues> /loadenv Hack as aWorld
#   Attempting to load the 'HackEnvironment' environment as 'aWorld'
#   Successfully loaded 'aWorld'
#	
#	mues> /roles
#   aWorld (HackEnvironment):
#        looter   A boring role for collecting gold
#        admin    A barely less-boring role for testing
#	
#   (2) roles available to you.
#	
#	mues> /play aWorld as looter
#   Connecting...
#   Connected to NullEnvironment as 'superuser'
#	
#	aWorld:looter>> ...
#
# == Rcsid
#
# $Id: HackEnvironment.rb,v 1.1 2002/10/24 05:04:54 stillflame Exp $
#
# == Authors
#
#	Martin Chase <stillflame@FaerieMUD.org>
#
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.

require "sync"

require "mues"
require "mues/Mixins"
require "mues/Exceptions"
require "mues/Events"
require "mues/Environment"
require "mues/Role"
require "mues/ObjectStore"
require "mues/IOEventFilters"
require "mues/ObjectSpaceVisitor"

module MUES

	### A simple NetHack-like environment.
	class HackEnvironment < MUES::NullEnvironment

		include MUES::TypeCheckFunctions

		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
		Rcsid = %q$Id: HackEnvironment.rb,v 1.1 2002/10/24 05:04:54 stillflame Exp $

		ObjectStoreParams = { #:!!!: Are these used anymore?
			:backend	=> 'Berkeley',
			:memmgr		=> 'Null',
			:indexes	=> [:class],
			:visitor	=> MUES::ObjectSpaceVisitor, #:?: Should this be changed?
		}

		DefaultDescription = %Q{
		This is a fairly boring environment to test MUES functionality and to
		fill the role of homework for stillflame.  It is intended to be
		nethack-like, in that you run around in a dungeon collecting items and
		gold, killing orcs and goblins, and getting lost.

		There are no plans to support this environment past the day stillflame
		turns it in for credit, except for engine testing purposes.
		}.gsub( /^[ \t]*/, '' )

		### Initialize and return a new MUES::HackEnvironment object.
		def initialize( *args )
			super(*args)
			# @map = GraphMap::new :?:
			# @orcs = [] :?:
			# @items = [] :?:
		end

		### Get the roles in this environment which are available to the
		### specified user. Returns an array of MUES::Role objects.
		def getAvailableRoles( user )
			checkType( user, MUES::User )

			roles = [ MUES::Role.new( self, "looter", "An average schmoe participant" ) ]
			roles << MUES::Role.new( self, "admin", "Administrative participant" ) if user.isAdmin?

			return roles
		end

	end # class HackEnvironment
end # module MUES

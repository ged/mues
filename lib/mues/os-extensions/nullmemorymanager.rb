#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::NullMemoryManager class: This is a
# simple memory manager class that doesn't do anything. It can be used for small
# or highly volatile stores that don't need collection.
# 
# == Synopsis
# 
#   require 'mues/ObjectStore'
#
#   os = MUES::ObjectStore::load( 'foo', [], nil, 'Null' )
#	...
# 
# == Rcsid
# 
# $Id: nullmemorymanager.rb,v 1.2 2002/07/09 15:09:53 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues'
require 'mues/ObjectStore'
require 'mues/StorableObject'

require 'mues/os-extensions/MemoryManager'

module MUES
	class ObjectStore

		### This is a simple memory-manager class that doesn't do anything. It
		### can be used for small or highly volatile stores that don't need
		### collection.
		class NullMemoryManager < MUES::ObjectStore::MemoryManager

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
			Rcsid = %q$Id: nullmemorymanager.rb,v 1.2 2002/07/09 15:09:53 deveiant Exp $


			######
			public
			######

			### Start the memory manager, Such as it is.
			def start( visitor )
				@running = true
			end

			### Stop the memory manager.
			def shutdown
				self.collectAll
				@running = false
			end


			#########
			protected
			#########

			### Collects all the (non-shallow) objects.
			def collectAll
				@activeObjects.each_value {|o|
					@backend.store(o) unless o.shallow?
				}
				@activeObjects.clear
			end

		end # class NullMemoryManager

	end # class ObjectStore
end # module MUES


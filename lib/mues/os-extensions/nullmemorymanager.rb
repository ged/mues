#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::NullMemoryManager class: This is a
# simple memory manager class that doesn't do anything. It can be used for small
# or highly volatile stores that don't need collection.
# 
# == Synopsis
# 
#   require 'mues/objectstore'
#
#   os = MUES::ObjectStore::load( 'foo', [], nil, 'Null' )
#	...
# 
# == Rcsid
# 
# $Id: nullmemorymanager.rb,v 1.7 2003/10/13 04:02:12 deveiant Exp $
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

require 'mues/object'
require 'mues/objectstore'
require 'mues/storableobject'

require 'mues/os-extensions/memorymanager'

module MUES
	class ObjectStore

		### This is a simple memory-manager class that doesn't do anything. It
		### can be used for small or highly volatile stores that don't need
		### collection.
		class NullMemoryManager < MUES::ObjectStore::MemoryManager

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
			Rcsid = %q$Id: nullmemorymanager.rb,v 1.7 2003/10/13 04:02:12 deveiant Exp $


			######
			public
			######

			### Start the memory manager, Such as it is.
			def start( visitor )
				@running = true
			end

			### Stop the memory manager.
			def shutdown
				@running = false
				return self.unswappedObjects
			end

			### Restart the memory manager.
			def restart( visitor )
				objs = self.shutdown
				@activeObjects.clear
				self.start( visitor )
				self.register( *objs )
			end

		end # class NullMemoryManager

	end # class ObjectStore
end # module MUES


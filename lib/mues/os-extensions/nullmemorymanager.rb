#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::NullGarbageCollector class: This is
# a simple garbage collector class that doesn't collect. It can be used for
# small or highly volatile stores that don't need collection.
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
# $Id: nullmemorymanager.rb,v 1.1 2002/05/28 03:21:29 deveiant Exp $
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


module MUES
	class ObjectStore

		### This is a simple garbage collector class that doesn't collect. It can be
		### used for small or highly volatile stores that don't need collection.
		class NullGarbageCollector < MUES::ObjectStore::GarbageCollector

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
			Rcsid = %q$Id: nullmemorymanager.rb,v 1.1 2002/05/28 03:21:29 deveiant Exp $


			######
			public
			######

			### Start the garbage collector. Such as it is.
			def start( visitor )
				@running = true
			end

			### Stop the garbage collector.
			def shutdown
				self._collect_all
				@running = false
			end


			#########
			protected
			#########

			### Collects all the (non-shallow) objects.
			### may take arguments from the same hash _collect doesct
			def _collect_all
				@active_objects.each_value {|o|
					@objectStore.store(o) unless o.shallow?
				}
				@active_objects.clear
			end

		end # class NullGarbageCollector

	end # class ObjectStore
end # module MUES


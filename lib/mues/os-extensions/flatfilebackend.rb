#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::BerkeleyDBBackend class: A
# MUES::ObjactStore backend that uses BerkeleyDB as its storage database.
# 
# == Synopsis
# 
#   require 'mues/ObjectStore'
#
#   os = MUES::ObjectStore::load( 'foo', [], 'BerkeleyDB' )
#   ...
# 
# == Rcsid
# 
# $Id: flatfilebackend.rb,v 1.2 2002/07/09 15:07:45 deveiant Exp $
# 
# == Authors
# 
# * ged@FaerieMUD.org
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'pstore'

require 'mues'
require 'mues/Exceptions'
require 'mues/ObjectStore'
require 'mues/StorableObject'
require 'mues/os-extensions/Backend'

module MUES
	class ObjectStore

		### BerkeleyDB ObjectStore backend.
		class FlatfileBackend < MUES::ObjectStore::Backend

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
			Rcsid = %q$Id: flatfilebackend.rb,v 1.2 2002/07/09 15:07:45 deveiant Exp $

			### Create a new BerkeleyDBBackend object.
			def initialize( name, indexes=[], configHash={} )
				@name = name

				@store = PStore::new( @name )
				@store.transaction {
					@indexes = @store['indexes'] if @store.root? 'indexes'
				}

				@indexes ||= {}
				indexes.each {|idx| @indexes[ind] ||= {}}
			end


			######
			public
			######

			### Drop the datastore under the backend
			def drop
				self.close
				File::delete( @name )
			end

			### store
			def store
			end


			### retrieve
			def retrieve
			end


			### retrieve_by_index
			def retrieve_by_index
			end


			### retrieve_all
			def retrieve_all
			end


			### lookup
			def lookup
			end


			### close
			def close
			end


			### exists?
			def exists?
			end


			### open?
			def open?
			end



			### entries
			def entries
			end


			### Clear
			def clear
			end

			#########
			protected
			#########


		end # class FlatfileBackend

	end # class ObjectStore
end # module MUES


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
# $Id: berkeleydbbackend.rb,v 1.1 2002/05/28 03:21:29 deveiant Exp $
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

require 'bdb'

require 'mues'
require 'mues/Exceptions'


module MUES
	class ObjectStore

		### BerkeleyDB ObjectStore backend.
		class BerkeleyDBBackend < MUES::ObjectStore::Backend

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
			Rcsid = %q$Id: berkeleydbbackend.rb,v 1.1 2002/05/28 03:21:29 deveiant Exp $

			### Create a new BerkeleyDBBackend object.
			def initialize( objectStore, name, serializer, indexes )
				@objectStore = objectStore
				@name = name
				@serializer = serializer
				@indexes = indexes

				@env = Bdb::Env::new( @name )
				@db = @env.open( @name )
			end


			######
			public
			######

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


		end # class BerkeleyDBBackend

	end # class ObjectStore
end # module MUES


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
# $Id: berkeleydbbackend.rb,v 1.2 2002/07/09 15:06:02 deveiant Exp $
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
require 'sync'

require 'mues'
require 'mues/Exceptions'
require 'mues/ObjectStore'
require 'mues/StorableObject'
require 'mues/os-extensions/Backend'


module MUES
	class ObjectStore

		### BerkeleyDB ObjectStore backend.
		class BerkeleyDBBackend < MUES::ObjectStore::Backend

			include MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
			Rcsid = %q$Id: berkeleydbbackend.rb,v 1.2 2002/07/09 15:06:02 deveiant Exp $

			### Turn on strict checking. Should be turned off for production.
			@@StrictMode = false


			### Create a new BerkeleyDBBackend object, using the specified
			### <tt>name</tt> as the directory to store the backing store files.
			def initialize( name, indexes=[], configHash={} )
				@name = name
				@indexes = {}
				@mutex = Sync::new

				# Versions < 3.3 don't have associate(), which we need for indexes
				raise RuntimeError,
					"The installed version of BDB doesn't support " +
					"associations. You should upgrade to BerkeleyDB " +
					">= 3.3.x and BDB >= 0.2.1" unless
					BDB::Common::instance_methods.include? 'associate'

				dir = File::join( ObjectStore::Backend::StoreDir, @name )
				Dir::mkdir( dir ) unless File.directory?( dir )

				@env = BDB::Env.new( dir, BDB::CREATE|BDB::INIT_TRANSACTION|BDB::INIT_MPOOL )
				@db = @env.open_db( BDB::Hash,
								    @name,
								    nil,
								    BDB::CREATE,
								    :marshal	=> true )

				@open = true
				self.addIndexes( *indexes )
			end



			######
			public
			######

			### Drop the backing store for this backend
			def drop
				self.close
				@env.remove()
			end

			### Backend Interface

			### Store the specified <tt>objects</tt> in the database.
			def store( *objects )
				checkOpened()
				checkEachType( objects, MUES::StorableObject )

				begin
					# Start a transaction and store each object. Txn
					# auto-commits at the end of the block.
					@env.begin( DBD::TXN_COMMIT, @db ) do |txn, db|
						objects.each {|obj| db[ obj.objectStoreID ] = obj }
					end
				rescue => err
					raise MUES::ObjectStoreException,
						"Transaction failed while storing: #{err.message}",
						err.backtrace
				end
			end


			### Retrieve the objects that have the specified <tt>ids</tt> from
			### the database and return them.
			def retrieve( *ids )
				checkOpened()
				objs = []

				begin
					@env.begin( DBD::TXN_COMMIT, @db ) do |txn, db|
						objs.replace ids.collect {|id| db[ id ]}
					end
				rescue => err
					raise MUES::ObjectStoreException,
						"Transaction failed while fetching: #{err.message}",
						err.backtrace
				end

				return *objs
			end
			alias :[] :retrieve


			### Retrieve the object/s specified by the given <tt>key</tt> and
			### <tt>value</tt>. The specified <tt>key</tt> may be a Symbol or a
			### String, and must be a valid index.
			def retrieve_by_index( key, val )
				checkOpened()
				raise ArgumentError, "Invalid index #{key.inspect}" unless
					@indexes.has_key?[ key.to_s ]

				objs = nil
				begin
					@env.begin( DBD::TXN_COMMIT, @indexes[key.to_s] ) do |txn, idx|
						objs.replace( idx.duplicates(val, false) )
					end
				rescue => err
					raise MUES::ObjectStoreException,
						"Transaction failed while fetching: #{err.message}",
						err.backtrace
				end

				return objs
			end


			### Fetch and return every object stored in the ObjectStore.
			def retrieve_all
				checkOpened()
				objs = nil

				begin
					@env.begin( DBD::TXN_COMMIT, @db ) do |txn, db|
						objs.replace( db.values )
					end
				rescue => err
					raise MUES::ObjectStoreException,
						"Transaction failed while fetching values: #{err.message}",
						err.backtrace
				end

				return objs
			end


			### Given the <tt>indexValuePairs</tt> Hash, which contains index =>
			### lookup values pairs, return objects which match the equality
			### natural join of the pairs.
			def lookup( indexValuePairs )
				checkOpened()
				objs = []

				begin
					@env.begin( DBD::TXN_COMMIT, @db ) do |txn, db|
						cursors = indexValuePairs.collect {|idx,vals|
							vals.to_a.collect {|val| txn.assoc(@indexes[idx]).cursor_set(val)}
						}.flatten
						db.join(cursors) {|key,val| objs << val }
					end
				rescue => err
					raise MUES::ObjectStoreException,
						"Transaction failed while fetching values: #{err.message}",
						err.backtrace
				end

				return objs
			end


			### Close the backend
			def close
				checkOpened()
				@open = false
				@env.close
			end


			### Returns <tt>true</tt> if an object with the specified
			### <tt>id</tt> exists in the store.
			def exists?( id )
				checkOpened()
				@db.include?( id )
			end


			### Returns <tt>true</tt> if the backend's datastore is open.
			def open?
				@open
			end


			### Returns the number of objects stored in the database/
			def nitems
				checkOpened()
				@db.length
			end


			### Clear
			def clear
				checkOpened()
				@db.clear
			end

			### End of Backend Interface


			### Add the specified <tt>indexes</tt>, which are Strings or Symbols
			### that represent methods to call on stored objects.
			def addIndexes( *indexes )
				checkOpened()

				indexes.each {|idx|
					name = idx.to_s
					idx  = name.intern

					# Open a secondary handle and associate it with the first,
					# along with a proc for making the index value from a key =>
					# value pair.
					@indexes[name] = @env.open_db( BDB::Hash,
												   @name,
												   name,
												   BDB::CREATE|BDB::DUP|BDB::DUPSORT )
					@db.associate( @indexes[name], BDB::CREATE ) {|db,key,value|
						# :TODO: This should be taken out of production code
						unless value.is_a? MUES::StorableObject
							$stderr.puts "Ack! Value in indexer proc is not a StorableObject," +
								"but a #{value.class.name}!"
						end

						if value.respond_to?( idx )
							return value.send( idx )
						else
							return false
						end
					}
				}
			end

			#########
			protected
			#########

			### Check to make sure the datastore for the backend is open,
			### raising an exception if not.
			def checkOpened
				raise ObjectStore::BackendError, "Operation attempted on closed backend" unless
					@open
			end

		end # class BerkeleyDBBackend

	end # class ObjectStore
end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::BerkeleyDBBackend class: A
# MUES::ObjactStore backend that uses BerkeleyDB as its storage database.
# 
# == Synopsis
# 
#   require 'mues/ObjectStore'
#
#   os = MUES::ObjectStore::create( 'foo', [], 'BerkeleyDB' )
#   ...
# 
# == Rcsid
# 
# $Id: berkeleydbbackend.rb,v 1.5 2002/08/29 07:31:06 deveiant Exp $
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

require 'mues/Object'
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
			Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
			Rcsid = %q$Id: berkeleydbbackend.rb,v 1.5 2002/08/29 07:31:06 deveiant Exp $

			EnvOptions = {
				:set_timeout	=> 50,
				:set_lk_detect	=> 1,
			}
			EnvFlags = BDB::CREATE|BDB::INIT_TRANSACTION|BDB::INIT_MPOOL|BDB::INIT_LOG

			### Turn on strict checking. Should be turned off for production.
			@@StrictMode = false


			### Create a new BerkeleyDBBackend object, using the specified
			### <tt>name</tt> as the directory to store the backing store files.
			def initialize( name, indexes=[], config=nil )
				@name = name
				@indexes = {}
				@mutex = Sync::new

				# Versions < 3.3 don't have associate(), which we need for indexes
				raise RuntimeError,
					"The installed version of BDB doesn't support " +
					"associations. You should upgrade to BerkeleyDB " +
					">= 3.3.x and BDB >= 0.2.1" unless
					BDB::Common::instance_methods.include? 'associate'

				@dir = File::join( ObjectStore::Backend::StoreDir, @name )
				Dir::mkdir( @dir ) unless File.directory?( @dir )

				@env = BDB::Env.new( @dir, EnvFlags, EnvOptions )
				@db = @env.open_db( BDB::Hash, @name, nil, BDB::CREATE, :marshal => Marshal )

				@open = true
				self.addIndexes( *indexes )
			end



			######
			public
			######

			### Drop the backing store for this backend
			def drop
				self.close if self.open?
				self.log.notice( "Dropping backing store for '#@name'" )
				BDB::Env::remove( @dir )
			end


			### Backend Interface

			### Store the specified <tt>objects</tt> in the database.
			def store( *objects )
				objects.flatten!
				checkOpened()
				checkEachType( objects, MUES::StorableObject )

				self.log.debug { "Storing %d objects" % objects.length }

				begin
					# Start a transaction and store each object. Txn
					# auto-commits at the end of the block.
					self.log.debug { "   Beginning transaction..." }
					# @env.begin( BDB::TXN_COMMIT, @db ) do |txn, db|
						objects.each {|obj|
							id = obj.objectStoreId

							self.log.debug { "      Storing object '#{obj.objectStoreId}'..." }
							@db[ id ] = obj
						}
					#end
					self.log.debug { "   Done with transaction." }
				rescue => err
					raise MUES::ObjectStoreError,
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
					objs.replace ids.collect {|id| @db[ id ].to_orig}
				rescue => err
					raise MUES::ObjectStoreError,
						"Transaction failed while fetching: #{err.message}",
						err.backtrace
				end

				return objs
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
					objs.replace( @indexes[key.to_s.intern].duplicates(val, false) )
				rescue => err
					raise MUES::ObjectStoreError,
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
					objs.replace( @db.values.collect {|o| o.to_orig} )
				rescue => err
					raise MUES::ObjectStoreError,
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

				indexValuePairs.keys.each {|idx|
					raise MUES::ObjectStoreError, "No such index #{idx.inspect}" unless
						@indexes.has_key? idx
				}
					
				begin
					cursors = []
					# @env.begin( 0, @db ) {|txn, db|
						indexValuePairs.each {|idx,vals|
							self.log.debug { "Looking up values '#{vals.inspect}' for idx '#{idx.inspect}'" }
							vals.to_a.each {|val|
								self.log.debug { "Fetching cursor for '#{val}'" }
								#cursor = txn.associate( @indexes[idx] ).cursor
								cursor = @indexes[idx].cursor
								rval = cursor.set( val )
								self.log.debug { "Got a cursor with #{cursor.count} values." }

								cursors << cursor
							}
						}

						self.log.debug {"Preparing to do a join with #{cursors.length} cursors."}

						@db.join(cursors) {|key,val|
							self.log.debug {"Adding a '%s' object (%s) for join." % [val.class.name, val.muesid]}

							# Have to do this despite the source saying not to
							# use this method because the delegator it returns
							# doesn't delegate inherited methods...
							objs << val.to_orig
							val = nil
						}

						#self.log.debug "Closing join transaction..."
						#txn.close
					#}
				rescue => err
					self.log.error "Transaction failed while fetching values: %s: %s" % [
						err.message, err.backtrace.join("\n\t") ]
					self.log.notice "Attempting recovery"
					@env.recover {|txn, id|
						self.log.error "Discarding txn #{id}"
						txn.discard
					}

				end

				self.log.debug {"Join returned '%d' ids" % objs.length}
				return objs
			end


			### Close the backend
			def close
				checkOpened()
				@open = false
				@indexes.each_value {|idx| idx.close}
				@db.close
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
					indexName = idx.to_s
					idx = indexName.intern

					self.log.debug {"Adding index '#{indexName}'"}
					
					# Open a secondary handle and associate it with the first,
					# along with a proc for making the index value from a key =>
					# value pair.
					@indexes[idx] =
						@env.open_db( BDB::Hash, indexName + "_i", nil, BDB::CREATE,
									  :set_flags => BDB::DUP|BDB::DUPSORT, :marshal => ::Marshal )

					@db.associate( @indexes[idx], BDB::CREATE ) {|db,key,value|
						# :TODO: This should be taken out of production code
						unless value.is_a? MUES::StorableObject
							$stderr.puts "Ack! Value in indexer proc is not a StorableObject," +
								"but a #{value.class.name}!"
						end

						if value.respond_to?( idx )
							value.send( idx )
						else
							false
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
					self.open?
			end

		end # class BerkeleyDBBackend

	end # class ObjectStore
end # module MUES


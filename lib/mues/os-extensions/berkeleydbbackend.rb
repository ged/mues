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
# $Id: berkeleydbbackend.rb,v 1.8 2002/10/13 23:24:05 deveiant Exp $
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
			Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
			Rcsid = %q$Id: berkeleydbbackend.rb,v 1.8 2002/10/13 23:24:05 deveiant Exp $

			EnvOptions = {
				:set_timeout	=> 50,
				:set_lk_detect	=> 1,
				:set_verbose	=> true,
			}
			EnvFlags = BDB::CREATE|BDB::INIT_TRANSACTION|BDB::RECOVER

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

				@env = BDB::Env::new( @dir, EnvFlags, EnvOptions )
				@db = @env.open_db( BDB::Hash, @name, nil, BDB::CREATE )

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

				self.log.debug "      Storing objects: %s..." % objects.inspect

				begin
					# Start a transaction and store each object. Txn
					# auto-commits at the end of the block.
					self.log.debug { "   Beginning transaction..." }
					@env.begin( BDB::TXN_COMMIT, @db ) do |txn, db|
						objects.each {|obj|
							id = obj.objectStoreId

							self.log.debug "      Storing object <%s> with id = '%s'..." %
								[ obj.inspect, obj.objectStoreId ]
							db[ id ] = Marshal::dump( obj )
						}
					end
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
					objs.replace ids.collect {|id|
						if @db.key?( id )
							Marshal::restore(@db[ id ])
						else
							nil
						end
					}
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
					@indexes.has_key?[ key.to_s.intern ]

				objs = []
				begin
					objs.replace @indexes[key.to_s.intern].
						duplicates(val, false).
						collect {|o| Marshal::restore(o) }
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
				objs = []

				begin
					objs.replace @db.values.collect {|o| Marshal::restore(o) }
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
					@env.begin( 0, @db ) do |txn, db|
						indexValuePairs.each {|idx,vals|
							vals = [ vals ] unless vals.is_a?( Array )
							self.log.debug { "Looking up values '#{vals.inspect}' for idx '#{idx.inspect}'" }
							vals.each {|val|
								self.log.debug { "Fetching cursor for '#{val}'" }
								cursor = txn.associate( @indexes[idx] ).cursor
								rval = cursor.set( val )
								self.log.debug { "Got a cursor with #{cursor.count} values." }

								cursors << cursor
							}
						}

						self.log.debug {"Preparing to do a join with #{cursors.length} cursors."}

						db.join(cursors) {|key,val|
							objs << Marshal::restore( val )
							self.log.debug "Added obj: <%s> in join." % objs[-1].inspect
						}

						self.log.debug "Closing cursors..."
						cursors.each {|cursor| cursor.close}

						self.log.debug "Leaving join transaction..."
					end
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
									  :set_flags => BDB::DUP|BDB::DUPSORT )

					# We have to de-serialize the value here (once per index per
					# object) because it's given to the associated indexer after
					# it's been serialized for some reason, which, of course,
					# makes it much slower. However, it *doesn't* pass the
					# serialized version when you use BDB's :marshal attribute,
					# but that strategy breaks your objects when you get them
					# back out by wrapping them in a delegate that doesn't
					# forward inherited methods.

					# @db.associate( @indexes[idx], BDB::CREATE ) {|db,key,value|
					@db.associate( @indexes[idx], BDB::CREATE ) {|db,key,serialized|
						value = Marshal::restore(serialized)

						# :TODO: This should be taken out of production code
						unless value.is_a? MUES::StorableObject
							$stderr.puts "Ack! Illegal value in indexer proc is not a StorableObject," +
								"but a #{value.class.name}!"
						end

						if value.respond_to?( idx )
							value.send( idx ).to_s
						else
							false
						end
					}
				}
			end


			### Return an Array of keys for the specified <tt>index</tt>.
			def indexKeys( index )
				raise MUES::IndexError, "No such index #{index}" unless @indexes.key?( index )
				@indexes[index].keys
			end

			### Returns <tt>true</tt> if the backing store has the specified
			### <tt>index</tt>, which can be either a String or a Symbol.
			def hasIndex?( index )
				@indexes.key?( index.to_s.intern )
			end
			


			### End of Backend Interface



			#########
			protected
			#########

			### Check to make sure the datastore for the backend is open,
			### raising an exception if not.
			def checkOpened
				raise MUES::BackendError, "Operation attempted on closed backend" unless
					self.open?
			end

		end # class BerkeleyDBBackend

	end # class ObjectStore
end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::BerkeleyDBBackend class: A
# MUES::ObjactStore backend that uses BerkeleyDB as its storage database.
#
# == Synopsis
# 
#   require 'mues/objectstore'
#
#   os = MUES::ObjectStore::create( 'foo', [], 'BerkeleyDB' )
#   ...
# 
# == Rcsid
# 
# $Id: berkeleydbbackend.rb,v 1.12 2003/10/13 04:02:12 deveiant Exp $
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

require 'mues/object'
require 'mues/exceptions'
require 'mues/objectstore'
require 'mues/storableobject'
require 'mues/os-extensions/backend'


module MUES
	class ObjectStore

		### BerkeleyDB ObjectStore backend.
		class BerkeleyDBBackend < MUES::ObjectStore::Backend ; implements MUES::Debuggable

			include MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
			Rcsid = %q$Id: berkeleydbbackend.rb,v 1.12 2003/10/13 04:02:12 deveiant Exp $

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
					BDB::Common::instance_methods( true ).include? 'associate'

				# Figure out what the target directory is
				@dir = File::join( ObjectStore::Backend::StoreDir, @name )
				Dir::mkdir( @dir ) unless File.directory?( @dir )

				# Open the environment object and then the primary database handle.
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

				debugMsg 1, "Storing %d objects" % objects.length

				begin
					# Start a transaction and store each object. Txn
					# auto-commits at the end of the block.
					debugMsg 2, "   Beginning transaction for 'store'"
					@env.begin( BDB::TXN_COMMIT, @db ) do |txn, db|
						objects.each {|obj|
							id = obj.objectStoreId

							debugMsg 5, "      Storing object <%s> with id = '%s'..." %
								[ obj.inspect, obj.objectStoreId ]
							db[ id ] = Marshal::dump( obj )
						}
					end
					debugMsg 2, "   Done with 'store' transaction."
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

				debugMsg 1, "Retrieving objects for %d ids" % ids.length

				begin
					@env.begin( 0, @db ) do |txn, db|
						objs.replace ids.collect {|id|
							if db.key?( id )
								Marshal::restore(@db[ id ])
							else
								nil
							end
						}
					end
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
					# Do the fetch, duplicates okay
					@env.begin( 0, @indexes[key.to_s.intern] ) do |txn, idx|
						objs.replace idx.duplicates(val, false).
							collect {|o| Marshal::restore(o) }
					end
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
					@env.begin( 0, @db ) do |txn, db|
						objs.replace db.values.collect {|o| Marshal::restore(o) }
					end
				rescue => err
					raise MUES::ObjectStoreError,
						"Transaction failed while fetching: #{err.message}",
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
				debugMsg 1, "Doing lookup with %d index pairs" % indexValuePairs.length
				
				begin
					cursors = []

					# Start transaction
					@env.begin( 0, @db ) do |txn, db|

						# Create a cursor for each index => value pair.
						indexValuePairs.each {|idx,vals|
							vals = [ vals ] unless vals.is_a?( Array )
							debugMsg 2, "Looking up values '#{vals.inspect}' for idx '#{idx.inspect}'"

							vals.each {|val|
								debugMsg 3, "Fetching cursor for '#{val}'"
								cursor = txn.associate( @indexes[idx] ).cursor
								rval = cursor.set( val )

								# If the cursor didn't find any values, the
								# lookup fails, so close the failing cursor,
								# stick a nil in the cursor array to signify the
								# failure, and break out of the index => val
								# loop.
								if rval.nil?
									debugMsg 1, "Lookup failed: No matching values for #{idx.inspect} = #{val.inspect}."
									cursors << nil
									cursor.close
									break
								else
									debugMsg 2, "Got a cursor with #{cursor.count} values."
								end

								cursors << cursor
							}
						}

						# Unless one of the cursors failed, do the join and
						# fetch the results
						unless cursors.include?( nil )
							debugMsg 2, "Preparing to do a join with #{cursors.length} cursors."

							db.join(cursors) {|key,val|
								objs << Marshal::restore( val )
								debugMsg 5, "Added obj: <%s> in join." % objs[-1].inspect
							}
						end

						# Close all of the valid cursors
						debugMsg 3, "Closing cursors..."
						cursors.each {|cursor| cursor.close unless cursor.nil?}

						debugMsg 2, "Leaving join transaction..."
					end

				# On an error, attempt to recover the DB
				rescue => err
					self.log.error "Transaction failed while fetching: %s: %s" % [
						err.message, err.backtrace.join("\n\t") ]
					self.log.notice "Attempting recovery"
					@env.recover {|txn, id|
						self.log.error "Discarding txn #{id}"
						txn.discard
					}

				end

				debugMsg 1, "Join returned '%d' ids" % objs.length
				return objs
			end


			### Remove and return the objects specified by the given
			### <tt>objects</tt> (which can be either objects or their ids) from
			### the backing store.
			def remove( *objects )
				checkEachType( objects, MUES::StorableObject, ::String )
				checkOpened()
				objs = []
				
				# Normalize all the target objects into their ids
				objects.collect! {|obj|
					case obj
					when MUES::StorableObject
						obj.objectStoreId

					when String
						obj

					else
						raise "Unexpected value '%s' in remove" % obj.inspect
					end
				}

				begin

					# Delete each object inside of a transaction
					@env.begin( BDB::TXN_COMMIT, @db ) do |txn, db|
						debugMsg 3, "Removing values for ids '%s'" % objs.inspect
						objects.each {|id| db.delete( id )}
						debugMsg 3, "Done with transaction"
					end

				# On an error, attempt to recover the DB
				rescue => err
					self.log.error "Transaction failed while removing: %s: %s" % [
						err.message, err.backtrace.join("\n\t") ]
					self.log.notice "Attempting recovery"
					@env.recover {|txn, id|
						self.log.error "Discarding txn #{id}"
						txn.discard
					}

				end
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

					debugMsg 1, "Adding index '#{indexName}'"
					
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


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
# $Id: flatfilebackend.rb,v 1.6 2002/09/27 16:20:31 deveiant Exp $
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

require 'sync'
require 'pstore'

require 'mues/Object'
require 'mues/Exceptions'
require 'mues/ObjectStore'
require 'mues/StorableObject'
require 'mues/os-extensions/Backend'

module MUES
	class ObjectStore

		### BerkeleyDB ObjectStore backend.
		class FlatfileBackend < MUES::ObjectStore::Backend

			include MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
			Rcsid = %q$Id: flatfilebackend.rb,v 1.6 2002/09/27 16:20:31 deveiant Exp $

			### Create a new BerkeleyDBBackend object.
			def initialize( name, indexes=[], configHash={} )
				dir = ObjectStore::Backend::StoreDir
				Dir::mkdir( dir ) unless File.directory?( dir )

				@name = File::join( dir, name + ".ffo" )

				self.log.info( "Opening objectstore '#{@name}' in #{dir}" )
				@store = PStore::new( @name )
				@store.transaction {
					@store['objects'] = {} unless @store.root?( 'objects' ) &&
						@store['objects'].is_a?( Hash )
					@objects = @store['objects']

					@store['indexes'] = {} unless @store.root?( 'indexes' ) &&
						@store['indexes'].is_a?( Hash )
					@indexes = @store['indexes']
				}

				@opened = true
				@mutex = Sync::new
				self.log.info( "Objectstore '#{name}' opened: %d indexes on %d objects" % [
								  @indexes.length, @objects.length] )

				addIndexes( *indexes )
			end


			######
			public
			######

			### Drop the datastore under the backend
			def drop
				self.log.info( "Dropping objectstore '#{@name}'" )
				@mutex.synchronize( Sync::EX ) {
					self.close if self.open?
					File::delete( @name )
				}
			end


			### store
			def store( *objects )
				objects.flatten!
				checkEachType( objects, MUES::StorableObject )

				@mutex.synchronize( Sync::SH ) {
					checkOpened()

					@mutex.synchronize( Sync::EX ) {
						objects.each {|o|
							@indexes.each {|idx,table|
								next unless o.respond_to? idx
								table[ o.send(idx) ] ||= []
								table[ o.send(idx) ] |= [ o ]
							}
							@objects[ o.objectStoreId ] = o
						}
						sync()
					}
				}
			end


			### retrieve
			def retrieve( *ids )
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					objs = ids.collect {|id| @objects[ id ]}
					return objs
				}
			end
			alias :[] :retrieve


			### retrieve_by_index
			def retrieve_by_index( key, val )
				lookup( key => val )
			end


			### retrieve_all
			def retrieve_all
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					return @objects.values
				}
			end


			### lookup
			def lookup( indexValuePairs )
				checkType( indexValuePairs, ::Hash )
				rset = []

				self.log.debug {""}
				@mutex.synchronize( Sync::SH ) {
					checkOpened()

					indexValuePairs.each {|idx,val|
						idx = idx.to_s.intern unless idx.is_a? Symbol
						raise IndexError, "No such index '#{idx.to_s}'" unless
							@indexes.key?( idx )
						subset = []
						
						# OR each specified value together, taking the union of all
						# search results.
						val = [ val ] unless val.is_a? Array
						val.each {|orVal|
							subset |= @indexes[idx][orVal]
						}
						
						# If the subset for this key => val pair doesn't contain
						# anything, then the search failed.
						if subset.empty?
							rset = []
							break
						end
						
						# If the rset doesn't have anything, it gets all
						# results. Otherwise, its ANDed with the most-current results.
						if rset.empty?
							rset.push( *subset )
						else
							rset &= subset
							break if rset.empty?
						end
					}
				}					

				return rset
			end


			### Close the backend.
			def close
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					sync()
					@opened = false
				}
			end


			### Returns true if an object with the specified <tt>id</tt> exists
			### in the backing store.
			def exists?( id )
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					@objects.keys.include?( id )
				}
			end


			### Returns true if the backend is open.
			def open?
				@opened
			end


			### Returns the number of objects in the backing store.
			def nitems
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					return @objects.keys.length
				}
			end


			### Clear the backing store of all objects.
			def clear
				@mutex.synchronize( Sync::SH ) {
					checkOpened()

					@mutex.synchronize( Sync::EX ) {
						@objects.clear
						@indexes.each_key {|idx| @indexes[idx].clear}
						sync()
					}
				}
			end


			### Add the specified <tt>indexes</tt>, which are Strings or Symbols
			### that represent methods to call on stored objects.
			def addIndexes( *indexes )
				@mutex.synchronize( Sync::SH ) {
					checkOpened()

					# Turn each index name into a symbol
					syms = indexes.collect {|idx| idx.to_s.intern}

					# Iterate over the keys; If the index hash doesn't already
					# contain it, add a sub-hash for that key.
					@mutex.synchronize( Sync::EX ) {
						syms.each {|idx|
							@indexes[ idx ] ||= Hash::new([])
						}
						
						sync()
					}
				}
			end


			### Return an Array of keys for the specified <tt>index</tt>.
			def indexKeys( index )
				raise MUES::IndexError, "No such index #{index}" unless self.hasIndex?( index )
				@indexes[index.to_s.intern].keys
			end

			
			### Returns <tt>true</tt> if the backing store has the specified
			### <tt>index</tt>, which can be either a String or a Symbol.
			def hasIndex?( index )
				@indexes.key?( index.to_s.intern )
			end



			#########
			protected
			#########

			### Check to be sure the backend is still open, raising an exception
			### if not.
			def checkOpened
				raise MUES::ObjectStoreError, "Cannot use a closed backend." unless self.open?
			end


			### Synchronize the objects in the in-memory table with the snapshot
			### on disk
			def sync
				self.log.info( "Syncing objectstore '#{@name}'" )
				@mutex.synchronize( Sync::EX ) {
					@store.transaction {|txn|
						txn['objects'] = @objects
						txn['indexes'] = @indexes
					}
				}
			end
		end # class FlatfileBackend

	end # class ObjectStore
end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore::FlatfileBackend class: A
# MUES::ObjectStore backend that uses PStore as its storage database.
# 
# == Synopsis
# 
#   require 'mues/ObjectStore'
#
#   os = MUES::ObjectStore::create( :backend => 'flatfile', ... )
#   ...
# 
# == Rcsid
# 
# $Id: flatfilebackend.rb,v 1.7 2003/04/24 14:59:36 deveiant Exp $
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

		### Flatfile ObjectStore backend.
		class FlatfileBackend < MUES::ObjectStore::Backend

			include MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
			Rcsid = %q$Id: flatfilebackend.rb,v 1.7 2003/04/24 14:59:36 deveiant Exp $

			### Create a new FlatfileBackend object.
			def initialize( name, indexes=[], configHash={} )
				checkType( name, ::String )
				raise MUES::BackendError, "No store name specified." if name.empty?

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

			### Drop the backing store for this backend
			def drop
				self.log.info( "Dropping objectstore '#{@name}'" )
				@mutex.synchronize( Sync::EX ) {
					self.close if self.open?
					File::delete( @name )
				}
			end


			### Store the specified <tt>objects</tt> in the database.
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


			### Retrieve the objects that have the specified <tt>ids</tt> from
			### the database and return them.
			def retrieve( *ids )
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					objs = ids.collect {|id| @objects[ id ]}
					return objs
				}
			end
			alias :[] :retrieve


			### Retrieve the object/s specified by the given <tt>key</tt> and
			### <tt>value</tt>. The specified <tt>key</tt> may be a Symbol or a
			### String, and must be a valid index.
			def retrieve_by_index( key, val )
				lookup( key => val )
			end


			### Fetch and return every object stored in the ObjectStore.
			def retrieve_all
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					return @objects.values
				}
			end


			### Given the <tt>indexValuePairs</tt> Hash, which contains index =>
			### lookup values pairs, return objects which match the equality
			### natural join of the pairs.
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


			### Remove and return the objects specified by the given
			### <tt>objects</tt> (which can be either objects or their ids) from
			### the backing store.
			def remove( *objects )
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					objects.each {|obj|
						@objects.delete( obj.objectStoreId )
					}
					sync()
				}
			end

			### Close the backend.
			def close
				@mutex.synchronize( Sync::SH ) {
					checkOpened()
					sync()
					@opened = false
				}
			end


			### Returns <tt>true</tt> if an object with the specified
			### <tt>id</tt> exists in the backing store.
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


# !/usr/bin/ruby -w
#
# This file contains the MUES::ObjectStore::ArunaDBBackend class: an ArunaDB-based
# backend for storing MUES::StorableObject objects in MUES.
#
# See the MUES::ObjectStore::Backend for more information.
#
# == Synopsis
#
#   require 'mues/objectstore'
#	$arunaOs = MUES::ObjectStore::new( 
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
# * Michael Granger <ged@FaerieMUD.org>
#
# == To Do
#
# * Add #indexKeys, #hasIndex?, and #addIndexes methods.
#
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "a_catalog" #arunadb file
require "a_table"   #arunadb file
require "a_index"   #arunadb file

require 'mues/objectstore'
require 'mues/storableobject'


module MUES
	class ObjectStore

	    ### The AruanaDB-based ObjectStore backend.
	    class ArundaDBBackend < MUES::ObjectStore::Backend
			include Sync_m

			### Class constants

			# SVN Revision
			SVNRev = %q$Rev$

			# SVN Id
			SVNId = %q$Id$

			# SVN URL
			SVNURL = %q$URL$

			A_Index.instance_eval { include Enumerable }
			A_Table.instance_eval { include Enumerable }

			# arguments:
			# [storename]   the filename to base the database file
			#               structure off of, can be directory.
			# [indexes]     a list of index name
			def initialize ( obj_store, storename, dump_undump, indexes = [] )
				@obj_store = obj_store
				@basename = storename
				@indexes = indexes
				@dump_undump = dump_undump
				@mutex = Sync.new
				setup_database()
			end

			#########
			protected
			#########

			# Does the detection/creation of a database, setting
			# @catalog, @table and @indexes.
			def setup_database()
				if File.exists?(@basename)

					@catalog = A_Catalog.use(filename)

					raise ObjectStoreError, 
						"The '#{@basename}' table does not exist in the catalog " +
						"contained in '#{filename}'." unless A_Table.exists?( @basename )
					# mostly happens when a database creation is
					# interupted in the middle

					@table = A_Table.connect( @basename )

					# :NEEDS: to put in grabbing all the A_Index
					# objects and checking for new ones that may have
					# been specified by the user

				else
					# create the database from scratch
					cat_name = @basename
					fs_name = @basename
					fs_filename = @basename + ".adb"
					bt_name = @basename
					table_name = @basename
					lck_name = @basename + "locks"
					locks_filename = lck_name + ".adb"

					@catalog  = A_Catalog.use(cat_name)
					fs   = A_FileStore.create(fs_name, 1024, fs_filename)
					locs = A_FileStore.create(lck_name, 1024, locks_filename)
					bt   = A_BTree.new(bt_name, fs_name)
					cols = []
					typ = "v"
					###################   name type not_nil default constraint action display
					cols << A_Column.new("id" , 'v', true  ,  nil  ,   nil    ,  nil ,  nil  )
					cols << A_Column.new("obj", 'v',  nil  ,  nil  ,   nil    ,  nil ,  nil  )
					if (@indexes && @indexes.length > 0) 
						@indexes.each { |ind|
							cols << A_Column.new( ind[0].id2name, 'v' )
						}
					end
					pkeys= "id"
					@table = A_Table.new(table_name, cols, pkeys, fs_name, lck_name)
					# add an A_Index object to @indexes for each entry
					if (@indexes && @indexes.length > 0)
						cols = ['id', 'obj']
						@indexes.each {|ind|
							cols.push( ind )
							@indexes[ind] = A_Index.new(ind, bt_name, cols, 'U', fs_name, lck_name)
							cols.pop
						}
					end
				end
			end

			######
			public
			######

			# the A_Table object
			attr_reader :table

			# the A_Catalog object
			attr_reader :catalog

			# the A_Index objects keyed to their names
			attr_reader :indexes

			### Stores the objects into the database
			### [arguments]
			###   objects - the objects to store
			### [caveats]
			###   aruna's docs say that while concurrant transactions work fine, their
			###   multi-threaded capabilities haven't been fully tested.  who knows what
			###   that's going to mean.
			def store ( *objects )
				(objects.kind_of?(Array)) ? objects.flatten! : (objects = [objects])
				raise("ObjectStore database not open.") unless (@table)
				index_names = @indexes.collect {|ind| ind[0].id2name}
				index_returns = objects.collect {|o|
					checkType( o, MUES::StorableObject )
					@indexes.collect {|ind|
						o.respond_to?(ind[0]) ? o.send(ind[0]) : nil
					}
				}
				ids = objects.collect {|o| o.objectStoreId}
				serialized = objects.collect {|o| @dump_undump.call(o)}
				@mutex.synchronize( Sync::EX ) {
					trans = A_Transaction.new
					col_names = ['id', 'obj'] + index_names
					ids.each_index do |i|
						if @table.exists?(trans, ids[i])
							#update(transaction, pkey, column_names, values)
							@table.update(trans, ids[i], col_names[1..-1],
										  [serialized[i], index_returns[i]].flatten)
						else
							@table.insert( trans, col_names,
										  [ids[i], serialized[i], index_returns[i]].flatten )
						end
					end
					trans.commit
				}
			end

			# Undumps and registers the string returned by @table
			def undump_register( *objstrs )
				@obj_store.register( a = objstrs.collect {|objstr|
										@dump_undump.call(objstr)
									} )
				return a
			end
			protected :undump_register

			# Gets an object out of storage, using the id string
			# provided.
			def retrieve ( *ids )
				undump_register( ids.collect {|id|
									@mutex.syncrhonize( Sync::SH ) {
										(td = @table.find(nil, id)) ? td.obj : nil
									} 
								} )
			end

			# Retrieves the object specified by the given id and value
			# using the index named.
			# Arguments:
			# [id]      the objectStoreId of the object
			# [index]   the name of the index to use
			# [value]   the value the object has in the specified index
			#           attribute
			def retrieve_by_index ( id, index )
				undump_register(@mutex.synchronize( Sync::SH ) {
									@indexes[index].find( nil, id )
								} )
			end

			# Retrieves all the objects in the database.
			def retrieve_all
				undump_register( @mutex.synchronize( Sync.SH ) {
									@table.each {|tdata|
										t_data.obj
									}
								} )
			end

			# Removes the specified objects from the database
			def remove ( *objects )
			    objects.flatten!
			    objects.compat!
			    trans = A_Transaction.new()
			    @mutex.synchronize( Sync::EX ) {
				objects.each {|o|
				    @table.delete(trans, o.objectStoreId)
				}
				trans.commit
			    }
			end

			# Closes the database
			def close()
				@table.close
				@catalog.close
				@table = @catalog = nil
			end

			# Checks to see if the given id is in the database
			def exists? ( an_id )
				checkType( an_id, String )
				@table.exists?(nil, an_id)
			end

			def empty?
				@table.nitems != 0
			end

			def open?
				! @table.nil?
			end

			def entries
				@table.nitems
			end

			def clear
				@table.clear
			end

			### Given a hash of index keys and values, fetch and return each object
			### that matches all of the specified pairs. Eg., assuming indexes of
			### <tt>'type'</tt> and <tt>'location'</tt>:
			###   foyerLights = ostore.lookup( :type => %w{candlestick lantern},
			###                                :location => 'foyer' )
			def lookup( index_pairs )
				checkType( index_pairs, Hash )
				
				tdatamap = {}
				
				rset = []
				index_pairs.each {|idx,val|
					subset = []
					
					# OR each specified value together, taking the union of all
					# search results.
					val.to_a.each {|orVal|
						subset |= @indexes[idx].each( nil, [nil, orVal], [nil, orVal] ) {|tdata|
							tdatamap[tdata.id] = tdata
							tdata.id
						}
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
				
				return dump_undump( rset )
			end

			

		end # class ArunaDBBackend

	end # class ObjectStore
end # module MUES

#!/usr/bin/ruby
# 
# This file contains the MUES::DBIBackend class, a derivative of
# (>>>superclass<<). RDBMS ObjectStore backend via DBI.
# 
# == Synopsis
# 
#   require 'mues/objectstore'
#
#   os = MUES::ObjectStore::create( 'foo', [], 'DBI', :backend => 'dbi:mysql:objectstore' )
#   ...
# 
# == Subversion ID
# 
# $Id$
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

require 'dbi'
require 'sync'
require 'pluginfactory'

require 'mues/object'
require 'mues/exceptions'
require 'mues/objectstore'
require 'mues/storableobject'
require 'mues/os-extensions/backend'


module MUES
class ObjectStore

	### RDBMS ObjectStore backend via DBI.
	class DBIBackend < Backend

		# Adapter class for bridging the gap between DBI and the functions
		# we need. Derivatives defined at the bottom of DBIBackend.rb, or
		# via user requires.
		class Adapter < MUES::Object ; implements MUES::AbstractClass
			include PluginFactory

			abstract :createDatabase,
				:createTable,
				:dropTable,
				:lock,
				:addIndexColumn,
				:delIndexColumn

		end # class Adapter


		include MUES::TypeCheckFunctions

		# SVN Revision
		SVNRev = %q$Rev$

		# SVN Id
		SVNId = %q$Id$

		# SVN URL
		SVNURL = %q$URL$


		# The default settings to use when connecting.
		DefaultConfig = {
			:username	=> 'mues',
			:password	=> 'mues',
			:preconnect	=> true,
		}

		### Class globals



		### Create a new DBIBackend object, where the specified
		### <tt>name</tt> is the DSN of the database to use. If the database
		### does not already exist, it will be created. The <tt>config</tt>
		### should contain the username and the password to use when
		### connecting (<tt>:username</tt> and <tt>:password</tt> keys) and
		### any other settings used by the adapter for the DBD specified by
		### the DSN.
		def initialize( name, indexes=[], config=DefaultConfig )
			checkType( indexes, ::Array )
			checkType( config, ::Hash )

			@dsn = name.to_s
			@indexes = indexes
			@config = config

			@username = config[:username] || DefaultConfig[:username]
			@password = config[:password] || DefaultConfig[:password]

			@adapter = nil
			@tablesUpToDate = false
			@indexesUpToDate = false

			self.log.debug "Connecting to '%s' as '%s'..." %
				[ @dsn, @username ]
			@adapter = self.getAdapter( @dsn, @username, @password )

			return true
		end


		######
		public
		######

		### Backend Interface

		### :TODO: This is copied over from the BerkeleyDB backend just to
		### provide a skeleton to work from for now. It obviously needs to
		### be changed to work with DBI.

		### Drop the backing store for this backend
		def drop
			self.close if self.open?
			self.log.notice( "Dropping backing store for '#@name'" )
			dropAllTables()
		end


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



		### End of Backend Interface

		#########
		protected
		#########



		### Adapter classes

		### An adapter class for Mysql.
		class MysqlAdapter < Adapter # :nodoc:

			CreateDatabaseSql = %q{ CREATE DATABASE %s; }

			CreateTableSql = %q{
			CREATE TABLE %s (
				id		VARCHAR(32)		NOT NULL PRIMARY KEY,	-- hexdigest.length
				ts		TIMESTAMP(14),
				class	VARCHAR(75)		NOT NULL,
				data	BLOB			NOT NULL,
			);
			}

		end # class MysqlAdapter

	end # class DBIBackend

end # class ObjectStore
end # module MUES


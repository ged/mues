#!/usr/bin/ruby
# 
# This file contains the MUES::ObjectStore class, which is a generic front end
# to various means of storing MUES objects. It uses one or more configurable
# back ends which serialize and store objects to some kind of storage medium
# (flat file, database, sub-atomic particle inference engine), and then later
# can restore and de-serialize them.
# 
# == Synopsis
# 
#   require "mues/ObjectStore"
#   require "mues/Config"
#   oStore = MUES::ObjectStore.new( MUES::Config.new("MUES.cfg") )
# 
#   objectIds = oStore.storeObjects( obj ) {|obj|
#		$stderr.puts "Stored object #{obj}"
#   }
# 
# == Rcsid
# 
# $Id: ObjectStore.rb,v 1.12 2002/04/01 16:15:33 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "find"

require "mues"
require "mues/Events"
require "mues/Exceptions"
require "mues/User"

module MUES

	### Exception class that is raised if a MUES::ObjectStore is asked to fetch
	### an object that doesn't exist in it's store.
	def_exception :NoSuchObjectError,	"No such object",	Exception

	### Exception class that is raised if a MUES::ObjectStore is asked to use a
	### storage adapter that it doesn't know about.
	def_exception :UnknownAdapterError, "No such adapter",	Exception

	### Object store class: Stores serialized MUES objects.
	class ObjectStore < Object ; implements MUES::Debuggable

		autoload :Adapter, "mues/adapters/Adapter"
		include MUES::Event::Handler

		### Class Constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.12 $ )[1]
		Rcsid = %q$Id: ObjectStore.rb,v 1.12 2002/04/01 16:15:33 deveiant Exp $

		AdapterSubdir = 'mues/adapters'
		AdapterPattern = /#{AdapterSubdir}\/(\w+Adapter).rb$/	#/

		### Class variables
		@@AdaptersAreLoaded = false
		@@Adapters = nil

		### Create and return a new ObjectStore based on the values in the
		### specified configuration object. If the specified <tt>driver</tt>
		### cannot be loaded, an <tt>UnknownAdapterError</tt> exception is
		### raised.
		def initialize( config )
			super()
			@dbAdapter = ObjectStore::getAdapter( config )
		end


		### Class methods
		class << self

			######
			public
			######

			### Returns true if the object store has an adapter class named
			### +name+.
			def hasAdapter?( name )
				return _getAdapterClass( name ).is_a?( Class )
			end


			### Get a new back-end adapter object for the driver specified by
			### +config['objectstore']['driver']+.
			def getAdapter( config )
				_loadAdapters()
				driver = config["objectstore"]["driver"]
				klass = _getAdapterClass( driver )
				raise UnknownAdapterError, "Could not fetch adapter class '#{driver}'" unless klass
				klass.new( config )
			end


			#########
			protected
			#########

			### Search for adapters in the subdir specified in the AdapterSubdir
			### class constant, attempting to load each one.
			def _loadAdapters
				return true if @@AdaptersAreLoaded

				@@Adapters = {}

				### Iterate over each directory in the include path, looking for
				### files which match the adapter class filename pattern. Add
				### the ones we find to a hash.
				$:.collect {|dir| "#{dir}/#{AdapterSubdir}"}.each do |dir|
					unless FileTest.exists?( dir ) &&
							FileTest.directory?( dir ) &&
							FileTest.readable?( dir )
						next
					end
						
					Find.find( dir ) {|f|
						next unless f =~ AdapterPattern
						@@Adapters[ $1 ] = false
					}
				end

				### Now for each potential adapter class that we found above,
				### try to require each one in turn. Mark those that load in the
				### hash.
				@@Adapters.each_pair {|name,loaded|
					next if loaded
					begin
						require "#{AdapterSubdir}/#{name}"
					rescue ScriptError => e
						$stderr.puts "Failed to load adapter '#{name}': #{e.to_s}"
						next
					end
		
					@@Adapters[ name ] = true
				}

				@@AdaptersAreLoaded = true
				return @@Adapters
			end


			### Returns the adapter class associated with the specified +name+,
			### or +nil+ if the class is not registered with the ObjectStore.
			def _getAdapterClass( name )
				_loadAdapters()
				MUES::ObjectStore::Adapter.getAdapterClass( name )
			end

		end


		######
		public
		######

		### Fetch the objects associated with the given <tt>objectIds</tt> from the
		### objectstore and call <tt>awaken()</tt> on them if they respond to such
		### a method. If the optional <tt>block</tt> is specified, it is used as an
		### iterator, being called with each new object in turn. If the block is
		### specified, this method returns the array of the results of each
		### call; otherwise, the fetched objects are returned.
		def fetchObjects( *objectIds )
			@dbAdapter.fetchObjects( *objectIds ).collect {|obj|
				obj.awaken if obj.respond_to?( :awaken )
				obj = yield( obj ) if block_given?
				obj
			}
		end


		### Store the given <tt>objects</tt> in the ObjectStore after calling
		### <tt>lull()</tt> on each of them, if they respond to such a method. If
		### the optional <tt>block</tt> is given, it is used as an iterator by
		### calling it with each object id after the objects are stored, and
		### then returning the results of each call in an Array. If no block is
		### given, the object ids are returned.
		def storeObjects( *objects )
			objects.each {|o| o.lull if o.respond_to?( :lull )}
			@dbAdapter.storeObjects( *objects ).collect {|oid|
				oid = yield( oid ) if block_given?
				oid
			}
		end


		### Return true if the ObjectStore contains an object associated with
		### the specified <tt>id</tt>.
		def hasObject?( id )
			return @dbAdapter.hasObject?( id )
		end

		
		### Return an array of all ids matching the specified +pattern+ (a
		### Regexp object), or all ids if no pattern is specified.
		def findIds( pattern=%r{.*} )
			return @dbAdapter.findIds( pattern )
		end

	end
end



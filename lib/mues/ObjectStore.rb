#!/usr/bin/ruby
#################################################################
=begin 

=ObjectStore.rb

== Name

ObjectStore - An object persistance abstraction class

== Synopsis

  require "mues/ObjectStore"
  oStore = ObjectStore.new( "MySQL", "faeriemud", "localhost", "fmuser", "fmpass" )

  objectIds = oStore.storeObjects( obj ) {|obj|
	$stderr.puts "Stored object #{obj}"
  }

  user = oStore.fetchUser( "login" )

  banTable = oStore.getBanTable
  allowTable = oStore.getAllowTable

== Description

This class is a generic front end to various means of storing MUES objects. It
uses one or more configurable back ends which serialize and store objects to
some kind of storage medium (flat file, database, sub-atomic particle inference
engine), and then later can restore and de-serialize them.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000-2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "find"

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/User"

module MUES

	### Exception classes
	def_exception :NoSuchObjectError,	"No such object",	Exception
	def_exception :UnknownAdapterError, "No such adapter",	Exception

	### Object store class
	class ObjectStore < Object ; implements Debuggable

		include Event::Handler
		autoload "MUES::ObjectStore::Adapter", "mues/adapters/Adapter"

		### Class Constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid = %q$Id: ObjectStore.rb,v 1.8 2001/07/30 11:51:06 deveiant Exp $

		AdapterSubdir = 'mues/adapters'
		AdapterPattern = /#{AdapterSubdir}\/(\w+Adapter).rb$/	#/

		### Class attributes
		@@AdaptersAreLoaded = false
		@@Adapters = nil

		### Class methods
		class << self

			protected

			### (PROTECTED CLASS) METHOD: _loadAdapters
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

			### (PROTECTED CLASS) METHOD: _getAdapterClass( name )
			### Returns the adapter class associated with the specified
			### ((|name|)), or (({nil})) if the class is not registered with the
			### ObjectStore.
			def _getAdapterClass( name )
				_loadAdapters()
				MUES::ObjectStore::Adapter.getAdapterClass( name )
			end

			public

			### (CLASS) METHOD: _hasAdapter?( name )
			### Returns true if the object store has an adapter class named
			### ((|name|)).
			def hasAdapter?( name )
				return _getAdapterClass( name ).is_a?( Class )
			end

			### (CLASS) METHOD: getAdapter( driver, db, host, user, password )
			### Get a new back-end adapter object for the specified
			### ((|driver|)), ((|db|)), ((|host|)), ((|user|)), and
			### ((|password|)).
			def getAdapter( driver, db, host, user, password )
				_loadAdapters()
				klass = _getAdapterClass( driver )
				raise UnknownAdapterError, "Could not fetch adapter class '#{driver}'" unless klass
				klass.new( db, host, user, password )
			end
		end

		### (PROTECTED) METHOD: initialize( driver="Bdb", db="mues", host, user, password )
		### Initialize a new ObjectStore with the specified arguments. If the
		### specified ((|driver|)) cannot be loaded, an
		### (({UnknownAdapterError})) exception is raised.
		def initialize( driver = "Bdb", db = "mues", host = nil, user = nil, password = nil )
			super()
			@dbAdapter = self.class.getAdapter( driver, db, host, user, password )
		end

		### METHOD: fetchObjects( *objectIds ) { |obj| block } -> objects=Array
		### Fetch the objects associated with the given ((|objectIds|)) from the
		### objectstore and call (({awaken()})) on them if they respond to such
		### a method. If the optional ((|block|)) is specified, it is used as an
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

		### METHOD: storeObjects( *objects ) { |oid| block }-> oids=Array
		### Store the given ((|objects|)) in the ObjectStore after calling
		### (({lull()})) on each of them, if they respond to such a method. If
		### the optional ((|block|)) is given, it is used as an iterator by
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

		### METHOD: hasObject?( id )
		### Return true if the ObjectStore contains an object associated with
		### the specified ((|id|)).
		def hasObject?( id )
			return @dbAdapter.hasObject?( id )
		end

		### METHOD: fetchUser( username ) { |obj| block } -> User
		### Returns a user object for the username specified unless the
		### optional code block is given, in which case it will be passed the
		### user object as an argument. When the block exits, the user
		### object will be automatically stored and de-allocated, and (({true}))
		### is returned if storing the user object succeeded. If the user
		### doesn't exist, (({ObjectStore.fetchUser})) returns (({nil})).
		def fetchUser( username )
			checkType( username, ::String )
			userData = @dbAdapter.fetchUserData( username )
			return nil if userData.nil?

			user = User.new( userData )

			if block_given?
				yield( user )
				storeUser( user )
				return nil
			else
				return user
			end
		end

		### METHOD: storeUser( user=MUES::User ) -> true
		### Store the given ((|user|)) in the datastore, returning (({true})) on
		### success.
		def storeUser( aUser )
			checkType( aUser, MUES::User )
			_debugMsg( 2, "Storing user: #{aUser.to_s}" )
			newDbInfo = @dbAdapter.storeUserData( aUser.username, aUser.dbInfo )
			_debugMsg( 2, "Done storing user: #{aUser.to_s}" )
			aUser.dbInfo = newDbInfo

			return true
		end

		### METHOD: createUser( username, role ) { |obj| block } -> User
		### Returns a new MUES::User object with the permissions specified by
		### ((|role|)) for the given ((|username|)). If the optional ((|block|))
		### is given, it will be passed the user object as an argument. When the
		### block exits, the user object will be automatically stored and
		### de-allocated. In this case, (({ObjectStore.fetchUser})) returns
		### (({true})).If no block is given, the new MUES::User object is
		### returned.
		def createUser( username, role=MUES::User::Role::USER )
			userData = @dbAdapter.createUserData( username )

			user = User.new( userData )

			if block_given?
				yield( user )
				storeUser( user )
				return true
			else
				return user
			end
		end
		
		### METHOD: deleteUser( username )
		### Deletes the user associated with the specified ((|username|)) from
		### the objectstore.
		def deleteUser( username )
			@dbAdapter.deleteUserData( username )
		end
		

	end
end



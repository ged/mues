#!/usr/bin/ruby
#################################################################
=begin 

=ObjectStore.rb

== Name

ObjectStore - An object persistance abstraction class

== Synopsis

  require "mues/ObjectStore"
  require "mues/Config"
  oStore = MUES::ObjectStore.new( MUES::Config.new("MUES.cfg") )

  objectIds = oStore.storeObjects( obj ) {|obj|
	$stderr.puts "Stored object #{obj}"
  }

  user = oStore.fetchUser( "login" )

== Description

This class is a generic front end to various means of storing MUES objects. It
uses one or more configurable back ends which serialize and store objects to
some kind of storage medium (flat file, database, sub-atomic particle inference
engine), and then later can restore and de-serialize them.

== Classes
=== MUES::ObjectStore
==== Class Methods

--- MUES::ObjectStore.hasAdapter?( name )

    Returns true if the object store has an adapter class named ((|name|)).

--- MUES::ObjectStore.getAdapter( driver, db, host, user, password )

    Get a new back-end adapter object for the specified ((|driver|)), ((|db|)),
    ((|host|)), ((|user|)), and ((|password|)).

==== Protected Class Methods

--- MUES::ObjectStore._getAdapterClass( name )

    Returns the adapter class associated with the specified ((|name|)), or
    (({nil})) if the class is not registered with the ObjectStore.

--- MUES::ObjectStore._loadAdapters

    Search for adapters in the subdir specified in the (({AdapterSubdir})) class
    constant, attempting to load each one.

==== Public Methods

--- MUES::ObjectStore#createUser( username ) { |obj| block } -> User

    Returns a new MUES::User object for the given ((|username|)). If the
    optional ((|block|)) is given, it will be passed the user object as an
    argument. When the block exits, the user object will be automatically stored
    and de-allocated. In this case, (({ObjectStore.fetchUser})) returns
    (({true})). If no block is given, the new MUES::User object is returned.

--- MUES::ObjectStore#deleteUser( username )

    Deletes the user associated with the specified ((|username|)) from the
    objectstore.

--- MUES::ObjectStore#fetchObjects( *objectIds ) { |obj| block } -> objects=Array

    Fetch the objects associated with the given ((|objectIds|)) from the
    objectstore and call (({awaken()})) on them if they respond to such a
    method. If the optional ((|block|)) is specified, it is used as an iterator,
    being called with each new object in turn. If the block is specified, this
    method returns the array of the results of each call; otherwise, the fetched
    objects are returned.

--- MUES::ObjectStore#fetchUser( username ) { |obj| block } -> User

    Returns a user object for the username specified unless the optional code
    block is given, in which case it will be passed the user object as an
    argument. When the block exits, the user object will be automatically stored
    and de-allocated, and (({true})) is returned if storing the user object
    succeeded. If the user doesn^t exist, (({ObjectStore.fetchUser})) returns
    (({nil})).

--- MUES::ObjectStore#getUserList()

    Returns an array of usernames that exist in the objectstore

--- MUES::ObjectStore#hasObject?( id )

    Return true if the ObjectStore contains an object associated with the
    specified ((|id|)).

--- MUES::ObjectStore#storeObjects( *objects ) { |oid| block }-> oids=Array

    Store the given ((|objects|)) in the ObjectStore after calling (({lull()}))
    on each of them, if they respond to such a method. If the optional
    ((|block|)) is given, it is used as an iterator by calling it with each
    object id after the objects are stored, and then returning the results of
    each call in an Array. If no block is given, the object ids are returned.

--- MUES::ObjectStore#storeUser( user=MUES::User ) -> true

    Store the given ((|user|)) in the datastore, returning (({true})) on
    success.

==== Protected Methods

--- MUES::ObjectStore#initialize( config=MUES::Config )

    Initialize a new ObjectStore based on the values in the specified
    configuration. If the specified ((|driver|)) cannot be loaded, an
    (({UnknownAdapterError})) exception is raised.

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

		autoload :Adapter, "mues/adapters/Adapter"
		include Event::Handler

		### Class Constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.11 $ )[1]
		Rcsid = %q$Id: ObjectStore.rb,v 1.11 2001/12/05 18:07:41 deveiant Exp $

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

			### (CLASS) METHOD: hasAdapter?( name )
			### Returns true if the object store has an adapter class named
			### ((|name|)).
			def hasAdapter?( name )
				return _getAdapterClass( name ).is_a?( Class )
			end

			### (CLASS) METHOD: getAdapter( config=MUES::Config )
			### Get a new back-end adapter object for the driver specified by the ((|config|)).
			def getAdapter( config )
				_loadAdapters()
				driver = config["objectstore"]["driver"]
				klass = _getAdapterClass( driver )
				raise UnknownAdapterError, "Could not fetch adapter class '#{driver}'" unless klass
				klass.new( config )
			end
		end

		### (PROTECTED) METHOD: initialize( config=MUES::Config )
		### Initialize a new ObjectStore based on the values in the specified
		### configuration object. If the specified ((|driver|)) cannot be
		### loaded, an (({UnknownAdapterError})) exception is raised.
		def initialize( config )
			super()
			@dbAdapter = ObjectStore::getAdapter( config )
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

		### METHOD: createUser( username ) { |obj| block } -> User
		### Returns a new MUES::User object with the given ((|username|)). If
		### the optional ((|block|)) is given, it will be passed the user object
		### as an argument. When the block exits, the user object will be
		### automatically stored and de-allocated. In this case,
		### (({ObjectStore.fetchUser})) returns (({true})).If no block is given,
		### the new MUES::User object is returned.
		def createUser( username )
			userData = @dbAdapter.createUserData( username )

			user = User.new( userData )
			user.username = username

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
		
		### METHOD: getUserList()
		### Returns an array of usernames that exist in the objectstore
		def getUserList
			@dbAdapter.getUsernameList()
		end

	end
end



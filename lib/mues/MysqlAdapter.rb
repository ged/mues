#!/usr/bin/ruby
#################################################################
=begin

=MysqlAdapter.rb

== Name

MysqlAdapter - A MySQL ObjectStore adapter class

== Synopsis

  require "mues/ObjectStore"

  oStore = MUES::ObjectStore.new( "Mysql", "db", "localhost", "user", "pass" )
  oStore.storeObjects( obj )

== Description

An adapter class for a Mysql-based MUES objectstore.

== Classes
=== MUES::ObjectStore::MysqlAdapter
==== Constructor

--- MUES::ObjectStore::MysqlAdapter.new( config )

    Initialize the adapter with the configuration values in the specified
    ((|config|)) object. This shouldn^t be called directly -- the
    ((<MUES::ObjectStore>)) class will call it for you if the driver argument to
    its constructor is 'Mysql'.

==== Public Methods

--- MUES::ObjectStore::MysqlAdapter#useTableLocks

    Return the value of the useTableLocks attribute.

--- MUES::ObjectStore::MysqlAdapter#storeObject( *objects )

    Store the specified objects in the datastore.

--- MUES::ObjectStore::MysqlAdapter#fetchObjects( *oids )

    Fetches and returns the objects from the datastore

--- MUES::ObjectStore::MysqlAdapter#hasObject?( id )

    Check to see if an object with the muesid specified exists in
    the object table

--- MUES::ObjectStore::MysqlAdapter#storeUserData( userName, dbInfo )

    Store the data for the specified user object, returning the
    (possibly modified) database info object.

--- MUES::ObjectStore::MysqlAdapter#fetchUserData( username )

    Fetch the hash of user data for the specified user

--- MUES::ObjectStore::MysqlAdapter#createUserData( username )

    Create a new hash of user data for the specified user

--- MUES::ObjectStore::MysqlAdapter#deleteUserData( username )

    Delete the hash of user data from the database for the specified user

--- MUES::ObjectStore::MysqlAdapter#getUsernameList

    Returns an array of the names of the stored user records.

==== Private Methods

--- MUES::ObjectStore::MysqlAdapter#__prepFieldValue( key, val )

    Return a database-safe value for the given value

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "sync"

require "tableadapter/Mysql"
require "tableadapter/Search"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/User"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class MysqlAdapter < Adapter

			include Debuggable

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
			Rcsid = %q$Id: MysqlAdapter.rb,v 1.7 2001/11/01 17:21:26 deveiant Exp $

			PlainUserFields = MUES::User::DefaultDbInfo.find_all {|field, defaultVal|
				!defaultVal.is_a?( Array ) && !defaultVal.is_a?( Hash )
			}.collect {|ary| ary[0]}
			MarshalledUserFields = MUES::User::DefaultDbInfo.find_all {|field, defaultVal|
				defaultVal.is_a?( Array ) || defaultVal.is_a?( Hash )
			}.collect {|ary| ary[0]}

			### Class variables
			@@ObjectTable	= 'object'
			@@UserTable		= 'muesuser'
			@@DenyTable		= 'deny'
			@@AllowTable	= 'allow'

			### Turn off warnings about method classes
			TableAdapter.printMethodClashWarnings = false

			#########################################################
			###	P R O T E C T E D   M E T H O D S
			#########################################################
			protected

			### (PROTECTED) METHOD: initialize( config )
			### Initialize the adapter with the values specified in the given ((|config|)) object.
			def initialize( config )
				super( config )

				@db = @config['db']
				@user = @config['username']
				@password = @config['password']
				@host = @config['host']

				@useTableLocks	= false

				@objectAdapterClass = TableAdapterClass( @db, @@ObjectTable, @user, @password, @host )
				@userAdapterClass	= TableAdapterClass( @db, @@UserTable, @user, @password, @host )
				@denyAdapterClass	= TableAdapterClass( @db, @@DenyTable, @user, @password, @host )
				@allowAdapterClass	= TableAdapterClass( @db, @@AllowTable, @user, @password, @host )

				@lock = { 'user' => Sync.new, 'object' => Sync.new }
			end


			#########################################################
			###	P U B L I C   M E T H O D S
			#########################################################
			public

			### Attribute accessors
			attr_accessor	:useTableLocks

			### METHOD: storeObject( *objects )
			def storeObjects( *objects )
				checkEachType( objects, MUES::Object )
				errors = []
				oids = []

				@lock['object'].synchronize(Sync::EX) {

					# Separate the objects which need updating from those which
					# need an insert. We assume that any object with a non-nil
					# objectStoreData attribute has come from a database record.
					updateObjects = objects.find_all {|obj| ! obj.objectStoreData.nil?}
					insertObjects = objects - updateObjects

					if updateObjects.length.nonzero?
						# Fetch the corresponding rows
						updateRows = @objectAdapterClass.lookup( updateObjects.collect {|obj| obj.objectStoreData} )

						# Iterate over each row object, serialize the corresponding
						# object into it, and storing it
						updateRows.each_index {|i|
							raise AdapterError,
								"Row object is not a TableAdapter while storing #{updateObjects[i].inspect}" unless
								updateRows[i].is_a?( TableAdapter )
							raise AdapterError,
								"Object's muesid (#{updateObjects[i].muesid}) doesn't match " +
								"its row's muesid field (#{updateRows[i].muesid})." unless
								updateObjects[i].muesid == updateRows[i].muesid
							
							updateRows[i].data = Marshal.dump( updateObjects[i] )
							updateRows[i].store
						}
					end

					if insertObjects.length.nonzero?
						# Now create new row objects for each new record and insert them.
						insertObjects.each {|obj|
							$stderr.puts( "" )
							row = @objectAdapterClass.new
							row.muesid	= obj.muesid
							row.data	= Marshal.dump( obj )
							row.store

							obj.objectStoreData = row.id
						}
					end
				}

				return objects.collect {|o| o.objectStoreData}
			end


			### METHOD: fetchObjects( *oids )
			### Fetches and returns the objects from the datastore
			def fetchObjects( *oids )
				search = TableAdapter::Search.new( 'muesid' => oids )
				
				return search.collect {|row|
					obj = Marshal.restore( row.data )
					obj.objectStoreData = row.id
					obj
				}
			end


			### METHOD: hasObject?( id )
			### Check to see if an object with the muesid specified exists in
			### the object table
			def hasObject?( id )
				escId = @objectAdapterClass.quoteValuesForField( 'muesid', id )

				# :TODO: This depends on the adapter being a MySQL adapter.  It
				# shouldn't do so, of course, but I've yet to implement the
				# DBI-ish TableAdapter. And (yuck), there's a hardcoded field
				# name in two places... and... and...
				dbh = @objectAdapterClass.dbHandle
				res = dbh.query( "SELECT COUNT(*) FROM #{@@ObjectTable} WHERE muesid = '#{escId}'" )
				row = res.fetch_row
				return !row.nil? && row[0] > 0
			end


			### METHOD: storeUserData( userName, dbInfo )
			### Store the data for the specified user object, returning the
			### (possibly modified) database info object.
			def storeUserData( userName, dbInfo )

				# Check the type of the info object. If it's a table adapter,
				# just store it. If it's a hash, convert it to a table adapter
				# and store it. Anything else raises an exception.
				case dbInfo
				when TableAdapter
					dbInfo.username = userName
					@lock['user'].synchronize( Sync::EX ) { dbInfo.store }
					return dbInfo

				when Hash
					@lock['user'].synchronize( Sync::EX ) { 
						userRow = @userAdapterClass.new
						(PlainUserFields + MarshalledUserFields).each {|key|
							userRow.send( "#{key}=", dbInfo[key] )
						}

						userRow.username = userName
						userRow.store
						return userRow
					}
				else
					raise AdapterError, "Cannot convert a #{dbInfo.type.name} to a MysqlAdapter"
				end
					
			end


			### METHOD: fetchUserData( username )
			### Fetch the hash of user data for the specified user
			def fetchUserData( username )
				checkType( username, String )

				userData = nil
				@lock['user'].synchronize( Sync::SH ) {
					search = TableAdapter::Search.new( @userAdapterClass, 'username' => username )
					userData = search[0]
				}

				return userData
			end


			### METHOD: createUserData( username )
			### Create a new hash of user data for the specified user
			def createUserData( username )
				checkType( username, String )

				@lock['user'].synchronize( Sync::SH ) {
					raise AdapterError, "A user with the username '#{username}' already exists" unless
						fetchUserData( username ).nil?

					storeUserData( username, MUES::User::DefaultDbInfo.dup )
				}
			end


			### METHOD: deleteUserData( username )
			### Delete the hash of user data from the database for the specified user
			def deleteUserData( username )
				checkType( username, String )

				@lock['user'].synchronize( Sync::SH ) {
					record = fetchUserData( username )
					raise AdapterError, "No user with the username '#{username}' exists" if
						record.nil?

					@lock['user'].synchronize( Sync::EX ) {
						record.delete
					}
				}
			end


			### METHOD: getUsernameList
			### Returns an array of the names of the stored user records.
			def getUsernameList
				names = []

				# :TODO: Same thing as hasObject?
				dbh = @objectAdapterClass.dbHandle
				res = dbh.query( "SELECT username FROM #{@@UserTable}" )
				res.each {|row| names.push row[0]}
				return names.sort
			end


			#########################################################
			###	P R I V A T E   M E T H O D S
			#########################################################
			private

			### (PRIVATE) METHOD: __prepFieldValue( key, val )
			### Return a database-safe value for the given value
			def __prepFieldValue( key, val )
				case val
				when ::String, ::Numeric, ::Time
					val

				when ::Hash, ::Array
					Marshal.dump(val)

				else
					raise AdapterError, "Attempt to store a #{val.type.name} in a user #{key} field"
				end
			end

		end # Class MysqlAdapter
	end # Class ObjectStore
end # Module MUES

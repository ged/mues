#!/usr/bin/ruby
###########################################################################
=begin

=BdbAdapter.rb

== Name

BdbAdapter - A Berkeley DB ObjectStore adapter class

== Synopsis

  require "mues/ObjectStore"
  oStore = ObjectStore.new( "Bdb", "faeriemud", "localhost", "fmuser", "fmpass" )

  objectId = oStore.storeObjects( obj )

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "bdb"
require "thread"
require "ftools"
require "sync"

require "mues/Namespace"
require "mues/Exceptions"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class BdbAdapter < Adapter

			include Debuggable

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
			Rcsid = %q$Id: BdbAdapter.rb,v 1.5 2001/07/18 02:01:44 deveiant Exp $
			DirectoryName = 'objectstore-bdb'

			### Class variables
			@@Sections = %w{object player ban allow}

			### METHOD: new( db, host, user, password )
			### Creates a new BerkeleyDB ObjectStore adapter. Only the 'db'
			### argument is used.
			def initialize( db, *ignored )

				# If the BDB objectstore directory doesn't yet exist, make it
				unless File.directory?( DirectoryName )
					Dir.mkdir( DirectoryName )
				end

				# Initialize attributes
				@env	= BDB::Env.new( DirectoryName, BDB::CREATE|BDB::INIT_TRANSACTION )
				@db		= db
				@dbh	= {}
				@@Sections.each {|key| @dbh[key] = @env.open_db( BDB::HASH, @db, key, BDB::CREATE )}
				@lock	= {}
				@@Sections.each {|key| @lock[key] = Sync.new}

				true
			end


			### METHOD: storeObject( *objects )
			### Store the specified objects in the database
			def storeObjects( *objects )
				oids = []

				### Iterate over the objects, getting an id and marshalling each
				### one, and then doing a synchronized store into the database
				objects.each {|obj|
					raise AdapterError, "Cannot store a non-MUES object" unless
						obj.is_a?( MUES::Object )

					### Fetch the object's unique id, and check for sane values
					oid = '%s:%s' % [ obj.class.name, obj.muesid ]
					if oid !~ /\S+/
						raise AdapterError, "Object has no muesid. Perhaps it needs super() in its initialize()?"
					end

					### Dump the object and store it
					rawObj = Marshal.dump(obj)
					@lock['object'].synchronize(Sync::EX) {
						@dbh['object'].store( oid, rawObj )
					}

					oids.push oid
				}

				return oids
			end


			### METHOD: fetchObjects( *oids )
			### Fetch objects with the specified ids from the database and return them
			def fetchObjects( *oids )
				objects = []

				### Iterate over each id, re-instantiating each corresponding
				### object
				oids.each {|oid|
					@lock['object'].synchronize(Sync::SH) {
						rawObj = @dbh['object'].fetch( oid )
					}

					obj = Marshal.restore(rawObj)
					objects.push obj
				}

				return objects
			end


			### METHOD: hasObject?( id )
			### Returns true if an entry with the specified id exists in the database
			def hasObject?( id )
				@lock['object'].synchronize(Sync::SH) {
					return @dbh['object'].has_key?( id )
				}
			end


			### METHOD: storePlayerData( username, playerDataHash )
			### Store the specified hash of player data for the specified user
			def storePlayerData( username, data )
				checkType( username, String )
				checkType( data, Hash )

				data['username'] = username
				frozenData = Marshal.dump( data )
				@lock['player'].synchronize(Sync::EX) {
					@dbh['player'].store( username, frozenData )
				}

				return data
			end


			### METHOD: fetchPlayerData( username )
			### Fetch the hash of player data for the specified user
			def fetchPlayerData( username )
				checkType( username, String )

				frozenData = @lock['player'].synchronize(Sync::SH) {
					@dbh['player'].fetch( username )
				}
				return nil if frozenData.nil?
				return Marshal.restore( frozenData )
			end


			### METHOD: createPlayerData( username )
			### Create a new hash of player data with the specified username
			def createPlayerData( username )
				checkType( username, String )

				@lock['player'].synchronize(Sync::SH) {
					raise AdapterError, "A player with the name '#{username}' already exists." if
						@dbh['player'].has_key?( username )

					storePlayerData( username, MUES::Player::DefaultDbInfo.dup )
				}
			end


			### METHOD: deletePlayerData( username )
			### Delete the hash of player data for the specified username
			def deletePlayerData( username )
				checkType( username, String )

				@lock['player'].synchronize(Sync::SH) {
					raise AdapterError, "No player with the name '#{username}' exists." unless
						@dbh['player'].has_key?( username )

					@lock['player'].synchronize(Sync::EX) {
						@dbh['player'].delete( username )
					}
				}
			end

		end # Class BdbAdapter
	end # Class ObjectStore
end # Module MUES

#!/usr/bin/ruby
###########################################################################
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

  player = oStore.fetchPlayer( "login" )

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
###########################################################################

require "find"

require "mues/Namespace"
require "mues/Events"
require "mues/Exceptions"
require "mues/Debugging"
require "mues/Player"

module MUES

	### NoSuchObjectError (Exception class)
	class NoSuchObjectError < Exception; end
	class UnknownAdapterError < Exception; end

	### Object store class
	class ObjectStore < Object ; implements Debuggable

		include Event::Handler

		### Class Constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.6 $ )[1]
		Rcsid = %q$Id: ObjectStore.rb,v 1.6 2001/06/25 14:09:26 deveiant Exp $

		AdapterSubdir = 'mues/adapters'
		AdapterPattern = /#{AdapterSubdir}\/(\w+Adapter).rb$/	#/

		### Class attributes
		@@AdaptersAreLoaded = false
		@@Adapters = nil

		### Class methods
		class << self

			### (CLASS) METHOD: _loadAdapters
			### Search for adapters in the subdir specified in the AdapterSubdir
			### class constant, attempting to load each one.
			def _loadAdapters
				return true if @@AdaptersAreLoaded

				@@Adapters = {}
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

			### (CLASS) METHOD: _hasAdapter?( name )
			def _hasAdapter?( name )
				klass = _getAdapterClass( name )
				return true if klass.is_a?( Class )
				return false
			end

			### (CLASS) METHOD: _getAdapterClass( name )
			def _getAdapterClass( name )
				_loadAdapters()
				ObjectSpace.each_object( Class ) {|klass|
					if klass.name == "#{name}Adapter" || klass.name == "MUES::ObjectStore::#{name}Adapter"
						return klass
					end
				}
				return nil
			end

			### (CLASS) _getAdapter( driver, db, host, user, password )
			def _getAdapter( driver, db, host, user, password )
				_loadAdapters()
				klass = _getAdapterClass( driver )
				raise UnknownAdapterError, "Could not fetch adapter class '#{driver}'" unless klass
				klass.new( db, host, user, password )
			end
		end

		### METHOD: initialize( driver="Bdb", db="mues", host, user, password )
		def initialize( driver = "Bdb", db = "mues", host = nil, user = nil, password = nil )
			super()
			@dbAdapter = self.class._getAdapter( driver, db, host, user, password )
		end

		### METHOD: fetchObjects( *objectIds ) { |obj| block } -> objects=Array
		def fetchObjects( *objectIds )
			@dbAdapter.fetchObjects( *objectIds ).collect {|obj|
				obj.awaken if obj.respond_to?( :awaken )
				obj = yield( obj ) if block_given?
				obj
			}
		end

		### METHOD: storeObjects( *objects ) { |oid| block }-> oids=Array
		def storeObjects( *objects )
			objects.each {|o| o.lull if o.respond_to?( :lull )}
			@dbAdapter.storeObjects( *objects ).collect {|oid|
				oid = yield( oid ) if block_given?
				oid
			}
		end

		### METHOD: hasObject?( id )
		def hasObject?( id )
			return @dbAdapter.hasObject?( id )
		end

		### METHOD: fetchPlayer( username ) { |obj| block } -> Player
		### Returns a player object for the username specified unless the
		### optional code block is given, in which case it will be passed the
		### player object as an argument. When the block exits, the player
		### object will be automatically stored and de-allocated, and (({true}))
		### is returned if storing the player object succeeded. If the player
		### doesn't exist, (({ObjectStore.fetchPlayer})) returns (({nil})).
		def fetchPlayer( username )
			checkType( username, ::String )
			playerData = @dbAdapter.fetchPlayerData( username )
			return nil if playerData.nil?

			player = Player.new( playerData )

			if block_given?
				yield( player )
				storePlayer( player )
				return nil
			else
				return player
			end
		end

		### METHOD: storePlayer( player )
		### Store the given player in the datastore, returning true on success
		def storePlayer( aPlayer )
			checkType( aPlayer, MUES::Player )
			_debugMsg( 2, "Storing player: #{aPlayer.to_s}" )
			newDbInfo = @dbAdapter.storePlayerData( aPlayer.username, aPlayer.dbInfo )
			_debugMsg( 2, "Done storing player: #{aPlayer.to_s}" )
			aPlayer.dbInfo = newDbInfo

			return true
		end

		### METHOD: createPlayer( username, role ) { |obj| block } -> Player
		### Returns a new player object for the username specified unless the
		### optional code block is given, in which case it will be passed the
		### player object as an argument. When the block exits, the player
		### object will be automatically stored and de-allocated. In this case,
		### (({ObjectStore.fetchPlayer})) returns (({true})).
		def createPlayer( username, role=MUES::Player::Role::PLAYER )
			playerData = @dbAdapter.createPlayerData( username )

			player = Player.new( playerData )

			if block_given?
				yield( player )
				storePlayer( player )
				return true
			else
				return player
			end
		end
		
		### METHOD: deletePlayer( username )
		### Deletes the named player from the objectstore.
		def deletePlayer( username )
			@dbAdapter.deletePlayerData( username )
		end
		

	end
end



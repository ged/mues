#!/usr/bin/ruby
###########################################################################
=begin

=DummyAdapter.rb

== Name

DummyAdapter - An ObjectStore debugging adapter class

== Synopsis

  

== Description

A testing filesystem-based objectstore adapter class.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mues/Namespace"
require "mues/Exceptions"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class DummyAdapter < Adapter

			include Debuggable

			Version = /([\d\.]+)/.match( %q$Revision: 1.4 $ )[1]
			Rcsid = %q$Id: DummyAdapter.rb,v 1.4 2001/07/18 02:04:19 deveiant Exp $

			attr_accessor :db, :host, :user, :password

			### METHOD: new( db, host, user, password )
			### Create a new DummyAdapter ObjectStore adapter object.
			def initialize( db, host, user, password )
				@db = db
				@host = host
				@user = user
				@password = password

				@dbDir = "%s/%s" % [ "objectstore", @db.gsub(%r{\W+}, "") ]
				unless FileTest.directory?( @dbDir )
					Dir.mkdir( @dbDir, 0755 )
					Dir.mkdir( "#{@dbDir}/players", 0755 )
				end
			end

			### METHOD: storeObjects( *objects )
			### Store the specified objects in the objectstore.
			def storeObjects( *objects )
				oids = []
				objects.each {|obj|
					# Make an object id out of the class name and the MUES id
					oid = _safeifyId( "%s:%s" % [ obj.class.name, obj.muesid ] )
					oids << oid

					# Open a file with the oid as the name and dump the object to it
					File.open( "#{@dbDir}/#{oid}", File::CREAT|File::TRUNC|File::RDWR, 0644 ) { |f|
						until f.flock( File::LOCK_EX|File::LOCK_NB )
							sleep 0.2
						end
						Marshal.dump( obj, f )
						f.flock( File::LOCK_UN )
					}
				}

				return oids
			end

			### METHOD: fetchObjects( *oids )
			### Fetch the objects with the specified oids.
			def fetchObjects( *ids )
				objs = []

				ids.each {|id|
					# Make the oid into a safe filename
					oid = _safeifyId( id )

					# Try to open the corresponding file, returning nil if we fail
					# After opening and locking, delete the file before reading.
					begin
						File.open( "#{@dbDir}/#{oid}", File::RDONLY ) { |f|
							until f.flock( File::LOCK_EX|File::LOCK_NB )
								sleep 0.2
							end
							obj = Marshal.restore( f )
							f.flock( File::LOCK_UN )
						}
					rescue IOError => e
						raise NoSuchObjectError, e.message
					end

					objs << obj
				}

				return objs
			end


			### METHOD: stored?( id )
			### Returns true if the id specified corresponds to a stored object.
			def stored?( id )
				oid = _safeifyId( id )
				return FileTest.exists?( "#{@dbDir}/#{oid}" )
			end


			### METHOD: storePlayerData( username, data )
			### Store the given data as the player record for the specified username
			def storePlayerData( username, data )
				filename = _safeifyId( username )
				
				# Open a file with the playername as the name and dump the object to it
				File.open( "#{@dbDir}/players/#{filename}", File::CREAT|File::TRUNC|File::RDWR, 0644 ) { |f|
					until f.flock( File::LOCK_EX|File::LOCK_NB )
						sleep 0.2
					end
					Marshal.dump( data, f )
					f.flock( File::LOCK_UN )
				}
			end

			### METHOD: fetchPlayerData( username )
			### Fetch the player record for the given username. Throws a
			### NoSuchObjectError exception if the player record does not exist.
			def fetchPlayerData( username )
				filename = _safeifyId( username )
				obj = nil

				# Try to open the corresponding file, returning nil if we fail
				# After opening and locking, delete the file before reading.
				begin
					File.open( "#{@dbDir}/players/#{filename}", File::RDONLY ) { |f|
						until f.flock( File::LOCK_EX|File::LOCK_NB )
							sleep 0.2
						end
						obj = Marshal.restore( f )
						f.flock( File::LOCK_UN )
					}
				rescue IOError => e
					raise NoSuchObjectError, e.message
				end

				return obj
			end

			### METHOD: createPlayerData( username )
			### Create a player record for the given username and return it
			def createPlayerData( username )
				filename = _safeifyId( username )
				raise AdapterError, "A player with the name '#{username}' already exists" if
					FileTest.exists?( "#{@dbDir}/players/#{filename}" )

				data = MUES::Player::DefaultDbInfo.dup
				storePlayerData( username, data )

				return data
			end

			### METHOD: deletePlayerData( username )
			### Delete the player data associated with the given username
			def deletePlayerData( username )
				filename = _safeifyId( username )
				raise AdapterError, "No player with the name '#{username}' exists" unless
					FileTest.exists?( "#{@dbDir}/players/#{filename}" )

				File.delete( "#{@dbDir}/players/#{filename}" )
			end
				
			protected

			### METHOD: safeifyId( id )
			def _safeifyId( id )
				checkType( id, String )
				return id.gsub( /[^:a-zA-Z0-9]+/, "" )
			end

		end
	end
end

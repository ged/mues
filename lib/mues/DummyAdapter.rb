#!/usr/bin/ruby
#################################################################
=begin

=DummyAdapter.rb

== Name

DummyAdapter - An ObjectStore debugging adapter class

== Synopsis

   require "mues/ObjectStore"
   oStore = MUES::ObjectStore.new( "Dummy", "faeriemud", "localhost", "fmuser", "somepass" )

== Description

A testing filesystem-based objectstore adapter class. This class shouldn^t be
required directly; you should instead specify "Dummy" as the first argument to
the MUES::ObjectStore class^s constructor.

== Classes
=== MUES::DummyAdapter
==== Public Methods

--- new( db, host, user, password )

	Create a new adapter object with the specified ((|db|)), ((|host|)),
	((|user|)), and ((|password|)) values.

--- db

    Return the database name associated with the adapter.

--- host

    Returns the host associated with the adapter.

--- user

    Returns the user associated with the adapter.

--- storeObjects( *objects )

    Store the specified ((|objects|)) in the ObjectStore and return their
    (({oids})).

--- fetchObject( *oids )

    Fetch the objects specified by the given ((|oids|)) from the ObjectStore and
    return them.

--- stored?( oid )

    Returns true if an object with the specified ((|oid|)) exists in the
    ObjectStore.

--- storeUserData( username, data )

    Store the specified ((|userdata|)) associated with the specified
    ((|username|)).

--- fetchUserData( username )

    Fetch a user record for the specified ((|username|)). Throws a
    (({NoSuchObjectError})) if no user is associated with the specified
    ((|username|)).

--- createUserData( username )

    Create a new user record and associate it with the given ((|username|))
    before returning it.

--- deleteUserData( username )

    Delete the user data associated with the specified ((|username|)).

--- getUsernameList

	Return an array of the names of the stored user records.

==== Protected Methods

--- _safeifyId( id )

    Returns the specified ((|id|)) (a (({String}))) after stripping any
    characters which couldn^t safely be used in a filename.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "find"

require "mues/Namespace"
require "mues/Exceptions"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class DummyAdapter < Adapter

			include Debuggable

			Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
			Rcsid = %q$Id: DummyAdapter.rb,v 1.7 2001/11/01 17:23:20 deveiant Exp $

			### METHOD: new( config=MUES::Config )
			### Create a new DummyAdapter ObjectStore adapter object.
			def initialize( config )
				super( config )

				dir = @config['directory'] || 'objectstore-d'

				# If the directory isn't absolute, tack the server root onto it
				if dir !~ %r{^/}
					dir = File.join( config['rootdir'], dir )
				end

				# If the BDB objectstore directory doesn't yet exist, make it
				unless File.directory?( dir )
					Dir.mkdir( dir )
				end

				@db = @config['db'] || 'mues'
				@dbDir = "%s/%s" % [ dir, @db.gsub(%r{\W+}, "") ]
				unless FileTest.directory?( @dbDir )
					Dir.mkdir( @dbDir, 0755 )
					Dir.mkdir( "#{@dbDir}/users", 0755 )
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


			### METHOD: storeUserData( username, data )
			### Store the given data as the user record for the specified username
			def storeUserData( username, data )
				filename = "#{@dbDir}/users/%s" % _safeifyId( username )
				
				# Open a file with the username as the name and dump the object to it
				File.delete( filename ) if File.exists?( filename )
				File.open( filename, File::CREAT|File::TRUNC|File::RDWR, 0644 ) { |f|
					begin
					until f.flock( File::LOCK_EX|File::LOCK_NB )
						sleep 0.2
					end
						$stderr.puts( "Marshalling user data to #{filename}: #{data.inspect}" )
					Marshal.dump( data, f )
					ensure
					f.flock( File::LOCK_UN )
					end
				}
			end

			### METHOD: fetchUserData( username )
			### Fetch the user record for the given username. Throws a
			### NoSuchObjectError exception if the user record does not exist.
			def fetchUserData( username )
				filename = _safeifyId( username )
				obj = nil

				# Try to open the corresponding file, returning nil if we fail
				# After opening and locking, delete the file before reading.
				begin
					File.open( "#{@dbDir}/users/#{filename}", File::RDONLY ) { |f|
						begin
						until f.flock( File::LOCK_EX|File::LOCK_NB )
							sleep 0.2
						end
						obj = Marshal.restore( f )
							$stderr.puts( "Unmarshalled user data: #{obj.inspect}" )
						ensure
						f.flock( File::LOCK_UN )
						end
					}
				rescue Errno::ENOENT => e
					obj = nil
				end

				return obj
			end

			### METHOD: createUserData( username )
			### Create a user record for the given username and return it
			def createUserData( username )
				filename = _safeifyId( username )
				raise AdapterError, "A user with the name '#{username}' already exists" if
					FileTest.exists?( "#{@dbDir}/users/#{filename}" )

				data = MUES::User::DefaultDbInfo.dup
				storeUserData( username, data )

				return data
			end

			### METHOD: deleteUserData( username )
			### Delete the user data associated with the given username
			def deleteUserData( username )
				filename = _safeifyId( username )
				raise AdapterError, "No user with the name '#{username}' exists" unless
					FileTest.exists?( "#{@dbDir}/users/#{filename}" )

				File.delete( "#{@dbDir}/users/#{filename}" )
			end
				

			### METHOD: getUsernameList
			### Return an array of names of the stored user records
			def getUsernameList
				list = []
				Find.find( "#{@dbDir}/users" ) {|f|
					next if f == "#{@dbDir}/users"
					Find.prune unless FileTest.file?( f )

					list << f.gsub( %r{.*#{File::Separator}}, '' )
				}

				return list
			end


			###############################################
			###	P R O T E C T E D   M E T H O D S
			###############################################
			protected

			### (PROTECTED) METHOD: safeifyId( id )
			def _safeifyId( id )
				checkType( id, String )
				return id.gsub( /[^:a-zA-Z0-9]+/, "" ).untaint
			end

		end
	end
end

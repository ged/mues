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

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Debugging"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class BdbAdapter < Adapter

			include Debuggable

			Version = %q$Revision: 1.3 $
			Rcsid = %q$Id: BdbAdapter.rb,v 1.3 2001/03/29 02:47:05 deveiant Exp $

			DirectoryName = 'objectstore-bdb'

			### METHOD: initialize( db, host, user, password )
			### Initialize the adapter. Only the 'db' argument is used.
			def initialize( db, *ignored )
				unless File.directory?( DirectoryName )
					Dir.mkdir( DirectoryName )
				end

				@env = BDB::Env.new( DirectoryName, BDB::CREATE|BDB::INIT_TRANSACTION )

				@db = db
				@dbh = @env.open_db( BDB::HASH, 'ObjectStore', @db, BDB::CREATE )
				@lock = Mutex.new

				true
			end

			### METHOD: storeObject( *objects )
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
					@lock.synchronize {
						@dbh.store( oid, rawObj )
					}

					oids.push oid
				}

				return oids
			end

			### METHOD: fetchObjects( *oids )
			def fetchObjects( *oids )
				objects = []

				### Iterate over each id, re-instantiating each corresponding
				### object
				oids.each {|oid|
					rawObj = nil
					@lock.synchronize {
						rawObj = @dbh.fetch( oid, BDB::RMW )
					}

					obj = Marshal.restore(rawObj)
					objects.push obj
				}

				return objects
			end

		end # Class BdbAdapter
	end # Class ObjectStore
end # Module MUES

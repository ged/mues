#!/usr/bin/ruby
###########################################################################
=begin

=BdbAdapter.rb

== Name

BdbAdapter - A Berkeley DB ObjectStore adapter class

== Synopsis

  

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

require "mues/MUES"
require "mues/Exceptions"
require "mues/Debugging"

require "mues/objstore_adapters/Adapter"

module MUES
	class ObjectStore
		class BdbAdapter < Adapter

			include Debuggable

			Version = %q$Revision: 1.1 $
			Rcsid = %q$Id: BdbAdapter.rb,v 1.1 2001/03/15 02:22:16 deveiant Exp $

			DirectoryName = 'objectstore-db'

			### METHOD: initialize( db, host, user, password )
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

			### METHOD: storeObject( obj, oid )
			def storeObject( obj, oid )
				rawObj = Marshal.dump(obj)

				@lock.synchronize {
					@dbh.store( oid, rawObj )
				}

				return oid
			end

			### METHOD: fetchObject( oid )
			def fetchObject( oid )
				rawObj = nil
				@lock.synchronize {
					rawObj = @dbh.fetch( oid, BDB::RMW )
				}

				return Marshal.restore( rawObj )
			end
		end
	end
end

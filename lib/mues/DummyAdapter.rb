#!/usr/bin/ruby
###########################################################################
=begin

=DummyAdapter.rb

== Name

DummyAdapter - An ObjectStore debugging adapter class

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

require "mutexm"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Debugging"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class DummyAdapter < Adapter

			include Debuggable

			Version = %q$Revision: 1.2 $
			Rcsid = %q$Id: DummyAdapter.rb,v 1.2 2001/03/29 02:47:05 deveiant Exp $

			attr_accessor :db, :host, :user, :password

			### METHOD: initialize( db, host, user, password )
			def initialize( db, host, user, password )
				@db = db
				@host = host
				@user = user
				@password = password

				@dbDir = @db.gsub( /[^a-zA-Z0-9]+/, "" )
				unless FileTest.directory?( @dbDir )
					Dir.mkdir( @dbDir, 0755 )
				end
			end

			### METHOD: storeObject( obj )
			def storeObject( obj )
				raise TypeError, "Cannot store a '#{obj.class.name}' object" unless
					obj.is_a?( MUES::Object )

				# Make an object id out of the class name and the MUES id
				oid = _safeifyId( "%s:%s" % [ obj.class.name, obj.muesid ] )

				# Open a file with the oid as the name and dump the object to it
				File.open( "#{@dbDir}/#{oid}", File::CREAT|File::TRUNC|File::RDWR, 0644 ) { |f|
					until f.flock( File::LOCK_EX|File::LOCK_NB )
						sleep 0.2
					end
					Marshal.dump( obj, f )
					f.flock( File::LOCK_UN )
				}

				return oid
			end

			### METHOD: fetchObject( id )
			def fetchObject( id )
				obj = nil

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
						File.delete( oid )
						f.flock( File::LOCK_UN )
					}
				rescue IOError => e
					raise NoSuchObjectError, e.message
				end

				return obj
			end

			### METHOD: stored?( id )
			def stored?( id )
				oid = _safeifyId( id )
				return FileTest.exists?( "#{@dbDir}/#{oid}" )
			end

			protected

			### METHOD: safeifyId( id )
			def _safeifyId( id )
				return id.gsub( /[^:a-zA-Z0-9]+/, "" )
			end

		end
	end
end

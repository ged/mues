#!/usr/bin/ruby
# 
# This is an ObjectStore adapter class for Berkeley DB. It follows the
# ((<MUES::Adapter>)) interface.
# 
# == Synopsis
# 
#   require "mues/ObjectStore"
#   oStore = ObjectStore.new( "Bdb", "faeriemud", "localhost", "fmuser", "fmpass" )
# 
#   objectId = oStore.storeObjects( obj )
# 
# == Rcsid
# 
# $Id: BdbAdapter.rb,v 1.10 2002/04/01 16:27:31 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "bdb"
require "thread"
require "ftools"
require "sync"

require "mues"
require "mues/Exceptions"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class BdbAdapter < Adapter

			include MUES::Debuggable

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.10 $ )[1]
			Rcsid = %q$Id: BdbAdapter.rb,v 1.10 2002/04/01 16:27:31 deveiant Exp $
			DirectoryName = 'objectstore-bdb'

			### Class variables
			@@Sections = %w{object user ban allow}

			### Creates a new BerkeleyDB ObjectStore adapter. Only the 'db'
			### argument is used.
			def initialize( sysconfig )
				super( sysconfig )

				dir = @config['directory'] || 'objectstore'

				# If the directory isn't absolute, tack the server root onto it
				if dir !~ %r{^/}
					dir = File.join( sysconfig['rootdir'], dir )
				end

				# If the BDB objectstore directory doesn't yet exist, make it
				unless File.directory?( dir )
					Dir.mkdir( dir )
				end

				# Initialize attributes
				@env	= BDB::Env.new( dir, BDB::CREATE|BDB::INIT_TRANSACTION )
				@db		= @config['db'] || 'mues'
				@dbh	= {}
				@@Sections.each {|key| @dbh[key] = @env.open_db( BDB::HASH, @db, key, BDB::CREATE )}
				@lock	= {}
				@@Sections.each {|key| @lock[key] = Sync.new}

				true
			end


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


			### Fetch objects with the specified ids from the database and return them
			def fetchObjects( *oids )
				objects = []
				rawObj = nil

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


			### Returns true if an entry with the specified id exists in the database
			def hasObject?( id )
				@lock['object'].synchronize(Sync::SH) {
					return @dbh['object'].has_key?( id )
				}
			end


			### Store the specified hash of user data for the specified user
			def storeUserData( username, data )
				checkType( username, String )
				checkType( data, Hash )

				_debugMsg( 2, "Prepping user data for '#{username}'" )
				data['username'] = username
				frozenData = Marshal.dump( data )
				_debugMsg( 2, "Storing user data for '#{username}'." )
				@lock['user'].synchronize(Sync::EX) {
					@dbh['user'].store( username, frozenData )
				}
				_debugMsg( 2, "User data stored successfully." )

				return data
			end


			### Fetch the hash of user data for the specified user
			def fetchUserData( username )
				checkType( username, String )

				frozenData = @lock['user'].synchronize(Sync::SH) {
					@dbh['user'].fetch( username )
				}
				return nil if frozenData.nil?
				return Marshal.restore( frozenData )
			end


			### Create a new hash of user data with the specified username
			def createUserData( username )
				checkType( username, String )

				@lock['user'].synchronize(Sync::SH) {
					raise AdapterError, "A user with the name '#{username}' already exists." if
						@dbh['user'].has_key?( username )

					storeUserData( username, MUES::User::DefaultDbInfo.dup )
				}
			end


			### Delete the hash of user data for the specified username
			def deleteUserData( username )
				checkType( username, String )

				@lock['user'].synchronize(Sync::SH) {
					raise AdapterError, "No user with the name '#{username}' exists." unless
						@dbh['user'].has_key?( username )

					@lock['user'].synchronize(Sync::EX) {
						@dbh['user'].delete( username )
					}
				}
			end


			### Return an array of the names of the stored user records
			def getUsernameList
				@lock['user'].synchronize(Sync::SH) {
					return @dbh['user'].keys.sort
				}
			end

		end # Class BdbAdapter
	end # Class ObjectStore
end # Module MUES

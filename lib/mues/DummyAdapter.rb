#!/usr/bin/ruby
# 
# A testing filesystem-based objectstore adapter class. This class shouldn^t be
# required directly; you should instead specify "Dummy" as the first argument to
# the MUES::ObjectStore class^s constructor.
# 
# == Synopsis
# 
#    require "mues/ObjectStore"
#    oStore = MUES::ObjectStore.new( "Dummy", "faeriemud", "localhost", "fmuser", "somepass" )
# 
# == Rcsid
# 
# $Id: DummyAdapter.rb,v 1.9 2002/04/01 16:27:31 deveiant Exp $
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


require "find"

require "mues"
require "mues/Exceptions"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class DummyAdapter < Adapter

			include MUES::Debuggable

			Version = /([\d\.]+)/.match( %q$Revision: 1.9 $ )[1]
			Rcsid = %q$Id: DummyAdapter.rb,v 1.9 2002/04/01 16:27:31 deveiant Exp $

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


			### Returns true if the id specified corresponds to a stored object.
			def stored?( id )
				oid = _safeifyId( id )
				return FileTest.exists?( "#{@dbDir}/#{oid}" )
			end


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
				# Red: ObjectStore sets user.dbinfo to return value of this fn
				# Return previous value so it remains valid for to_s -> isCreator?
				data
			end

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

			### Create a user record for the given username and return it
			def createUserData( username )
				filename = _safeifyId( username )
				raise AdapterError, "A user with the name '#{username}' already exists" if
					FileTest.exists?( "#{@dbDir}/users/#{filename}" )

				data = MUES::User::DefaultDbInfo.dup
				storeUserData( username, data )

				return data
			end

			### Delete the user data associated with the given username
			def deleteUserData( username )
				filename = _safeifyId( username )
				raise AdapterError, "No user with the name '#{username}' exists" unless
					FileTest.exists?( "#{@dbDir}/users/#{filename}" )

				File.delete( "#{@dbDir}/users/#{filename}" )
			end
				

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


			#########
			protected
			#########

			### Remove unsafe characters from the specified +id+ so that it can
			### be used as a filename.
			def _safeifyId( id )
				checkType( id, String )
				return id.gsub( /[^:a-zA-Z0-9]+/, "" ).untaint
			end

		end
	end
end

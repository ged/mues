#!/usr/bin/ruby
###########################################################################
=begin

=ObjectStore.rb

== Name

ObjectStore - An object persistance abstraction class

== Synopsis

  require "mues/ObjectStore"
  oStore = ObjectStore.new( "MySQL", "faeriemud", "localhost", "fmuser", "fmpass" )

  objectId = oStore.storeObjects( obj )

== Description



== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2000 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "find"

require "mues/MUES"
require "mues/Events"
require "mues/Exceptions"
require "mues/Debugging"

module MUES

	### NoSuchObjectError (Exception class)
	class NoSuchObjectError < Exception; end
	class UnknownAdapterError < Exception; end

	### Object store class
	class ObjectStore < Object

		include Event::Handler
		include Debuggable

		### Constants
		Version = %q$Revision: 1.1 $
		Rcsid = %q$Id: ObjectStore.rb,v 1.1 2001/03/15 02:22:16 deveiant Exp $

		AdapterSubdir = 'mues/objstore_adapters'
		AdapterPattern = /#{AdapterSubdir}\/(\w+Adapter).rb$/	#/

		### Class attributes
		@@AdaptersAreLoaded = false
		@@Adapters = nil

		### Class methods
		class << self

			### (CLASS) METHOD: _loadAdapters
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
					if klass.name == name || klass.name == "MUES::ObjectStore::#{name}Adapter"
						return klass
					end
				}
				return nil
			end

			### (CLASS) _getAdapter( driver, db, host, user, password )
			def _getAdapter( driver, db, host, user, password )
				_loadAdapters() unless @@AdaptersAreLoaded
				klass = _getAdapterClass( driver )
				raise UnknownAdapterError, "Could not fetch adapter class '#{driver}'" unless klass
				klass.new( db, host, user, password )
			end
		end

		### METHOD: initialize( db, host, user, password )
		def initialize( driver = "Bdb", db = "mues", host = nil, user = nil, password = nil )
			super()
			@dbAdapter = self.class._getAdapter( driver, db, host, user, password )
		end

		### METHOD: fetchObjects( *objectIds ) { block }
		def fetchObjects( *objectIds )
			@dbAdapter.fetchObjects( *objectIds ).collect {|obj|
				obj.awaken if obj.respond_to?( :awaken )
				obj = yield( obj ) if block_given?
			}
		end

		### METHOD: storeObjects( *objects )
		def storeObjects( *objects )
			@dbAdapter.storeObjects( *objects ).collect {|obj|
				obj.lull if obj.respond_to?( :lull )
				oid = yield( oid, obj ) if block_given?
				ids.push oid
			}
		end

		### METHOD: stored?( id )
		def stored?( id )
			return @dbAdapter.stored?( id )
		end

	end
end



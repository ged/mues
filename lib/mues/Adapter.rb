#!/usr/bin/ruby
#################################################################
=begin

=Adapter.rb

== Name

Adapter - An ObjectStore adapter abstract base class

== Synopsis

  require "mues/adapters/Adapter"

  module MUES
    class ObjectStore
      class MyAdapter < Adapter

		def initialize( db, host, user, password )
			...
		end

		def storeObject( obj )
			...
		end

		def fetchObject( id )
			...
		end

		def hasObject?( id )
			...
		end

        def storeUserData( username, data )
			...
		end

        def fetchUserData( username )
			...
		end

        def createUserData( username )
            ...
        end

        def deleteUserData( username )
			...
		end

        def listUsers
			...
		end

	  end
    end
  end

== Description

This is an abstract base class which defines the required interface for
MUES::ObjectStore adapters. You shouldn^t use this class except as a superclass
for your own adapter classes.

== Methods
=== Protected Methods

--- initialize( db, host, user, password )

	Initialize the adapter object with the specified ((|db|)), ((|host|)),
	((|user|)), and ((|password|)) values.

=== Attribute Accessor Methods

--- db

    Return the database name associated with the adapter.

--- host

    Returns the host associated with the adapter.

--- user

    Returns the user associated with the adapter.

=== Abstract Methods

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

    Return an array of usernames of the stored user records.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
#################################################################

require "mues/Namespace"
require "mues/Exceptions"

module MUES
	class ObjectStore

		class AdapterError < Exception; end

		class Adapter < Object ; implements Debuggable, AbstractClass

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.7 $ )[1]
			Rcsid = %q$Id: Adapter.rb,v 1.7 2001/08/05 05:49:23 deveiant Exp $

			### Class variables
			@@AdapterClasses = {}

			### Class methods
			class << self
			
				### (CLASS) METHOD: inherit( subclass=Class )
				### Called when this class is inherited.
				def inherited( subclass )
					debugMsg( 2, "Adding ObjectStore adapter class '#{subclass.name}'" )
					@@AdapterClasses[ subclass.name ] = subclass
				end

				### (CLASS) METHOD: getAdapterClass( name )
				### Returns the adapter class that matches the specified name,
				### if any.
				def getAdapterClass( name )
					checkType( name, ::String )

					@@AdapterClasses.each {|className,klass|
						return klass if className =~ name
					}

					return nil
				end

			end

			### Protected methods

			### METHOD: initialize( db, host, user, password )
			### Initialize the adapter with the specified values
			protected
			def initialize( db, host, user, password )
				@db			= db
				@host		= host
				@user		= user
				@password	= password
			end

			### Public methods
			public

			attr_reader :db, :host, :user
			abstract :storeObjects,
				:fetchObjects,
				:stored? ,
				:storeUserData,
				:fetchUserData,
				:createUserData,
				:deleteUserData,
				:getUsernameList
		end
	end
end

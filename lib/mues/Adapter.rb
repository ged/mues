#!/usr/bin/ruby
###########################################################################
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

		def storePlayerData( username, data )
			...
		end

		def fetchPlayerData( username )
			...
		end

		def createPlayerData( username )
			...
		end

	  end
    end
  end


== Description

This is an abstract base class which defines the required interface for
MUES::ObjectStore adapters.

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

module MUES
	class ObjectStore

		class AdapterError < Exception; end

		class Adapter < Object

			include Debuggable
			include AbstractClass

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
			Rcsid = %q$Id: Adapter.rb,v 1.5 2001/07/18 02:01:39 deveiant Exp $

			### METHOD: initialize( db, host, user, password )
			### Initialize the adapter with the specified values
			protected
			def initialize( db, host, user, password )
				@db			= db
				@host		= host
				@user		= user
				@password	= password
			end


			###################################################################
			###	P U B L I C   M E T H O D S
			###################################################################
			public

			attr_reader :db, :host, :user

			def storeObject( obj )
				raise VirtualMethodError, "Required method 'storeObject' unimplemented."
			end

			def fetchObject( id )
				raise VirtualMethodError, "Required method 'fetchObject' unimplemented."
			end

			def hasObject?( id )
				raise VirtualMethodError, "Require method 'hasObject?' unimplemented."
			end

			def storePlayerData( username, data )
				raise VirtualMethodError, "Required method 'storePlayerData' unimplemented."
			end

			def fetchPlayerData( username )
				raise VirtualMethodError, "Required method 'fetchPlayerData' unimplemented."
			end

			def createPlayerData( username )
				raise VirtualMethodError, "Required method 'createPlayerData' unimplemented."
			end

		end
	end
end

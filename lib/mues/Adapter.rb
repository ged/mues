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

		def stored?( id )
			...
		end

	  end
    end
  end


== Description



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
require "mues/Debugging"

module MUES
	class ObjectStore

		class AdapterError < Exception; end

		class Adapter < Object

			include Debuggable
			include AbstractClass

			Version = %q$Revision: 1.3 $
			Rcsid = %q$Id: Adapter.rb,v 1.3 2001/03/29 02:47:05 deveiant Exp $

			def storeObject( obj )
				raise UnimplementedError, "Required method unimplemented."
			end

			def fetchObject( id )
				raise UnimplementedError, "Required method unimplemented."
			end

			def stored?( id )
				raise UnimplementedError, "Require method unimplemented."
			end
		end
	end
end

#!/usr/bin/ruby
###########################################################################
=begin

=MysqlAdapter.rb

== Name

MysqlAdapter - An ObjectStore MySQL adapter class

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

require "mysql"

require "mues/Namespace"
require "mues/Exceptions"
require "mues/Debugging"

require "mues/adapters/Adapter"

module MUES
	class ObjectStore
		class MysqlAdapter < Adapter

			include Debuggable

			Version = %q$Revision: 1.2 $
			Rcsid = %q$Id: MysqlAdapter.rb,v 1.2 2001/03/29 02:47:05 deveiant Exp $

			attr_accessor :db, :host, :user, :password
			def initialize( db, host, user, password )
				@db = db
				@host = host
				@user = user
				@password = password

				@dbh = Mysql.connect( host, user, password, db )
			end

			def storeObject( obj )
			end

			def fetchObject( id )
			end

		end
	end
end

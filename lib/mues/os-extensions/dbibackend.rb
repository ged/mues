#!/usr/bin/ruby
# 
# This file contains the MUES::DBIBackend class, a derivative of
# (>>>superclass<<). RDBMS ObjectStore backend via DBI.
# 
# == Synopsis
# 
#   require 'mues/ObjectStore'
#
#   os = MUES::ObjectStore::create( 'foo', [], 'DBI', :backend => 'dbi:mysql:objectstore' )
#   ...
# 
# == Rcsid
# 
# $Id: dbibackend.rb,v 1.2 2002/08/02 20:03:43 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'dbi'
require 'sync'

require 'mues/Object'
require 'mues/Exceptions'
require 'mues/ObjectStore'
require 'mues/StorableObject'
require 'mues/os-extensions/Backend'


module MUES
	class ObjectStore

		### RDBMS ObjectStore backend via DBI.
		class DBIBackend < Backend

			# Adapter class for bridging the gap between DBI and the functions
			# we need. Derivatives defined at the bottom of DBIBackend.rb, or
			# via user requires.
			class Adapter < MUES::Object ; implements MUES::AbstractClass
				include MUES::FactoryMethods

				abstract :createDatabase,
					:createTable,
					:dropTable,
					:lock,
					:addIndexColumn,
					:delIndexColumn

			end # class Adapter


			include MUES::TypeCheckFunctions

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.2 $ )[1]
			Rcsid = %q$Id: dbibackend.rb,v 1.2 2002/08/02 20:03:43 deveiant Exp $

			# The default Data Source Name, username, and password to use when connecting.
			DefaultDsn = {
				:dsn		=> 'dbi:Mysql:objectstore',
				:username	=> 'mues',
				:password	=> 'mues',
				:preconnect	=> true,
			}

			### Class globals
			
				

			### Create a new DBIBackend object, where the names of the tables to
			### use are based on the specified <tt>name</tt>. The
			### <tt>config</tt> should be the DSN of the database to use, the
			### username to connect as, and the password, separated by
			### semicolons.
			def initialize( name, indexes=[], config=DefaultConfig )
				checkType( config, Hash )

				@name = name.to_s
				@indexes = indexes
				@config = config

				@dbh = nil
				@tablesUpToDate = false
				@indexesUpToDate = false

				@dbh = self.getDbh() if @config[:preconnect]
			end


			# Store the specified <tt>objects</tt>, which must be
			# MUES::StorableObject derivatives, in the backing store database.
			def store( *objects )
				checkEachType( objects, MUES::StorableObject )

				
			end


			# retrieve
			def retrieve
			end

			# retrieve_by_index
			def retrieve_by_index
			end

			# retrieve_all
			def retrieve_all
			end

			# lookup
			def lookup
			end

			# close
			def close
			end

			# exists?
			def exists?
			end

			# open?
			def open?
			end

			# nitems
			def nitems
			end

			# clear
			def clear
			end

			# drop
			def drop
			end


			######
			public
			######


			#########
			protected
			#########



			### Adapter classes

			### An adapter class for Mysql.
			class MysqlAdapter < Adapter # :nodoc:

				CreateTableSql = %q{
				CREATE TABLE %s (
					id		VARCHAR(32)		NOT NULL PRIMARY KEY,	-- hexdigest.length
					ts		TIMESTAMP(14),
					class	VARCHAR(75)		NOT NULL,
					data	BLOB			NOT NULL,
				);
				}

			end # class MysqlAdapter

		end # class DBIBackend

	end # class ObjectStore
end # module MUES


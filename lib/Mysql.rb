#!/usr/bin/ruby
###########################################################################
=begin

=MysqlTableAdapter.rb

== Name

MysqlTableAdapter - An adapter class for MySQL tables

== Synopsis

  require "MysqlTableAdapter"

  class MyAdapter < AdapterClass( host, db, tableName, username, password )
	  @@relations = {
		  
	  }
  end

  a = MyAdapter.new
  puts a.columnName
  a.columnName = value
  a.store

  a = MyAdapter.lookup( 5 )

  names = MyAdapter.lookup( 5, 10, 15, 21 ) { |a|
	  a.collect {|r| r.name}
  }

== Description

This is an adapter class for abstracting rows from a MySQL table behind an
object interface. Columns of the row can be manipulated by calling methods of
the same name as the column, and rows can be fetched, stored, created, and
deleted via method calls as well.

((*More documentation to come*))

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

require "mysql"
require "weakref"
require "md5"

class TableAdapterError < StandardError; end
class MysqlTableAdapter

	### Inner class -- reference-counted object cache
	class ObjectCache < Hash

		### (OVERRIDDEN) METHOD: []( key )
		### Key lookup
		def []( key )
			return nil unless self.key?( key )

			# Disable garbage collection while we fetch the object behind the
			# weak reference
			gcWasDisabled = GC.disable

			# Attempt to fetch the object and then turn garbage-collection back
			# on
			rval = nil
			begin
				if super(key).weakref_alive?
					rval = super(key).__getobj__
				end
			rescue RefError
				rval = nil
			ensure
				GC.enable unless gcWasDisabled
			end

			return rval
		end

		### (OVERRIDDEN) METHOD: []=( key, val )
		def []=( key, val )
			super( key, WeakRef.new(val) )
			return val
		end
	end

	### Innert class -- checksumming row data hash
	class RowState < Hash

		### METHOD: initialize( default=nil )
		### Initialize the row state hash
		def initialize( default=nil )
			super( default )

			@savedChecksum = checksum()
			@modifiedFields = {}
		end

		### (OVERRIDDEN) METHOD: [ column ]= value
		### Set the value of the specified column to the specified value
		def []=( col, val )
			super( col, val )
			@modifiedFields[ col ] = 1
		end

		### METHOD: setState( hash )
		### Set the hash values and checksum of the row data to those of the
		### specified hash
		def setState( hash )
			replace( hash )
			@savedChecksum = checksum()
			@modifiedFields = {}
		end

		### METHOD: modifiedFields()
		### Return an array of all fields which have been modified since this
		### object was last retrieved from the database.
		def modifiedFields
			return @modifiedFields.keys.uniq
		end

		### METHOD: checksum()
		### Returns a 20-character (MD5 hexdigest) checksum String for the data
		### fields of this object.
		def checksum
			MD5.new( keys.sort.collect {|k| "#{k}=#{self[k]}"}.join(':') ).hexdigest
		end

		### METHOD: hasChanged?()
		### Returns true if the data in the row state has changed
		def hasChanged?
			checksum() != @savedChecksum
		end

		### METHOD: modified?()
		### Returns true if the fields have been modified, even if they were set
		### to the same values as they previously had.
		def modified?
			return @modifiedFields.length > 0
		end
		
	end

	### Class constants
	TypeMap = {
		"TINY"		=> MysqlField::TYPE_TINY,
		"ENUM"		=> MysqlField::TYPE_ENUM,
		"DECIMAL"	=> MysqlField::TYPE_DECIMAL,
		"SHORT"		=> MysqlField::TYPE_SHORT,
		"LONG"		=> MysqlField::TYPE_LONG,
		"FLOAT"		=> MysqlField::TYPE_FLOAT,
		"DOUBLE"	=> MysqlField::TYPE_DOUBLE,
		"NULL"		=> MysqlField::TYPE_NULL,
		"TIMESTAMP"	=> MysqlField::TYPE_TIMESTAMP,
		"LONGLONG"	=> MysqlField::TYPE_LONGLONG,
		"INT24"		=> MysqlField::TYPE_INT24,
		"DATE"		=> MysqlField::TYPE_DATE,
		"TIME"		=> MysqlField::TYPE_TIME,
		"DATETIME"	=> MysqlField::TYPE_DATETIME,
		"YEAR"		=> MysqlField::TYPE_YEAR,
		"SET"		=> MysqlField::TYPE_SET,
		"BLOB"		=> MysqlField::TYPE_BLOB,
		"STRING"	=> MysqlField::TYPE_STRING,
		"VARCHAR"	=> 253,
		"CHAR"		=> MysqlField::TYPE_CHAR
	}

	TypeNameMap = TypeMap.invert

	FlagMap = {
		"NOT_NULL"		=> MysqlField::NOT_NULL_FLAG,
		"PRIMARY_KEY"	=> MysqlField::PRI_KEY_FLAG,
		"UNIQUE"		=> MysqlField::UNIQUE_KEY_FLAG,
		"MULTIPLE_KEY"	=> MysqlField::MULTIPLE_KEY_FLAG,
		"BLOB"			=> MysqlField::BLOB_FLAG,
		"UNSIGNED"		=> MysqlField::UNSIGNED_FLAG,
		"ZEROFILL"		=> MysqlField::ZEROFILL_FLAG,
		"BINARY"		=> MysqlField::BINARY_FLAG
	}

	Version = /([\d\.]+)/.match( %q$Revision: 1.1 $ )[1]
	Rcsid = %q$Id: Mysql.rb,v 1.1 2001/04/06 07:34:08 deveiant Exp $

	###########################################################################
	###	C L A S S   V A R I A B L E S
	###########################################################################

	### Cached objects, connection handles, and table info
	@@oCache	= {}
	@@handles	= {}
	@@tableInfo = nil

	### Connection variables
	@@database	= nil
	@@table		= nil
	@@username	= nil
	@@password	= nil
	@@host		= nil

	### Flag: Print a warning every time we alias a real method out of the way
	@@printMethodClashWarnings = true

	###########################################################################
	###	C L A S S   M E T H O D S
	###########################################################################
	class << self

		### (CLASS) METHOD: dbKey()
		def dbKey
			unless @@database && @@database.is_a?( String ) && @@database.length > 0
				raise TableAdapterError, "No database defined for the \"#{self.name}\" class"
			end

			return [ @@host, @@database, @@username ].join(":")
		end

		### (CLASS) METHOD: tableKey()
		def tableKey
			unless @@table && @@table.is_a?( String ) && @@table.length > 0
				raise TableAdapterError, "No table defined for the \"#{self.name}\" class"
			end

			return [ dbKey(), @@table ].join(':')
		end

		### (CLASS) METHOD: tableInfo()
		def tableInfo
			@@tableInfo ||= fetchTableInfoHash( @@table )
		end

		### (CLASS) METHOD: lookup( idArray )
		def lookup( *ids )
			ids.collect! {|elem| elem.to_a}.flatten!.compact!
			raise ArgumentError, "No ids specified." unless ids.length > 0

			### Prepare to check pre-emptive caching
			tkey = tableKey()
			preCached = {}
			@@oCache[ tkey ] ||= MysqlTableAdapter::ObjectCache.new

			### See if any of the ids we've requested are already cached
			splicedIds = ids.dup
			ids.each_with_index {|elem,i|
				next unless (( obj = @@oCache[ tkey ][ elem ] ))
				preCached[ i ] = obj
				splicedIds.slice!( i )
			}

			### If we still have objects that haven't been looked up, build the
			### query
			rval = nil
			if splicedIds.length > 0
				query = nil
				if splicedIds.length == 1
					query = "SELECT * FROM %s WHERE %s = %s" % [
						@@table,
						primaryKey(),
						quoteValuesForField( primaryKey(), splicedIds[0] )[0]
					]
				else
					query = "SELECT * FROM %s WHERE %s IN ( %s )" % [
						@@table,
						primaryKey(),
						quoteValuesForField( primaryKey(), splicedIds ).join(",")
					]
				end
				
				### Execute the query
				res = dbHandle().query( query )
				return nil if res.nil?

				### Instantiate new Adapter objects for each row returned
				pkey = primaryKey()
				rows = {}
				res.each_hash {|row| rows[ row[pkey].to_s ] = row}
				rval = splicedIds.collect {|objId| 
					obj = self.new( rows[objId.to_s] )
					@@oCache[ tkey ][ objId ] = obj
				}
			else
				rval = []
			end

			### Splice the cached objects back into the return val
			preCached.keys.sort.each {|key|
				rval[ key, 0 ] = preCached[ key ]
			}

			return ids.length == 1 ? rval[0] : rval
		end
		alias :find :lookup

		### (CLASS) METHOD: primaryKey()
		def primaryKey
			### :FIXME: Doesn't handle multiple-column primary keys yet
			(self.tableInfo.values.find {|f| (f.flags & MysqlField::PRI_KEY_FLAG) != 0}).name
		end

		### (CLASS) METHOD: columnInfoTable()
		### Returns a String with a human-readable table of fields information
		### for this class
		def columnInfoTable
			infoTable = ''
			infoTable << "-" * 75 << "\n"
			infoTable <<  "%-15s %-20s %-10s %5s %5s   %-30s" % [ "Name", "Default", "Type", "Length", "Max", "Flags" ] << "\n"
			infoTable <<  "-" * 75 << "\n"
			tableInfo.values.sort {|a,b| a.name <=> b.name }.each {|f|
				infoTable <<  "%-15s %-20s %-10s %5d %5d   %-30s" % [
					f.name, 
					f.def, 
					TypeNameMap[ f.type ],
					f.length, 
					f.max_length, 
					_flagList(f.flags).join("|") 
				] << "\n"
			}
			infoTable
		end

		### (PROTECTED CLASS) METHOD: dbHandle()
		def dbHandle
			@@handles[ dbKey() ] ||= Mysql.connect( @@host, @@username, @@password, @@database )
		end

		### (PROTECTED CLASS) METHOD: fetchTableInfoHash( tableName )
		def fetchTableInfoHash( table )
			dbh = dbHandle()
			fields = Hash.new

			dbh.list_fields( table ).fetch_fields.each {|f|
				fields[ f.name ] = f.dup

				### If the column name clashes with an already-extant method,
				### try to alias the real method out of the way.
				if method_defined?( f.name )
					if method_defined?( "object#{f.name.capitalize}" )
						raise TableAdapterError, "Unresolvable method clash for method '#{f.name}'"
					end

					$stderr.puts "Warning: Method name for column '#{f.name}' for the '#{table}' " +
						"table clashes with pre-existing object method.\n Moving object method to " +
						"'object#{f.name.capitalize}'" unless ! @@printMethodClashWarnings

					alias_method "object#{f.name.capitalize}".intern, f.name.intern
					undef_method f.name.intern
				end
			}

			return fields
		end

		### (PROTECTED CLASS) METHOD: quoteValuesForField( fieldName, *values )
		def quoteValuesForField( field, *values )
			fieldType = self.tableInfo[field].type
			raise ArgumentError, "No such column '#{field}' in the '#{@table}' table." unless fieldType

			quotedVals = []
			values.collect {|val|
				case fieldType
				when MysqlField::TYPE_ENUM, MysqlField::TYPE_TIMESTAMP,
						MysqlField::TYPE_DATE, MysqlField::TYPE_TIME,
						MysqlField::TYPE_DATETIME, MysqlField::TYPE_YEAR
					
					"'%s'" % [ Mysql.escape_string( val.to_s ) ]

				when MysqlField::TYPE_NULL
					"NULL"

				when MysqlField::TYPE_SET
					set = nil
					if ! val.nil?
						val = [ val.to_s ] unless val.is_a?( Array )
						raise AdapterError, "A set cannot have more than 64 members." unless val.length <= 64
						set = val.collect {|v| "'" + Mysql.escape_string(v.to_s) + "'"}.join(",")
					else
						set = ""
					end
					"(#{set})"

				when MysqlField::TYPE_BLOB, MysqlField::TYPE_STRING, 253
					"'%s'" % [ Mysql.escape_string( val.to_s ) ]

				else
					val
				end
			}
		end


		### (PROTECTED CLASS) METHOD: _flagList( flags )
		### Return an Array of flag names for the flags given
		def _flagList( flags )
			FlagMap.keys.find_all {|key|
				FlagMap[ key ] & flags != 0
			}
		end

	end # class << self


	###########################################################################
	###	I N S T A N C E   M E T H O D S
	###########################################################################

	### METHOD: initialize( row=nil )
	def initialize( row=nil )
		@row = RowState.new

		if row.nil?
			@@oCache[ self.class.tableKey() ] ||= ObjectCache.new
			self.class.tableInfo.each {|name,field| @row[name] = nil}
		elsif row.is_a?( Hash )
			@row.setState( row )
		else
			raise ArgumentError, "Row must be a hash"
		end
	end

	### METHOD: store()
	### Store the row in the database
	def store
		return true unless @row.hasChanged?
		setPhrase = @row.modifiedFields.collect {|field|
			quotedVal = self.class.quoteValuesForField(field, @row[field])
			"#{field} = #{quotedVal}"
		}.join(", ")

		dbh = self.class.dbHandle()

		if _rowid().nil? || _rowid() == "0"
			query = 'INSERT INTO %s SET %s' %
				[ @@table, setPhrase ]
			$stderr.puts( "Running query: #{query}" ) if $DEBUG
			res = dbh.query( query )
			insertId = dbh.insert_id
			_rowid( insertId )
			@@oCache[ self.class.tableKey() ] ||= ObjectCache.new
			@@oCache[ self.class.tableKey() ][ insertId ] = self
		else
			query = 'UPDATE %s SET %s WHERE %s = %s' %
				[ @@table, setPhrase, self.class.primaryKey(), _rowid() ]
			$stderr.puts( "Running query: #{query}" ) if $DEBUG
			res = dbh.query( query )
		end

		return true
	end

	### METHOD: method_missing( aSymbol, *args )
	### Create and call methods that are the same as column names
	def method_missing( aSymbol, *args )
		origMethName = aSymbol.id2name
		methName = origMethName.sub( /=$/, '' )
		super unless @row.has_key?( methName )

		oldVerbose = $VERBOSE
		$VERBOSE = false

		self.class.class_eval <<-"end_eval"
		def #{methName}( arg=nil )
			if !arg.nil?
				@row["#{methName}"] = arg
			end
			@row["#{methName}"]
		end
		def #{methName}=( arg )
			self.#{methName}( arg )
		end
		end_eval

		$VERBOSE = oldVerbose

		raise RuntimeError, "Method definition for '#{methName}' failed." if method( methName ).nil?
		method( origMethName ).call( *args )
	end


	###########################################################################
	###	P R O T E C T E D   M E T H O D S
	###########################################################################
	protected

	### (PROTECTED) METHOD: _rowid()
	def _rowid( arg=nil )
		send( self.class.primaryKey(), arg )
	end

end


def TableAdapterClass( db, table, user, password, host = nil )
	klass = Class.new( MysqlTableAdapter )

	klass.class_eval {
		@@database = db
		@@table = table
		@@user = user
		@@password = password
		@@host = host

		@@tableInfo = nil
	}

	return klass
end



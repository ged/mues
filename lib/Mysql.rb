#!/usr/bin/ruby -w
#####################################################################
=begin  

= Mysql
== Name

Mysql.rb - The MySQL tableadapter class

== Synopsis

	
== Description

This class 

== Classes
=== TableAdapter::ObjectCache
==== Overridden Methods

--- ObjectCache#[]( key )

    Key lookup

--- ObjectCache#[]=( key, val )

	Element assignment

--- initialize( *args )

    Initialize the ObjectCache object

=== TableAdapter::RowState < Hash
==== Overridden Methods

--- RowState#[ column ]= value

    Set the value of the specified column to the specified value

==== Methods

--- initialize( default=nil )

    Initialize the row state hash

--- setState( hash )

    Set the hash values and checksum of the row data to those of the
    specified hash

--- modifiedFields()

    Return an array of all fields which have been modified since this
    object was last retrieved from the database.

--- checksum()

    Returns a 20-character (MD5 hexdigest) checksum String for the data
    fields of this object.

--- hasChanged?()

    Returns true if the data in the row state has changed

--- modified?()

    Returns true if the fields have been modified, even if they were set
    to the same values as they previously had.

=== TableAdapter
==== Public Class Methods
-- TableAdapter.dbKey

   Returns a string which can be used to uniquely identify the table this class
   abstracts. The string is of the form:

     '((|host|)):((|database|)):((|username|))'

-- TableAdapter.tableKey

   Returns a string which can be used to uniquely identify the table this class
   abstracts. The string is of the form:

     "#{dbKey()}:table"

-- TableAdapter.tableInfo

   Returns a (possible cached) (({Hash})) of table information like that
   returned by ((<TableAdapter.fetchTableInfoHash()>)).

-- TableAdapter.lookup( ((|*idArray|)) )

   Returns an array of objects whose rowids are in ((|idArray|)).

-- TableAdapter.primaryKey

   Returns the name of the primary key of the abstracted table.

-- TableAdapter.columnInfoTable

   Returns a (({String})) with a human-readable table of fields information for
   this class.

-- TableAdapter.dbHandle

   Return a database connection to the database this class's table is in.

-- fetchTableInfoHash( ((|tableName|)) )

   Returns a (({Hash})) of field information about the table this class
   abstracts. The hash is of the form:

	 { ((|columnName|)) => ((|ColumnInfo|)) }


-- TableAdapter.quoteValuesForField( ((|field|)), ((|*values|)) )

   Returns the specified array of ((|values|)) properly quoted for the
   ((|field|)) specified.

-- TableAdapter.flagList( flags )

   Return an (({Array})) of flag names for the ((|flags|)) given.

-- TableAdapter.table

   Returns the table associated with this class.

-- TableAdapter.database

   Returns the database associated with this class.

-- TableAdapter.host

   Returns the host associated with this class.

-- TableAdapter.username

   Returns the username associated with this class.

==== Protected class methods
-- TableAdapter.password

   Returns the table associated with this class.

==== Protected instance methods

-- TableAdapter#initialize( aRowHash=nil )

   Instantiate the adapter object. If the optional row hash is given, sets the
   row state of the object to the values contained in the hash.

==== Public instance methods

-- TableAdapter#store

   Store the row in the database.

-- TableAdapter#delete( cascade=false )

   Delete the row this object abstracts. Note that this doesn't affect the
   object's state except to delete its rowid (primary key). The ((|cascade|))
   parameter isn't used yet, but will eventually when the object-relational
   stuff works.

-- TableAdapter#method_missing( aSymbol, *args )

   Create and call column methods.

-- TableAdapter#rowid

   Returns the value of the primary key column for this row.

-- TableAdapter#rowid=((|value|))

   Sets the value of the primary key column for this row to the ((|value|))
   specified.

==== ClassFactory Function

-- TableAdapterClass( db, table, user, password, host = nil )

   Create and return an adapter class with class attributes set to the specified
   values. See the synopsis for examples.

=end
#####################################################################

require "mysql"
require "weakref"
require "sync"
require "md5"

#require "translucenthash"
require "tableadapter/Search"

class TableAdapterError < StandardError; end
class TableAdapter

	### Inner class -- reference-counted object cache
	class ObjectCache < Hash

		### (OVERRIDDEN) METHOD: initialize( *args )
		### Initialize the ObjectCache object
		def initialize( *args )
			super( *args )
			@mutex = Sync.new
		end

		### (OVERRIDDEN) METHOD: []( key )
		### Key lookup
		def []( key )
			return nil unless self.key?( key )

			### Synchronize to avoid screwing up the GC setting with multiple
			### threads
			@mutex.synchronize( Sync::EX ) {

				# Disable garbage collection while we fetch the object behind
				# the weak reference
				gcWasDisabled = GC.disable

				# Attempt to fetch the object and then turn garbage-collection
				# back on
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
			}
			
			return rval
		end

		### (OVERRIDDEN) METHOD: []=( key, val )
		### Element assignment
		def []=( key, val )
			super( key, WeakRef.new(val) )
			return val
		end
	end


	### Inner class -- checksumming row data hash
	class RowState < Hash

		### METHOD: initialize( default=nil )
		### Initialize the row state hash
		def initialize( default=nil )
			super( default )

			@savedChecksum = checksum()
			@modifiedFields = {}
			@mutex = Sync.new
		end

		### (OVERRIDDEN) METHOD: [ column ]= value
		### Set the value of the specified column to the specified value
		def []=( col, val )
			@mutex.synchronize(Sync::EX) {
				super( col, val )
				@modifiedFields[ col ] = 1
			}
		end

		### METHOD: setState( hash )
		### Set the hash values and checksum of the row data to those of the
		### specified hash
		def setState( hash )
			@mutex.synchronize(Sync::EX) {
				replace( hash )
				@savedChecksum = checksum()
				@modifiedFields = {}
			}
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

	### :GENERICIZE: Constants are, obviously, Mysql-specific
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

	Version = /([\d\.]+)/.match( %q$Revision: 1.5 $ )[1]
	Rcsid = %q$Id: Mysql.rb,v 1.5 2001/09/26 13:38:46 deveiant Exp $


	###########################################################################
	###	C L A S S   V A R I A B L E S
	###########################################################################

	### Cached objects, connection handles, and table info
	@@oCache	= {}
	@@handles	= {}
	@@tableInfo	= {}

	### Flag: Print a warning every time we alias a real method out of the way
	@@printMethodClashWarnings = true

	###########################################################################
	###	C L A S S   M E T H O D S
	###########################################################################
	class << self

		### (CLASS) METHOD: printMethodClashWarnings?
		### Returns the value of the flag that controls method clash warnings
		### for redefined methods
		def printMethodClashWarnings?
			@@printMethodClashWarnings
		end

		### (CLASS) METHOD: printMethodClashWarnings=( trueOrFalse )
		### Turn on or off the method clash warnings for redefined methods
		def printMethodClashWarnings=( trueFalse )
			raise TypeError, "Flag must be true or false" unless
				trueFalse == true || trueFalse == false
			@@printMethodClashWarnings = trueFalse
		end

		### (CLASS) METHOD: dbKey()
		### Returns a string which uniquely identifies the particular database
		### this class's table lives in. The returned string is of the form:
		###
		###	'host:database:username'
		###
		def dbKey
			unless database && database.is_a?( String ) && database.length > 0
				raise TableAdapterError, "No database defined for the \"#{self.name}\" class"
			end

			return [ host, database, username ].join(":")
		end


		### (CLASS) METHOD: tableKey()
		### Returns a string which can be used to uniquely identify the table
		### this class abstracts. The string is of the form:
		###
		###	"#{dbKey()}:table"
		###
		def tableKey
			unless table && table.is_a?( String ) && table.length > 0
				raise TableAdapterError, "No table defined for the \"#{self.name}\" class"
			end

			return [ dbKey(), table ].join(':')
		end


		### (CLASS) METHOD: tableInfo()
		### Returns a (possible cached) hash of table information like that
		### returned by (({fetchTableInfoHash()}))
		def tableInfo
			@@tableInfo[tableKey] ||= fetchTableInfoHash( table )
		end


		### (CLASS) METHOD: lookup( idArray ) {|obj| block }
		### Returns an array of objects which match the rows of the abstracted
		### table whose rowids are in the idArray specified.
		def lookup( *ids )
			ids.collect! {|elem| elem.to_a}.flatten!.compact!
			raise ArgumentError, "No ids specified." unless ids.length > 0

			### Prepare to check pre-emptive caching
			tkey = tableKey()
			preCached = {}
			@@oCache[ tkey ] ||= TableAdapter::ObjectCache.new

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
						table,
						primaryKey(),
						quoteValuesForField( primaryKey(), splicedIds[0] )[0]
					]
				else

					### :GENERICIZE: IN( <set> ) is probably not portable
					query = "SELECT * FROM %s WHERE %s IN ( %s )" % [
						table,
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

			if block_given?
				rval.each {|obj| yield(obj)}
			else
				return *rval
			end
		end
		alias :find :lookup


		### :GENERICIZE: Abstract this to the db-specific module
		### (CLASS) METHOD: primaryKey()
		### Returns the name of the primary key of the abstracted table.
		def primaryKey
			### :FIXME: Doesn't handle multiple-column primary keys yet
			(self.tableInfo.values.find {|f| (f.flags & MysqlField::PRI_KEY_FLAG) != 0}).name
		end


		### :GENERICIZE: Abstract this (if it's kept at all)
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
					flagList(f.flags).join("|") 
				] << "\n"
			}
			infoTable
		end


		### :GENERICIZE: Abstract this (if it's kept at all)
		### (CLASS) METHOD: dbHandle()
		### Open, cache, and return a database connection to the database this
		### class's table is in
		def dbHandle
			key = dbKey()
			return @@handles[ key ] if @@handles[ key ]
			$stderr.puts( %Q{Mysql.connect( "%s", "%s", "%s", "%s" )} % 
						 [ host, username, password, database ])
			handle = Mysql.connect( host, username, password, database )
			@@handles[ key ] = handle
			return @@handles[ key ]
		end


		### (CLASS) METHOD: fetchTableInfoHash( tableName )
		### Returns a hash of field information about the table this class
		### abstracts. The hash is of the form:
		###
		###	{ String(columnName) => MysqlField(ColumnInfo) }
		###
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


		### (CLASS) METHOD: quoteValuesForField( fieldName, *values )
		### Returns the specified array of values properly quoted for the field
		### specified.
		def quoteValuesForField( field, *values )
			fieldType = self.tableInfo[field].type
			raise ArgumentError, "No such column '#{field}' in the '#{table}' table." unless fieldType

			quotedVals = []
			values.collect {|val|
				case fieldType
				when MysqlField::TYPE_ENUM, MysqlField::TYPE_TIMESTAMP,
						MysqlField::TYPE_DATE, MysqlField::TYPE_TIME,
						MysqlField::TYPE_DATETIME, MysqlField::TYPE_YEAR
					
					"'%s'" % Mysql.escape_string( val.to_s )

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
					"'%s'" % Mysql.escape_string( val.to_s )

				else
					val
				end
			}
		end


		### (CLASS) METHOD: flagList( flags )
		### Return an Array of flag names for the flags given
		def flagList( flags )
			FlagMap.keys.find_all {|key|
				FlagMap[ key ] & flags != 0
			}
		end


		### (CLASS) METHOD: table
		### Return the table associated with this class
		def table
			@@table
		end

		### (CLASS) METHOD: database
		### Return the database associated with this class
		def database
			@@database
		end

		### (CLASS) METHOD: host
		### Return the host associated with this class
		def host
			@@host
		end

		### (CLASS) METHOD: username
		### Return the username associated with this class
		def username
			@@username
		end

		### (PROTECTED CLASS) METHOD: password
		### Return the password associated with this class
		protected
		def password
			@@password
		end


	end # class << self


	###########################################################################
	###	P R O T E C T E D   I N S T A N C E   M E T H O D S
	###########################################################################
	protected

	### METHOD: initialize( row=nil )
	### Initialize an adapter object, optionally setting the state of the
	### abstracted row to the values in the row hash specified.
	def initialize( row=nil )
		@row = RowState.new

		if row.nil?
			@@oCache[ self.class.tableKey() ] ||= ObjectCache.new
		elsif row.is_a?( Hash )
			@row.setState( row )
		else
			raise ArgumentError, "Row must be a hash"
		end
	end


	###########################################################################
	###	P U B L I C   I N S T A N C E   M E T H O D S
	###########################################################################
	public

	### METHOD: store()
	### Store the row in the database
	def store

		# Don't bother storing it unless it's changed
		return true unless @row.hasChanged?

		### Build a SQL phrase that will set/update all of the modified fields.
		setPhrase = @row.modifiedFields.collect {|field|
			quotedVal = self.class.quoteValuesForField(field, @row[field])
			"#{field} = #{quotedVal}"
		}.join(", ")

		dbh = self.class.dbHandle()

		### If the rowid is nil, it means we need to insert, so build an insert
		### SQL query with the set phrase from above and execute it. We then
		### grab the insert id, which should be the rowid if the table's set up
		### correctly, and cache the newly inserted object
		if self.rowid.nil? || self.rowid == "0"
			query = 'INSERT INTO %s SET %s' %
				[ self.class.table, setPhrase ]
			$stderr.puts( "Running query: #{query}" ) if $DEBUG
			res = dbh.query( query )
			insertId = dbh.insert_id
			self.rowid = insertId
			@@oCache[ self.class.tableKey() ] ||= ObjectCache.new
			@@oCache[ self.class.tableKey() ][ insertId ] = self

		### If the rowid isn't nil, we only need an update, so build that and
		### execute it
		else
			query = 'UPDATE %s SET %s WHERE %s = %s' %
				[ self.class.table, setPhrase, self.class.primaryKey(), rowid ]
			$stderr.puts( "Running query: #{query}" ) if $DEBUG
			res = dbh.query( query )
		end

		return true
	end


	### METHOD: delete( cascade=false )
	### Delete the row this object abstracts. Note that this doesn't affect the
	### object's state except to delete its rowid (primary key). The
	### ((|cascade|)) parameter isn't used yet, but will eventually when the
	### object-relational stuff works.
	def delete( cascade=false )
		res = dbh.query("DELETE FROM %s WHERE %s = %s" % [ self.class.table, self.class.primaryKey, rowid ])
		self.rowid = nil
		return true
	end


	### METHOD: [ key ]
	### Column accessor method
	def []( key )
		return self.send( key )
	end


	### METHOD: [ key ]= value
	### Column accessor method
	def []=( key, value )
		return self.send( "#{key}=", value )
	end


	### METHOD: has_key?( keyname )
	### Returns true if the table which this object abstracts has a column named
	### ((|keyname|)).
	def has_key?( keyname )
		return self.class.tableInfo.has_key?( keyname )
	end
	alias :key? :has_key?

	### METHOD: method_missing( aSymbol, *args )
	### Create and call methods that are the same as column names
	def method_missing( aSymbol, *args )
		origMethName = aSymbol.id2name
		methName = origMethName.sub( /=$/, '' )
		super unless self.class.tableInfo.has_key?( methName )

		code = ''

		### :FIXME: This is obviously more generalizable, and really should be
		### made to be more sensitive to the datatype of any field, not just
		### BLOBs.
		if self.class.tableInfo[methName].type == MysqlField::TYPE_BLOB
			code =<<-"ENDCODE"
			def #{methName}

				### :FIXME: There's probably a better way to check for a
				### Marshalled string... This also will break for Marshal format
				### versions with a major number above 10 or a minor number
				### above 99.
				if @row["#{methName}"].is_a?( String ) &&
				   @row["#{methName}"][0] < 10 &&
				   @row["#{methName}"][1] < 100
					Marshal.restore( @row["#{methName}"] )
				else
					@row["#{methName}"]
				end
			end

			def #{methName}=( arg )
				unless (String Numeric).find {|t| arg.type == t}
					@row["#{methName}"] = Marshal.dump( arg )
				else
					@row["#{methName}"] = arg
				end
			end
			ENDCODE
		else
			code =<<-"ENDCODE"
			def #{methName}
				@row["#{methName}"]
			end

			def #{methName}=( arg )
				@row["#{methName}"] = arg
			end
			ENDCODE
		end

		oldVerbose = $VERBOSE
		$VERBOSE = false
		self.class.class_eval code
		$VERBOSE = oldVerbose

		raise RuntimeError, "Method definition for '#{methName}' failed." if method( methName ).nil?
		method( origMethName ).call( *args )
	end


	### METHOD: rowid
	### Fetch the value of the primary key column for this row
	def rowid
		send( self.class.primaryKey() )
	end

	
	### METHOD: rowid=( arg )
	### Set the value of the primary key column for this row
	def rowid=( arg )
		send( "#{self.class.primaryKey()}=", arg )
	end

	
end


### Global function to facilitate the creation of an adapter class.
def TableAdapterClass( db, table, user, pass, host = nil )
	klass = Class.new( TableAdapter )
	klass.class_eval <<-"EOF"
		class << self
			def database
				"#{db}"
			end

			def table
				"#{table}"
			end

			def username
				"#{user}"
			end

			def host
				"#{host}"
			end

			def password
				"#{pass}"
			end
		end
		EOF


	return klass
end



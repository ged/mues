=begin

=MysqlTableAdapter.rb

== Name

MysqlTableAdapter - An adapter class for MySQL tables

== Synopsis

  require "tableadapter/Mysql"

  ### Create an abstract class for adapters for tables in my database
  def MyAdapterClass( table )
      TableAdapterClass( "myDatabase", table, "myUsername", "myPassword", "myDbHost" )
  end

  ### Create a subclass for a specific table
  class MyThingie < MyAdapterClass( "thingie" ); end

  ### Create another one for widgets
  class MyWidget < MyAdapterClass( "widget" ); end

  ### Now fetch a few rows, alter them, and store 'em back into the db
  MyWidget.lookup( 1..10 ) {|widget|
    puts "Incrementing inventory of the #{widget.name} widget."
    widget.inventory += 1
    widget.store
  }

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

== Classes
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

== To Do

More documentation and example code.

The code in this module is still Mysql-specific. I intend (eventually) to
abstract out all the Mysql-specific parts and use a delegate or driver class to
do interaction with the database, but that requires a bit more design
work. Suggestions/patches are welcome.

Here^s a (probably incomplete) list of stuff that will need to be done:

* Abstract out all the database interaction. This will mean that I^ll need to
  move all the functionality of methods like lookup(), primaryKey(), dbHandle(),
  etc. into the delegate. I just don^t yet know how much to move.

* Constants, and ways of discovering metadata about columns will have to be
  moved.

* The caching should probably be kept separate, but I^m not sure how without
  introducing unportable SQL.

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end

		


#!/usr/bin/ruby -w
#
# This file contains the class for the ObjectStore service, as it will be
# used by MUES.
#
# == Copyright
#
# Copyright (c) 2002 FaerieMUD Consortium, all rights reserved.
# 
# This is Open Source Software.  You may use, modify, and/or redistribute 
# this software under the terms of the Perl Artistic License, a copy of which
# should have been included in this distribution (See the file Artistic). If
# it was not, a copy of it may be obtained from
# http://language.perl.com/misc/Artistic.html or
# http://www.faeriemud.org/artistic.html).
# 
# THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTIBILITY AND
# FITNESS FOR A PARTICULAR PURPOSE.
#
# == Synopsis
#
#   require "ObjectStore"
#
#   #:?:  i'll figure this out later.
#
# == Description
#
#   This is the class that implements the storage and retrieval of objects for
#   the ObjectStoreService.  This will use ArunaDB as the database manager.
#
# == Caveats
#
#   All objects stored must inherit from the class StorableObject, for
#   the required ability to be a shallow reference.
#
# == Authors
#
# * Martin Chase <stillflame@FaerieMUD.org>
#

require "a_catalog" #arunadb file
require "a_table"   #arunadb file
require "StorableObject/StorableObject.rb"

class ObjectStore

	#########
	# Class #
	#########

	### Creates a new ObjectStore object, or loads it if it already exists
	def ObjectStore.new(filename, indexes = [], serialize = nil, deserialize = nil)
		if File.exists?(filename)
			file = File.open(filename)
			conf = file.readlines.join('')
			file.close
			
			name = ( %r~<name>(.*?)</name>~im.match(conf) )[1]
			catl = ( %r~<catalog>(.*?)</catalog>~im.match(conf) )[1]
			tabl = ( %r~<table>(.*?)</table>~im.match(conf) )[1]
			
			the_cat = A_Catalog.use(catl)
			the_table = A_Table.connect(tabl)
			database = [the_cat, the_table]
		else
			database = ObjectStore.create_database(filename)
		end
		super(filename, database, indexes, serialize, deserialize)
	end

	### Loads in the specified config file, and returns the ObjectStore attached to it
	### arguments:
	###   filename - the filename of the ObjectStore config file (?)
	def ObjectStore.load (*args)
		ObjectStore.new(args[0])
	end
		

	#########
	protected
	#########

	### Creates and returns an ArunaDB database - specifically an array of objects:
	### [A_Catalog, A_Table]
	### typical usage will usually only require accessing the A_Table object, but
	### the catalog should be kept alive.
	### args:
	###   conf_filename - the name of the ObjectStoreConfig file
	def create_database(conf_filename)
		#cat  = A_Catalog.new(filename)
		#fs   = A_FileStore.create(name, blksize, filename)
		#bt   = A_BTree.new(name, fs, filename)
		#cols = []
		#cols << A_Column.new(name,type,not_nil,default,constraint,action,display)
		###repeat
		#pkeys= %w(the primary keys names) or "name"
		#tabl = A_Table.new(name,cols,pkeys)
		#return [cat,tabl]
	end

	### Initializes a new ObjectStore
	### arguments:
	###   filename - the filename to store the ObjectStore config file as
	###   database - the array of ArunaDB objects to be used for storing data
	###   indexes - an array of symbols for methods to create indicies off of
	###   serialize - the symbol for the method to serialize the objects
	###   deserialize - the symbol for the method to deserialize the objects
	def initialize( filename, database, indexes = [],
				    serialize = nil, deserialize = nil)
		@filename = filename
		@indexes = indexes
		@serialize = serialize
		@deserialize = deserialize

		add_indexes( @indexes )
		
		@database = database
		@table = @database[-1]
	end
	
	######
	public
	######
	
	attr_accessor :filename, :indexes, :serialize, :deserialize, :database, :table

	### Stores the objects into the database
	### arguments:
	###   objects - the objects to store
	def store ( *objects )
		objects.flatten!
	end

	### Closes the database.
	### caveats:
	###   This method does not have any way of telling if there are active objects
	###   in the environment which need to be stored.  Use an ObjectStoreGC to keep
	###   track of those objects.
	def close 
	end

	### Gets the object specified by the given id out of the database
	### Well, not really.  returns a StorableObject style shallow reference
	def retrieve ( id )
		StorableObject.new( id )
	end

	### *ACTUALLY* gets the object specifed by the given id out of the database
	def _retrieve ( id )
	end

	def add_indexes ( *indexes )
		@indexes << indexes.flatten
	end

	def empty? 
		@table.nitems == 0
	end

	def open? 
		@table ? true : false
	end

	def entries 
		@table.nitems()
	end

end

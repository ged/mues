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

#require "ArunaDB"
require "StorableObject/StorableObject.rb"

class ObjectStore

	#########
	# Class #
	#########

	### Loads in the specified config file, and returns the ObjectStore attached to it
	### arguments:
	###   filename - the filename of the ObjectStore config file (?)
	### ObjectStoreConfig file format:
	###   it's in XML, a base of 'ObjectStoreConfig', with attributes of
	###      'name' - a name
	###      'catalog' - the filename of the ArunaDB catalog file
	###      'table' - the name of the table to use
	def ObjectStore.load (filename)
		file = File.open(filename)
		conf = file.readlines.join('')
		file.close
		#:TODO: this should use an XML parser of some sort, instead of doing it manually

		#:TODO: parse the data to reveal the location of the database, the
		#       database interface object, and the index, serialize and
		#       deserialize methods.

		#:TODO: return a new ObjectStore object, but without calling initialize.
		#       how?
		#       I think i need to declare my own 'new' method, and make initialize
		#       more general.  i should inquire about this.

		#:!: symbols cannot be serialized (at least not using Marshal#dump)
	end

	#########
	protected
	#########

	### Creates and returns an ArunaDB database - specifically an array of objects:
	### [A_Catalog, A_FileStore, A_BTree, A_Table]
	### typical usage will usually only require accessing the A_Table object, but
	### all should be kept alive.
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
		#tab  = A_Table.new(name,cols,pkeys)
		#return [cat,fs,bt,tab]
	end

	### Initializes a new ObjectStore
	### arguments:
	###   filename - the filename to store the ObjectStore config file as
	###   objects - an array of objects to store
	###   indexes - an array of symbols for methods to create indicies off of
	###   serialize - the symbol for the method to serialize the objects
	###   deserialize - the symbol for the method to deserialize the objects
	def initialize( filename, objects = [], indexes = [],
				    serialize = nil, deserialize = nil )
		if File.exists?(filename)
			return ObjectStore.load(filename)
		end
		@filename = filename
		@indexes = indexes
		@serialize = serialize
		@deserialize = deserialize

		add_indexes( @indexes )

		#:TODO: actually create the database here
		ObjectStore.create_database(filename)

		objects.each {|o|
			store(o)
		}
	end
	
	######
	public
	######
	
	attr_accessor :filename, :indexes, :serialize, :deserialize, :database

	### Stores the objects into the database
	### arguments:
	###   objects - the objects to store
	def store ( *objects )
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

	### ACTUALLY gets the object specifed by the given id out of the database
	def _retrieve ( id )
	end

	def add_indexes ( *indexes )
		@indexes << indexes.flatten
	end

	def empty? 
	end

	def open? 
	end

	def entries 
	end

end

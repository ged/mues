#!/usr/bin/ruby
###########################################################################
=begin

=Search.rb

== Name

Search - A tableadapter search class

== Synopsis

  search = new TableAdapter::Search( AdapterClass, 'name' => /some.*string/ )

  search.each_result {|adapterObj|
    puts "Found #{adapterObj.name}"
  }

== Description

A class which facilitate easy searching of the tables which TableAdapter classes
abstract.

((*More docs later after the API solidifies*))

== Author

Michael Granger <((<ged@FaerieMUD.org|URL:mailto:ged@FaerieMUD.org>))>

Copyright (c) 2001 The FaerieMUD Consortium. All rights reserved.

This module is free software. You may use, modify, and/or redistribute this
software under the terms of the Perl Artistic License. (See
http://language.perl.com/misc/Artistic.html)

=end
###########################################################################

class Search
	include Enumerable

	### Class constants
	Version = %q$Revision: 1.1 $
	Rcsid = %q$Id: Search.rb,v 1.1 2001/04/08 08:23:53 deveiant Exp $

	#######################################################################
	###	C L A S S   M E T H O D S
	#######################################################################
	class << self

		### (STATIC) METHOD: buildWhereClause( aClass, anArray )
		### Given a target class and an array of criteria, which are
		### two-element arrays of the form: [columnName => specification],
		### returns a String which contains the where-clause of a SQL query
		### which will match the criteria
		def buildWhereClause( targetClass, criteriaArray )
			raise TypeError, "Target class must be a TableAdapter class" unless
				targetClass.is_a?( Class ) && targetClass < TableAdapter
			raise TypeError, "Criteria array must be an Array" unless criteriaArray.is_a?( Array )

			return "1=1" if criteriaArray.length == 0

			return criteriaArray.collect {
				|criteria|
				buildWherePhrase( targetClass, criteria )
			}.join( " AND " )
		end

		
		### (STATIC) METHOD: buildWherePhrase( aClass, anArray )
		### Given a target class and a two-element array which specifies a
		### criteria for selection, return a String which contains a phrase
		### suitable for including in a where clause of a SQL statement.
		def buildWherePhrase( targetClass, criteria )

			# Sanity-check the arguments
			raise TypeError "Target class must be a TableAdapter class" unless
				targetClass.is_a?( Class ) && targetClass < TableAdapter
			raise TypeError "Criteria is not an array" unless criteria.is_a?( Array )
			raise TableAdapterError, "Cannot interpret criteria with #(criteria.length} elements" if
				criteria.length != 2

			# Handle each criteria type by building a phrase
			case criteria[1]
			when String, Numeric
				return "#{criteria[0]} = %s" %
					targetClass.quoteValuesForField( criteria[0], criteria[1] )
				
			when Regexp
				return "#{criteria[0]} RLIKE '#{criteria[1].source}'"

			when Range
				return "(%s >= %s AND %s <= %s)" % [
					criteria[0],
					targetClass.quoteValuesForField( criteria[0], criteria[1].begin ),
					criteria[0],
					targetClass.quoteValuesForField( criteria[0], criteria[1].end )
				]

			when Array
				return "%s IN ( %s )" % [
					criteria[0],
					criteria[1].collect {||}
				]

			else
				raise "Unknown type '#{criteria[1].type.name}' for criteria element"
			end
		end

	end # self << class

	### (PROTECTED) METHOD: initialize( class, criteria )
	### Search for objects of the specified class which match the criteria
	### given.  Criteria are specified in the same form as those for
	### addCriteria.
	protected
	def initialize( klass, criteria=nil )
		raise ArgumentError, "Target class must be a Class" unless klass.is_a?( Class )
		raise TypeError, "Target class must be a TableAdapter" unless klass < TableAdapter

		@targetClass	= klass
		@criteria		= []
		@results		= nil
		@resultsCursor	= nil
		@resultsMutex	= RMutex.new
		@executed		= false

		addCriteria( criteria ) if criteria
	end


	#######################################################################
	###	P U B L I C   M E T H O D S
	#######################################################################
	public

	### METHOD: addCriteria( criteriaHash )
	### Add the specified criteria to the search.  Criteria are specified
	### with an array of (({[column name => value]})) array pairs. The type
	### of the value specified controls how the criteria will be met:
	###
	###	String, Numeric - "column = '#{value}'"
	###	Regexp          - "column LIKE '%#{value}%'"
	###	Range           - "column >= #{value.begin} AND column <= #{value.end}"
	###	Array				 - "column IN ( #{value.join(',')} )"
	###
	### If the current criteria is a manually-set query string, calling this
	### method will discard it in favor of the new criteria.
	def addCriteria( newCriteria )

		@resultsMutex.synchronize {
			@results = nil
			@executed = false
			close() if @resultsCursor
			@criteria = [] unless @criteria.is_a?( Array )

			case newCriteria
			when Hash
				@criteria += newCriteria.to_a

			when Array
				@criteria += newCriteria

			else
				raise TypeError, "Criteria to add should be a Hash or an Array of Arrays"
			end
		}

		return @criteria.length
	end
	alias :<< :addCriteria


	### METHOD: queryString
	### Get a SQL string for this search object.
	def queryString
		case @criteria
		when String
			return @criteria

		when Array
			return "SELECT * FROM %s WHERE %s" % [
				@targetClass.table,
				self.class.buildWhereClause( @targetClass, @criteria )
			]

		else
			raise TypeError, "Unhandled criteria type #{@criteria.type.name}"
		end
	end


	### METHOD: queryString=( aString )
	### Set the sql string for this search object explicitly. All current
	### criteria and results are discarded.
	def queryString=( aString )
		@resultsMutex.synchronize {
			finish() if @resultsCursor
			@results = []
			@criteria = aString
		}
	end


	### METHOD: at( anInteger )
	### Fetch the result at the specified index, executing the search if it
	### hasn't been already.
	def at( index )
		execute() unless @executed

		if index < 0
			index = self.length + index
		end

		### Fetch results for the rows necessary to return the requested
		### object
		@resultsMutex.synchronize {
			until index <= @results.length - 1 || ! @resultsCursor
				row = @resultsCursor.fetch_hash
				if row.nil?
					finish()
					break
				end

				@results.push row
			end

			# If the index requested is outside the bounds of the result
			# set, raise an exception
			if index > @results.length - 1
				finish() if @resultsCursor
				return nil
				
			elsif @results[ index ].is_a?( Hash )
				return @results[ index ] = @targetClass.new( @results[index] )

			else
				return @results[ index ]

			end
		}

	end


	### METHOD: [ anInteger ]
	### METHOD: [ start, length ]
	### METHOD: [ aRange ]
	### Returns the element at index ((|anInteger|)), or returns a subarray
	### starting at index ((|start|)) and continuing for ((|length|))
	### elements, or returns a subarray specified by ((|aRange|)). Negative
	### indices count backward from the end of the array (-1 is the last
	### element). Returns nil if any indices are out of range.
	def []( index, length=0 )
		range = if index.is_a?( Range )
				then index
				else Range.new( index, index+length )
				end

		range.collect {|i| self.at( i )}
	end


	### METHOD: each {|item| block}
	### Calls ((|block|)) once for each element in the result set, passing
	### that element as a parameter
	def each
		raise LocalJumpError, "each called without a block" unless block_given?

		index = 0
		item = nil
		while !(( item = self.at(index) )).nil?
			yield( item )
			index += 1
		end
	end
	alias :eachResult :each
	alias :each_result :each

	### METHOD: length
	### Return the number of results in the set
	def length
		execute() unless @executed

		if @resultsCursor
			return @resultsCursor.num_rows
		else
			return @results.length
		end
	end


	### METHOD: execute
	### Execute the search specified by the criteria
	def execute

		# Get the connection from the target class, build and run the query
		@resultsMutex.synchronize {
			dbh = @targetClass.dbHandle
			@resultsCursor = dbh.query( queryString )

			@executed = true
			@results = []
		}
	end


	### METHOD: finish
	### Free the results cursor if it's still alive
	def finish
		@resultsMutex.synchronize {
			@resultsCursor = nil
		}
	end
	
end

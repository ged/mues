#!/usr/bin/ruby
# 
# Adapter.rb contains the abstract base class for MUES::ObjectStore adapters,
# and an exception class which can be used by adapters to indicate error
# conditions within them.
# 
# == Synopsis
# 
#   require "mues/adapters/Adapter"
# 
#   module MUES
#     class ObjectStore
#       class MyAdapter < Adapter
# 
#         def initialize( configObj )
#             ...
#         end
# 
#         def storeObject( obj )
#             ...
#         end
# 
#         def fetchObject( id )
#             ...
#         end
# 
#         def hasObject?( id )
#             ...
#         end
# 
# 		def findIds( pattern )
# 			...
# 		end
# 
#       end
#     end
#   end
# 
# == Contract
# 
# Classes which inherit this one are required to provide implementations for the
# following methods:
# 
# [<tt><b>storeObjects<em>( *objects )</em></b></tt>]
# 
#     Store the specified ((|objects|)) in the ObjectStore and return their
#     (({oids})).
# 
# [<tt><b>fetchObject<em>( *oids )</em></b></tt>]
# 
#     Fetch the objects specified by the given ((|oids|)) from the ObjectStore and
#     return them.
# 
# [<tt><b>stored?<em>( oid )</em></b></tt>]
# 
#     Returns true if an object with the specified ((|oid|)) exists in the
#     ObjectStore.
# 
# == Rcsid
# 
# $Id: Adapter.rb,v 1.10 2002/04/01 16:27:31 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT for licensing details.
#

require "mues"
require "mues/Exceptions"


module MUES
	class ObjectStore

		### An exception class for indicating problems within an
		### MUES::ObjectStore::Adapter.
		class AdapterError < Exception; end

		### ObjectStore adapter abstract base class. This is an abstract base
		### class which defines the required interface for MUES::ObjectStore
		### adapters. You shouldn't use this class directly; it should be used
		### as a superclass for your own adapter classes.
		class Adapter < MUES::Object ; implements MUES::Debuggable, MUES::AbstractClass

			### Class constants
			Version = /([\d\.]+)/.match( %q$Revision: 1.10 $ )[1]
			Rcsid = %q$Id: Adapter.rb,v 1.10 2002/04/01 16:27:31 deveiant Exp $

			### Class variables
			@@AdapterClasses = {}

			### Class methods
			class << self

				### Inheritance callback: Called when this class is
				### inherited. Adds +subclass+ to the list of valid adapter
				### classes that can be used by a MUES::ObjectStore.
				def inherited( subclass )
					debugMsg( 2, "Adding ObjectStore adapter class '#{subclass.name}'" )
					@@AdapterClasses[ subclass.name ] = subclass
				end


				### Returns the adapter class that matches the specified +name+,
				### if any.
				def getAdapterClass( name )
					checkType( name, ::String )

					@@AdapterClasses.each {|className,klass|
						return klass if className =~ name
					}

					return nil
				end

			end


			#########
			protected
			#########

			### Initialize the adapter with the specified +config+ object (a
			### MUES::Config object). This method should be called via
			### <tt>super()</tt> in a derivative's initializer.
			def initialize( config ) # :notnew:
				super()
				@config = config['objectstore']
			end


			######
			public
			######

			# The 'objectstore' section of the configuration used by the adapter
			# (a MUES::Config::Section object)
			attr_reader :config

			# Virtual methods
			abstract :storeObjects,
				:fetchObjects,
				:stored?,
				:findIds

		end
	end
end

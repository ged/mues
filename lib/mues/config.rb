#!/usr/bin/ruby
#
# This module contains the MUES::Config class, which is a configuration file
# reader/writer. Given an IO object, a filename, or a String with configuration
# contents, this class parses the configuration and returns an instantiated
# configuration object that provides a method interface to the config
# values. MUES::Config objects can also dump the configuration back into a
# string for writing.
# 
# The config file can be in any format for which there is a loader class; see
# the CONFIGURATION file for more information about the details.
#
# == Rcsid
# 
# $Id$
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

require 'pluginfactory'

require 'mues/mixins'
require 'mues/exceptions'

# Configuration-instantiation dependencies
require 'mues/logger'
require 'mues/object'
require 'mues/objectstore'
require 'mues/environment'
require 'mues/filters/commandshell'
require 'mues/filters/questionnaire'
require 'mues/eventqueue'

module MUES

	### A configuration file reader/writer object class. Given an IO object, a
	### filename, or a String with configuration contents, this class parses the
	### configuration and returns an instantiated configuration object that
	### provides a method interface to the config values. MUES::Config objects
	### can also dump the configuration back into a string for writing.
	class Config < MUES::Object
		extend Forwardable

		### Class constants/methods
		Version = /([\d\.]+)/.match( %q{$Revision: 1.32 $} )[1]
		Rcsid = %q$Id$

		def self::debugMsg( *msgs )
			$stderr.puts msgs.join
		end

		# Define the layout and defaults for the underlying structs
		Defaults = {
			:general => {
				:serverName			=> "Experimental MUD",
				:serverDescription	=> "An experimental MUES server",
				:serverAdmin		=> "MUES ADMIN <muesadmin@localhost>",
				:rootDir			=> ".",
				:includePath		=> ["lib"],
			},

			:engine => {
				:tickLength			=> 1.0,
				:exceptionStackSize	=> 10,
				:debugLevel			=> 0,
				:eventQueue			=> {
					:minWorkers => 5,
					:maxWorkers => 50,
					:threshold  => 2,
					:safeLevel 	=> 2,
				},
				:privilegedEventQueue => {
					:minWorkers => 2,
					:maxWorkers => 5,
					:threshold  => 1.5,
					:safeLevel 	=> 1,
				},
				:objectStore => {
					:name			=> 'engine',
					:backend		=> 'BerkeleyDB',
					:memorymanager	=> 'Null',
					:visitor		=> nil,
					:argHash		=> {},
				},

				:listeners => {
					'shell' => {
						:kind	=> 'telnet',
						:params	=> {
							:bindPort		=> 4848,
							:bindAddress	=> '0.0.0.0',
							:useWrapper		=> false,
							:questionnaire	=> {
								:name => 'login',
								:params => {
									:userPrompt => 'Username: ',
									:passPrompt => 'Password: ',
								}
							},
							:banner => <<-'...END'.gsub(/\t+/, ''),
								--- #{general.serverName} ---------------
								#{general.serverDescription}
								Contact: #{general.serverAdmin}
							...END
						},
					},
				},
			},

			:environments => {
				:envPath	=> ["server/environments"],
				:autoload	=> {
					'null' => {
						:kind => 'Null',
						:description => "A testing environment without any surroundings.",
						:params => {},
					},
				}
			},

			:commandShell => {
				:commandPath => [],
				:shellClass => nil,
				:tableClass	=> nil,
				:parserClass => nil,
				:params => {
					:reloadInterval => 50,
					:defaultPrompt => 'mues> ',
					:commandPrefix => '/',
				},
			},

			:logging => {
				'MUES'			=> {
					:level => :notice,
					:outputters => ""
				},
				'MUES::Engine'	=> {
					:level => :info,
					:outputters => {"file" => "server/log/server.log"},
				}
			},
		}
		Defaults.freeze



		#############################################################
		###	C L A S S   M E T H O D S
		#############################################################

		### The default config file loader to use
		@defaultLoader = 'yaml'
		@loaders = {}
		class << self
			attr_accessor :defaultLoader, :loaders
		end


		### Get the loader by the given name, creating a new one if one is not
		### already instantiated.
		def self::getLoader( name=nil )
			name ||= self.defaultLoader
			self.loaders[name] ||= MUES::Config::Loader::create( name )
		end


		### Read and return an MUES::Config object from the given file or
		### configuration source using the specified +loader+.
		def self::load( source, loaderObj=nil )
			loaderObj = self.getLoader( loaderObj ) unless
				loaderObj.is_a?( MUES::Config::Loader )
			confighash = loaderObj.load( source )

			obj = new( untaintValues(confighash) )
			obj.loader = loaderObj
			obj.name = source

			return obj
		end


		### Return a copy of the specified +hash+ with all of its values
		### untainted.
		def self::untaintValues( hash )
			newhash = {}
			hash.each {|key,val|
				case val
				when Hash
					newhash[ key ] = untaintValues( hash[key] )

				when NilClass, TrueClass, FalseClass, Numeric, Symbol
					newhash[ key ] = val

				when Array
					MUES::Logger[ self ].debug "Untainting array %p" % [val]
					newval = val.collect {|v| v.dup.untaint}
					newhash[ key ] = newval
					
				else
					MUES::Logger[ self ].debug "Untainting %p" % val
					newval = val.dup
					newval.untaint
					newhash[ key ] = newval
				end
			}
			return newhash
		end


		### Return a duplicate of the given +hash+ with its keys transformed
		### into symbols from whatever they were before.
		def self::internifyKeys( hash )
			unless hash.is_a?( Hash )
				raise TypeError, "invalid confighash: Expected Hash, not %s" %
					hash.class.name
			end

			newhash = {}
			hash.each {|key,val|
				if val.is_a?( Hash )
					newhash[ key.to_s.intern ] = internifyKeys( val )
				else
					newhash[ key.to_s.intern ] = val
				end
			}

			return newhash
		end


		### Return a version of the given +hash+ with its keys transformed
		### into Strings from whatever they were before.
		def self::stringifyKeys( hash )
			newhash = {}
			hash.each {|key,val|
				if val.is_a?( Hash )
					newhash[ key.to_s ] = stringifyKeys( val )
				else
					newhash[ key.to_s ] = val
				end
			}

			return newhash
		end



		#############################################################
		###	I N S T A N C E   M E T H O D S
		#############################################################

		### Create a new MUES::Config object. Values passed in via the
		### +confighash+ will be used instead of the defaults.
		def initialize( confighash={} )
			ihash = self.class.internifyKeys( confighash )
			mergedhash = Defaults.merge( ihash, &MUES::HashMergeFunction )
			@struct = ConfigStruct::new( mergedhash )
			@createTime = Time::now
			@name = nil
			@loader = self.class.getLoader

			super()
		end


		######
		public
		######

		# Define delegators to the inner data structure
		def_delegators :@struct, :to_h, :member?, :members

		# The underlying config data structure
		attr_reader :struct

		# The time the configuration was loaded
		attr_accessor :createTime

		# The loader that will be used to save this config
		attr_reader :loader

		# The name of the associated record stored on permanent storage for this
		# configuration.
		attr_accessor :name


		### Change the configuration object's loader. The +newLoader+ argument
		### can be either an MUES::Config::Loader object or the name of one
		### suitable for passing to MUES::Config::Loader::create.
		def loader=( newLoader )
			if newLoader.is_a?( MUES::Config::Loader )
				@loader = newLoader
			else
				@loader = self.class.getLoader( newLoader )
			end
		end


		### Write the configuration object using the specified name and any
		### additional +args+.
		def write( name=@name, *args )
			raise ArgumentError,
				"No name associated with this config." unless name
			lobj = self.loader
			strHash = self.class.stringifyKeys( @struct.to_h )
			self.loader.save( strHash, name, *args )
		end


		### Returns +true+ for methods which can be autoloaded
		def respond_to?( sym )
			return true if @struct.member?( sym.to_s.sub(/(=|\?)$/, '').intern )
			super
		end

		
		### Returns +true+ if the configuration has changed since it was last
		### loaded, either by setting one of its members or changing the file
		### from which it was loaded.
		def changed?
			return true if @struct.modified?
			return false unless self.name
			self.loader.isNewer?( self.name, self.createTime )
		end


		### Reload the configuration from the original source if it has
		### changed. Returns +true+ if it was reloaded and +false+ otherwise.
		def reload
			return false unless @loader && @name
			confighash = @loader.load( @name )
			ihash = self.class.internifyKeys( self.class.untaintValues(confighash) )
			mergedhash = Defaults.merge( ihash, &MUES::HashMergeFunction )
			@struct = ConfigStruct::new( mergedhash )
		end


		#########################################################
		###	C O N F I G U R A T I O N   C O N S T R U C T O R S
		#########################################################

		# This is a collection of methods designed to create properly-configured
		# MUES objects from a configuration object.

		### Instantiate the MUES::Engine's objectstore from the configured
		### values.
		def createEngineObjectstore
			os = self.engine.objectStore

			# Turn the argument hash's keys back into Symbols
			args = {}
			os.argHash.to_h.each {|k,v|
				args[k.intern] = v
			} 

			# Make a Hash out of all the construction arguments
			configHash = {
				:name => os.name,
				:backend => os.backend,
				:memmgr => os.memorymanager,
				:config => args,
			}

			# Visitor element is optional, so don't add it if it's not defined.
			configHash[:visitor] = os.visitor if os.visitor

			return MUES::ObjectStore::create( configHash )
		end


		### Instantiate the primary event queue (a MUES::EventQueue object) from
		### the config values.
		def createEventQueue
			qconfig = self.engine.eventQueue
			return MUES::EventQueue::new(
				qconfig.minWorkers,
				qconfig.maxWorkers,
				qconfig.threshold,
				qconfig.safeLevel,
				"Primary Event Queue" )
		end


		### Instantiate the privileged event queue (a MUES::EventQueue object)
		### from the config values.
		def createPrivilegedEventQueue
			qconfig = self.engine.privilegedEventQueue
			return MUES::EventQueue::new(
				qconfig.minWorkers,
				qconfig.maxWorkers,
				qconfig.threshold,
				qconfig.safeLevel,
				"Privileged Event Queue" )
		end


		### Instantiate a new MUES::CommandShell::Factory from the configured
		### values.
		def createCommandShellFactory
			cshell = self.commandShell
			MUES::CommandShell::Factory::new(
				cshell.commandPath,
				cshell.params.to_h,
				cshell.shellClass,
				cshell.tableClass,
				cshell.parserClass )
		end


		### Instantiate and return one or more MUES::Environment objects from
		### the configuration.
		def createConfiguredEnvironments
			self.log.info "Autoloading %d environments from configuration" %
				self.environments.autoload.nitems
			MUES::Environment::derivativeDirs.unshift( *(self.environments.envPath) )

			return self.environments.autoload.collect {|name, env|
				self.log.debug "Loading a %s env as '%s'" %
 					[ env[:kind], name ]
				MUES::Environment::create(
					env[:kind],
					name,
					env[:description],
					env[:params] )
			}
		end


		### Instantiate and return one or more MUES::Listener objects from the
		### configuration.
		def createConfiguredListeners
			self.log.info "Creating %d listener/s from configuration." %
				self.engine.listeners.nitems

			return self.engine.listeners.collect {|name, lconfig|
				self.log.info "Calling create for a '%s' listener named '%s': " +
					"parameters: %s." %
					[ lconfig[:kind], name, lconfig[:params].inspect ]

				MUES::Listener::create( *(lconfig[:kind, :name, :params]) )
			}
		end


		#########
		protected
		#########

		### Handle calls to struct-members
		def method_missing( sym, *args )
			key = sym.to_s.sub( /(=|\?)$/, '' ).intern
			return super unless @struct.member?( key )

			self.log.debug( "Autoloading #{key} accessors." )

			self.class.class_eval %{
				def #{key}; @struct.#{key}; end
				def #{key}=(*args); @struct.#{key} = *args; end
				def #{key}?; @struct.#{key}?; end
			}

			@struct.send( sym, *args )
		end


		#############################################################
		###	I N T E R I O R   C L A S S E S
		#############################################################

		### Hash-wrapper that allows struct-like accessor calls on nested
		### hashes.
		class ConfigStruct < MUES::Object
			include Enumerable
			extend Forwardable
			
			# Mask most of Kernel's methods away so they don't collide with
			# config values.
			Kernel::methods(false).each {|meth|
				next if /^(?:__|dup|object_id|inspect|class|raise|method_missing)/.match( meth )
				undef_method( meth )
			}

			# Forward some methods to the internal hash
			def_delegators :@hash, :keys, :key?, :values, :value?, :[]


			### Create a new ConfigStruct from the given +hash+.
			def initialize( hash )
				@hash = hash.dup
				@modified = false
			end

			######
			public
			######

			# Modification flag. Set to +true+ to indicate the contents of the
			# Struct have changed since it was created.
			attr_writer :modified


			### Returns the number of items in the struct.
			def length
				return @hash.length
			end
			alias_method :nitems, :length


			### Returns +true+ if the ConfigStruct or any of its sub-structs
			### have changed since it was created.
			def modified?
				return @modified || @hash.values.find {|obj|
					obj.is_a?( ConfigStruct ) && obj.modified?
				}
			end

			
			### Return the receiver's values as a (possibly multi-dimensional)
			### Hash with String keys.
			def to_h
				rhash = {}
				@hash.each {|k,v|
					case v
					when ConfigStruct
						rhash[k] = v.to_h
					when NilClass, FalseClass, TrueClass, Numeric, Symbol
						rhash[k] = v
					else
						rhash[k] = v.dup
					end
				}
				return rhash
			end
			

			### Return +true+ if the receiver responds to the given
			### method. Overridden to grok autoloaded methods.
			def respond_to?( sym, priv=false )
				key = sym.to_s.sub( /(=|\?)$/, '' ).intern
				return true if @hash.key?( key )
				super
			end


			### Returns an Array of the names of the struct's members.
			def members
				@hash.keys.collect {|sym| sym.to_s}
			end


			### Returns +true+ if the given +name+ is the name of a member of
			### the receiver.
			def member?( name )
				return @hash.key?( name.to_s.intern )
			end


			### Call into the given block for each member of the receiver.
			def each( &block ) # :yield: member, value
				@hash.each( &block )
			end


			### Merge the specified +other+ object with this config struct. The
			### +other+ object can be either a Hash or another ConfigStruct.
			def merge!( other )
				case other
				when Hash
					@hash = self.to_h.merge( other,
						&MUES::HashMergeFunction )
					
				when ConfigStruct
					@hash = self.to_h.merge( other.to_h,
						&MUES::HashMergeFunction )

				else
					raise TypeError,
						"Don't know how to merge with a %p" % other.class
				end

				return self
			end


			### Return a new ConfigStruct which is the result of merging the
			### receiver with the given +other+ object (a Hash or another
			### ConfigStruct).
			def merge( other )
				self.dup.merge!( other )
			end


			#########
			protected
			#########

			### Handle calls to key-methods
			def method_missing( sym, *args )
				key = sym.to_s.sub( /(=|\?)$/, '' ).intern
				super unless @hash.key?( key )

				self.class.class_eval {
					define_method( key ) {
						if @hash[ key ].is_a?( Hash )
							@hash[ key ] = ConfigStruct::new( @hash[key] )
						end

						@hash[ key ]
					}
					define_method( "#{key}?" ) {@hash[key] ? true : false}
					define_method( "#{key}=" ) {|val| @hash[key] = val}
				}

				self.send( sym, *args )
			end
		end


		### Abstract base class (and Factory) for configuration loader
		### delegates. Create specific instances with the
		### MUES::Config::Loader::create method.
		class Loader < MUES::Object
			include PluginFactory

			#########################################################
			###	C L A S S   M E T H O D S
			#########################################################

			### Returns a list of directories to search for deriviatives.
			def self::derivativeDirs
				["mues/config"]
			end


			#########################################################
			###	I N S T A N C E   M E T H O D S
			#########################################################

			######
			public
			######

			### Load configuration values from the storage medium associated
			### with the given +name+ (e.g., filename, rowid, etc.) and return
			### them in the form of a (possibly multi-dimensional) Hash.
			def load( name )
				raise NotImplementedError,
					"required method 'load' not implemented in '#{self.class.name}'"
			end


			### Save configuration values from the given +confighash+ to the
			### storage medium associated with the given +name+ (e.g., filename,
			### rowid, etc.) and return them.
			def save( confighash, name )
				raise NotImplementedError,
					"required method 'save' not implemented in '#{self.class.name}'"
			end


			### Returns +true+ if the configuration values in the storage medium
			### associated with the given +name+ has changed since the given
			### +time+.
			def isNewer?( name, time )
				raise NotImplementedError,
					"required method 'isNewer?' not implemented in '#{self.class.name}'"
			end

		end # class Loader

	end # class Config

end # module MUES


if __FILE__ == $0
	loader = ARGV.shift || MUES::Config::defaultLoader
	filename = "default.conf"

	$stderr.puts "Dumping default configuration to '%s' using the '%s' loader" %
		[ filename, loader ]

	conf = MUES::Config::new
	conf.loader = loader
	conf.write( filename )
end


		


#!/usr/bin/ruby
#
# This module contains the MUES::Config class, which is a configuration file
# reader/writer. Given an IO object, a filename, or a String with configuration
# contents, this class parses the configuration and returns an instantiated
# configuration object that provides a method interface to the config
# values. MUES::Config objects can also dump the configuration back into a
# string for writing.
# 
# The config file is an XML document described by the DTD in
# docs/muesconfig.dtd. See the CONFIGURATION file for more information about the
# format of the config file.
#
# *Note:* While instances of this class cannot currently be modified, and cannot
# save itself to a new config file, the intention is to modify it so it can do
# so.
#
# == Example
#
# This is an example config file.
# 
#    <?xml version="1.0" encoding="UTF-8"?>
#    <!DOCTYPE muesconfig SYSTEM "muesconfig.dtd">
#    
#    <muesconfig version="1.1">
#    
#      <!-- General server configuration -->
#      <general>
#    	<server-name>Experimental MUD</server-name>
#    	<server-description>An experimental MUES server.</server-description>
#    	<server-admin>MUES Admin &lt;muesadmin@localhost&gt;</server-admin>
#    	<root-dir>server</root-dir>
#      </general>
#    
#    
#      <!-- Engine (core) configuration -->
#      <engine>
#    
#    	<!-- Number of floating-point seconds between tick events -->
#    	<tick-length>1.0</tick-length>
#    	<exception-stack-size>10</exception-stack-size>
#    	<debug-level>0</debug-level>
#    
#    	<!-- Engine objectstore config -->
#    	<objectstore>
#    	  <backend class="BerkeleyDB"></backend>
#    	  <memorymanager class="Simple">
#    		<param name="trash_rate">50</param>
#    	  </memorymanager>
#    	</objectstore>
#    
#    	<!-- Listener objects -->
#    	<listeners>
#    
#    	  <!-- Telnet listener: MUES::TelnetOutputFilter -->
#    	  <listener name="telnet">
#    		<filter-class>MUES::TelnetOutputFilter</filter-class>
#    		<bind-port>23</bind-port>
#    		<bind-address>0.0.0.0</bind-address>
#    		<use-wrapper>true</use-wrapper>
#    	  </listener>
#    
#    	  <!-- Client listener: MUES::ClientOutputFilter (BEEP) -->
#    	  <listener name="client">
#    		<filter-class>MUES::ClientOutputFilter</filter-class>
#    		<bind-port>2424</bind-port>
#    		<bind-address>0.0.0.0</bind-address>
#    		<use-wrapper>false</use-wrapper>
#    	  </listener>
#    	</listeners>
#      </engine>
#    
#    
#      <!-- Logging system configuration (Log4R format) -->
#      <logging>
#    	<log4r_config>
#    
#    	  <!-- Log4R pre-config -->
#    	  <pre_config>
#    		<parameters>
#    		  <logpath>server/log</logpath>
#    		  <mypattern>%l [%d] %m</mypattern>
#    		</parameters>
#    	  </pre_config>
#    
#    	  <!-- Log Outputters -->
#    	  <outputter type="IOOutputter" name="console" fdno="2" />
#    	  <outputter type="FileOutputter" name="serverlog"
#    		filename="#{logpath}/server.log" trunc="false" />
#    	  <outputter type="FileOutputter" name="errorlog"
#    		filename="#{logpath}/error.log" trunc="true" />
#    	  <outputter type="FileOutputter" name="environmentlog"
#    		filename="#{logpath}/environments.log" trunc="false" />
#    	  <outputter type="EmailOutputter" name="mailadmin">
#    		<server>localhost</server>
#    		<port>25</port>
#    		<from>mueslogs@localhost</from>
#    		<to>muesadmin@localhost</to>
#    	  </outputter>
#    
#    	  <!-- Loggers -->
#    	  <logger name="MUES"   level="INFO"  outputters="serverlog" />
#    	  <logger name="error"  level="WARN"  outputters="errorlog,console" />
#    	  <logger name="dire"   level="ERROR" outputters="errorlog,console,mailadmin" />
#    	</log4r_config>
#      </logging>
#    
#    
#      <!-- Environments which are to be loaded at startup -->
#      <environments>
#    	<environment name="FaerieMUD" class="FaerieMUD::World">
#    	  <objectstore name="FaerieMUD">
#    		<backend class="BerkeleyDB"></backend>
#    		<memorymanager class="PMOS"></memorymanager>
#    	  </objectstore>
#    	</environment>
#    
#    	<environment name="testing" class="MUES::ObjectEnv">
#    	  <objectstore name="testing-objectenv">
#    		<backend class="Flatfile" />
#    		<memorymanager class="Simple">
#    		  <param name="trash_rate">100</param>
#    		</memorymanager>
#    	  </objectstore>
#    	</environment>
#      </environments>
#    
#    
#      <!-- Services which are to be loaded at startup -->
#      <services>
#    	<service name="objectstore" class="MUES::ObjectStoreService" />
#    	<service name="soap" class="MUES::SOAPService">
#    	  <param name="listen-port">7680</param>
#    	  <param name="listen-address">0.0.0.0</param>
#    	  <param name="use-wrappers">true</param>
#    	</service>
#    	<service name="physics" class="MUES::ODEService" />
#    	<service name="weather" class="MUES::WeatherService" />
#      </services>
#    
#    </muesconfig>
#
# This would yield an object that you could use like this:
# 
#   # Hypens become underscores in method names:
#   configObj = MUES::Config::new( "muesconfig.xml" )
#   Dir.chdir configObj.general.root_dir
#   puts "Starting #{configObj.general.server_name}
#
#	# Sections can be interated over...
#   configObj.engine.listeners.each {|listenerConfig|
#
#		# Tag attributes are treated like key-value pairs
#		puts "Starting listener for #{listenerConfig['name']}"
#		startListener( listenerConfig.filter_class,
#		               listenerConfig.bind_address,
#		               listenerConfig.bind_port,
#		               listenerConfig.use_wrapper )
#   }
#
# == Synopsis
# 
#   require "mues/Config"
# 
#   config = MUES::Config::new( "muesconfig.xml" )
#   config.general.items
#   # => ["server_name", "server_admin", "server_description", "root_dir"]
#
#	config.general.server_name
#   # => "Experimental MUD"
#
# == Rcsid
# 
# $Id: config.rb,v 1.8 2002/07/07 18:26:05 deveiant Exp $
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


require 'forwardable'
require 'rexml/document'

require 'mues'
require 'mues/Exceptions'
require 'mues/Environment'


module MUES

	### A configuration file reader/writer class - this reads configuration
	### values from a String (after potentially having first read it in from an
	### IO object), and creates one or more MUES::Config::Section objects to
	### represent the configured values.
	class Config < MUES::Object
		
		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.8 $ )[1]
		Rcsid = %q$Id: config.rb,v 1.8 2002/07/07 18:26:05 deveiant Exp $

		### Return a new configuration object, optionally loading the
		### configuration from <tt>source</tt>, which should be either a file
		### name or an IO object opened to the XML configuration source.
		def initialize( source = nil )

			# If no source is specified, it just gets the default config from
			# the data section below.
			if source.nil?
				source = _getDefaultConfig
				@xmldoc = REXML::Document::new( source )
			else

				# A source argument should be either a filename or an IO already
				# opened to the config XML source.
				unless source.kind_of?( String ) || source.kind_of?( IO )
					raise TypeError "Source must be an IO or the name of a file"
				end

				@xmldoc = REXML::Document::new( source )
			end

			@mainSection = MUES::Config::Section::create( @xmldoc.root )
			super()
		end

		

		######
		public
		######

		# The main section of the config file
		attr_reader :mainSection
		alias :main_section :mainSection

		# The underlying XML document object
		attr_reader :xmldoc


		# Returns the configuration object as a string suitable for
		# debugging. Not to be confused with #to_s, which returns the XML
		# source.
		def inspect
			"<%s %d: Sections: %s>" % [
				self.class.name,
				self.id,
				self.mainSection.subsections.inspect,
			]
		end

		# Overloaded <tt>respond_to?</tt> that knows about autoloading
		# delegation.
		def respond_to?( sym )
			super( sym ) or @mainSection.respond_to? sym
		end

		
		# Autoloading auto-generating delegator method
		def method_missing( sym, *args )
			unless @mainSection.respond_to? sym
				super( sym, *args )
			end

			# Get the name of the method being called, and a non-mutator version
			methodName = sym.id2name

			# Eval the new method code
			self.class.class_eval %{
				def #{methodName}( *args )
					@mainSection.#{methodName}( *args )
				end
				public :#{methodName}
			}
			

			# Raise an error if the method didn't take, or call it if it did
			raise RuntimeError, "Method definition for '#{methodName}' failed." if 
				method( methodName ).nil?
			method( methodName ).call( *args )
		end


		#########
		protected
		#########

		### Return the source of the default configuration as a String.
		def _getDefaultConfig

			# Read through the source for this file, capturing everything
			# between __END__ and __END_DATA__ tokens.
			inDataSection = false
			File::readlines( __FILE__ ).find_all {|line|
				case line
				when /^__END_DATA__$/
					inDataSection = false
					false

				when /^__END__/
					inDataSection = true
					false

				else
					inDataSection
				end
			}.join('')
		end




		### An abstract base class for configuration elements. Both sections and
		### items inherit from this class.
		class Element < MUES::Object ; implements MUES::AbstractClass

			include MUES::TypeCheckFunctions

			### Initialize a new element object with the <tt>xmlElement</tt>
			### specified.
			def initialize( xmlElement, parent=nil ) # :notnew
				checkType( xmlElement, REXML::Element )
				@xmlElement = xmlElement
				@parent = parent
				@name = @xmlElement.name.gsub( '-', '_' )
				@subsections = {}
				@items = {}

				super()
			end


			######
			public
			######

			# Element name
			attr_reader :name

			# REXML::Element object that created this section
			attr_reader :xmlElement


			### Returns an Array of item names contained by this element.
			def items
				return @items.keys
			end


			### Returns an Array of the subsections contained by this element.
			def subsections
				return @subsections.keys
			end


			### Dump the configuration section as a string, indented by
			### <tt>indent</tt> character.
			def dump( indent=0 )
				source = ''
				@xmlElement.write( source, indent )
				return source
			end

			### Return a string containing a human-readable representation of
			### the section.
			def inspect
				"<%s %d: %s Subsections: %s Items: %s>" % [
					self.class.name,
					self.id,
					self.name,
					self.subsections.inspect,
					self.items.inspect,
				]
			end


			### Get the element attribute by the <tt>name</tt> specified.
			def []( name )
				name = name.to_s.gsub( '_', '-' ).downcase
				return @xmlElement.attributes[ name ]
			end


			### Set the element's attribute specified by +name+ to the +value+
			### specified.
			def []=( name, value )
				name = name.to_s.gsub( '_', '-' ).downcase
				@xmlElement.attributes[ name ] = value.to_s
			end


			### Return true if the current element has a sub-section with the
			### specified <tt>name</tt>.
			def has_subsection?( name )
				return false
			end


			### Return true if the current element has a sub-item with the
			### specified <tt>name</tt>.
			def has_item?( name )
				return false
			end

		end



		### Configuration item class -- This class stores leaf-nodes of the
		### configuration, along with any associated attributes.
		class Item < MUES::Config::Element

			### Create and return a new configuration item object from the
			### specified <tt>xmlElement</tt> (a REXML::Element object).
			def initialize( xmlElement, parent = nil )
				super( xmlElement, parent )
			end


			######
			public
			######
			
			### Returns the item cast into an appropriate datatype
			def value
				val = @xmlElement.text
				return case val
					   when /^\d+\.\d+$/
						   val.to_f

					   when /^\d+$/
						   val.to_i

					   else
						   val
					   end
			end

		end




		### Configuration section class -- base (factory) class for
		### configuration sections. Each oontainer element in the configuration
		### file (except some special cases like <param> and <log4r_config>)
		### becomes a Section object.
		class Section < MUES::Config::Element

			@@SectionTypes = {}

			### Class methods
			class << self

				### Callback for inheritance -- registers the section derivative
				### in the @@SectionTypes hash with the element name as the
				### key. Eg., MUES::Config::EngineSection => 'engine',
				### MUES::Config::ObjectStoreSection => 'objectstore', etc.
				def inherited( subclass )
					typeName = subclass.name.gsub( /MUES::Config::(\w+)Section/, "\\1" )
					@@SectionTypes[ typeName.downcase ] = subclass
				end

				### Instantiate and return a section object of the correct type,
				### given the specified <tt>element</tt> (a REXML::Element
				### object), and an optional <tt>parent</tt> element.
				def create( element, parent=nil )
					typeName = element.name.downcase
					raise MUES::ConfigError, "Unknown section type '#{typeName}'" unless
						@@SectionTypes.key? typeName

					@@SectionTypes[ typeName ].new( element, parent )
				end
			end


			### Return a new config section object with the <tt>sectionName</tt>
			### specified.
			def initialize( xmlElement, parent=nil ) # notnew
				super( xmlElement, parent )

				@items = {}
				@parameters = {}

				# Add a subsection or a config item for each sub-element,
				# converting any hyphens to underscores so they're valid method
				# names.
				@xmlElement.elements.collect {|elem|
					addSubelement( elem )
				}

			end


			######
			public
			######

			### Returns true if the configuration section has a subsection with
			### the specified <tt>name</tt>. <EM>Aliases:</EM>
			### <tt>subsection?</tt>.
			def has_subsection?( name )
				key = name.downcase.gsub('-', '_')
				@subsections.has_key?( key ) && @subsections[ key ].kind_of?( MUES::Config::Section )
			end
			alias :subsection? :has_subsection?


			### Returns true if the configuration section has an item with
			### the specified <tt>name</tt>. <EM>Aliases:</EM>
			### <tt>item?</tt>.
			def has_item?( name )
				key = name.downcase.gsub('-', '_')
				@items.has_key?( key ) && @items[ key ].kind_of?( MUES::Config::Item )
			end
			alias :item? :has_item?


			### Overloaded <tt>respond_to?</tt> that knows about autoloading
			### element-methods.
			def respond_to?( sym )
				super( sym ) or @subsections.key? sym.to_s or @items.key? sym.to_s
			end


			### Element-reference operator. Return the result of calling the
			### method indicated by the specified <tt>name</tt>, which can be a
			### Symbol or a String, or <tt>nil</tt> if no such method exists.
			def []( sym )
				return super( sym ) unless
					self.has_subsection?( sym.to_s ) ||
					self.has_item?( sym.to_s )
				return self.send( sym )
			end


			### Autoloading element-method constructor
			def method_missing( sym, *args )
				methodName = sym.id2name.gsub( "-", "_" )
				super( sym, *args ) unless 
					@subsections.key?( methodName ) || @items.key?( methodName )

				# Install an accessor method
				if @subsections.key? methodName
					self.class.class_eval <<-END
					def #{methodName}
						@subsections['#{methodName}']
					end
					END
				else
					self.class.class_eval <<-END
					def #{methodName}
						@items['#{methodName}'].value
					end
					END
				end

				# Raise an error if the method didn't take, or call it if it did
				raise RuntimeError, "Method definition for '#{methodName}' failed." \
					if method( methodName ).nil?
				method( methodName ).call( *args )
			end


			#########
			protected
			#########

			### Add the specified element to this section with the specified
			### name.
			def addSubelement( element )
				checkType( element, REXML::Element )
				name = element.name.gsub( '-', '_' )

				# Create a new item for whichever section is appropriate
				# based on whether or not it has sub-elements, and set the
				# target hash to the correct one.
				if element.has_elements?
					self.addSubsection( MUES::Config::Section::create(element, self), name )
				else
					self.addItem( MUES::Config::Item::new(element, self), name )
				end
			end


			### Add the specified <tt>section</tt> to the current one as a
			### sub-section with the specified name.
			def addSubsection( section, name )
				checkType( section, MUES::Config::Section )

				# Make an array out of the target value if there's already
				# one defined. Otherwise, just set it.
				if @subsections.key? name
					unless @subsections[ name ].is_a? Array
						@subsections[ name ] = @subsections[ name ].to_a
					end
					@subsections[ name ] << section
				else
					@subsections[ name ] = section
				end
			end


			### Add the specified <tt>item</tt> (leaf node) to the current
			### section with the specified name.
			def addItem( item, name )
				checkType( item, MUES::Config::Item )

				# Make an array out of the target value if there's already
				# one defined. Otherwise, just set it.
				if @items.key? name
					unless @items[ name ].is_a? Array
						@items[ name ] = @items[ name ].to_a
					end
					@items[ name ] << item
				else
					@items[ name ] = item
				end
			end

			
			# Given a String or a REXML::Text object, return the boolean
			# (<tt>true</tt> or <tt>false</tt> equivalent)
			def asBoolean( item )
				return case item.to_s
					   when /^false$/i, /^no$/i, "0", 0
						   false
					   else
						   true
					   end
			end

		end # class Section


		### Base class for sections which act as containers for one or more
		### sub-elements (eg., environments, services).
		class EnumerableSection < MUES::Config::Section

			include Enumerable
			extend  Forwardable

			
			### Create and return a new MUES::Config::EnvironmentsSection object.
			def initialize( element, parent )
				@items = {}
				super( element, parent )
			end

			
			######
			public
			######

			# Delegate the Enumerable interface to the underlying Hash
			def_delegators :@items, *( Hash.instance_methods - %w{inspect} )

			### Returns a stringified version of the services section object
			def inspect
				"<%s %d: %s>" % [
					self.class.name,
					self.id,
					@items.inspect,
				]
			end

		end




		#############################################################
		###	C O N C R E T E   S E C T I O N   C L A S S E S
		#############################################################

		### The base configuration section class -- this section contains all of
		### the other sections.
		class MuesConfigSection < MUES::Config::Section
		end # class MuesConfigSection


		### The general configuration section class -- this section contains
		### things like the server name, admin name and email, the server
		### description offered at connect-time, and the server root directory.
		class GeneralSection < MUES::Config::Section
		end # class GeneralSection 


		### The engine configuration section class -- this section contains
		### configuration items for the MUES::Engine.
		class EngineSection < MUES::Config::Section
		end # class EngineSection 


		### The logging configuration section class -- this section contains a
		### Log4R-style XML configuration for configuring the server's internal
		### logging.
		class LoggingSection < MUES::Config::Section

			### Create and return a new <tt>logging</tt> section object from the
			### specified element and parent element.
			def initialize( element, parent )
				@logConfig = nil
				super( element, parent )
			end


			######
			public
			######

			# The raw XML Log4r-style logging configuration.
			attr_reader :logConfig


			#########
			protected
			#########

			### Read the Log4r configuration from the specified element.
			def addSubelement( element )
				text = ''
				element.write( text )
				@logConfig = text
			end
		end # class LoggingSection 


		### Environments configuration section class -- this section specifies
		### MUES::Environment objects to load at server startup.
		class EnvironmentsSection < MUES::Config::EnumerableSection

			######
			public
			######

			### Create and return MUES::Environment objects that were specified
			### by this section.
			def getConfiguredEnvironments( config )
				environments = []

				# Iterate 
				self.each {|name,env|
					MUES::Environment::create(  )
				}
			end


			#########
			protected
			#########

			### Extract the configuration information from the specified
			### <tt>env</tt> REXML::Element, and add it to the array of
			### environments.
			def addSubelement( env )
				checkType( env, REXML::Element )

				if env.name == 'environment'
					ostore = Section::create( env.elements["objectstore"], self )
					@items[ env.attributes["name"] ] = {
						'class'		=> env.attributes["class"],
						'ostore'	=> ostore,
					}

				else
					raise MUES::ConfigError,
						"Unknown subelement #{name} in environments section"
				end
			end
		end # class EnvironmentsSection 


		### Services configuration section. This section contains the list of
		### MUES::Service objects which should be loaded at Engine startup.
		class ServicesSection < MUES::Config::EnumerableSection


			######
			public
			######

			### Callback -- load the specifications of a service to be loaded
			### from the REXML::Element <tt>service</tt>.
			def addSubelement( service )
				checkType( service, REXML::Element )

				if service.name == 'service'
					parameters = {}
					service.elements.each("param") {|param|
						parameters[ param.attributes["name"] ] = param.text
					}

					@items[ service.attributes["name"] ] = {
						'class'			=> service.attributes["class"],
						'parameters'	=> parameters
					}

				else
					raise MUES::ConfigError,
						"Unknown subelement #{service.name} in services section"
				end
			end
		end # class ServicesSection 


		### Generic ObjectStore configuration section -- this section is used as
		### a way of specifying configuration for an objectstore for some other
		### section.
		class ObjectStoreSection < MUES::Config::Section

			### Create and return a new MUES::Config::ObjectStoreSection object.
			def initialize( element, parent )
				@backend = nil
				@memoryManager = nil
				@visitor = nil
				@argHash = {}

				super( element, parent )
			end


			######
			public
			######

			# The name of the class to be used for the ObjectStore's
			# backend.
			attr_reader :backend

			# The name of the class to be used for the ObjectStore's
			# memory-manager.
			attr_reader :memoryManager

			# The name of the visitor class to be used when traversing the
			# objectspace, if specified.
			attr_reader :visitor

			# The arguments hash used to configure the MM and Backend
			attr_reader :argHash


			### Inspect method -- returns a stringified version of the object
			### suitable for debugging.
			def inspect
				"<%s '%s' (%d): Backend: %s, MemoryManager: %s, Visitor: %s>" % [
					self.class.name,
					self['name'],
					self.id,
					self.backend.inspect,
					self.memoryManager.inspect,
					self.visitor.inspect,
				]
			end


			### Add the configuration data specified by the given
			### <tt>element</tt> to the objectstore configuration.
			def addSubelement( element )
				checkType( element, REXML::Element )
				name = element.name.gsub( '-', '_' )

				# Parse the elements that belong to an ObjectStoreSection and
				# any parameters that belong to them.
				case name

				# MemoryManager element
				when /memorymanager/i
					className = element.attributes["class"]
					params = {}
					element.each_element {|param|
						raise MUES::ConfigError,
							"Unknown element #{element.name} in memorymanager" unless
							param.name = 'param'
						params[ param.attributes["name"] ] = param.text
					}
					@memoryManager = className
					@argHash[:memoryManager] = params

				# Backend element
				when /backend/i
					className = element.attributes["class"]
					params = {}
					element.each_element {|param|
						raise MUES::ConfigError,
							"Unknown element #{element.name} in memorymanager" unless
							param.name = 'param'
						params[ param.attributes["name"] ] = param.text
					}
					@backend = className
					@argHash[:backend] = params

				when /visitor/
					className = element.attributes["class"]
					params = {}
					element.each_element {|param|
						raise MUES::ConfigError,
							"Unknown element #{element.name} in visitor" unless
							param.name = 'param'
						params[ param.attributes["name"] ] = param.text
					}
					@visitor = className
					@argHash[:visitor] = params

				else
					raise MUES::ConfigError,
						"Unknown subelement #{name} in objectstore section"
				end
			end

		end # class ObjectStoreSection


		### Listeners configuration -- this section specifies types and
		### configuration data for the listeners the Engine should load at
		### startup. See MUES::Listener for more information about listeners.
		class ListenersSection < MUES::Config::EnumerableSection

			#########
			protected
			#########

			### Read listener configuration information from the specified
			### <tt>listener</tt> REXML::Element object, and add it to the array
			### of listeners to be loaded at startup.
			def addSubelement( listener )
				checkType( listener, REXML::Element )

				if listener.name == 'listener'
					@items[ listener.attributes["name"] ] = {
						'filterClass'	=> listener.elements["filter-class"].text,
						'bindPort'		=> listener.elements["bind-port"].text.to_i,
						'bindAddr'		=> listener.elements["bind-address"].text,
						'useWrapper'	=> asBoolean( listener.elements["use-wrapper"].text )
					}

				else
					raise MUES::ConfigError,
						"Unknown subelement #{name} in listeners section"
				end
			end
		end

	end # class Config
end # module MUES


# Embed the default configuration
__END__
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE muesconfig SYSTEM "muesconfig.dtd">

<muesconfig version="1.1" time-stamp="07-Jul-2002 10:02:25">

  <!-- General server configuration -->
  <general>
	<server-name>Experimental MUD</server-name>
	<server-description>An experimental MUES server.</server-description>
	<server-admin>MUES Admin &lt;muesadmin@localhost&gt;</server-admin>
	<root-dir>server</root-dir>
  </general>


  <!-- Engine (core) configuration -->
  <engine>

	<!-- Number of floating-point seconds between tick events -->
	<tick-length>1.0</tick-length>
	<exception-stack-size>10</exception-stack-size>
	<debug-level>0</debug-level>
	
	<!-- Engine objectstore config -->
	<objectstore name="mues">
	  <backend class="BerkeleyDB"></backend>
	  <memorymanager class="Simple">
		<param name="interval">50</param>
	  </memorymanager>
	  <visitor class="ObjectSpaceVisitor">
	</objectstore>

	<!-- Listener objects -->
	<listeners>

	  <!-- Telnet listener: MUES::TelnetOutputFilter -->
	  <listener name="telnet">
		<filter-class>MUES::TelnetOutputFilter</filter-class>
		<bind-port>23</bind-port>
		<bind-address>0.0.0.0</bind-address>
		<use-wrapper>true</use-wrapper>
	  </listener>
	  
	  <!-- Client listener: MUES::ClientOutputFilter (BEEP) -->
	  <listener name="client">
		<filter-class>MUES::ClientOutputFilter</filter-class>
		<bind-port>2424</bind-port>
		<bind-address>0.0.0.0</bind-address>
		<use-wrapper>false</use-wrapper>
	  </listener>
	</listeners>
  </engine>
  

  <!-- Logging system configuration (Log4R format) -->
  <logging>
	<log4r_config>

	  <!-- Log4R pre-config -->
	  <pre_config>
		<parameter name="logpath" value="server/log" />
		<parameter name="mypattern" value="%l [%d] %m" />
	  </pre_config>

	  <!-- Log Outputters -->
	  <outputter type="IOOutputter" name="console" fdno="2" />
	  <outputter type="FileOutputter" name="serverlog"
		filename="#{logpath}/server.log" trunc="false" />
	  <outputter type="FileOutputter" name="errorlog"
		filename="#{logpath}/error.log" trunc="true" />
	  <outputter type="FileOutputter" name="environmentlog"
		filename="#{logpath}/environments.log" trunc="false" />
	  <outputter type="EmailOutputter" name="mailadmin" server="localhost"
		port="25" from="mueslogs@localhost" to="muesadmin@localhost" />

	  <!-- Loggers -->
	  <logger name="MUES"   level="INFO"  outputters="serverlog" />
	  <logger name="error"  level="WARN"  outputters="errorlog,console" />
	  <logger name="dire"   level="ERROR" outputters="errorlog,console,mailadmin" />
	</log4r_config>
  </logging>

  
  <!-- Environments which are to be loaded at startup -->
  <environments>
	<environment name="FaerieMUD" class="FaerieMUD::World">
	  <objectstore name="FaerieMUD">
		<backend class="BerkeleyDB" />
		<memorymanager class="PMOS" />
	  </objectstore>
	</environment>
	
	<environment name="testing" class="MUES::ObjectEnv">
	  <objectstore name="testing-objectenv">
		<backend class="Flatfile" />
		<memorymanager class="Simple">
		  <param name="interval">100</param>
		</memorymanager>
	  </objectstore>
	</environment>
  </environments>

  
  <!-- Services which are to be loaded at startup -->
  <services>
	<service name="objectstore" class="MUES::ObjectStoreService" />
	<service name="soap" class="MUES::SOAPService">
	  <param name="listen-port">7680</param>
	  <param name="listen-address">0.0.0.0</param>
	  <param name="use-wrappers">true</param>
	</service>
	<service name="physics" class="MUES::ODEService" />
	<service name="weather" class="MUES::WeatherService" />
  </services>

</muesconfig>

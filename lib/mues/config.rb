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
#	<?xml version="1.0" encoding="UTF-8"?>
#	<!DOCTYPE muesconfig SYSTEM "muesconfig.dtd">
#	
#	<muesconfig version="1.1" time-stamp="$Date: 2002/08/01 06:07:27 $">
#	
#	  <!-- General server configuration -->
#	  <general>
#		<server-name>Experimental MUD</server-name>
#		<server-description>An experimental MUES server.</server-description>
#		<server-admin>MUES Admin &lt;muesadmin@localhost&gt;</server-admin>
#		<root-dir>server</root-dir>
#	  </general>
#	
#	
#	  <!-- Engine (core) configuration -->
#	  <engine>
#	
#		<!-- Number of floating-point seconds between tick events -->
#		<tick-length>1.0</tick-length>
#		<exception-stack-size>10</exception-stack-size>
#		<debug-level>0</debug-level>
#	
#		<!-- Engine EventQueue configuration -->
#		<eventqueue>
#		  <!-- Minimum number of worker threads to have running at all times -->
#		  <minworkers>5</minworkers>
#	
#		  <!-- Maximum number of worker threads to have running at any time -->
#		  <maxworkers>50</maxworkers>
#		  
#		  <!-- What $SAFE should be set to running inside a worker thread -->
#		  <safelevel>2</safelevel>
#	
#		  <!-- The number of seconds to wait before changing the number of worker
#		  threads that are currently running -->
#		  <threshold>2</threshold>
#		</eventqueue>
#	
#		<!-- Engine objectstore config -->
#		<objectstore name="mues">
#		  <backend class="BerkeleyDB" />
#		  <memorymanager class="Simple">
#			<param name="interval">50</param>
#		  </memorymanager>
#		  <visitor class="ObjectSpaceVisitor" />
#		</objectstore>
#	
#		<!-- Listener objects -->
#		<listeners>
#	
#		  <!-- Telnet listener: MUES::TelnetOutputFilter -->
#		  <listener name="telnet">
#			<filter-class>MUES::TelnetOutputFilter</filter-class>
#			<bind-port>23</bind-port>
#			<bind-address>0.0.0.0</bind-address>
#			<use-wrapper>true</use-wrapper>
#		  </listener>
#		  
#		</listeners>
#	  </engine>
#	  
#	
#	  <!-- Logging system configuration (Log4R format) -->
#	  <logging>
#		<log4r_config>
#	
#		  <!-- Log4R pre-config -->
#		  <pre_config>
#			<parameter name="logpath" value="server/log" />
#			<parameter name="mypattern" value="%l [%d] %m" />
#		  </pre_config>
#	
#		  <!-- Log Outputters -->
#		  <outputter type="IOOutputter" name="console" fdno="2" />
#		  <outputter type="FileOutputter" name="serverlog"
#			filename="#{logpath}/server.log" trunc="false" />
#		  <outputter type="FileOutputter" name="errorlog"
#			filename="#{logpath}/error.log" trunc="true" />
#		  <outputter type="FileOutputter" name="environmentlog"
#			filename="#{logpath}/environments.log" trunc="false" />
#		  <outputter type="EmailOutputter" name="mailadmin" server="localhost"
#			port="25" from="mueslogs@localhost" to="muesadmin@localhost" />
#	
#		  <!-- Loggers -->
#		  <logger name="MUES"   level="INFO"  outputters="serverlog" />
#		  <logger name="error"  level="WARN"  outputters="errorlog,console" />
#		  <logger name="dire"   level="ERROR" outputters="errorlog,console,mailadmin" />
#		</log4r_config>
#	  </logging>
#	
#	  
#	  <!-- Environments which are to be loaded at startup -->
#	  <environments>
#		<environment name="null" class="NullEnv">
#		  <description>A testing environment without any surrounding.</description>
#		  <objectstore name="FaerieMUD">
#			<backend class="BerkeleyDB" />
#			<memorymanager class="PMOS" />
#		  </objectstore>
#		</environment>
#		
#		<environment name="testing" class="MUES::ObjectEnv">
#		  <description>A surroundings/object proving ground.</description>
#		  <objectstore name="testing-objectenv">
#			<backend class="Flatfile" />
#			<memorymanager class="Simple">
#			  <param name="interval">100</param>
#			</memorymanager>
#		  </objectstore>
#		</environment>
#	  </environments>
#	
#	  <commandshell class="MUES::CommandShell">
#		<param name="reload-interval">50</param>
#		<param name="default-prompt">mues&gt; </param>
#		<param name="command-prefix">/</param>
#		<commandspath>
#		  <directory>server/commands</directory>
#		</commandspath>
#	  </commandshell>
#	  
#	</muesconfig>
#
# This would yield an object that you could use like this:
# 
#   # Hypens become underscores in method names:
#   configObj = MUES::Config::new( "muesconfig.xml" )
#   Dir.chdir configObj.general.root_dir
#   puts "Starting #{configObj.general.server_name}
#
#   # Sections can be interated over...
#   configObj.engine.listeners.each {|listenerConfig|
#
#       # Tag attributes are treated like key-value pairs
#       puts "Starting listener for #{listenerConfig['name']}"
#       startListener( listenerConfig.filter_class,
#                      listenerConfig.bind_address,
#                      listenerConfig.bind_port,
#                      listenerConfig.use_wrapper )
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
#   config.general.server_name
#   # => "Experimental MUD"
#
# == Rcsid
# 
# $Id: config.rb,v 1.10 2002/08/01 06:07:27 deveiant Exp $
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


module MUES

	### A configuration file reader/writer class - this reads configuration
	### values from a String (after potentially having first read it in from an
	### IO object), and creates one or more MUES::Config::Section objects to
	### represent the configured values.
	class Config < MUES::Object
		
		### Class constants
		Version = /([\d\.]+)/.match( %q$Revision: 1.10 $ )[1]
		Rcsid = %q$Id: config.rb,v 1.10 2002/08/01 06:07:27 deveiant Exp $

		### Return a new configuration object, optionally loading the
		### configuration from <tt>source</tt>, which should be either a file
		### name or an IO object opened to the XML configuration source.
		def initialize( source = nil )

			@fileSource = nil
			@loadTime = Time::now

			# If no source is specified, it just gets the default config from
			# the data section below.
			if source.nil?
				source = getDefaultConfig()
				@xmldoc = REXML::Document::new( source )
			else

				# A source argument should be either a filename or an IO already
				# opened to the config XML source.
				if source.kind_of?( String )
					@fileSource = source
					io = File::new( source, "r" )
				elsif source.kind_of?( IO )
					io = source
				else
					raise TypeError, "Source must be an IO or the name of a file"
				end

				@xmldoc = REXML::Document::new( io )
				io.close
			end

			@mainSection = MUES::Config::Section::create( @xmldoc.root )
			super()

			return true
		end

		

		######
		public
		######

		# The main section of the config file
		attr_reader :mainSection
		alias :main_section :mainSection

		# The underlying XML document object
		attr_reader :xmldoc


		# Reload the configuration from the original source. Returns
		# <tt>true</tt> if the configuration had changed and was successfully
		# reloaded. If the config object was loaded without a file as the
		# original source, this method will just return false.
		def reload
			return false unless @fileSource
			unless File.readable?( @fileSource )
				return false
			end

			initialize( @fileSource )
		end


		# Returns <tt>true</tt> if the source file for this configuration has
		# changed. If the config object wasn't loaded from a file, or the file
		# has not changed since it was read, <tt>false</tt> is returned.
		def fileHasChanged?
			return false unless @fileSource
			return @loadTime < File.stat( @fileSource ).mtime
		end


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
		def getDefaultConfig

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
				@name = @xmlElement.name.gsub( /-/, '_' )
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
				name = name.to_s.gsub( /_/, '-' ).downcase
				return @xmlElement.attributes[ name ]
			end


			### Set the element's attribute specified by +name+ to the +value+
			### specified.
			def []=( name, value )
				name = name.to_s.gsub( /_/, '-' ).downcase
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
				key = name.downcase.gsub(/-/, '_')
				@subsections.has_key?( key ) && @subsections[ key ].kind_of?( MUES::Config::Section )
			end
			alias :subsection? :has_subsection?


			### Returns true if the configuration section has an item with
			### the specified <tt>name</tt>. <EM>Aliases:</EM>
			### <tt>item?</tt>.
			def has_item?( name )
				key = name.downcase.gsub(/-/, '_')
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
				methodName = sym.id2name.gsub( /-/, "_" )
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
				name = element.name.gsub( /-/, '_' )

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
					   when /^false$/i, /^no$/i, /^off$/i
						   false
					   else
						   item
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


		### The EventQueue configuration section class -- this section contains
		### configuration items for the MUES::EventQueue that runs in the
		### Engine.
		class EventQueueSection < MUES::Config::Section
		end # class EventQueueSection 


		### The Login configuration section class -- this section contains
		### configuration items for controlling user login via
		### MUES::LoginSession objects.
		class LoginSection < MUES::Config::Section
		end # class LoginSection


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

			#########
			protected
			#########

			### Extract the configuration information from the specified
			### <tt>env</tt> REXML::Element, and add it to the array of
			### environments.
			def addSubelement( env )
				checkType( env, REXML::Element )

				if env.name == 'environment'
					parameters = {}
					env.elements.each("param") {|param|
						parameters[ param.attributes["name"] ] = asBoolean( param.text )
					}

					ostore = Section::create( env.elements["objectstore"], self )
					description = env.elements["description"].text

					@items[ env.attributes["name"] ] = {
						'class'			=> env.attributes["class"],
						'description'	=> description,
						'parameters'	=> parameters,
						'ostore'		=> ostore,
					}

				else
					raise MUES::ConfigError,
						"Unknown subelement #{name} in environments section"
				end
			end
		end # class EnvironmentsSection 


		### Generic ObjectStore configuration section -- this section is used as
		### a way of specifying configuration for an objectstore for some other
		### section.
		class ObjectStoreSection < MUES::Config::Section

			### Create and return a new MUES::Config::ObjectStoreSection object.
			def initialize( element, parent )
				@backend = nil
				@memoryManager = nil
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

			# The arguments hash used to configure the MM and Backend
			attr_reader :argHash


			### Inspect method -- returns a stringified version of the object
			### suitable for debugging.
			def inspect
				"<%s '%s' (%d): Backend: %s, MemoryManager: %s>" % [
					self.class.name,
					self['name'],
					self.id,
					self.backend.inspect,
					self.memoryManager.inspect,
				]
			end


			### Add the configuration data specified by the given
			### <tt>element</tt> to the objectstore configuration.
			def addSubelement( element )
				checkType( element, REXML::Element )
				name = element.name.gsub( /-/, '_' )

				# Parse the elements that belong to an ObjectStoreSection and
				# any parameters that belong to them.
				case name

				# MemoryManager element
				when /memorymanager/i
					className = element.attributes["class"]
					params = {}
					element.each_element {|param|
						raise MUES::ConfigError,
							"Unknown element #{param.name} in memorymanager" unless
							param.name = 'param'
						params[ param.attributes["name"].intern ] = param.text
					}
					@memoryManager = className
					@argHash[:memoryManager] = params

				# Backend element
				when /backend/i
					className = element.attributes["class"]
					params = {}
					element.each_element {|param|
						raise MUES::ConfigError,
							"Unknown element #{param.name} in backend" unless
							param.name = 'param'
						params[ param.attributes["name"].intern ] = param.text
					}
					@backend = className
					@argHash[:backend] = params

				when /param/i
					key = element.attributes["name"].to_s.intern
					@argHash[key] = element.text

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

				name = listener.attributes["name"]

				if listener.name == 'listener'
					parameters = {}
					listener.elements.each("param") {|param|
						parameters[ param.attributes["name"] ] = param.text
					}

					@items[ name ] = {
						'class'			=> listener.attributes["class"] || name.capitalize,
						'parameters'	=> parameters,
					}

				else
					raise MUES::ConfigError,
						"Unknown subelement #{name} in listeners section"
				end
			end
		end

		### CommandShell configuration section. This section contains the
		### configuration values for the MUES::CommandShell, or an alternative
		### class to use instead.
		class CommandShellSection < MUES::Config::Section

			### Create and return a new MUES::Config::CommandShellSection object.
			def initialize( element, parent )
				@parameters		= {}
				@commandPath	= []
				@shellClass		= element.attributes['shell-class']
				@tableClass		= element.attributes['table-class']
					 
				super( element, parent )
			end

			######
			public
			######

			# The Array of directories to search for command source files.
			attr_reader :commandPath

			# The Hash of parameters specified for the command shell
			attr_reader :parameters

			# The command-shell class to use (potentially nil)
			attr_reader :shellClass

			# The command-table class to use (potentially nil)
			attr_reader :tableClass


			### Callback -- load the specifications for the command shell from
			### the REXML::Element <tt>commandshell</tt>.
			def addSubelement( elem )
				checkType( elem, REXML::Element )

				case elem.name

				when 'commandspath'
					elem.each_element {|dir|
						raise MUES::ConfigError,
							"Unknown element #{dir.name} in commandshell/commandspath" unless
							dir.name = 'directory'
						@commandPath << dir.text
					}

				when 'param'
					@parameters[ elem.attributes['name'] ] = elem.text

				else
					raise MUES::ConfigError,
						"Unknown subelement #{commandshell.name} in commandshell section"
				end
			end

			### Provide a stringified representation of the commandshell section
			def inspect
				"<%s (%d): Parameters: %s, Command Path: %s>" % [
					self.class.name,
					self.id,
					self.parameters.inspect,
					self.commandPath.inspect,
				]
			end

		end # class CommandShellSection 

	end # class Config
end # module MUES


# Embed the default configuration
__END__
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE muesconfig PUBLIC "-//FAERIEMUD//MUES Config v0.02//EN" "../docs/muesconfig.dtd">

<muesconfig version="1.1" time-stamp="$Date: 2002/08/01 06:07:27 $">
  <general>
	<server-name>FaerieMUD</server-name>
	<server-description>This is an experimental MUES server.</server-description>
	<server-admin>ged@FaerieMUD.org</server-admin>
	<root-dir>/var/mud</root-dir>
  </general>

  <engine>
	<eventqueue>
	  <maxworkers>50</maxworkers>
	  <minworkers>5</minworkers>
	  <safelevel>2</safelevel>
	  <threshold>0.5</threshold>
	</eventqueue>
	<objectstore name="engine">
	  <backend class="Flatfile" />
	  <memorymanager class="Null" />
	</objectstore>
	<listeners>
	  <listener name="telnet" class="Telnet" />
	</listeners>
  </engine>

  <login>
	<maxtries>3</maxtries>
	<timeout>300</timeout>
	<banner>FaerieMUD MUES</banner>
	<userprompt>User: </userprompt>
	<passprompt>Pass: </passprompt>
  </login>

  <logging>
	<log4r_config>
	  <pre_config>
	  </pre_config>
	</log4r_config>
  </logging>

  <environments>
  </environments>

  <commandshell>
	<commandspath>
	  <directory>server/shellCommands/</directory>
	</commandspath>
  </commandshell>
</muesconfig>


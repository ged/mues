#!/usr/bin/ruby
# 
# This file contains a collection of interfaces and mixins for MUES classes.
# 
# It contains the following modules:
#
# [<tt>MUES</tt>]
#    The base namespace.
#
# [<tt>MUES::TypeCheckFunctions</tt>]
#    A collection of type-checking functions.
#
# [<tt>MUES::SafeCheckFunctions</tt>]
#    A collection of <tt>$SAFE</tt> and taint-checking functions.
#
# [<tt>MUES::ServerFunctions</tt>]
#    A collection of functions that allow interaction with the Engine outside of
#    the event subsystem.
#
# [<tt>MUES::AbstractClass</tt>]
#    An interface/mixin for designating a class as abstract (ie., incapable of
#    being instantiated).
#
# [<tt>MUES::Debuggable</tt>]
#    An interface/mixin that adds debugging functions and methods to a class.
#
# [<tt>MUES::FactoryMethods</tt>]
#    A mixin that adds methods to a class that allow it to be used as a factory
#    for derivative classes that follow a certain naming convention.
#
# [<tt>MUES::Notifiable</tt>]
#    An interface/mixin that designates a class as being interested in receiving
#    a notification when the Engine is starting or stopping.
#
# [<tt>MUES::UtilityFunctions</tt>]
#    A mixin that contains some miscellaneous utility functions.
#
# == Synopsis
# 
#   require "mues/Mixins"
#
#   class MyClass
#   include MUES::AbstractClass, MUES::FactoryMethods, MUES::Debuggable,
#           MUES::TypeCheckFunctions, MUES::SafeCheckFunctions,
#           MUES::ServerFunctions, MUES::Notifiable
# 
# == Rcsid
# 
# $Id: mixins.rb,v 1.21 2003/09/12 02:19:37 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Alexis Lee <red@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'mues/Exceptions'

module MUES

	# A mixin that adds abstractness to a class. Instantiating a class which includes
	# this mixin will result in an InstantiationError.
	module AbstractClass

		### Raise an exception if called in a Class which mixes this in.
		def new( *args, &block )
			if instance_variables.include?("@isAbstract")
				raise InstantiationError if self.instance_variable_get( :@isAbstract )
			end
			super
		end


		### Only allow Class objects to be extended.
		def self::extend_object( obj )
			unless obj.is_a?( Class )
				raise TypeError, "Cannot extend a #{obj.class.name}."
			end
			obj.instance_variable_set( :@isAbstract, true )
			super
		end

		### Add a <tt>new</tt> class method to the class which mixes in this
		### module. The method raises an exception if called on the class
		### itself, but not if called via <tt>super()</tt> from a subclass.
		def self::included( klass )
			klass.extend( self )
		end

	end # module AbstractClass



	### An interface that can be implemented by objects (typically, but not necessarily,
	### classes) which need global notification of changes to the Engine^s state outside
	### of the event system. This can be used for initialization and/or cleanup when the
	### event system is not running.
	###
	### The methods which it requires be implemented are:
	###
	### [<tt>atEngineStartup( <em>engineObject</em> )</tt>]
	###   This method will be called during engine startup, immediately after the
	###   event subsystem is started. Any returned events will be dispatched from
	###   the Engine.
	###
	### [<tt>atEngineShutdown( <em>engineObject</em> )</tt>]
	###   This method will be called just before the engine shuts down, and can be
	###   used to queue critical cleanup events that need to be executed before
	###   the event subsystem is shut down.
	module Notifiable
		@@NotifiableClasses = []

		### Returns an array of classes which implement the MUES::Notifiable
		### interface.
		def self::classes
			@@NotifiableClasses
		end

		### Add the class which is including us to our array of notifiable
		### classes.
		def self::included( klass )
			@@NotifiableClasses |= [ klass ]
			
			super( klass )
		end

	end # module Notifiable


	### A mixin that can be used to add debugging capability to a class and its
	### instances.
	module Debuggable

		### Include callback that ensures 'mues/Log' is required before adding
		### methods which depend on it.
		def self::included( mod )
			require "mues/Log"
			super
		end


		### Add and initialize the @debugLevel of the reciever.
		def initialize( *args ) # :notnew:
			@debugLevel = 0
			super
		end


		### Returns the current debugging level as a Fixnum. Higher values = more
		### debugging output
		def debugLevel
			@debugLevel ||= 0
		end

		### Set the debugging level of the reciever. The <tt>value</tt> argument
		### can be <tt>true</tt>, <tt>false</tt>, a Numeric, or a String that
		### yields something Numeric when <tt>to_i</tt> is called.
		def debugLevel=( value )
			case value
			when true
				@debugLevel = 1
			when false
				@debugLevel = 0
			when Numeric, String
				value = value.to_i
				value = 5 if value > 5
				value = 0 if value < 0
				@debugLevel = value
			else
				raise TypeError, "Cannot set debugging level to #{value.inspect} (#{value.class.name})"
			end
		end

		### Returns true if the current debugging level of the reciever is
		### greater than or equal to the specified <tt>level</tt>.
		def debugged?( level=1 )
			debugLevel() >= level
		end


		###############
		module_function
		###############

		### Output <tt>messages</tt> to the debugging log if the
		### <tt>debugLevel</tt> of the calling object is greater than or equal
		### to <tt>level</tt>
		def debugMsg( level, *messages )
			raise TypeError, "Level must be a Fixnum, not a #{level.class.name}." unless
				level.is_a?( Fixnum )
			return unless debugged?( level )

			logMessage = messages.collect {|m| m.to_s}.join('')
			frame = caller(1)[0]
			if Thread.current != Thread.main && Thread.current.respond_to?( :desc )
				logMessage = "[Thread: #{Thread.current.desc}] #{frame}: #{logMessage}"
			elsif Thread.current != Thread.main
				logMessage = "[Thread #{Thread.current.id}] #{frame}: #{logMessage}"
			else
				logMessage = "#{frame}: #{logMessage}"
			end

			self.log.debug( logMessage )
		end

		# Backward-compatibility alias
		alias :_debugMsg :debugMsg
		
	end # module Debuggable

	
	### Mixin that adds some type-checking functions to the current scope
	module TypeCheckFunctions

		###############
		module_function
		###############

		### Check <tt>anObject</tt> to make sure it's one of the specified
		### <tt>validTypes</tt>. If the object is not one of the specified value
		### types, and an optional block is given it is called with the object being
		### tested and the array of valid types. If no handler block is given, a
		### <tt>TypeError</tt> is raised.
		def checkType( anObject, *validTypes ) # :yields: object, *validTypes
			validTypes.flatten!
			validTypes.compact!

			unless validTypes.empty?

				### Compare the object against the array of valid types, and either
				### yield to the error block if given or generate our own exception
				### if not.
				unless validTypes.find {|type| anObject.kind_of?( type ) } then
					typeList = validTypes.collect {|type| type.name}.join(" or ")

					if block_given? then
						yield( anObject, [ *validTypes ].flatten )
					else
						raise TypeError, 
							"Argument must be of type #{typeList}, not a #{anObject.class.name}",
							caller(1).find_all {|frame| /#{__FILE__}/ !~ frame}
					end
				end
			else
				if anObject.nil? then
					if block_given? then
						yield( anObject, *validTypes )
					else
						raise ArgumentError, 
							"Argument missing.",
							caller(1).find_all {|frame| /#{__FILE__}/ !~ frame}
					end
				end
			end

			return true
		end


		### Check each object in the specified <tt>objectArray</tt> with a call to
		### #checkType with the specified validTypes array.
		def checkEachType( objectArray, *validTypes, &errBlock ) # :yields: object, *validTypes
			raise ScriptError, "First argument to checkEachType must be an array" unless
				objectArray.is_a?( Array )

			objectArray.each do |anObject|
				if block_given? then
					checkType anObject, validTypes, &errBlock
				else
					checkType( anObject, *validTypes ) {|obj, vTypes|
						typeList = vTypes.collect {|type| type.name}.join(" or ")
						raise TypeError, 
							"Argument must be of type #{typeList}, not a #{obj.class.name}",
							caller(1).find_all {|frame| /#{__FILE__}/ !~ frame}
					}
				end
			end

			return true
		end


		### Check <tt>anObject</tt> for implementations of <tt>requiredMethods</tt>.
		### If one of the methods is unimplemented, and an optional block is given it
		### is called with the method that failed the responds_to? test and the object
		### being checked. If no handler block is given, a <tt>TypeError</tt> is
		### raised.
		def checkResponse( anObject, *requiredMethods ) # yields method, anObject
			# Red: Throw away any nil types, and warn
			# Debug level might be inappropriate?
			os = requiredMethods.size
			requiredMethods.compact!
			debugMsg(1, "nil given in *requiredMethods") unless os == requiredMethods.size
			if requiredMethods.size > 0 then
				requiredMethods.each do |method|
					next if anObject.respond_to?( method )

					if block_given? then
						yield( method, anObject )
					else
						raise TypeError, "Argument '#{anObject.inspect}' does "\
							"not answer the '#{method}()' method",
							caller(1).find_all {|frame| /#{frame}/ !~ __FILE__}
					end
				end
			end

			return true
		end


		### Check each object of <tt>anArray</tt> for implementations of
		### <tt>requiredMethods</tt>, calling the optional <tt>errBlock</tt> if
		### specified, or raising a <tt>TypeError</tt> if one of the methods is
		### unimplemented.
		def checkEachResponse( anArray, *requiredMethods, &errBlock ) # :yeilds: method, object
			raise ScriptError,
				"First argument to checkEachResponse must be an array" unless
				anArray.is_a?( Array )

			anArray.each do |anObject|
				if block_given? then
					checkResponse anObject, *requiredMethods, &errBlock
				else
					checkResponse( anObject, *requiredMethods ) {|method, object|
						raise TypeError, "Argument '#{anObject.inspect}' does "\
							"not answer the '#{method}()' method",
							caller(1).find_all {|frame| /#{frame}/ !~ __FILE__}
					}
				end
			end

			return true
		end

	end # module TypeCheckFunctions


	### Mixin module that adds some <tt>$SAFE</tt>-level checking functions to the
	### current scope.
	module SafeCheckFunctions

		###############
		module_function
		###############

		### Check the current $SAFE level, and if it is greater than
		### <tt>permittedLevel</tt>, raise a SecurityError.
		def checkSafeLevel( permittedLevel=2 )
			raise SecurityError,
				"Call to restricted method from insecure space ($SAFE = #{$SAFE})",
				caller(1) if $SAFE > permittedLevel
			return true
		end

		### Check the current $SAFE level and the taintedness of the current
		### <tt>self</tt>, raising a SecurityError if <tt>$SAFE</tt> is greater
		### than <tt>permittedLevel</tt>, or <tt>self</tt> is tainted.
		def checkTaintAndSafe( permittedLevel=2 )
			raise SecurityError,
				"Call to restricted code from insecure space ($SAFE = #{$SAFE})",
				caller(1) if $SAFE > permittedLevel
			raise SecurityError,
				"Call to restricted code with tainted receiver",
				caller(1) if self.tainted?
			return true
		end

	end # module SafeCheckFunctions


	### Mixin module that adds various miscellaneous utility functions to the
	### current scope.
	module UtilityFunctions
		
		###############
		module_function
		###############

		### Return an Array of untainted parts of the specified <tt>string</tt>
		### after having been untainted with the given <tt>pattern</tt> (a
		### Regexp object). The pattern should contain paren-groups for all the
		### parts it wishes returned.
		def untaintString( string, pattern )
			match = pattern.match( string ) or return nil
			parts = match.to_a[ 1 .. -1 ].collect{|part| part.untaint}
		end

		### Return a String containing a description of the specified number of
		### <tt>seconds</tt> in the form: "/y/ years /d/ days /h/ hours /m/
		### minutes /s/ seconds". If <tt>includeZero</tt> is <tt>true</tt>,
		### units that are zero are included; if it's <tt>false</tt>, they are
		### omitted. If <tt>joinWithComma</tt>, the units will be separated by a
		### comma in addition to the space.
		def timeDelta( seconds, includeZero=false, joinWithComma=true )
			minuteSeconds	= 60
			hourSeconds		= ( minuteSeconds * 60 )
			daySeconds		= ( hourSeconds * 24 )
			yearSeconds		= ( daySeconds * 365 )

			part = Struct::new( :unit, :count )

			parts = []
			parts << part.new('year', (seconds/yearSeconds).to_i)
			seconds %= yearSeconds

			parts << part.new('day', (seconds/daySeconds).to_i)
			seconds %= daySeconds

			parts << part.new('hour', (seconds/hourSeconds).to_i)
			seconds %= hourSeconds

			parts << part.new('minute', (seconds/minuteSeconds).to_i)
			seconds %= minuteSeconds

			parts << part.new('second', seconds.to_i)

			joinStr = joinWithComma ? ', ' : ' '
			return parts.find_all {|p| includeZero || p.count.nonzero?}.
				collect {|p| "%d %s%s" % [p.count, p.unit, p.count == 1 ? "" : "s"]}.
				join( joinStr )
		end


		### Trim a <tt>string</tt> to the given <tt>maxLength</tt> (at maximum),
		### appending an ellipsis if it was truncated.
		def trimString( string, maxLength=20 )
			if string.length > maxLength
				return string[ 0, maxLength - 3 ] + "..."
			end
			return string
		end


		### Given a Ruby <tt>objectId</tt>, return the specified MUES::Object
		### instance, or <tt>nil</tt> if no such object exists in the
		### objectspace. Can only be used in $SAFE <= 2 and an untainted object.
		def getObjectByRubyId( objectId )
			MUES::SafeCheckFunctions::checkTaintAndSafe()
			targetObject = nil
			ObjectSpace.each_object( MUES::Object ) {|obj|
				next unless obj.id == objectId
				targetObject = obj
				break 
			}
			return targetObject
		end


		### Given a <tt>muesId</tt>, return the specified MUES::Object instance,
		### or <tt>nil</tt> if no such object exists in the objectspace. Can
		### only be used in $SAFE <= 2 and an untainted object.
		def getObjectByMuesId( objectId )
			MUES::SafeCheckFunctions::checkTaintAndSafe()
			targetObject = nil
			ObjectSpace.each_object( MUES::Object ) {|obj|
				next unless obj.muesid == objectId
				targetObject = obj
				break 
			}
			return targetObject
		end

	end


	### A mixin module that adds Engine-access functions to the including
	### namespace.
	module ServerFunctions

		###############
		module_function
		###############

		### Schedule the specified <tt>events</tt> to be dispatched at the
		### <tt>time</tt> specified. If <tt>time</tt> is a <tt>Time</tt> object,
		### it will be executed at the tick which occurs immediately after the
		### specified time. If <tt>time</tt> is a positive <tt>Integer</tt>, it is
		### assumed to be a tick offset, and the event will be dispatched
		### <tt>time</tt> ticks from now.  If <tt>time</tt> is a negative
		### <tt>Integer</tt>, it is assumed to be a repeating event which requires
		### dispatch every <tt>time.abs</tt> ticks.
		def scheduleEvents( time, *events )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			MUES::Engine::instance.scheduleEvents( time, *events )
		end


		### Removes and returns the specified +events+ (MUES::Event objects), if
		### they were scheduled.
		def cancelScheduledEvents( *events )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			MUES::Engine::instance.cancelScheduledEvents( *events )
		end


		### Queue the given +events+ for dispatch.
		def dispatchEvents( *events )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			MUES::Engine::instance.dispatchEvents( *events )
		end


		### Returns an Arry of the names of the loaded environments
		def getEnvironmentNames
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.getEnvironmentNames
		end

		### Get the loaded environment with the specified +name+.
		def getEnvironmentByName( name )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.getEnvironmentByName( name )
		end

		### Return a multi-line string indicating the current status of the engine.
		def engineStatusString
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.getStatusString
		end

		### Fetch a list of the names of all users known to the server, both
		### connected and unconnected.
		def getUserNames
			MUES::SafeCheckFunctions::checkTaintAndSafe( 3 )
			return MUES::Engine::instance.getUserNames
		end

		### Fetch a list of the names of all connected users
		def getConnectedUserNames
			MUES::SafeCheckFunctions::checkTaintAndSafe( 3 )
			return MUES::Engine::instance.getConnectedUserNames
		end

		### Fetch a connected user object by +name+. Returns +nil+ if no such
		### user is currently connected.
		def getUserByName( name )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.getUserByName( name )
		end

		### Add a new user (a MUES::User object) to the Engine's objectstore.
		def registerUser( user )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.registerUser( user )
		end

		### Remove the specified user (a MUES::User oject) from the Engine's
		### objectstore.
		def unregisterUser( user )
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.unregisterUser( user )
		end

		### Turn off 'init mode' in the Engine, if it was on.
		def cancelInitMode
			return MUES::Engine::instance.cancelInitMode
		end

		### Fetch and return the Engine's scheduled events table as a String and
		### return it.
		def engineScheduledEventsString
			MUES::SafeCheckFunctions::checkTaintAndSafe( 2 )
			return MUES::Engine::instance.getScheduledEventsString
		end


	end # module ServerFunctions



	### A mixin that adds factory class methods to a base class, so that
	### subclasses may be instantiated by name.
	module FactoryMethods

		### Inclusion callback -- extends the including class.
		def self::included( klass )
			klass.extend( self )
			klass.extend( MUES::TypeCheckFunctions )
		end


		### Raise an exception if the object being extended is anything but a
		### class.
		def self::extend_object( obj )
			unless obj.is_a?( Class )
				raise TypeError, "Cannot extend a #{obj.class.name}", caller(1)
			end
			obj.instance_variable_set( :@derivatives, {} )
			super
		end


		#############################################################
		###	M I X I N   M E T H O D S
		#############################################################

		### Return the Hash of derivative classes, keyed by various versions of
		### the class name.
		def derivatives
			ancestors.each {|klass|
				if klass.instance_variables.include?( "@derivatives" )
					break klass.instance_variable_get( :@derivatives )
				end
			}
		end


		### Returns the type name used when searching for a derivative.
		def factoryType
			base = nil
			self.ancestors.each {|klass|
				if klass.instance_variables.include?( "@derivatives" )
					base = klass
					break
				end
			}

			raise FactoryError, "Couldn't find factory base for #{self.name}" if
				base.nil?

			if base.name =~ /^.*::(.*)/
				return $1
			else
				return base.name
			end
		end

	
		### Inheritance callback -- Register subclasses in the derivatives hash
		### so that ::create knows about them.
		def inherited( subclass )
			MUES::Log.debug( "Inheritance callback for '%s'" % self.factoryType )
			truncatedName =
				# Handle class names like 'FooBar' for 'Bar' factories.
				if subclass.name.match( /(?:.*::)?(\w+)(?:#{self.factoryType})/ )
					Regexp.last_match[1]
				else
					subclass.name.sub( /.*::/, '' )
				end

			[ subclass.name, truncatedName, subclass ].each {|key|
				MUES::Log.debug( "Registering '%s' as '%s'" % [subclass.name, key] )
				self.derivatives[ key ] = subclass
			}
			super
		end


		### Returns an Array of registered derivatives
		def derivativeClasses
			self.derivatives.values.uniq
		end


		### Given the <tt>className</tt> of the class to instantiate, and other
		### arguments bound for the constructor of the new object, this method
		### loads the derivative class if it is not loaded already (raising a
		### LoadError if an appropriately-named file cannot be found), and
		### instantiates it with the given <tt>args</tt>. The <tt>className</tt>
		### may be the the fully qualified name of the class, the class object
		### itself, or the unique part of the class name. The following examples
		### would all try to load and instantiate a class called
		### "MUES::FooListener" if MUES::Listener included MUES::FactoryMethods
		### (which it does):
		###   obj = MUES::Listener::create( 'MUES::FooListener' )
		###   obj = MUES::Listener::create( MUES::FooListener )
		###   obj = MUES::Listener::create( 'Foo' )
		### If the including class responds to a method called
		### <tt>beforeCreation</tt>, it will be called after the subclass is
		### looked up, but before it is instantiated, passing the subclass, the
		### <tt>className</tt> argument, and the argument array. If the class
		### responds to a method called <tt>afterCreation</tt>, it will be
		### called after the object is instantiated, and is passed the new
		### instance.
		def create( subType, *args )
			checkType( subType, ::String, ::Class )
			subclass = getSubclass( subType )

			if self.respond_to?( :beforeCreation )
				# :TODO: Use return values?
				self.beforeCreation( subclass, subType, *args )
			end

			instance = subclass.new( *args )

			if self.respond_to?( :afterCreation )
				# :TODO: Use return values?
				self.afterCreation( instance, *args )
			end

			return instance
		end


		### Given a <tt>className</tt> like that of the first argument to
		### #create, attempt to load the corresponding class if it is not
		### already loaded and return the class object.
		def getSubclass( className )
			checkType( className, ::Class, ::String )
			return self if ( self.name == className || className == '' )
			return className if className.is_a?( Class ) && className >= self

			unless self.derivatives.has_key?( className )

				self.loadDerivative( className )

				unless self.derivatives.has_key?( className )
					raise FactoryError,
						"loadDerivative(%s) didn't add a '%s' key to the "\
						"registry for %s" % [ className, className, self.name ]
				end
				unless self.derivatives[className].is_a?( Class )
					raise FactoryError,
						"loadDerivative(%s) added something other than a class "\
						"to the registry for %s" % [ className, self.name ]
				end
			end

			return self.derivatives[ className ]
		end


		### Calculates an appropriate filename for the derived class using the
		### name of the base class and tries to load it via <tt>require</tt>. If
		### the including class responds to a method named
		### <tt>derivativeDirs</tt>, its return value (either a String, or an
		### array of Strings) is added to the list of prefix directories to try
		### when attempting to require a modules. Eg., if
		### <tt>class.derivativeDirs</tt> returns <tt>['foo','bar']</tt> the
		### require line is tried with both <tt>'foo/'</tt> and <tt>'bar/'</tt>
		### prepended to it.
		def loadDerivative( className )
			className = className.to_s

			# Get the unique part of the derived class name and try to
			# load it from one of the derivative subdirs, if there are
			# any.
			modName = self.getModuleName( className )
			self.requireDerivative( modName )

			# Check to see if the specified listener is now loaded. If it
			# is not, raise an error to that effect.
			unless self.derivatives[ className ]
				MUES::Log.error "Failed to load '%s' via %s::create" %
					[ className, self.name ]
				raise RuntimeError,
					"Couldn't find a %s named '%s'" % [
					self.factoryType,
					className
				], caller(3)
			end

			return true
		end


		### Build and return the unique part of the given <tt>className</tt>
		### either by stripping leading namespaces if the name already has the
		### name of the factory type in it (eg., 'My::FooService' for
		### MUES::Service, or by appending the factory type if it doesn't.
		def getModuleName( className )
			if className =~ /\w+#{self.factoryType}/
				modName = className.sub( /(?:.*::)?(\w+)(?:#{self.factoryType})?/,
										"\1#{self.factoryType}" )
			else
				modName = "%s#{self.factoryType}" % className
			end

			return modName
		end


		### If the factory responds to the #derivativeDirs method, call
		### it and use the returned array as a list of directories to
		### search for the module with the specified <tt>modName</tt>.
		def requireDerivative( modName )

			# See if we have a list of special subdirs that derivatives
			# live in
			if ( self.respond_to?(:derivativeDirs) )
				subdirs = self.derivativeDirs
				subdirs = [ subdirs ] unless subdirs.is_a?( Array )
				checkEachType( subdirs, ::String )

			# If not, just try requiring it from $LOAD_PATH
			else
				subdirs = ['']
			end

			# Iterate over the subdirs until we successfully require a
			# module.
			subdirs.collect {|dir| dir.strip}.each {|subdir|
				modPath = subdir.empty? ? modName : File::join( subdir, modName )

				MUES::Log.debug(
					%Q{Trying to load '%s' %s with 'require "%s"'} % [
						modName,
						self.factoryType,
						modPath
					]
				)

				# Try to require the module that defines the specified
				# listener
				begin
					require( modPath.untaint )
				rescue LoadError => e
					MUES::Log.warn "No module at '#{modPath}': '#{e.message}'"
				rescue ScriptError,StandardError => e
					MUES::Log.error "Found '#{modPath}', but encountered an error:\n" +
						"    #{e.message} at #{e.backtrace[0]}"
				else
					MUES::Log.info "Successfully loaded '#{modPath}'"
					break
				end
			}

		end

	end # module FactoryMethods

end # module MUES


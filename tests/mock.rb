# Ruby/Mock version 1.0
# 
# A class for conveniently building mock objects in Test::Unit test cases. It is
# based on ideas in Ruby/Mock by Nat Pryce <nat.pryce@b13media.com>, which is a
# class for doing the same thing for RUnit test cases.
#
# == Examples
#
# For the examples below, it is assumed that a hypothetical '<tt>Adapter</tt>'
# class is needed to test whatever class is being tested. It has two instance
# methods in addition to its initializer: <tt>read</tt>, which takes no
# arguments and returns data read from the adapted source, and <tt>write</tt>,
# which takes a String and writes as much as it can to the adapted destination,
# returning any that is left over.
#
#	# With the in-place mock-object constructor, you can make an instance of a
#	# one-off anonymous test class:
#	mockAdapter = Test::Unit::MockObject( Adapter ).new
#	
#	# Now set up some return values for the next test:
#	mockAdapter.setReturnValues( :read => "",
#								 :write => Proc::new {|data| data[-20,20]} )
#	
#	# Mandate a certain order to the calls
#	mockAdapter.setCallOrder( :read, :read, :read, :write, :read )
#
#	# Now start the mock object recording interactions with it
#	mockAdapter.activate
#
#	# Send the adapter to the tested object and run the tests
#	testedObject.setAdapter( mockAdapter )
#	...
#
#	# Now check the order of method calls on the mock object against the expected
#	# order.
#	mockAdapter.verify
#
# == Rcsid
#
# $Id: mock.rb,v 1.1 2002/10/04 09:57:21 deveiant Exp $
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
#
# 
#

require 'algorithm/diff'

require 'test/unit'
require 'test/unit/assertionfailederror'

module Test
	module Unit

		class Mockup

			### Instantiate and return a new mock object after recording the
			### specified args.
			def initialize( *args )
				@args = args
				@calls = []
				@activated = nil
				@returnValues = Hash::new( true )
				@callOrder = []
				@strictCallOrder = false
			end


			#########################################################
			###	F A K E   T Y P E - C H E C K I N G   M E T H O D S
			#########################################################

			# Handle #type and #class methods
			alias :__class :class
			def class # :nodoc:
				return __class.mockedClass
			end
			undef_method :type
			alias :type :class

			# Fake instance_of? and kind_of? with the mocked class
			def instance_of?( klass ) # :nodoc:
				self.class == klass
			end
			def kind_of?( klass ) # :nodoc:
				self.class <= klass
			end


			#########################################################
			###	S E T U P   M E T H O D S
			#########################################################

			### Set the return value for one or more methods. The <tt>hash</tt>
			### should contain one or more key/value pairs, the key of which is
			### the symbol which corresponds to the method being configured, and
			### the value which is a specification of the value to be
			### returned. More complex returns can be configured with one the
			### following types of values:
			### 
			### [<tt>Method</tt> or </tt>Proc</tt>]
			###    A <tt>Method</tt> or <tt>Proc</tt> object will be called with
			###    the arguments given to the method, and whatever it returns
			###    will be used as the return value.
			### [<tt>Array</tt>]
			###    The leftmost value in the <tt>Array</tt> will be returned
			###    after being rotated to the end.
			### [<tt>Hash</tt>]
			###    The Array of method arguments will be used as a key, and
			###    whatever the corresponding value is will be returned.
			###
			### Any other value will be returned as-is. To return one of the
			### above types of objects literally, just wrap it in an Array like
			### so:
			###
			###		# Return a literal Proc without calling it:
			###		mockObj.setReturnValues( :meth => [myProc] )
			###
			###		# Return a literal Array:
			###		mockObj.setReturnValues( :meth => [["an", "array", "of", "stuff"]] )
			def setReturnValues( hash )
				@returnValues.update hash
			end
			alias :__setReturnValues :setReturnValues


			### Set up an expected method call order and argument specification
			### to be checked when #verify is called to the methods specified by
			### the given <tt>symbols</tt>.
			def setCallOrder( *symbols )
				@callOrder = symbols
			end
			alias :__setCallOrder :setCallOrder


			### Set the strict call order flag. When #verify is called, the
			### methods specified in calls to #setCallOrder will be checked
			### against the actual methods that were called on the object.  If
			### this flag is set to <tt>true</tt>, any deviation (missing,
			### misordered, or extra calls) results in a failed assertion. If it
			### is not set, other method calls may be interspersed between the
			### calls specified without effect, but a missing or misordered
			### method still fails.
			def strictCallOrder=( flag )
				@strictCallOrder = true if flag
			end
			alias :__strictCallOrder= :strictCallOrder=


			### Returns true if strict call order checking is enabled.
			def strictCallOrder?
				@strictCallOrder
			end
			alias :__strictCallOrder? :strictCallOrder?



			#########################################################
			###	T E S T I N G   M E T H O D S
			#########################################################

			### Returns an array of Strings describing, in cronological order,
			### what method calls were registered with the object.
			def callTrace
				return [] unless @activated
				@calls.collect {|call|
					"%s( %s ) at %0.5f seconds from %s" % [
						call[:method].to_s,
						call[:args].collect {|arg| arg.inspect}.join(","),
						call[:time] - @activated,
						call[:caller][0]
					]
				}
			end
			alias :__callTrace :callTrace


			### Turn on call registration -- begin testing.
			def activate
				raise "Already activated!" if @activated
				self.__clear
				@activated = Time::now
			end
			alias :__activate :activate


			### Verify the registered required methods were called with the
			### specified args
			def verify
				raise "Cannot verify a mock object that has never been "\
					"activated." unless @activated
				return true if @callOrder.empty?

				actualCallOrder = @calls.collect {|call| call[:method]}
				diff = Diff::diff( @callOrder, actualCallOrder )

				if @strictCallOrder
					unless diff.empty?
						raise AssertionFailedError,
							__callOrderFailMessage( *diff[0] )
					end
				else
					missingDiff = diff.find {|d| d[0] == :-}
					if missingDiff
						raise AssertionFailedError,
							__callOrderFailMessage( *missingDiff )
					end
				end
			end
			alias :__verify :verify


			### Deactivate the object without doing call order checks and clear
			### the call list, but keep its configuration.
			def clear
				@calls.clear
				@activated = nil
			end
			alias :__clear :clear
			

			### Clear the call list and call order, unset any return values, and
			### deactivate the object without checking for conformance to the
			### call order.
			def reset
				self.__clear
				@callOrder.clear
				@returnValues.clear
			end
			alias :__reset :reset


			#########
			protected
			#########

			### Register a call to the faked method designated by <tt>sym</tt>
			### if the object is activated, and return a value as configured by
			### #setReturnValues given the specified <tt>args</tt>.
			def __mockRegisterCall( sym, *args )
				if @activated
					@calls.push({
						:method		=> sym,
						:args		=> args,
						:time		=> Time::now,
						:caller		=> caller(2),
					})
				end

				rval = @returnValues[ sym ]
				case rval
				when Method, Proc
					return rval.call( *args )

				when Array
					return rval.push( rval.shift )[-1]

				when Hash
					return rval[ args ]

				else
					return rval
				end
			end


			### Build and return an error message for a call-order verification
			### failure. The expected arguments are those returned in an element
			### of the Array that is returned from Diff::diff.
			def __callOrderFailMessage( action, position, elements )
				case action

				# "Extra" method/s
				when :+
					extraCall = @calls[ position ]
					return "Call order assertion failed: Unexpected method %s "\
						   "called from %s at %0.5f" %
						   [ extraCall[:method].inspect,
						     extraCall[:caller][0],
							 extraCall[:time] - @activated ]

				when :-
					extraCall = @calls[ position ]
					missingCall = @callOrder[ position ]
					return "Call order assertion failed: Expected call to %s, "\
						   "but got call to %s from %s at %0.5f instead" %
						   [ missingCall.inspect,
							 extraCall[:method].inspect,
						     extraCall[:caller][0],
							 extraCall[:time] - @activated ]

				else
					return "Unknown diff action '#{action.inspect}'"
				end
			end


		end

		
		# Factory for creating semi-functional mock objects given the class
		# which is to be mocked up.
		def self.MockObject( klass )
			mockup = Class::new( Mockup )
			mockup.instance_eval do @mockedClass = klass end

			# Provide an accessor to class instance var that holds the class
			# object we're faking
			def mockup.mockedClass
				self.instance_eval do @mockedClass end
			end

			# Propagate the mocked class ivar to derivatives so we can be called
			# like:
			#   class MockFoo < Test::Unit::MockObject( RealClass )
			def mockup.inherited( subclass )
				mc = self.mockedClass
				subclass.instance_eval do @mockedClass = mc end
			end
			
			# Build method definitions for all the mocked class's instance
			# methods, as well as those given to it by its superclasses, since
			# we're not really inheriting from it.
			imethods = klass.instance_methods(true).collect {|name|
				next if name =~ /^(__|inspect|kind_of?|instance_of?|type|class|method|send|hash)/

				# Figure out the argument list
				argCount = klass.instance_method( name ).arity
				optionalArgs = false

				if argCount < 0
					optionalArgs = true
					argCount = (argCount+1).abs
				end
				
				args = []
				argCount.times do |n| args << "arg#{n+1}" end
				args << "*optionalArgs" if optionalArgs

				# Build a method definition. Some method need special
				# declarations.
				case name.intern
				when :initialize
					"def initialize( %s ) ; super(%s) ; end" %
						[ args.join(','), args.join(',') ]

				else
					"def %s( %s ) ; self.__mockRegisterCall(%s) ; end" %
						[ name, args.join(','), [":#{name}", *args].join(',') ]
				end
			}

			# Now add the instance methods to the mockup class
			mockup.class_eval imethods.join( "\n" )
			return mockup
		end

	end # module Unit
end # module Test



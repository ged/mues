#!/usr/bin/ruby
# 
# This file contains the MUES::Questionnaire class, a derivative of
# MUES::IOEventFilter. Instances of this class are dynamically-configurable
# question and answer session objects which are inserted into a MUES::User's
# MUES::IOEventStream to gather useful information about a subject or task. It
# does this by iterative over one or more steps, prompting the user with a
# question specified by each one, and gathering and validating input sent in
# reply.
#
# When an Questionnaire is created, it is given a procedure for gathering the
# needed information in the form of an Array of one or more "steps", and an
# optional block to be called when all of the necessary questions are answered.
#
# A "step" can be any object which responds to the element reference (#[]) and
# the #key? methods. Both methods will be called with Symbol arguments like
# <tt>:name</tt> and <tt>:question</tt>, and are expected to behave like a Hash
# when responding to them. This makes a Hash a particularly good choice for
# specifying steps. Each step should describe (via responses to said methods)
# the question to be answered and what constitutes acceptable input for each
# step. It may also specify other optional keys to further control the way the
# step is presented or processed. The steps are executed one at a time in the
# order they are in the #steps array at the moment input arrives.
#
# The mandatory keys for a step are:
#
# [<tt>:name</tt>]
#   Specifies an identifier for the question. Validated answers will then be
#   stored in the #answers hash with the symbolified (via <tt>name.intern</tt>)
#   version of this name.
#
# The optional keys for a step are:
#
# [<tt>:question</tt>]
#   A String or MUES::OutputEvent object containing the prompt to be sent to the
#   user upon entering or re-entering this step. If no question is specified, a
#   capitalized version of the <tt>:name</tt> value is used.
#
# [<tt>:validator</tt>]
#   An object which provides validation for input data. It can be one of several
#   different kinds of objects:
#
#   [a Proc or Method object]
#      The Proc or Method will be called with two arguments: the Questionnaire
#      object doing the validation, and the answer as a String. If the validator
#      returns <tt>nil</tt> or <tt>false</tt>, the input data is discarded and
#      the question is re-asked. If the validator returns <tt>true</tt>, the
#      input data is used directly for the answer. Returning anything else
#      causes whatever is returned to be used as the answer.
#
#   [a Regexp object]
#      The validator pattern will be matched against the incoming data, and if
#      no match is found, returns nil. If a match is found, and the Regexp
#      contains paren groups (eg., /(\w+) (\w+)/), the matches from the parent
#      group are used. If the match contains no paren groups, the whole of the
#      match will be used.
#
#   [an Array]
#	   The Array contains a list of valid data; validation succeeds when the
#	   answer matches one of the values. The unchanged data is returned.
#
#   [a Hash]
#	   Validation succeeds when the input data or the Symbol-ified input data
#	   matches one of the keys of the Hash. The corresponding value for that key
#	   is used as the answer.
#
#   If no validator is specified, any input except empty input is accepted
#   as-is. On empty input, the default will be used if specified (see below), or
#   it will cause the Questionnaire to abort if no default exists.
#
# [<tt>:default</tt>]
#   The default value of the question, should no answer be given. If there is no
#   <tt>:default</tt> key in the step, entering a blank line aborts the whole
#   Questionnaire.
#
# [<tt>:errorMsg</tt>]
#   The text of the error message to use for simple validators. If an
#   <tt>:errorMsg</tt> is not supplied, an appropriate message for the type of
#   validator being used will be generated if validation fails.
#
# [<tt>:hidden</tt>]
#   If this key exists in the step and is set to <tt>true</tt>, the prompt sent
#   will be a HiddenInputPromptEvent, which should cause the input for the
#   response to be obscured. Defaults to <tt>false</tt>.
#
# If a block is given at construction, or set later in the object's lifecycle
# via the #finalizer= method, it will be called once all the steps are
# completed, passing the Questionnaire object as an argument.
# 
# == Synopsis
#
#	require 'mues/filters/Questionnaire'
#
#	steps = [
#		{
#			:name		=> 'height',
#			:question	=> "Height: ",
#			:validator	=> /\d+/,
#			:errorMsg	=> "Height must be a number.",
#		},
#		
#		{
#			:name		=> 'color',
#			:question	=> "What color [red,green,blue]?",
#			:validator	=> %w{red green blue},
#		}
#	]
#
#   questionnaire = MUES::Questionnaire::new( 'Set some stuff', steps ) {|questionnaire|
#		thingie = Thingie::new
#
#		thingie.height = questionnaire.answers[:height]
#		thingie.color  = questionnaire.answers[:color]
#		thingie.save
#	}
# 
# == Rcsid
# 
# $Id: questionnaire.rb,v 1.7 2002/10/13 23:37:16 deveiant Exp $
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# 
#:include: COPYRIGHT
#
#---
#
# Please see the file COPYRIGHT in the 'docs' directory for licensing details.
#

require 'sync'

require 'mues/Mixins'
require 'mues/Object'
require 'mues/Exceptions'
require 'mues/Events'
require 'mues/filters/IOEventFilter'


module MUES

	### Instances of this class are dynamically-configurable question and answer
	### wizard IO abstractions which can be inserted into a MUES::User's
	### MUES::IOEventStream to gather information to perform a specific task.
	class Questionnaire < MUES::IOEventFilter ; implements MUES::Debuggable

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.7 $} )[1]
		Rcsid = %q$Id: questionnaire.rb,v 1.7 2002/10/13 23:37:16 deveiant Exp $

		DefaultSortPosition = 600


		### Create a new Questionnaire object.
		def initialize( name, *steps )
			@name = name
			@steps = checkSteps( *(steps.flatten) )
			@stepsMutex = Sync::new
			@currentStepIndex = -1

			# Grab the block given as a Proc if there is one.
			@finalizer = if block_given? then Proc::new else nil end

			@delayedOutputEvents = []
			@delayedOutputEventMutex = Sync::new
			@answers = {}
			@result = nil

			@supportData = {}
			@inProgress = false

			super( DefaultSortPosition )
		end


		######
		public
		######

		# The hash of answers completed so far
		attr_accessor :answers

		# The block to be called when the questionnaire has completed all of its
		# steps. Should be either a Proc or a Method object.
		attr_accessor :finalizer

		# The index of the current step
		attr_accessor :currentStepIndex

		# The steps of the questionnaire
		attr_accessor :steps

		# The return value from the finalizer after the questionnaire is finished
		attr_reader :result

		# The name of the questionnaire
		attr_reader :name

		# Returns true if the session is in progress (ie., has been started, but
		# is not yet finished).
		attr_reader :inProgress
		alias :inProgress? :inProgress
		alias :in_progress? :inProgress

		# Ancillary support data Hash that can be used to pass objects to
		# validators or the finalizer.
		attr_accessor :supportData
		alias :data :supportData



		### Returns a human-readable String describing the object
		def to_s
			if self.inProgress?
				step = @steps[ @currentStepIndex ]
				"%s Questionnaire: %s: %s (%d of %d steps)." % [
					self.name,
					step[:name],
					step.key?(:question) ? step[:question] : step[:name].capitalize,
					@currentStepIndex + 1,
					@steps.length,
				]
			else
				"%s Questionnaire: Not in progress (%d steps)." % [
					self.name,
					@steps.length
				]
			end
		end

		


		#############################################################
		###	I O E V E N T F I L T E R   I N T E R F A C E
		#############################################################

		### Start filter notifications for the specified stream.
		def start( streamObject )
			raise "Questionnaire cannot be started without "\
				"at least one step" if @steps.empty?

			debugMsg 1, "Starting %s questionnaire %s" %
				[ self.name, self.muesid ]
			results = super( streamObject )

			self.askNextQuestion
			return results
		end


		### Stop the filter notifications for the specified stream, returning
		### any final events which should be dispatched on behalf of the filter.
		def stop( streamObject )

			debugMsg 1, "Stopping %s questionnaire %s" %
				[ self.name, self.muesid ]
			results = super( streamObject )
			self.finish

			results.push( MUES::InputEvent::new('') )
			return results
		end


		### Mark the questionnaire as finished and prep it for shutdown
		def finish
			debugMsg 1, "Finishing %s questionnaire %s" %
				[ self.name, self.muesid ]

			@inProgress = false
			@finalizer = nil
			super()

			debugMsg 2, "@isFinished = %s" % @isFinished.inspect
		end


		### Process the specified InputEvents as answers to the unfinished
		### steps.
		def handleInputEvents( *events )

			if self.inProgress?
				# Interate until we run out of events to process or steps to feed
				# answers to
				until events.empty? || ! self.inProgress?
					self.addAnswer( events.shift.data )
				end

				### If we've completed all the steps, call the finalizer.
				unless self.inProgress? || self.finished?
					debugMsg 2, "Last step answered. Calling finalizer."
					@result = @finalizer.call( self ) if @finalizer
					debugMsg 3, "Finalizer returned <%s>" % @result.inspect
					self.finish
				end
			end

			return super( *events )
		end


		### Buffer the specified OutputEvents until the questionnaire is
		### finished or aborted, but send the ones that have been queued
		### internally.
		def handleOutputEvents( *events )
			debugMsg 5, "Called in thread %s via %s" % 
				[ Thread.current.inspect, caller(1).inspect ]
			self.queueDelayedOutputEvents( *events ) unless events.empty?
			events.clear
			results = super( *events )
			debugMsg 3, "Returning #{results.length} output events."
			return results
		end

		### End IOEventFilter interface


		### Add one or more <tt>steps</tt> to the end of the questionnaire. Note
		### that if the questionnaire is in progress when doing this, any
		### answers already given will be cleared, progress reset to step 1, and
		### the first question asked again.
		def addSteps( *steps )
			newSteps = checkSteps( *steps )
			debugMsg 2, "Adding %d new step/s: [%s]" %
				[ newSteps.length, newSteps.collect{|s| s[:name]}.join(', ') ]

			@stepsMutex.synchronize( Sync::SH ) {
				@stepsMutex.synchronize( Sync::EX ) {
					@steps += newSteps
				}

				if self.inProgress?
					self.clear
					self.askNextQuestion
				end
			}
		end


		### Remove one or more <tt>steps</tt> from the questionnaire. If no
		### <tt>steps</tt> are specified, all steps are removed. Note that if
		### the questionnaire is in progress when doing this, any answers
		### already given will be cleared, progress reset to step 1, and the
		### first question asked again.
		def removeSteps( *steps )
			@stepsMutex.synchronize( Sync::SH ) {
				if steps.empty?
					debugMsg 2, "Clearing current steps"
					@stepsMutex.synchronize( Sync::EX ) {
						@steps.clear
					}
				else
					debugMsg 2, "Removing %d steps" % (@steps & steps).length
					@stepsMutex.synchronize( Sync::EX ) {
						@steps -= steps
					}
				end

				if self.inProgress?
					self.clear
					self.askNextQuestion unless @steps.empty?
				end
			}
		end


		### Get a reference to the current step. Returns <tt>nil</tt> if the
		### questionnaire has not yet been started.
		def currentStep
			@stepsMutex.synchronize( Sync::SH ) {
				return nil unless @currentStepIndex >= 0
				@steps[ @currentStepIndex ]
			}
		end


		### Add non-blocked output <tt>events</tt> (such as from the filter
		### itself) to the queue that will go on the next io loop.
		def queueDelayedOutputEvents( *events )
			checkEachType( events, MUES::OutputEvent )

			debugMsg 3, "Queueing %d output events for later" % events.length
			@delayedOutputEventMutex.synchronize( Sync::EX ) {
				@delayedOutputEvents.push( *events )
			}

			return @delayedOutputEvents.size
		end


		### Discard the last <tt>count</tt> answers given and decrement the step
		### index by <tt>count</tt>. If a step has an <tt>:onUndo</tt> pair (the
		### value of which must be an object which answers '<tt>call</tt>', such
		### as a Proc or a Method), it will be called before the step is undone
		### with the Questionnaire as an argument. Returns the new step index.
		def undoSteps( count=1 )
			debugMsg 2, "Undoing %d steps" % count

			@stepsMutex.synchronize( Sync::SH ) {
				raise "Cannot undo more steps than are already complete" unless
					@currentStepIndex >= count

				@stepsMutex.synchronize( Sync::EX ) {
					count.times do
						@currentStepIndex -= 1
						step = self.currentStep
						
						if step.key?( :onUndo )
							step[:onUndo].call( self )
						end
						@answers.delete( step[:name].intern )
					end
				}
			}

			return @currentStepIndex
		end


		### Skip the next <tt>count</tt> steps, and increment the step index by
		### <tt>count</tt>. If a step has an <tt>:onSkip</tt> pair (the value of
		### which must be an object which answers '<tt>call</tt>', such as a
		### Proc or a Method), it will be called as it is skipped with the
		### Questionnaire as an argument, and its return value will be used as
		### the value set in the step's answer. If the step doesn't have an
		### <tt>:onSkip</tt> key, but does have a <tt>:default</tt> pair, its
		### value will be used instead. If it has neither key, the answer will
		### be set to '<tt>:skipped</tt>'. This method returns the new step
		### index.
		def skipSteps( count=1 )
			debugMsg 2, "Skipping %d steps" % count

			@stepsMutex.synchronize( Sync::SH ) {
				raise "Cannot skip more steps than there are remaining uncompleted" if
					@currentStepIndex + count >= @steps.length

				count.times do
					ans = nil
					@currentStepIndex += 1
					step = self.currentStep

					if step.key?( :onSkip )
						ans = step[:onSkip].call( self )
					elsif step.key?( :default )
						ans = step[:default]
					else
						ans = :skipped
					end

					@answers[ step[:name].intern ] = ans
				end
			}

			return @currentStepIndex
		end


		### Reset the questionnaire, discarding answers given up to this point.
		def clear
			debugMsg 1, "Clearing current progress"
			@stepsMutex.synchronize( Sync::EX ) {
				@answers = {}
				@currentStepIndex = -1
				@inProgress = false
				@isFinished = false
			}
		end


		### Clear the questionnaire and ask the first question again.
		def reset
			self.clear
			self.askNextQuestion
		end


		### Abort the current session with the specified <tt>message</tt>. This
		### is a method designed to be used by callback-type answerspecs and
		### pre- and post-processes.
		def abort( message="Aborted.\n\n" )
			debugMsg 2, "Aborting questionnaire: %s" % self.muesid
			self.queueOutputEvents MUES::OutputEvent::new( message )
			self.clear
			self.finish
		end


		### Report an error
		def error( message )
			debugMsg 2, "Sending error message '%s'" % message.chomp
			self.queueOutputEvents MUES::OutputEvent::new( message )
		end



		#########
		protected
		#########

		### Insert the question for the next step into the stream.
		def askNextQuestion
			event = nil

			@stepsMutex.synchronize( Sync::SH ) {

				@stepsMutex.synchronize( Sync::EX ) {
					@inProgress = true
					@currentStepIndex += 1
				}

				debugMsg 2, "Asking question %d" % @currentStepIndex

				# If there's a next step, ask its question
				if (( step = self.currentStep ))

					# If the step has a question value, use it, otherwise use the
					# capitalized name.
					if step.key?( :question )
						if step[:question].kind_of? MUES::OutputEvent
							event = step[:question].dup
						elsif step[ :hidden ]
							event = MUES::HiddenInputPromptEvent::new( step[:question] )
						else
							event = MUES::PromptEvent::new( step[:question].to_s )
						end
					else
						event = MUES::PromptEvent::new( step[:name].capitalize + ": " )
					end

					debugMsg 4, "Question event is <%s>" % event.inspect

				# Otherwise, we're all out of questions
				else
					event = nil
					debugMsg 2, "Last step reached for %s questionnaire %s" %
						[ self.name, self.muesid ]
				end
			}

			if event
				self.queueOutputEvents( event )
				return true
			else
				return false
			end
		end


		### Insert the question for the current step
		def reaskCurrentQuestion
			@stepsMutex.synchronize( Sync::SH ) {
				@stepsMutex.synchronize( Sync::EX ) {
					@currentStepIndex -= 1 unless @currentStepIndex < 0
				}

				self.askNextQuestion
			}
		end


		### Set the specified input <tt>data</tt> (a String) as the answer for
		### the current step, if it validates.
		def addAnswer( data )
			checkType( data, ::String )
			debugMsg 2, "Adding answer '%s' for step %d" %
				[ data, @currentStepIndex ]

			@stepsMutex.synchronize( Sync::SH ) {
				step = self.currentStep
				result = nil

				# Validate the data if it has a validator.
				if step.key?( :validator )
					result = validateAnswer( data, step )
					debugMsg 3, "Validator returned result: %s" % result.inspect
					unless result
						self.reaskCurrentQuestion if self.inProgress?
						return nil
					end

				# If the data's empty, do one of two things: if it has a default,
				# just use that, otherwise assume a blank input is an abort.
				elsif data.empty?
					return handleEmptyInput( step )

				else
					debugMsg 3, "No validator: Accepting answer as-is"
					result = data
				end

				# If we're still here, it means the answer validateed, so set it
				# for this question
				self.answers[ step[:name].intern ] = result

				# Queue the next question, flaging ourselves as no longer
				# needing input events if that fails.
				self.askNextQuestion or @inProgress = false
			}

		end


		### Handle empty input conditions
		def handleEmptyInput( step )
			if step.key?( :default )
				result = step[:default]
				debugMsg 3, "Empty data with no validator -- using default '%s'" % result
			else
				debugMsg 2, "Empty data with no validator and no default -- aborting"
				self.abort
				return nil
			end
		end


		### Use the specified step's validator (a Proc, a Method, a Regexp, an
		### Array, or a Hash) to validate the given data. Returns the validated
		### answer data on success, and false if it fails to validate.
		def validateAnswer( data, step )
			checkType( data, ::String )

			validator = step[:validator]
			debugMsg 3, "Validating answer '%s' with a %s validator" %
				[ data, validator.class.name ]

			result = nil

			# Handle the various types of validators.
			case validator

			# Proc/Method validator - If the return value is false, validation
			# failed. If true, use the original data. Otherwise use whatever the
			# validator returns.
			when Proc, Method
				result = validator.call( self, data.dup ) or return nil
				result = data if result.equal?( true )

			# Regex validator - If the match has paren-groups, use the array of
			# "kept" matches instead of the whole match.
			when Regexp
				if data.empty?
					return handleEmptyInput( step )

				elsif (( match = validator.match( data ) ))
					if match.size > 1
						result = match.to_ary[ 1 .. -1 ]
					else
						result = data
					end
				else
					self.error( step[:errorMsg] || "Invalid input. Must "\
							    "match /#{validator.to_s}/" )
					return nil
				end

			# Array validator - Succeeds if the data is in the array.
			when Array
				if data.empty?
					return handleEmptyInput( step )

				elsif validator.include?( data )
					result = data

				else
					self.error( step[:errorMsg] || "Invalid input. Must "\
							    "be one of:\n  %s." %
							    validator.sort.join(',') )
					return nil
				end

			# Hash validator - If the data is a key of the hash, succeed and use
			# the corresponding value as the answer.  Try both the string and
			# the symbolified string when matching keys.
			when Hash
				if data.empty?
					return handleEmptyInput( step )

				elsif validator.has_key?( data )
					result = validator[data]

				elsif validator.has_key?( data.intern )
					result = validator[data.intern]

				else
					self.error( step[:errorMsg] || "Invalid input. Must "\
							    "be one of:\n  %s." %
							    validator.keys.sort.join(',') )
					return nil
				end					

			# Unhandled validator types
			else
				raise TypeError, "Invalid validator type '#{validator.class.name}'."
			end

			return result
		end


		### Check each of the specified steps for validity.
		def checkSteps( *steps )
			checkEachResponse( steps, :[], :key? )

			debugMsg 3, "Checking %d steps for sanity." % steps.length

			if steps.find {|step| !step.key?( :name )}
				raise ArgumentError, "Invalid step: doesn't have a name key."
			end

			return steps
		end
		


	end # class Questionnaire
end # module MUES


#!/usr/bin/ruby
# 
# This file contains the MUES::Questionnaire class, a derivative of
# MUES::IOEventFilter. Instances of this class are dynamically-configurable
# question and answer session objects which are inserted into a MUES::User's
# MUES::IOEventStream to gather useful information about a subject or task. It
# does this by prompting the user with one or more questions, and gathering and
# validating input sent in reply.
#
# When an Questionnaire is created, it is given a procedure for gathering the
# needed information in the form of one or more "questions" or "steps", and an
# optional block to be called when all of the necessary questions are answered.
#
# A "step" can be any object which responds to the element reference (#[]) and
# the #has? methods. Both methods will be called with Symbol arguments like
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
#	   Validation succeeds when the Array contains a list of valid data. The
#	   unchanged data is returned.
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
# $Id: questionnaire.rb,v 1.1 2002/09/27 16:19:17 deveiant Exp $
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
	class Questionnaire < MUES::IOEventFilter

		### Class constants
		Version = /([\d\.]+)/.match( %q{$Revision: 1.1 $} )[1]
		Rcsid = %q$Id: questionnaire.rb,v 1.1 2002/09/27 16:19:17 deveiant Exp $

		DefaultSortPosition = 600


		### Create a new Questionnaire object.
		def initialize( name, *steps )
			@name = name
			@steps = checkSteps( *steps )
			@stepsMutex = Sync::new
			@currentStepIndex = 0

			# Grab the block given as a Proc if there is one.
			@finalizer = if block_given? then Proc::new else nil end

			@delayedOutputEvents = []
			@delayedOutputEventMutex = Sync::new
			@answers = {}

			@inProgress = false
		end


		######
		public
		######

		# The hash of answers completed so far
		attr_accessor :answers

		# The block to be called when the questionnaire has completed all of its
		# steps. Should be either a Proc or a Method object.
		attr_accessor :finalizer

		# Returns true if the session is in progress (ie., has been started, but
		# is not yet finished).
		attr_reader :inProgress
		alias :inProgress? :inProgress
		alias :in_progress? :inProgress

		# Returns a human-readable String describing the object
		def to_s
			if self.inProgress?
				step = currentStep()
				"%s Questionnaire: %s: %s (%d of %d steps)." % [
					self.name,
					step[:name],
					step.has?(:question) ? step[:question] : step[:name].capitalize,
					@currentStepIndex + 1,
					@steps.length,
				]
			else
				"%s Questionnaire: Not in progress (%d steps)."
			end
		end


		#############################################################
		###	I O E V E N T F I L T E R   I N T E R F A C E
		#############################################################

		### Start filter notifications for the specified stream.
		def start( streamObject )
			results = super( streamObject )
			self.askNextQuestion
			@inProgress = true
			return results
		end


		### Stop the filter notifications for the specified stream, returning
		### any final events which should be dispatched on behalf of the filter.
		def stop( streamObject )
			results = super( streamObject )
			self.finish
			return results
		end


		### Mark the questionnaire as finished and prep it for shutdown
		def finish
			@inProgress = false
			@finalizer = nil
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
				unless self.inProgress?
					results = @finalizer.call( self ) if @finalizer
					self.finish
				end
			end

			return super( *events )
		end


		### Buffer the specified OutputEvents until the questionnaire is
		### finished or aborted.
		def handleOutputEvents( *events )
			self.queueDelayedOutputEvents( *events )
			events.clear
			return super( *events )
		end



		# End IOEventFilter interface

		### Get a reference to the current step.
		def currentStep
			@stepsMutex.synchronize( Sync::SH ) {
				@steps[ @currentStepIndex ]
			}
		end


		### Add non-blocked output <tt>events</tt> (such as from the filter
		### itself) to the queue that will go on the next io loop.
		def queueDelayedOutputEvents( *events )
			checkEachType( events, MUES::OutputEvent )

			@delayedOutputEventMutex.synchronize( Sync::EX ) {
				@delayedOutputEvents.push( *events )
			}

			return @delayedOutputEvents.size
		end



		### Insert the question for the next step into the stream.
		def askNextQuestion
			event = nil

			@stepsMutex.synchronize( Sync::EX ) {
				step = currentStep()

				# If the step has a question value, use it, otherwise use the
				# capitalized name.
				if step.has?( :question )
					if step[:question].kind_of? MUES::OutputEvent
						event = step[:question].dup
					elsif step[ :hidden ]
						event = MUES::HiddenInputPromptEvent( step[:question] )
					else
						event = MUES::PromptEvent( step[:question].to_s )
					end
				else
					event = MUES::PromptEvent( step[:name].capitalize + ": " )
				end
			}

			self.queueOutputEvents( event )
		end


		### Set the specified input <tt>data</tt> (a String) as the answer for
		### the current step, if it validates.
		def addAnswer( data )
			checkType( data, ::String )

			@stepsMutex.synchronize( Sync::EX ) {
				step = currentStep()
				result = nil

				# Validate the data if it has a validator.
				if step.has?( :validator )
					result = validateAnswer( data, step[:validator] ) or return nil

				# If the data's empty, do one of two things: if it has a default,
				# just use that, otherwise assume a blank input is an abort.
				elsif data.empty?
					if step.has?( :default )
						result = step[:default]
					else
						self.abort
						return nil
					end
				else
					result = data
				end

				# If we're still here, it means the answer validateed, so set it
				# for this question
				self.answers[ step[:name].intern ] = result
				@currentStepIndex += 1

				# Queue the next question and increment the index if we have
				# more steps. Otherwise, flag ourselves as no longer needing
				# input events
				if @currentStepIndex < @steps.length
					self.askNextQuestion
				else
					@inProgress = false
				end
			}

		end


		### Use the specified validator (a Proc, a Method, a Regexp, an Array,
		### or a Hash) to validate the given data. Returns the validated answer
		### data on success, and false if it fails to validate.
		def validateAnswer( data, validator )
			checkType( data, ::String )
			checkType( validator, ::Proc, ::Method, ::Regexp, ::Array, ::Hash )

			result = nil

			# Handle the various types of validators.
			case validator.type

			# Proc/Method validator - If the return value is false, validation
			# failed. If true, use the original data. Otherwise use whatever the
			# validator returns.
			when Proc, Method
				result = validator.call( self, data.dup ) or return nil
				result = data if result.equal?( true )
				

			# Regex validator - If the match has paren-groups, use the array of
			# "kept" matches instead of the whole match.
			when Regexp
				if (( match = validator.match( data ) ))
					if match.size > 1
						result = match.to_a[ 1 .. -1 ]
					else
						result = match[0]
					end
				else
					sendError( step[:errorMsg] || "Invalid input. Must "\
							   "match /#{validator.to_s}/" )
					return nil
				end

			# Array validator - Succeeds if the data is in the array.
			when Array
				if validator.include?( data )
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
				if validator.has_key?( data )
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
				raise Exception, "Invalid validator type '#{validator.type.name}'."
			end

			return result
		end


		### Reset the questionnaire, discarding answers given up to this point.
		def clear
			@stepsMutex.synchronize( Sync::EX ) {
				@answers = {}
				@currentStepIndex = 0
			}
		end


		### Abort the current session with the specified <tt>message</tt>. This
		### is a method designed to be used by callback-type answerspecs and
		### pre- and post-processes.
		def abort( message="Aborted." )
			self.queueOutputEvents MUES::OutputEvent::new( message )
			@inProgress = false
		end


		### Report an error
		def error( message )
			self.queueOutputEvents MUES::OutputEvent::new( message )
		end



		#########
		protected
		#########

		### Check each of the specified steps for validity.
		def checkSteps( *steps )
			checkEachResponse( steps, :[], :has? )

			if steps.find {|step| !step.has?( :name )}
				throw ArgumentError, "Invalid step: doesn't have a name key."
			end

			return steps
		end
		


	end # class Questionnaire
end # module MUES


#!/usr/bin/ruby -w

unless defined? MUES && defined? MUES::TestCase
	testsdir = File::dirname( File::expand_path(__FILE__) )
	basedir = File::dirname( testsdir )

	$LOAD_PATH.unshift "#{basedir}/lib" unless
		$LOAD_PATH.include?( "#{basedir}/lib" )
	$LOAD_PATH.unshift "#{basedir}/ext" unless
		$LOAD_PATH.include?( "#{basedir}/ext" )
	$LOAD_PATH.unshift "#{basedir}/tests" unless
		$LOAD_PATH.include?( "#{basedir}/tests" )

	require 'muestestcase'
end

require 'mues/filters/questionnaire'
require 'mues/ioeventstream'

class MockStream < Test::Unit::MockObject( MUES::IOEventStream )
	def initialize( *filters )
		super
		@inputEvents	= []
		@outputEvents	= []
	end
	attr_reader :inputEvents, :outputEvents
end

class MockInputEvent < Test::Unit::MockObject( MUES::InputEvent )
	def initialize( data )
		super
		@data = data
	end
	attr_reader :data
end


class QuestionnaireTestCase < MUES::TestCase

	TestSteps = [

		# Minimal step
		{
			:name		=> 'minimalStep',

			:passAnswers	=> %w{some test answers},
			:abortAnswers	=> [''],
		},

		# Regexp validator step
		{
			:name		=> 'regexpValidatorAnswer',
			:question	=> 'Question: ',
			:validator	=> /correct answer/i,
			:errorMsg	=> "Incorrect answer",

			:failAnswers	=> [ 'Waka-waka', 'correct', 'an answer' ],
			:passAnswers	=> [ 'correct answer', 'a correct answer', 'CorrECT ANsweR' ],
			:abortAnswers	=> [ '' ],
		},

		# Proc validator step
		{
			:name		=> 'question2',
			:question	=> 'Question: ',
			:validator	=> Proc::new {|questionnaire,answer|
				if answer.empty? || answer == 'abort'
					questionnaire.abort
					false

				elsif answer.downcase.split(//).uniq.join.length <= 5
					true

				else
					questionnaire.error("Answer must contain no more than 5 unique characters")
					false
				end
			},
			:errorMsg	=> "Answer must contain no more than 5 unique characters",

			:failAnswers	=> %w{foobazbarbim acquire eskimo},
			:passAnswers	=> %w{foofofooooooof belle inuit intuition},
			:abortAnswers	=> ['', 'abort'],
		},

		# Array validator step
		{
			:name		=> 'arrayValidatorAnswer',
			:question	=> 'Dwarf: ',
			:validator	=> %w{dopey bashful sneezy grumpy sleepy happy doc},
			:errorMsg	=> "That's not a dwarf!",

			:failAnswers	=> %w{dancer prancer donner blitzen},
			:passAnswers	=> %w{dopey bashful sneezy grumpy sleepy happy doc},
			:abortAnswers	=> [ '' ],
		},

		# Hash validator step
		{
			:name		=> 'hashValidatorAnswer',
			:question	=> 'Element: ',
			:validator	=> {
				'fe'		=> 'Iron',
				'al'		=> 'Aluminum',
				'ga'		=> 'Gallium',
				'sr'		=> 'Strontium',
			},
			:errorMsg	=> "Wrong!",

			:failAnswers	=> %w{boo pring tapau},
			:passAnswers	=> {
				'fe'		=> 'Iron',
				'al'		=> 'Aluminum',
				'ga'		=> 'Gallium',
				'sr'		=> 'Strontium',
			},
			:abortAnswers	=> [ '' ],
		},



	]


	# Setup method
	def setup
		super
		@mockStream = MockStream::new
	end


	#################################################################
	###	T E S T S
	#################################################################

	### Test classes
	def test_00_Classes
		printTestHeader "Questionnaire: Classes"
		assert_instance_of Class, MUES::Questionnaire
	end


	### Test instantiation with various arguments
	def test_10_InstantiateWithoutSteps
		qnaire = nil

		# A questionnaire requires at least a name.
		assert_raises( ArgumentError ) { qnaire = MUES::Questionnaire::new }

		# Make sure a questionnaire can be created with no steps
		assert_nothing_raised { qnaire = MUES::Questionnaire::new( "NameOnly" ) }
		assertValidQuestionnaire( qnaire )

		# Make sure starting without steps causes a RuntimeError
		assert_raises( RuntimeError ) { qnaire.start(@mockStream) }
	end


	### Test instantiation with steps
	def test_20_InstantiateWithSteps
		qnaire = nil

		printTestHeader "InstantiateWithSteps"

		assert_nothing_raised { qnaire = MUES::Questionnaire::new( *TestSteps ) }
		assertValidQuestionnaire( qnaire )

		assert_respond_to @mockStream, :update
		assert_nothing_raised { qnaire.start( @mockStream ) }
		assert qnaire.inProgress?

		# We'll need a questionnaire from now on, so instantiate one in set_up
		addSetupBlock {
			@qnaire = MUES::Questionnaire::new( "Test Quest" )
			@qnaire.debugLevel = 5 if $DEBUG
		}
		addTeardownBlock {
			@qnaire = nil
		}
	end


	### Test adding steps
	def test_30_AddSteps
		assert_nothing_raised { @qnaire.addSteps(*TestSteps) }
		assert_equal TestSteps.length, @qnaire.steps.length
	end


	### Build tests out of the test steps
	def test_40_Steps
		TestSteps.each {|step|
			printTestHeader "Testing step '%s'" % step[:name]

			@qnaire.removeSteps
			@qnaire.addSteps( step )

			@qnaire.start( @mockStream )
			assert @qnaire.inProgress?

			if step.key?( :failAnswers )
				step[:failAnswers].each do |ans|
					assert_nothing_raised { @qnaire.handleOutputEvents() }
					assertInputFails( @qnaire, step, ans )
					@qnaire.reset
				end
			end

			if step.key?( :passAnswers )
				step[:passAnswers].each do |*ans|
					assert_nothing_raised { @qnaire.handleOutputEvents() }

					assertInputPasses( @qnaire, step, *ans )
					@qnaire.reset
				end
			end

 			if step.key?( :abortAnswers )
 				step[:abortAnswers].each do |ans|
					assert_nothing_raised { @qnaire.handleOutputEvents() }
 					assertInputAborts( @qnaire, step, ans )
					@qnaire.reset
 				end
 			end
				
		}
	end


	### :TODO: Write tests for:
	### * Questionnaire#skipSteps + onSkip callback
	### * Questionnaire#undoSteps + onUndo callback
	### * 


	### Test a questionnaire object to make sure it's well-formed
	def assertValidQuestionnaire( qnaire )
		rval = nil

		assert_instance_of MUES::Questionnaire, qnaire
		[ :answers, :finalizer, :currentStepIndex, :inProgress?, :start,
			:stop, :finish, :handleInputEvents, :handleOutputEvents,
			:currentStep, :queueDelayedOutputEvents, :clear,
			:addSteps, :removeSteps, :skipSteps, :undoSteps,
			:clear, :abort, :error ].each {|meth|
			assert_respond_to qnaire, meth
		}
	end


	### Test a given input against a questionnaire object, and expect it to fail.
	def assertInputFails( qnaire, step, ans )
		MUES::Log.debug( "#%s: assertInputFails(%s, %s, %s)" %
						 [Thread.current.inspect, qnaire.inspect, step.inspect, ans.inspect] )
		ev = MockInputEvent::new( ans )
		assert_nothing_raised { qnaire.handleInputEvents(ev) }
		
		revs = qnaire.handleOutputEvents()
		assert_kind_of MUES::OutputEvent, revs[0]

		if step.key?( :errorMsg )
			assert_equal step[:errorMsg], revs[0].data
		else
			assert_match( /Invalid input\. Must (match|be one of)/,
				revs[0].data )
		end
	end


	### Test a given input against a questionnaire object, and expect it to
	### succeed.
	def assertInputPasses( qnaire, step, ans, expected=ans )
		MUES::Log.debug( "#%s: assertInputPasses(%s, %s, %s, %s)" %
						 [Thread.current.inspect, qnaire.inspect, step.inspect,
							ans.inspect, expected.inspect] )
		qnaire.debugLevel = 5

		ev = MockInputEvent::new( ans )
		assert_nothing_raised { qnaire.handleInputEvents(ev) }
		
		revs = qnaire.handleOutputEvents()
		assert revs.empty?,
			"Unexpected output event <#{revs[0].inspect}> in finished questionnaire."

		assert qnaire.finished?, "Questionnaire is not finished"
		assert qnaire.answers.key?( step[:name].intern ),
			"Questionnaire doesn't have a ':%s' answer key" % step[:name]
		assert_equal expected, qnaire.answers[ step[:name].intern ]
	end


	### Test a given input against a questionnaire object, and expect it to
	### succeed.
	def assertInputAborts( qnaire, step, ans )
		qnaire.debugLevel = 5
		MUES::Log.debug( "#%s: assertInputAborts(%s, %s, %s)" %
						 [Thread.current.inspect, qnaire.inspect, step.inspect, ans.inspect] )

		ev = MockInputEvent::new( ans )
		assert_nothing_raised { qnaire.handleInputEvents(ev) }
		
		revs = qnaire.handleOutputEvents()
		assert_kind_of MUES::OutputEvent, revs[0]
		assert qnaire.finished?, "Questionnaire wasn't finished after abort input."
	end

end # class QuestionnaireTestCase


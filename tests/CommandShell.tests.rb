#!/usr/bin/ruby -w
#
# Unit tests for the MUES::CommandShell.
#
# == Rcsid
# 
#  $Id: CommandShell.tests.rb,v 1.7 2003/10/13 06:26:54 deveiant Exp $
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
# 

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

require 'mues/filters/commandshell'
require 'mues/user'

class MUES::CommandShellTestCase < MUES::TestCase

	# Initial setup method. Overridden later after testing setup stuff
	def setup
		@shells = {}
		super
	end

	def teardown
		super
		@shells = nil
	end


	### Test instantiation of the shell factory, then add a factory to the setup
	def test_00_InstantiateFactory
		printTestHeader "Testing factory instantiation"
		shellFactory	= nil

		# Test instantiation of the shell factory
		assert_nothing_raised {
			shellFactory = MUES::CommandShell::Factory::
				new(["server/shellCommands", "../server/shellCommands"])
		}
		assert_instance_of MUES::CommandShell::Factory, shellFactory

		# Add the setup method now that factory instantiation has been
		# tested
		addSetupBlock {
			@shellFactory = MUES::CommandShell::Factory::
				new(["server/shellCommands", "../server/shellCommands"])
		}
		addTeardownBlock {
			@shellFactory = nil
		}
	end

	### Test the commandshell factory
	def test_01_Factory
		printTestHeader "Testing factory object"
		rval = nil

		{
			:registry				=> Hash,
			:commandPath			=> Array,
			:parserClass			=> Class,
			:loadNewCommands		=> Array,
			:buildCommandRegistry	=> nil,
			:rebuildCommandRegistry	=> nil,
		}.each {|sym,expected|
			debugMsg "...method #{sym.to_s}"
			rval = nil
			assert_respond_to @shellFactory, sym
			assert_nothing_raised { rval = @shellFactory.send(sym) }
			if expected
				assert_instance_of expected, rval
			end
		}

		# Will test this method more thoughly below...
		assert_respond_to @shellFactory, :createShellForUser

	end


  ### MUES::CommandShell::Command tests

	### Test shell command sets to see if they have the correct subsets for
	### their user types.
	def test_10_CommandObjects
		printTestHeader "Testing command objects"

		@shellFactory.registry.values.uniq {|cmd|
			debugMsg "...#{cmd.to_s}"
			assert_instance_of	MUES::CommandShell::Command, cmd
			assert_respond_to	cmd, :invoke

			# Test for attribute accessors
			[ :abstract, :description, :name, :restriction,
				:sourceFile, :sourceLine, :synonyms, :usage ].each {|sym|
				rval = nil
				assert_respond_to cmd, sym
				assert_nothing_raised { rval = cmd.send( sym ) }
				assert_not_nil rval
			}

		}
	end


  ### MUES::CommandShell tests

	### Test instantiation of shells from the factory, then adds shells to the
	### factory.
	def test_20_InstantiateShells
		shells = {}

		# :TODO: Update this when user-priv stuff is done
	end


end # class MUES::CommandShellTestCase

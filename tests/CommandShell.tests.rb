#!/usr/bin/ruby -w
#
# Unit tests for the MUES::CommandShell.
#
# == Rcsid
# 
#  $Id: CommandShell.tests.rb,v 1.5 2003/09/12 04:34:41 deveiant Exp $
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

begin
	require 'tests/muestestcase'
rescue
	require '../muestestcase'
end

require 'mues/filters/CommandShell'
require 'mues/User'

module MUES
	class CommandShellTestCase < MUES::TestCase

		# Different types of users to test shells for
		@@Users = {}
		MUES::User::AccountType::Map.each {|name,type|
			@@Users[name.intern] = MUES::User::new( :accountType => type, :username => "#{name}TestUser" )
		}

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

			# Test creating a shell for each of the user types
			@@Users.each {|sym,user|

				# Test instantiation of each type of shell
				assert_nothing_raised {
					shells[sym] = @shellFactory.createShellForUser( user )
				}

				assert_instance_of MUES::CommandShell, shells[sym]
			}

			# Redefine the setup method now that both factory and shell
			# instantiation have been tested
			addSetupBlock {
				@@Users.each {|sym,user|
					@shells[sym] = @shellFactory.createShellForUser( user )
				}
			}
		end


	end # class CommandShellTestCase
end # module MUES

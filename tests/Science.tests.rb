require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Science.rb'

module MUES
	class MockScience < Science
	end

	class TestScience < RUNIT::TestCase

		$mockScience = nil

		def setup
			super
			$mockScience = MockScience.new
		end

		def teardown
			mockScience = nil
			super
		end

		def test_New
			assert_exception( InstantiationError ) {
				Science.new
			}
		end

		def test_DerivedNew
			assert_kind_of( Science, $mockScience )
		end

	end
end


if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::TestScience.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::TestScience.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Engine.rb'

module MUES
	class TestEngine < RUNIT::TestCase

		def setup
			$Engine = MUES::Engine.instance
		end

		def teardown
			$Engine = nil
		end

		def test_s_instance
			assert_instance_of( MUES::Engine, $Engine )
			assert_equals( $Engine, MUES::Engine.instance )
		end

	end
end

if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::TestEngine.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::TestEngine.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

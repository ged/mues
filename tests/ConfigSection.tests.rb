require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Config.rb'

class ConfigSectionTestCase < RUNIT::TestCase

	$SectionObj = nil
	$SectionName = "testsection"
	$DumpedSection = <<-EOF
testitem "testval"
	EOF

	def setup
		super
		$SectionObj = Config::Section.new( $SectionName )
	end

	def teardown
		$SectionObj = nil
		super
	end

	def test_AREF # '[]'
		assert_no_exception {
			$SectionObj["nonexistant"]
		}
	end

	def test_ASET # '[]='
		assert_no_exception {
			$SectionObj['testNumeric'] = 1
		}
		assert_equals( $SectionObj['testNumeric'], 1 )
		assert_equals( $SectionObj['TESTNUMERIC'], 1 )
		assert_no_exception {
			$SectionObj['testString'] = "testval"
		}
		assert_equals( $SectionObj['testNumeric'], 1 )
		assert_no_exception {
			$SectionObj['testSection'] = Config::Section.new( "notherTestSection" )
		}
		assert_instance_of( Config::Section, $SectionObj['testSection'] )
		assert_no_exception {
			$SectionObj['testTrue'] = true
		}
		assert_equals( $SectionObj['testTrue'], true )
		assert_no_exception {
			$SectionObj['testFalse'] = false
		}
		assert_equals( $SectionObj['testFalse'], false )
	end

	def test_dump
		$SectionObj['testitem'] = 'testval'
		assert_equals( $DumpedSection, $SectionObj.dump )
	end

	def test_has_key?
		$SectionObj['testkey'] = true
		assert( $SectionObj.has_key?('testkey') )
		assert( $SectionObj.has_key?('TESTKEY') )
	end

	def test_include?
		$SectionObj['testkey'] = true
		assert( $SectionObj.include?('testkey') )
		assert( $SectionObj.include?('TESTKEY') )
	end

	def test_key?
		$SectionObj['testkey'] = true
		assert( $SectionObj.key?('testkey') )
		assert( $SectionObj.key?('TESTKEY') )
	end

	def test_name
		assert_equals( $SectionObj.name, $SectionName )
	end

	def test_s_new
		assert_instance_of( Config::Section, $SectionObj )
	end

end

if $0 == __FILE__
	if ARGV.size == 0
		suite = ConfigSectionTestCase.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(ConfigSectionTestCase.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

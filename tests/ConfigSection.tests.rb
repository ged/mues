#!/usr/bin/ruby

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Config.rb'

module MUES
	class ConfigSectionTestCase < MUES::TestCase

		$SectionObj = nil
		$SectionName = "testsection"
		$DumpedSection = <<-EOF
testitem "testval"
		EOF


		def set_up
			$SectionObj = Config::Section.new( $SectionName )
		end


		def tear_down
			$SectionObj = nil
		end


		def test_AREF # '[]'
			assert_nothing_raised {
				$SectionObj["nonexistant"]
			}
		end


		def test_ASET # '[]='
			assert_nothing_raised {
				$SectionObj['testNumeric'] = 1
			}
			assert_equal $SectionObj['testNumeric'], 1
			assert_equal $SectionObj['TESTNUMERIC'], 1
			assert_nothing_raised {
				$SectionObj['testString'] = "testval"
			}
			assert_equal $SectionObj['testNumeric'], 1
			assert_nothing_raised {
				$SectionObj['testSection'] = Config::Section.new( "notherTestSection" )
			}
			assert_instance_of Config::Section, $SectionObj['testSection']
			assert_nothing_raised {
				$SectionObj['testTrue'] = true
			}
			assert_equal $SectionObj['testTrue'], true
			assert_nothing_raised {
				$SectionObj['testFalse'] = false
			}
			assert_equal $SectionObj['testFalse'], false
		end


		def test_dump
			$SectionObj['testitem'] = 'testval'
			assert_equal $DumpedSection, $SectionObj.dump
		end


		def test_has_key?
			$SectionObj['testkey'] = true
			assert $SectionObj.has_key?('testkey')
			assert $SectionObj.has_key?('TESTKEY')
		end


		def test_include?
			$SectionObj['testkey'] = true
			assert $SectionObj.include?('testkey')
			assert $SectionObj.include?('TESTKEY')
		end


		def test_key?
			$SectionObj['testkey'] = true
			assert $SectionObj.key?('testkey')
			assert $SectionObj.key?('TESTKEY')
		end


		def test_name
			assert_equal $SectionObj.name, $SectionName
		end


		def test_s_new
			assert_instance_of Config::Section, $SectionObj
		end

	end # class ConfigSectionTestCase

end # module MUES


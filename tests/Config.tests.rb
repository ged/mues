#!/usr/bin/ruby -w

require 'runit/testcase'
require 'runit/cui/testrunner'

require 'mues/Config.rb'

module MUES
	class ConfigTestCase < RUNIT::TestCase

		$ConfigFile = "test.cfg"
		$ConfigContent = <<-EOF
testitem "testval"

<testsection>
	testitem "testval"
</testsection>
		EOF
		$ConfigObj = nil

		def setup
			super
			File.open($ConfigFile, "w") { |f|
				f.print $ConfigContent
			}
			$ConfigObj = Config.new
		end

		def teardown
			$ConfigObj = nil
			File.delete( $ConfigFile )
			super
		end

		def test_AREF # '[]'
			assert_no_exception {
				$ConfigObj["testsection"]
			}
		end

		def test_ASET # '[]='
			assert_no_exception {
				$ConfigObj["testsection"] = true
			}
			assert( $ConfigObj["testsection"] )
		end

		def test_dump
			$ConfigObj = Config.new( $ConfigFile )
			assert_equal( $ConfigObj.dump, $ConfigContent )
		end

		def test_new
			assert_instance_of( Config, $ConfigObj )
		end

		def test_newWithNonExistantFile
			assert_exception( Errno::ENOENT ) {
				$ConfigObj = Config.new( "blorg" )
			}
		end

		def test_GetMainConfigValue
			$ConfigObj = Config.new( $ConfigFile )
			assert_equal( $ConfigObj["testitem"], "testval" )
		end

		def test_GetSection
			$ConfigObj = Config.new( $ConfigFile )
			assert_instance_of( Config::Section, $ConfigObj["testsection"] )
		end

		def test_GetSectionConfigValue
			$ConfigObj = Config.new( $ConfigFile )
			assert_equal( $ConfigObj["testsection"]["testitem"], "testval" )
		end

	end

end


if $0 == __FILE__
	if ARGV.size == 0
		suite = MUES::ConfigTestCase.suite
	else
		suite = RUNIT::TestSuite.new
		ARGV.each do |testmethod|
			suite.add_test(MUES::ConfigTestCase.new(testmethod))
		end
	end
	RUNIT::CUI::TestRunner.run(suite)
end

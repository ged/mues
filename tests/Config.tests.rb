#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/Config.rb'

module MUES
	class ConfigTestCase < MUES::TestCase

		$ConfigFile = "test.cfg"
		$ConfigContent = <<-EOF
testitem "testval"

<testsection>
	testitem "testval"
</testsection>
		EOF
		$ConfigObj = nil

		def set_up
			super
			File.open($ConfigFile, "w") { |f|
				f.print $ConfigContent
			}
			$ConfigObj = Config.new
		end

		def tear_down
			$ConfigObj = nil
			File.delete( $ConfigFile )
			super
		end

		def test_AREF # '[]'
			assert_nothing_raised {
				$ConfigObj["testsection"]
			}
		end

		def test_ASET # '[]='
			assert_nothing_raised {
				$ConfigObj["testsection"] = true
			}
			assert( $ConfigObj["testsection"] )
		end

		def test_dump
			$ConfigObj = Config.new( $ConfigFile )
			assert_equal $ConfigObj.dump, $ConfigContent
		end

		def test_new
			assert_instance_of MUES::Config, $ConfigObj
		end

		def test_newWithNonExistantFile
			assert_raises( Errno::ENOENT ) {
				$ConfigObj = Config.new( "blorg" )
			}
		end

		def test_GetMainConfigValue
			$ConfigObj = Config.new( $ConfigFile )
			assert_equal $ConfigObj["testitem"], "testval"
		end

		def test_GetSection
			$ConfigObj = Config.new( $ConfigFile )
			assert_instance_of Config::Section, $ConfigObj["testsection"]
		end

		def test_GetSectionConfigValue
			$ConfigObj = Config.new( $ConfigFile )
			assert_equal $ConfigObj["testsection"]["testitem"], "testval"
		end

	end

end


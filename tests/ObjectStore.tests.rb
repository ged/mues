#!/usr/bin/ruby -w

begin
	require 'tests/muesunittest'
rescue
	require '../muesunittest'
end

require 'mues/ObjectStore'

class ObjectStoreTestCase < MUES::TestCase

	TestOSConfig = {
		:name		=> 'teststore',
		:backend	=> 'Flatfile',
		:memmgr		=> 'Null',
	}

	### Test instantiation with various arguments
	def test_Instantiate
		os = nil
		
		# Instantiation via new() should fail
		assert_raises( NoMethodError ) { MUES::ObjectStore::new }
		assert_raises( TypeError ) { MUES::ObjectStore::create(1) }

		# However, instantiation via create() should work
		assert_nothing_raised {
			os = MUES::ObjectStore::create(TestOSConfig)
		}
	end

end # class ObjectStoreTestCase

